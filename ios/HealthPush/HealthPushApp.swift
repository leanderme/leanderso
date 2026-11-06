import SwiftUI

@main
struct HealthPushApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var sender = Sender.shared

    init() {
        // HealthKit may relaunch the app in the background; observers have to be set up again on every launch.
        if UserDefaults.standard.bool(forKey: "healthRequested") { Sender.shared.observeHealthUpdates() }
    }

    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(sender)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await sender.sendIfDue() } }
            if phase == .background { Sender.scheduleRefresh() }
        }
        .backgroundTask(.appRefresh(Sender.refreshTask)) {
            Sender.scheduleRefresh()
            await Sender.shared.sendIfDue()
        }
    }
}
