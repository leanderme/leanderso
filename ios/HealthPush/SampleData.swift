#if DEBUG
import HealthKit

/// Writes recognisable figures into the Simulator's Health store to test the summary.
/// Each night has overlapping sleep samples, so the merged total should be exactly 7 h 30 min.
enum SampleData {
    static let writeTypes: Set<HKSampleType> = [HKQuantityType(.stepCount), HKCategoryType(.sleepAnalysis), HKObjectType.workoutType()]

    static func add() async -> String {
        let store = HealthReader.shared.store
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        var samples: [HKSample] = []
        do {
            for offset in 1...30 {
                let day = calendar.date(byAdding: .day, value: -offset, to: today)!
                let at = { (hour: Int, minute: Int) in calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)! }
                let nextMorning = { (hour: Int, minute: Int) in calendar.date(byAdding: .day, value: 1, to: at(hour, minute))! }
                for (hour, steps) in [(8, 2000), (12, 3000 + offset * 50), (18, 3000)] {
                    samples.append(HKQuantitySample(type: HKQuantityType(.stepCount), quantity: HKQuantity(unit: .count(), doubleValue: Double(steps)), start: at(hour, 0), end: at(hour, 45)))
                }
                let sleep = HKCategoryType(.sleepAnalysis)
                samples += [
                    HKCategorySample(type: sleep, value: HKCategoryValueSleepAnalysis.inBed.rawValue, start: at(22, 50), end: nextMorning(7, 0)),
                    HKCategorySample(type: sleep, value: HKCategoryValueSleepAnalysis.asleepCore.rawValue, start: at(23, 10), end: nextMorning(3, 0)),
                    HKCategorySample(type: sleep, value: HKCategoryValueSleepAnalysis.asleepDeep.rawValue, start: nextMorning(3, 0), end: nextMorning(4, 0)),
                    HKCategorySample(type: sleep, value: HKCategoryValueSleepAnalysis.asleepREM.rawValue, start: nextMorning(4, 0), end: nextMorning(6, 40)),
                    HKCategorySample(type: sleep, value: HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue, start: at(23, 30), end: nextMorning(6, 30)),
                ]
                if offset % 2 == 1 {
                    let configuration = HKWorkoutConfiguration()
                    configuration.activityType = .running
                    let builder = HKWorkoutBuilder(healthStore: store, configuration: configuration, device: nil)
                    try await builder.beginCollection(at: at(7, 0))
                    try await builder.endCollection(at: at(7, 40))
                    _ = try await builder.finishWorkout()
                }
            }
            try await store.save(samples)
            return "Added 30 days. Yesterday should read 8,050 steps, 7 h 30 min sleep and 1 workout."
        } catch {
            return error.localizedDescription
        }
    }
}
#endif
