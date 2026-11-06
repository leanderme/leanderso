#if DEBUG
import HealthKit

/// Writes recognisable figures into the Simulator's Health store to test the summary.
/// Each night has overlapping sleep samples, so the merged total should be exactly 7 h 30 min.
/// Over the last 7 days: 8,200 steps a day, 42 km, 450 kcal a day, 6 workouts (running 160 min, strength 70 min),
/// 52 ms HRV and a latest VO₂ max of 45.2.
enum SampleData {
    static let writeTypes: Set<HKSampleType> = [
        HKQuantityType(.stepCount), HKQuantityType(.distanceWalkingRunning), HKQuantityType(.activeEnergyBurned),
        HKQuantityType(.heartRateVariabilitySDNN), HKQuantityType(.vo2Max),
        HKCategoryType(.sleepAnalysis), HKObjectType.workoutType(),
    ]

    static func add() async -> String {
        let store = HealthReader.shared.store
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        var samples: [HKSample] = []
        let quantity = { (id: HKQuantityTypeIdentifier, unit: HKUnit, value: Double, start: Date, end: Date) in
            HKQuantitySample(type: HKQuantityType(id), quantity: HKQuantity(unit: unit, doubleValue: value), start: start, end: end)
        }
        do {
            for offset in 1...30 {
                let day = calendar.date(byAdding: .day, value: -offset, to: today)!
                let at = { (hour: Int, minute: Int) in calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)! }
                let nextMorning = { (hour: Int, minute: Int) in calendar.date(byAdding: .day, value: 1, to: at(hour, minute))! }
                for (hour, steps, meters, kcal) in [(8, 2000, 1500, 120), (12, 3000 + offset * 50, 2300, 180), (18, 3000, 2200, 150)] {
                    samples.append(quantity(.stepCount, .count(), Double(steps), at(hour, 0), at(hour, 45)))
                    samples.append(quantity(.distanceWalkingRunning, .meter(), Double(meters), at(hour, 0), at(hour, 45)))
                    samples.append(quantity(.activeEnergyBurned, .kilocalorie(), Double(kcal), at(hour, 0), at(hour, 45)))
                }
                samples.append(quantity(.heartRateVariabilitySDNN, .secondUnit(with: .milli), 52, at(6, 0), at(6, 1)))
                if offset % 3 == 1 { samples.append(quantity(.vo2Max, HKUnit(from: "ml/kg*min"), 45.2, at(7, 40), at(7, 40))) }

                let sleep = HKCategoryType(.sleepAnalysis)
                samples += [
                    HKCategorySample(type: sleep, value: HKCategoryValueSleepAnalysis.inBed.rawValue, start: at(22, 50), end: nextMorning(7, 0)),
                    HKCategorySample(type: sleep, value: HKCategoryValueSleepAnalysis.asleepCore.rawValue, start: at(23, 10), end: nextMorning(3, 0)),
                    HKCategorySample(type: sleep, value: HKCategoryValueSleepAnalysis.asleepDeep.rawValue, start: nextMorning(3, 0), end: nextMorning(4, 0)),
                    HKCategorySample(type: sleep, value: HKCategoryValueSleepAnalysis.asleepREM.rawValue, start: nextMorning(4, 0), end: nextMorning(6, 40)),
                    HKCategorySample(type: sleep, value: HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue, start: at(23, 30), end: nextMorning(6, 30)),
                ]

                var workouts: [(HKWorkoutActivityType, Date, Date)] = []
                if offset % 2 == 1 { workouts.append((.running, at(7, 0), at(7, 40))) }
                if offset % 3 == 0 { workouts.append((.traditionalStrengthTraining, at(19, 0), at(19, 35))) }
                for (type, start, end) in workouts {
                    let configuration = HKWorkoutConfiguration()
                    configuration.activityType = type
                    let builder = HKWorkoutBuilder(healthStore: store, configuration: configuration, device: nil)
                    try await builder.beginCollection(at: start)
                    try await builder.endCollection(at: end)
                    _ = try await builder.finishWorkout()
                }
            }
            try await store.save(samples)
            return "Added 30 days. The last 7 should read 8,200 steps a day, 42 km, 450 kcal, 6 workouts (running 160 min, strength 70 min), 7:30 sleep, 52 ms HRV, VO₂ max 45.2."
        } catch {
            return error.localizedDescription
        }
    }
}
#endif
