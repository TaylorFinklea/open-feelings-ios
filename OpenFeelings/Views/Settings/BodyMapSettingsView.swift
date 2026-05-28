import SwiftData
import SwiftUI

/// Settings → Body map. Lists body regions with their effective cores
/// (override > learned > default) and lets users edit overrides.
struct BodyMapSettingsView: View {
    @Environment(\.modelContext) private var modelContext

    @AppStorage("checkInLearnFromHistory") private var learnFromHistory = true

    @Query private var bodyMaps: [UserBodyMap]
    @Query private var allLogs: [FeelingLog]
    @Query(sort: \CustomBodyRegion.createdAt) private var customRegions: [CustomBodyRegion]

    @State private var editingRegion: BodyRegion?
    @State private var showingAddCustom = false
    @State private var newCustomName = ""
    @State private var pendingRename: CustomBodyRegion?
    @State private var renameText = ""

    private var bodyMap: UserBodyMap? { bodyMaps.first }

    private var displayRegions: [BodyRegion] {
        BodyRegion.allCases.filter { $0 != .nowhere }
    }

    var body: some View {
        Form {
            Section {
                Toggle("Learn from history", isOn: $learnFromHistory)
                Text("When on, the app shifts suggestions over time based on what you've actually picked.")
                    .font(.OF.caption)
                    .foregroundStyle(Color.OF.textMuted)
            }

            Section("Mappings") {
                ForEach(displayRegions, id: \.self) { region in
                    Button { editingRegion = region } label: {
                        HStack {
                            Text(region.displayName).foregroundStyle(Color.OF.text)
                            Spacer()
                            Text(coreSummary(for: region))
                                .font(.OF.caption)
                                .foregroundStyle(Color.OF.textMuted)
                                .lineLimit(1)
                            Image(systemName: "chevron.right")
                                .font(.OF.caption)
                                .foregroundStyle(Color.OF.textMuted)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            Section("Your regions") {
                if customRegions.isEmpty {
                    Text("Add places that fit your body — anywhere from \"left arm\" to \"jaw.\" Picks land on your check-ins alongside the built-in regions and the app learns from them the same way.")
                        .font(.OF.caption)
                        .foregroundStyle(Color.OF.textMuted)
                }
                ForEach(customRegions) { region in
                    Button {
                        renameText = region.name
                        pendingRename = region
                    } label: {
                        HStack {
                            Text(region.name).foregroundStyle(Color.OF.text)
                            Spacer()
                            Image(systemName: "pencil")
                                .font(.OF.caption)
                                .foregroundStyle(Color.OF.textMuted)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .onDelete(perform: deleteCustomRegions)

                Button {
                    newCustomName = ""
                    showingAddCustom = true
                } label: {
                    Label("Add region", systemImage: "plus.circle")
                }
            }

            Section {
                Button(role: .destructive) {
                    bodyMap?.resetAll()
                    try? modelContext.save()
                } label: {
                    Text("Reset all to defaults")
                }
            }
        }
        .navigationTitle("Body map")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingRegion) { region in
            EditBodyRegionView(region: region, bodyMap: bodyMap)
                .environment(\.modelContext, modelContext)
        }
        .sheet(isPresented: $showingAddCustom) {
            AddCustomBodyRegionView(name: $newCustomName) { trimmed in
                let region = CustomBodyRegion(name: trimmed)
                modelContext.insert(region)
                try? modelContext.save()
            }
        }
        .alert("Rename region", isPresented: renameAlertBinding) {
            TextField("Region name", text: $renameText)
            Button("Cancel", role: .cancel) { pendingRename = nil }
            Button("Save") {
                if let region = pendingRename {
                    Self.rename(region, to: renameText, in: modelContext)
                }
                pendingRename = nil
            }
        }
    }

    private var renameAlertBinding: Binding<Bool> {
        Binding(get: { pendingRename != nil },
                set: { if !$0 { pendingRename = nil } })
    }

    private func deleteCustomRegions(at offsets: IndexSet) {
        for index in offsets {
            Self.delete(customRegions[index], in: modelContext)
        }
    }

    // MARK: - Mutations (static for testability)

    /// Trim and persist a new name. No-op if the trimmed name is empty.
    /// Ref-safe: `FeelingLog.customBodyRegionIDsRaw` stores UUIDs, not names.
    static func rename(_ region: CustomBodyRegion, to newName: String, in context: ModelContext) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        region.name = trimmed
        try? context.save()
    }

    /// Delete the region. No cascade — a deleted region's UUID may remain
    /// in old `FeelingLog.customBodyRegionIDsRaw` and renders as benign.
    static func delete(_ region: CustomBodyRegion, in context: ModelContext) {
        context.delete(region)
        try? context.save()
    }

    private func coreSummary(for region: BodyRegion) -> String {
        let effective: [String]
        if let overridden = bodyMap?.coreIDs(for: region), !overridden.isEmpty {
            effective = overridden
        } else {
            effective = BodyEmotionMap.defaultCores(for: region)
        }
        let names = effective.compactMap { id in
            EmotionTaxonomy.cores.first(where: { $0.id == id })?.name
        }
        let mark = bodyMap?.coreIDs(for: region) != nil ? " ★" : ""
        return names.joined(separator: ", ") + mark
    }
}

private struct EditBodyRegionView: View {
    let region: BodyRegion
    let bodyMap: UserBodyMap?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var selectedCoreIDs: Set<String> = []

    var body: some View {
        NavigationStack {
            Form {
                Section("Cores you tend to feel here") {
                    ForEach(EmotionTaxonomy.cores) { core in
                        Toggle(core.name, isOn: bindingFor(core.id))
                    }
                }
            }
            .navigationTitle(region.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        bodyMap?.setOverride(for: region, coreIDs: Array(selectedCoreIDs))
                        try? modelContext.save()
                        dismiss()
                    }
                    .disabled(selectedCoreIDs.isEmpty)
                }
            }
            .onAppear {
                if let existing = bodyMap?.coreIDs(for: region) {
                    selectedCoreIDs = Set(existing)
                } else {
                    selectedCoreIDs = Set(BodyEmotionMap.defaultCores(for: region))
                }
            }
        }
    }

    private func bindingFor(_ id: String) -> Binding<Bool> {
        Binding(
            get: { selectedCoreIDs.contains(id) },
            set: { isOn in
                if isOn { selectedCoreIDs.insert(id) } else { selectedCoreIDs.remove(id) }
            }
        )
    }
}

private struct AddCustomBodyRegionView: View {
    @Binding var name: String
    var onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var fieldFocused: Bool

    private var trimmed: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("e.g., left arm, jaw", text: $name)
                        .focused($fieldFocused)
                        .textInputAutocapitalization(.sentences)
                        .submitLabel(.done)
                        .onSubmit(commit)
                }
            }
            .navigationTitle("New region")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add", action: commit).disabled(trimmed.isEmpty)
                }
            }
            .onAppear { fieldFocused = true }
        }
    }

    private func commit() {
        guard !trimmed.isEmpty else { return }
        onSave(trimmed)
        dismiss()
    }
}
