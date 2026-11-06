import AppIntents

/// Lets a Shortcuts automation send the summary at a fixed time each day, without opening the app.
struct SendHealthSummaryIntent: AppIntent {
    static let title: LocalizedStringResource = "Send Health Summary"
    static let description = IntentDescription("Sends the last 30 days of Apple Health figures to leander.so.")
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let sender = Sender.shared
        guard let days = await sender.send() else {
            throw SendFailure(message: sender.status ?? "Nothing was sent.")
        }
        return .result(dialog: "Sent \(days) days to leander.so.")
    }
}

/// Shown by Shortcuts when a send fails, so a failed automation says why.
struct SendFailure: Error, CustomLocalizedStringResourceConvertible {
    let message: String
    var localizedStringResource: LocalizedStringResource { "\(message)" }
}

struct HealthPushShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SendHealthSummaryIntent(),
            phrases: ["Send health summary with \(.applicationName)", "Update leander.so with \(.applicationName)"],
            shortTitle: "Send Health Summary",
            systemImageName: "heart.text.square"
        )
    }
}
