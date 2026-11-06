import HealthKit

/// One day of figures, in the shape `scripts/record-health.mjs` expects. Missing figures are left out of the JSON.
struct DailySummary: Codable, Equatable {
    var date: String
    var steps: Int?
    var sleepMinutes: Int?
    var restingHeartRate: Int?
    var exerciseMinutes: Int?
    var workouts: Int?

    var isEmpty: Bool { steps == nil && sleepMinutes == nil && restingHeartRate == nil && exerciseMinutes == nil && (workouts ?? 0) == 0 }
}

final class HealthReader {
    static let shared = HealthReader()
    let store = HKHealthStore()

    static let readTypes: Set<HKObjectType> = [
        HKQuantityType(.stepCount),
        HKQuantityType(.restingHeartRate),
        HKQuantityType(.appleExerciseTime),
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

    /// Totals for the calendar day containing `day`. Sleep is the night that ends the following morning
    /// (18:00 on `day` to 12:00 the next day), so a summary sent in the morning covers the night just slept.
    func summary(for day: Date, calendar: Calendar = .current) async throws -> DailySummary {
        let start = calendar.startOfDay(for: day)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        let sleepStart = calendar.date(byAdding: .hour, value: 18, to: start)!
        let sleepEnd = calendar.date(byAdding: .hour, value: 12, to: end)!

        async let steps = statistic(.stepCount, .cumulativeSum, unit: .count(), from: start, to: end)
        async let exercise = statistic(.appleExerciseTime, .cumulativeSum, unit: .minute(), from: start, to: end)
        async let resting = statistic(.restingHeartRate, .discreteAverage, unit: .count().unitDivided(by: .minute()), from: start, to: end)
        async let workouts = workoutCount(from: start, to: end)
        async let sleep = sleepMinutes(from: sleepStart, to: sleepEnd)

        return DailySummary(
            date: Self.dayFormatter.string(from: start),
            steps: try await steps.map(rounded),
            sleepMinutes: try await sleep.map(rounded),
            restingHeartRate: try await resting.map(rounded),
            exerciseMinutes: try await exercise.map(rounded),
            workouts: try await workouts
        )
    }

    private func rounded(_ value: Double) -> Int { Int(value.rounded()) }

    /// Statistics queries merge overlapping iPhone and Apple Watch samples the way the Health app does.
    private func statistic(_ id: HKQuantityTypeIdentifier, _ option: HKStatisticsOptions, unit: HKUnit, from start: Date, to end: Date) async throws -> Double? {
        let predicate = HKSamplePredicate.quantitySample(type: HKQuantityType(id), predicate: HKQuery.predicateForSamples(withStart: start, end: end))
        do {
            let statistics = try await HKStatisticsQueryDescriptor(predicate: predicate, options: option).result(for: store)
            let quantity = option == .cumulativeSum ? statistics?.sumQuantity() : statistics?.averageQuantity()
            return quantity?.doubleValue(for: unit)
        } catch HKError.errorNoData {
            return nil
        }
    }

    private func workoutCount(from start: Date, to end: Date) async throws -> Int {
        let predicate = HKSamplePredicate.workout(HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate))
        return try await HKSampleQueryDescriptor(predicates: [predicate], sortDescriptors: []).result(for: store).count
    }

    /// Asleep stages only (core, deep, REM, unspecified). Overlapping samples from several sources are merged so no minute counts twice.
    private func sleepMinutes(from start: Date, to end: Date) async throws -> Double? {
        let asleep = HKCategoryValueSleepAnalysis.allAsleepValues.map(\.rawValue)
        let predicate = HKSamplePredicate.categorySample(type: HKCategoryType(.sleepAnalysis), predicate: HKQuery.predicateForSamples(withStart: start, end: end))
        let samples = try await HKSampleQueryDescriptor(predicates: [predicate], sortDescriptors: [SortDescriptor(\.startDate)]).result(for: store)
        let intervals = samples
            .filter { asleep.contains($0.value) }
            .map { (max($0.startDate, start), min($0.endDate, end)) }
            .filter { $0.0 < $0.1 }
        guard !intervals.isEmpty else { return nil }

        var total: TimeInterval = 0
        var current = intervals[0]
        for interval in intervals.dropFirst() {
            if interval.0 <= current.1 {
                current.1 = max(current.1, interval.1)
            } else {
                total += current.1.timeIntervalSince(current.0)
                current = interval
            }
        }
        total += current.1.timeIntervalSince(current.0)
        return total / 60
    }
}
