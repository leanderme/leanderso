import BackgroundTasks
import Foundation
import HealthKit

/// Sends the last `daysToSend` days to the website repository once a day, after `sendAfterHour`, as a GitHub repository_dispatch event.
/// Resending earlier days fills gaps and picks up data the Watch synced late; unchanged days produce no commit.
@MainActor
final class Sender: ObservableObject {
    static let shared = Sender()
    nonisolated static let refreshTask = "so.leander.healthpush.refresh"
    nonisolated static let sendAfterHour = 9
    nonisolated static let daysToSend = 30

    @Published private(set) var lastSummary: DailySummary?
    @Published private(set) var lastSentAt: Date?
    @Published private(set) var status: String?
    @Published private(set) var isSending = false
    /// Days with data per metric label in the last `daysToSend` days, from the most recent check or send.
    @Published private(set) var coverage: [String: Int] = [:]
    @Published private(set) var isChecking = false

    private let defaults = UserDefaults.standard
    private var observing = false

    /// Overridable for testing, e.g. `SIMCTL_CHILD_HEALTHPUSH_API_BASE=http://localhost:8787`.
    static var dispatchURL: URL {
        let base = ProcessInfo.processInfo.environment["HEALTHPUSH_API_BASE"] ?? "https://api.github.com"
        return URL(string: base)!.appending(path: "repos/leanderme/leanderso/dispatches")
    }

    private init() {
        lastSentAt = defaults.object(forKey: "lastSentAt") as? Date
        if let data = defaults.data(forKey: "lastSummary") { lastSummary = try? JSONDecoder().decode(DailySummary.self, from: data) }
        coverage = defaults.dictionary(forKey: "coverage") as? [String: Int] ?? [:]
    }

    /// Reads the last `daysToSend` days without sending, to show which metrics Apple Health returns.
    func checkData() async {
        guard !isChecking else { return }
        isChecking = true
        defer { isChecking = false }
        do {
            record(try await HealthReader.shared.summaries(days: Self.daysToSend))
        } catch HKError.errorDatabaseInaccessible {
            status = "Apple Health is locked until the phone is unlocked."
        } catch {
            status = error.localizedDescription
        }
    }

    private func record(_ summaries: [DailySummary]) {
        coverage = Dictionary(uniqueKeysWithValues: DailySummary.metrics.map { metric in (metric.label, summaries.filter(metric.has).count) })
        defaults.set(coverage, forKey: "coverage")
    }

    private var yesterday: Date { Calendar.current.date(byAdding: .day, value: -1, to: .now)! }
    private var sentDay: String? { defaults.string(forKey: "sentDay") }

    /// Called on launch, when the app opens, from background refresh and from Health updates.
    func sendIfDue() async {
        guard Calendar.current.component(.hour, from: .now) >= Self.sendAfterHour,
              sentDay != HealthReader.dayFormatter.string(from: yesterday),
              Keychain.token != nil else { return }
        await send()
    }

    func send() async {
        guard !isSending else { return }
        isSending = true
        defer { isSending = false }
        do {
            guard let token = Keychain.token else { throw Failure("Add a GitHub token first.") }
            let summaries = try await HealthReader.shared.summaries(days: Self.daysToSend)
            record(summaries)
            let days = summaries.filter { !$0.isEmpty }
            guard let summary = days.last else { throw Failure("Apple Health has no figures for the last \(Self.daysToSend) days.") }

            var request = URLRequest(url: Self.dispatchURL)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
            request.httpBody = try JSONEncoder().encode(Dispatch(client_payload: Batch(days: days)))
            let (data, response) = try await URLSession.shared.data(for: request)
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard code == 204 else {
                let message = (try? JSONDecoder().decode(GitHubError.self, from: data))?.message ?? "HTTP \(code)"
                throw Failure(code == 401 || code == 403 || code == 404 ? "GitHub refused the token: \(message)" : "GitHub: \(message)")
            }

            lastSummary = summary
            lastSentAt = .now
            status = nil
            defaults.set(HealthReader.dayFormatter.string(from: yesterday), forKey: "sentDay")
            defaults.set(lastSentAt, forKey: "lastSentAt")
            defaults.set(try JSONEncoder().encode(summary), forKey: "lastSummary")
        } catch HKError.errorDatabaseInaccessible {
            status = "Apple Health is locked until the phone is unlocked. It will try again."
        } catch {
            status = (error as? Failure)?.message ?? error.localizedDescription
        }
    }

    /// HealthKit relaunches the app in the background when new steps or sleep arrive; each wake checks whether a send is due.
    func observeHealthUpdates() {
        guard !observing, HKHealthStore.isHealthDataAvailable() else { return }
        observing = true
        let store = HealthReader.shared.store
        for type in [HKQuantityType(.stepCount), HKCategoryType(.sleepAnalysis)] as [HKSampleType] {
            let query = HKObserverQuery(sampleType: type, predicate: nil) { _, completion, error in
                guard error == nil else { return completion() }
                Task { @MainActor in
                    await Sender.shared.sendIfDue()
                    completion()
                }
            }
            store.execute(query)
            store.enableBackgroundDelivery(for: type, frequency: .hourly) { _, _ in }
        }
    }

    /// A second, independent wake-up shortly after the send time, in case no Health update arrives.
    nonisolated static func scheduleRefresh() {
        let calendar = Calendar.current
        var next = calendar.date(bySettingHour: sendAfterHour, minute: 15, second: 0, of: .now)!
        if next <= .now { next = calendar.date(byAdding: .day, value: 1, to: next)! }
        let request = BGAppRefreshTaskRequest(identifier: refreshTask)
        request.earliestBeginDate = next
        try? BGTaskScheduler.shared.submit(request)
    }
}

private struct Dispatch: Encodable {
    let event_type = "health"
    let client_payload: Batch
}

private struct Batch: Encodable { let days: [DailySummary] }

private struct GitHubError: Decodable { let message: String }

private struct Failure: Error {
    let message: String
    init(_ message: String) { self.message = message }
}
