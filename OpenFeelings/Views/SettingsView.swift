import SwiftUI

struct SettingsView: View {
    @Environment(HealthService.self) private var healthService
    @Environment(\.colorScheme) private var colorScheme

    @AppStorage("appLockEnabled") private var appLockEnabled = false
    @AppStorage("healthEnabled") private var healthEnabled = false
    @AppStorage("remindersEnabled") private var remindersEnabled = false
    @AppStorage("reminderHour") private var reminderHour = 20
    @AppStorage("reminderMinute") private var reminderMinute = 0
    @AppStorage("displayName") private var displayName = ""

    @State private var reminderTime = Date.now
    @State private var notificationError: String?

    var body: some View {
        ScrollView {
            VStack(spacing: .OF.xl) {
                privacySection
                remindersSection
                healthSection
                referenceSection
                openSourceSection
                aboutSection
            }
            .padding(.bottom, CGFloat.OF.xxxl)
        }
        .background(Color.OF.background, ignoresSafeAreaEdges: .all)
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

    // MARK: - Privacy

    private var privacySection: some View {
        section(title: "Privacy") {
            OFListRow(title: "Require Face ID or passcode", systemImage: "lock.shield") {
                Toggle("", isOn: $appLockEnabled)
                    .labelsHidden()
                    .tint(Color.OF.accent.color(for: colorScheme))
            }
            divider
            OFListRow(title: "Data storage",
                      subtitle: "On device + private iCloud",
                      systemImage: "lock.icloud")
            footerCaption("Open Feelings has no accounts, ads, analytics, or third-party SDKs.")
        }
    }

    // MARK: - Reminders

    private var remindersSection: some View {
        section(title: "Reminders") {
            OFListRow(title: "Daily check-in reminder", systemImage: "bell") {
                Toggle("", isOn: $remindersEnabled)
                    .labelsHidden()
                    .tint(Color.OF.accent.color(for: colorScheme))
            }
            .onChange(of: remindersEnabled) { _, isEnabled in
                updateReminder(enabled: isEnabled)
            }

            if remindersEnabled {
                divider
                OFListRow(title: "Reminder time", systemImage: "clock") {
                    DatePicker("", selection: $reminderTime, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                }
                .onChange(of: reminderTime) { _, newValue in
                    let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                    reminderHour = components.hour ?? 20
                    reminderMinute = components.minute ?? 0
                    updateReminder(enabled: true)
                }
            }
        }
    }

    // MARK: - Apple Health

    private var healthSection: some View {
        section(title: "Apple Health") {
            OFListRow(title: "Save State of Mind entries", systemImage: "heart") {
                Toggle("", isOn: Binding(
                    get: { healthEnabled },
                    set: { setHealthEnabled($0) }
                ))
                .labelsHidden()
                .tint(Color.OF.accent.color(for: colorScheme))
            }
            divider
            OFListRow(title: "Permission",
                      subtitle: healthStatusLabel,
                      systemImage: "info.circle")
            footerCaption("Apple Health support is optional and write-only in this version. Open Feelings saves check-ins as momentary State of Mind entries after you grant permission.")
        }
    }

    // MARK: - Reference Text

    private var referenceSection: some View {
        section(title: "Reference Text") {
            OFListRow(title: "Definitions",
                      subtitle: "Clinically informed",
                      systemImage: "book")
            footerCaption(EmotionDefinitions.disclaimer)
            footerCaption(EmotionDefinitions.sourceSummary)
            VStack(alignment: .leading, spacing: .OF.xs) {
                ForEach(EmotionDefinitions.referenceSources) { source in
                    Link(source.title, destination: source.url)
                        .font(.OF.caption)
                        .foregroundStyle(Color.OF.accent)
                }
            }
            .padding(.horizontal, CGFloat.OF.lg)
            .padding(.bottom, CGFloat.OF.md)
        }
    }

    // MARK: - Open Source

    private var openSourceSection: some View {
        section(title: "Open Source") {
            OFListRow(title: "Code license",
                      subtitle: "MIT",
                      systemImage: "doc.plaintext")
            divider
            OFListRow(title: "Emotion wheel",
                      subtitle: EmotionTaxonomy.sourceName,
                      systemImage: "circle.grid.3x3")
            divider
            OFListRow(title: "Wheel license",
                      subtitle: EmotionTaxonomy.sourceLicenseName,
                      systemImage: "info.circle")
            footerCaption(EmotionTaxonomy.sourceAttribution)
        }
    }

    // MARK: - About (new — Display name + version)

    private var aboutSection: some View {
        section(title: "About") {
            NavigationLink {
                DisplayNameEditView(name: $displayName)
            } label: {
                OFListRow.chevron(
                    title: "Display name",
                    subtitle: displayName.isEmpty ? "Not set" : displayName,
                    systemImage: "person.crop.circle"
                )
            }
            .buttonStyle(.plain)
            divider
            OFListRow(title: "Version",
                      subtitle: "v\(Bundle.main.appVersion) (\(Bundle.main.appBuild))",
                      systemImage: "number")
        }
    }

    // MARK: - Section + reusable bits

    @ViewBuilder
    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            OFSectionHeader(title: title)
            VStack(spacing: 0) {
                content()
            }
            .background(Color.OF.surface)
            .clipShape(RoundedRectangle(cornerRadius: CGFloat.OF.Radius.card, style: .continuous))
            .padding(.horizontal, CGFloat.OF.lg)
        }
    }

    private var divider: some View {
        Divider()
            .background(Color.OF.divider)
            .padding(.leading, CGFloat.OF.xxxl + .OF.sm) // align past leading icon column
    }

    private func footerCaption(_ text: String) -> some View {
        Text(text)
            .font(.OF.caption)
            .foregroundStyle(Color.OF.textMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, CGFloat.OF.lg)
            .padding(.bottom, CGFloat.OF.md)
    }

    // MARK: - Existing controller methods (preserved verbatim)

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

// MARK: - Display name editor

private struct DisplayNameEditView: View {
    @Binding var name: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section {
                TextField("Your name", text: $name)
                    .textInputAutocapitalization(.words)
            } footer: {
                Text("Used in the greeting on Today. Leave blank for an unaddressed greeting.")
            }
        }
        .navigationTitle("Display name")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Bundle helpers

private extension Bundle {
    var appVersion: String { (infoDictionary?["CFBundleShortVersionString"] as? String) ?? "?" }
    var appBuild: String   { (infoDictionary?["CFBundleVersion"] as? String) ?? "?" }
}
