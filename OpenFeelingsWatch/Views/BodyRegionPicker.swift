import SwiftUI

/// "Where do you feel it?" — multi-select region toggles.
/// Mirrors iOS BodyStep exclusivity: Everywhere/Nowhere replace and are
/// replaced by any other selection.
struct BodyRegionPicker: View {
    @Binding var selection: Set<BodyRegion>
    var onContinue: () -> Void

    private var orderedRegions: [BodyRegion] {
        // Specials first so they're reachable without scrolling.
        [.wholeBody, .nowhere] + BodyRegion.allCases.filter { $0 != .wholeBody && $0 != .nowhere }
    }

    var body: some View {
        List {
            ForEach(orderedRegions) { region in
                Button {
                    toggle(region)
                } label: {
                    HStack {
                        Image(systemName: selection.contains(region) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selection.contains(region) ? Color.accentColor : Color.secondary)
                        Text(region.displayName)
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
            }

            Section {
                Button(action: onContinue) {
                    Text(selection.isEmpty ? "Skip" : "Continue")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .navigationTitle("Where")
    }

    private func toggle(_ region: BodyRegion) {
        let isExclusive = (region == .wholeBody || region == .nowhere)
        let hasExclusive = selection.contains(.wholeBody) || selection.contains(.nowhere)

        if isExclusive {
            selection = (selection == [region]) ? [] : [region]
            return
        }

        if hasExclusive {
            selection.remove(.wholeBody)
            selection.remove(.nowhere)
        }

        if selection.contains(region) {
            selection.remove(region)
        } else {
            selection.insert(region)
        }
    }
}
