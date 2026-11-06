import HealthKit

/// One day of figures, in the shape `scripts/record-health.mjs` expects. Missing figures are left out of the JSON.
struct DailySummary: Codable, Equatable {
    var date: String
    var steps: Int?
    var distanceMeters: Int?
    var activeEnergy: Int?
    var exerciseMinutes: Int?
    var workouts: Int?
    var workoutMinutes: [String: Int]?
    var sleepMinutes: Int?
    var restingHeartRate: Int?
    var hrv: Int?
    var vo2Max: Double?

    var isEmpty: Bool {
        steps == nil && distanceMeters == nil && activeEnergy == nil && exerciseMinutes == nil && (workouts ?? 0) == 0
            && sleepMinutes == nil && restingHeartRate == nil && hrv == nil && vo2Max == nil
    }
}

final class HealthReader {
    static let shared = HealthReader()
    let store = HKHealthStore()

    static let readTypes: Set<HKObjectType> = [
        HKQuantityType(.stepCount),
        HKQuantityType(.distanceWalkingRunning),
        HKQuantityType(.activeEnergyBurned),
        HKQuantityType(.appleExerciseTime),
        HKQuantityType(.restingHeartRate),
        HKQuantityType(.heartRateVariabilitySDNN),
        HKQuantityType(.vo2Max),
        HKCategoryType(.sleepAnalysis),
        HKObjectType.workoutType(),
    ]

    static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    func requestAuthorization() async throws {
        #if DEBUG
        try await store.requestAuthorization(toShare: SampleData.writeTypes, read: Self.readTypes)
        #else
        try await store.requestAuthorization(toShare: [], read: Self.readTypes)
        #endif
    }

    /// Daily summaries for the `count` complete days before today, oldest first. Sleep for a day is the night that
    /// ends the following morning (18:00 to 12:00), so a summary sent in the morning covers the night just slept.
    func summaries(days count: Int, calendar: Calendar = .current) async throws -> [DailySummary] {
        let today = calendar.startOfDay(for: .now)
        let days = (1...count).reversed().map { calendar.date(byAdding: .day, value: -$0, to: today)! }
        let start = days[0]

        async let steps = daily(.stepCount, .cumulativeSum, .count(), from: start, to: today)
        async let distance = daily(.distanceWalkingRunning, .cumulativeSum, .meter(), from: start, to: today)
        async let energy = daily(.activeEnergyBurned, .cumulativeSum, .kilocalorie(), from: start, to: today)
        async let exercise = daily(.appleExerciseTime, .cumulativeSum, .minute(), from: start, to: today)
        async let resting = daily(.restingHeartRate, .discreteAverage, .count().unitDivided(by: .minute()), from: start, to: today)
        async let hrv = daily(.heartRateVariabilitySDNN, .discreteAverage, .secondUnit(with: .milli), from: start, to: today)
        async let vo2 = daily(.vo2Max, .discreteAverage, HKUnit(from: "ml/kg*min"), from: start, to: today)
        async let workouts = workoutsByDay(from: start, to: today, calendar: calendar)
        async let sleep = sleepByDay(days, calendar: calendar)

        let (stepValues, distanceValues, energyValues, exerciseValues, restingValues, hrvValues, vo2Values) =
            try await (steps, distance, energy, exercise, resting, hrv, vo2)
        let (workoutValues, sleepValues) = try await (workouts, sleep)
        let round = { (value: Double?) in value.map { Int($0.rounded()) } }

        return days.map { day in
            DailySummary(
                date: Self.dayFormatter.string(from: day),
                steps: round(stepValues[day]),
                distanceMeters: round(distanceValues[day]),
                activeEnergy: round(energyValues[day]),
                exerciseMinutes: round(exerciseValues[day]),
                workouts: workoutValues[day]?.count ?? 0,
                workoutMinutes: workoutValues[day]?.minutes,
                sleepMinutes: round(sleepValues[day]),
                restingHeartRate: round(restingValues[day]),
                hrv: round(hrvValues[day]),
                vo2Max: vo2Values[day].map { ($0 * 10).rounded() / 10 }
            )
        }
    }

