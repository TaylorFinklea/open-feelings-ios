import SwiftUI

struct SettingsView: View {
    @Environment(HealthService.self) private var healthService

    @AppStorage("appLockEnabled") private var appLockEnabled = false
    @AppStorage("healthEnabled") private var healthEnabled = false
    @AppStorage("remindersEnabled") private var remindersEnabled = false
    @AppStorage("reminderHour") private var reminderHour = 20
    @AppStorage("reminderMinute") private var reminderMinute = 0

    @State private var reminderTime = Date.now
    @State private var notificationError: String?

    var body: some View {
        Form {
            Section("Privacy") {
                Toggle("Require Face ID or passcode", isOn: $appLockEnabled)

                LabeledContent("Data storage") {
                    Text("On device + private iCloud")
                        .foregroundStyle(.secondary)
                }

                Text("Open Feelings has no accounts, ads, analytics, or third-party SDKs.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Reminders") {
                Toggle("Daily check-in reminder", isOn: $remindersEnabled)
                    .onChange(of: remindersEnabled) { _, isEnabled in
                        updateReminder(enabled: isEnabled)
                    }

                if remindersEnabled {
                    DatePicker("Reminder time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                        .onChange(of: reminderTime) { _, newValue in
                            let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                            reminderHour = components.hour ?? 20
                            reminderMinute = components.minute ?? 0
                            updateReminder(enabled: true)
                        }
                }
            }

            Section("Apple Health") {
                Toggle("Save State of Mind entries", isOn: Binding(
                    get: { healthEnabled },
                    set: { newValue in
                        setHealthEnabled(newValue)
                    }
                ))

                LabeledContent("Permission") {
                    Text(healthStatusLabel)
                        .foregroundStyle(.secondary)
                }

                Text("Apple Health support is optional and write-only in this version. Open Feelings saves check-ins as momentary State of Mind entries after you grant permission.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Reference Text") {
                LabeledContent("Definitions") {
                    Text("Clinically informed")
                        .foregroundStyle(.secondary)
                }

                Text(EmotionDefinitions.disclaimer)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Text(EmotionDefinitions.sourceSummary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                ForEach(EmotionDefinitions.referenceSources) { source in
                    Link(source.title, destination: source.url)
                }
            }

            Section("Open Source") {
                LabeledContent("Code license") {
                    Text("MIT")
                        .foregroundStyle(.secondary)
                }

                LabeledContent("Emotion wheel") {
                    Text(EmotionTaxonomy.sourceName)
                        .foregroundStyle(.secondary)
                }

                LabeledContent("Wheel license") {
                    Text(EmotionTaxonomy.sourceLicenseName)
                        .foregroundStyle(.secondary)
                }

                Text(EmotionTaxonomy.sourceAttribution)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                LabeledContent("Version") {
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Settings")
        .onAppear {
            syncReminderTime()
            healthService.refreshAuthorizationStatus()
        }
        .alert("Reminder unavailable", isPresented: Binding(
            get: { notificationError != nil },
            set: { if !$0 { notificationError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(notificationError ?? "")
        }
    }

    private var healthStatusLabel: String {
        if !healthService.isAvailable {
            return "Unavailable"
        }

        switch healthService.authorizationStatus {
        case .notDetermined:
            return "Not requested"
        case .sharingDenied:
            return "Denied"
        case .sharingAuthorized:
            return "Authorized"
        @unknown default:
            return "Unknown"
        }
    }

    private func setHealthEnabled(_ enabled: Bool) {
        if enabled {
            Task {
                let authorized = await healthService.requestAuthorization()
                await MainActor.run {
                    healthEnabled = authorized
                }
            }
        } else {
            healthEnabled = false
            healthService.refreshAuthorizationStatus()
        }
    }

    private func updateReminder(enabled: Bool) {
        if enabled {
            Task {
                let authorized = await ReminderService.requestAuthorization()
                guard authorized else {
                    await MainActor.run {
                        remindersEnabled = false
                        notificationError = "Notification permission was not granted."
                    }
                    return
                }

                do {
                    try await ReminderService.scheduleDailyReminder(hour: reminderHour, minute: reminderMinute)
                } catch {
                    await MainActor.run {
                        remindersEnabled = false
                        notificationError = error.localizedDescription
                    }
                }
            }
        } else {
            ReminderService.cancelDailyReminder()
        }
    }

    private func syncReminderTime() {
        var components = DateComponents()
        components.hour = reminderHour
        components.minute = reminderMinute
        reminderTime = Calendar.current.date(from: components) ?? .now
    }
}
