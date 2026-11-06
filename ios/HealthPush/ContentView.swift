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
                    Text("Sends your daily Apple Health summaries for the last \(Sender.daysToSend) days to leander.so every morning after \(Sender.sendAfterHour):00.")
                        .foregroundStyle(.secondary)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }

            Section {
                if let summary = sender.lastSummary {
                    row("Day", summary.date)
                    if let steps = summary.steps { row("Steps", steps.formatted()) }
                    if let distance = summary.distanceMeters { row("Distance", (Double(distance) / 1000).formatted(.number.precision(.fractionLength(1))) + " km") }
                    if let energy = summary.activeEnergy { row("Active energy", "\(energy.formatted()) kcal") }
                    if let exercise = summary.exerciseMinutes { row("Active minutes", exercise.formatted()) }
                    if let workouts = summary.workouts { row("Workouts", workouts.formatted()) }
                    ForEach((summary.workoutMinutes ?? [:]).sorted { $0.value > $1.value }, id: \.key) { type, minutes in
                        row("  \(type.capitalized)", "\(minutes) min")
                    }
                    if let sleep = summary.sleepMinutes { row("Sleep", "\(sleep / 60) h \(sleep % 60) min") }
                    if let resting = summary.restingHeartRate { row("Resting heart rate", "\(resting) bpm") }
                    if let hrv = summary.hrv { row("Heart rate variability", "\(hrv) ms") }
                    if let vo2 = summary.vo2Max { row("VO₂ max", vo2.formatted()) }
                } else {
                    Text("Nothing sent yet").foregroundStyle(.secondary)
                }
                if let status = sender.status {
                    Text(status).foregroundStyle(.red)
                }
            } header: {
                Text("Last sent, most recent day")
            } footer: {
                if let sentAt = sender.lastSentAt { Text("Sent \(sentAt.formatted(date: .abbreviated, time: .shortened)).") }
            }

            Section {
                if sender.coverage.isEmpty {
                    Text("Not checked yet").foregroundStyle(.secondary)
                } else {
                    ForEach(DailySummary.metrics, id: \.label) { metric in
                        let days = sender.coverage[metric.label] ?? 0
                        LabeledContent(metric.label) {
                            Text("\(days) of \(Sender.daysToSend) days").foregroundStyle(days == 0 ? .orange : .secondary)
                        }
                    }
                }
                Button {
                    Task { await sender.checkData() }
                } label: {
                    HStack {
                        Text("Check Apple Health now")
                        if sender.isChecking { Spacer(); ProgressView() }
                    }
                }
                .disabled(sender.isChecking || !healthRequested)
            } header: {
                Text("Found in Apple Health")
            } footer: {
                Text("Days with data in the last \(Sender.daysToSend). Workouts counts days with at least one workout. A metric at 0 is usually switched off in Settings → Health → Data Access & Devices → Health Push, or your Watch didn't record it.")
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
                Text("Reads steps, distance, active energy, exercise minutes, workouts, sleep, resting heart rate, heart rate variability and VO₂ max. Turn all of them on; iOS doesn't tell the app which ones you left off. Change this later in Settings → Health → Data Access & Devices.")
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
                        Text("Send the last \(Sender.daysToSend) days now")
                        if sender.isSending { Spacer(); ProgressView() }
                    }
                }
                .disabled(sender.isSending || !hasToken || !healthRequested)
            } footer: {
                Text("Days already on the site are replaced with the current figures from Apple Health.")
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