    /// One statistics collection per metric, bucketed by calendar day. Statistics queries merge overlapping
    /// iPhone and Apple Watch samples the way the Health app does, so nothing is counted twice.
    private func daily(_ id: HKQuantityTypeIdentifier, _ option: HKStatisticsOptions, _ unit: HKUnit, from start: Date, to end: Date) async throws -> [Date: Double] {
        let predicate = HKSamplePredicate.quantitySample(type: HKQuantityType(id), predicate: HKQuery.predicateForSamples(withStart: start, end: end))
        let descriptor = HKStatisticsCollectionQueryDescriptor(predicate: predicate, options: option, anchorDate: start, intervalComponents: DateComponents(day: 1))
        let collection: HKStatisticsCollection
        do {
            collection = try await descriptor.result(for: store)
        } catch HKError.errorNoData {
            return [:]
        }
        var values: [Date: Double] = [:]
        collection.enumerateStatistics(from: start, to: end) { statistics, _ in
            let quantity = option == .cumulativeSum ? statistics.sumQuantity() : statistics.averageQuantity()
            if let quantity { values[statistics.startDate] = quantity.doubleValue(for: unit) }
        }
        return values
    }

    private func workoutsByDay(from start: Date, to end: Date, calendar: Calendar) async throws -> [Date: (count: Int, minutes: [String: Int])] {
        let predicate = HKSamplePredicate.workout(HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate))
        let workouts = try await HKSampleQueryDescriptor(predicates: [predicate], sortDescriptors: []).result(for: store)
        var result: [Date: (count: Int, minutes: [String: Int])] = [:]
        for workout in workouts {
            let day = calendar.startOfDay(for: workout.startDate)
            var entry = result[day] ?? (0, [:])
            entry.count += 1
            entry.minutes[Self.activityName(workout.workoutActivityType), default: 0] += Int((workout.duration / 60).rounded())
            result[day] = entry
        }
        return result
    }

    /// Asleep stages only (core, deep, REM, unspecified). Overlapping samples from several sources are merged so no minute counts twice.
    private func sleepByDay(_ days: [Date], calendar: Calendar) async throws -> [Date: Double] {
        let windows = days.map { day in
            (day, calendar.date(byAdding: .hour, value: 18, to: day)!, calendar.date(byAdding: .hour, value: 36, to: day)!)
        }
        let asleep = HKCategoryValueSleepAnalysis.allAsleepValues.map(\.rawValue)
        let predicate = HKSamplePredicate.categorySample(type: HKCategoryType(.sleepAnalysis), predicate: HKQuery.predicateForSamples(withStart: windows[0].1, end: windows.last!.2))
        let samples = try await HKSampleQueryDescriptor(predicates: [predicate], sortDescriptors: [SortDescriptor(\.startDate)]).result(for: store)
            .filter { asleep.contains($0.value) }

        var result: [Date: Double] = [:]
        for (day, start, end) in windows {
            let intervals = samples
                .map { (max($0.startDate, start), min($0.endDate, end)) }
                .filter { $0.0 < $0.1 }
            guard var current = intervals.first else { continue }
            var total: TimeInterval = 0
            for interval in intervals.dropFirst() {
                if interval.0 <= current.1 {
                    current.1 = max(current.1, interval.1)
                } else {
                    total += current.1.timeIntervalSince(current.0)
                    current = interval
                }
            }
            total += current.1.timeIntervalSince(current.0)
            result[day] = total / 60
        }
        return result
    }

    /// Workout type keys understood by the website (`workoutNames` in src/sections.mjs).
    static func activityName(_ type: HKWorkoutActivityType) -> String {
        switch type {
        case .running: "running"
        case .walking: "walking"
        case .hiking: "hiking"
        case .cycling, .handCycling: "cycling"
        case .swimming: "swimming"
        case .rowing: "rowing"
        case .elliptical, .stairClimbing, .stairs: "elliptical"
        case .traditionalStrengthTraining, .functionalStrengthTraining: "strength"
        case .coreTraining: "core"
        case .highIntensityIntervalTraining, .crossTraining, .mixedCardio: "hiit"
        case .yoga, .mindAndBody: "yoga"
        case .pilates: "pilates"
        case .flexibility, .preparationAndRecovery, .cooldown: "mobility"
        case .tennis, .pickleball, .squash, .badminton, .tableTennis: "tennis"
        case .soccer: "football"
        default: "other"
        }
    }
}
