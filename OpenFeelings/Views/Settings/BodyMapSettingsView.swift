import SwiftData
import SwiftUI

/// Settings → Body map. Lists body regions with their effective cores
/// (override > learned > default) and lets users edit overrides.
struct BodyMapSettingsView: View {
    @Environment(\.modelContext) private var modelContext

    @AppStorage("checkInLearnFromHistory") private var learnFromHistory = true

    @Query private var bodyMaps: [UserBodyMap]
    @Query private var allLogs: [FeelingLog]

    @State private var editingRegion: BodyRegion?

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
