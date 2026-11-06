import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var sender: Sender
    @AppStorage("healthRequested") private var healthRequested = false
    @State private var hasToken = Keychain.token != nil
    @State private var tokenInput = ""
    @State private var healthError: String?
    @State private var sampleStatus: String?

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Health Push").font(.system(.largeTitle, design: .serif))
                    Text("Sends yesterday's Apple Health summary to leander.so every morning after \(Sender.sendAfterHour):00.")
                        .foregroundStyle(.secondary)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }

            Section {
                if let summary = sender.lastSummary {
                    row("Day", summary.date)
                    if let steps = summary.steps { row("Steps", steps.formatted()) }
                    if let sleep = summary.sleepMinutes { row("Sleep", "\(sleep / 60) h \(sleep % 60) min") }
                    if let resting = summary.restingHeartRate { row("Resting heart rate", "\(resting) bpm") }
                    if let workouts = summary.workouts { row("Workouts", workouts.formatted()) }
                    if let exercise = summary.exerciseMinutes { row("Active minutes", exercise.formatted()) }
                } else {
                    Text("Nothing sent yet").foregroundStyle(.secondary)
                }
                if let status = sender.status {
                    Text(status).foregroundStyle(.red)
                }
            } header: {
                Text("Last sent")
            } footer: {
                if let sentAt = sender.lastSentAt { Text("Sent \(sentAt.formatted(date: .abbreviated, time: .shortened)).") }
            }

            Section {
                Button(healthRequested ? "Health access requested" : "Allow Health access") {
                    Task {
                        do {
                            try await HealthReader.shared.requestAuthorization()
                            healthRequested = true
                            sender.observeHealthUpdates()
                        } catch {
                            healthError = error.localizedDescription
                        }
                    }
                }
                if let healthError { Text(healthError).foregroundStyle(.red) }
            } header: {
                Text("Apple Health")
            } footer: {
                Text("Reads steps, sleep, resting heart rate, exercise minutes and workouts. Change this later in Settings → Health → Data Access & Devices.")
            }

            Section {
                if hasToken {
                    Label("Token saved", systemImage: "checkmark")
                    Button("Remove token", role: .destructive) {
                        Keychain.remove()
                        hasToken = false
                    }
                } else {
                    SecureField("Fine-grained token", text: $tokenInput)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button("Save token") {
                        Keychain.save(tokenInput.trimmingCharacters(in: .whitespacesAndNewlines))
                        tokenInput = ""
                        hasToken = true
                    }
                    .disabled(tokenInput.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            } header: {
                Text("GitHub")
            } footer: {
                Text("Needs access to leanderme/leanderso only, with Contents read and write. It is kept in this iPhone's Keychain.")
            }

            Section {
                Button {
                    Task { await sender.send() }
                } label: {
                    HStack {
                        Text("Send yesterday's summary now")
                        if sender.isSending { Spacer(); ProgressView() }
                    }
                }
                .disabled(sender.isSending || !hasToken || !healthRequested)
            } footer: {
                Text("Sending the same day again replaces its figures on the site.")
            }

            #if DEBUG
            Section("Testing") {
                Button("Add 30 days of sample data") {
                    Task { sampleStatus = await SampleData.add() }
                }
                if let sampleStatus { Text(sampleStatus).foregroundStyle(.secondary) }
                row("Sends to", Sender.dispatchURL.host() ?? "")
            }
            #endif
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        LabeledContent(label, value: value)
    }
}
