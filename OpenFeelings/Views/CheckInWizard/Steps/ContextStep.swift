import SwiftUI

struct ContextStep: View {
    @Binding var draft: CheckInDraft

    var body: some View {
        VStack(alignment: .leading, spacing: .OF.sm) {
            Text("Where were you?")
                .font(.OF.caption).foregroundStyle(Color.OF.textMuted)
            WrapLayout(hSpacing: CGFloat.OF.sm, vSpacing: CGFloat.OF.sm) {
                ForEach(ContextPlace.allCases) { p in
                    OFChip(label: p.displayName, isOn: placeBinding(for: p))
                }
            }
            Divider().background(Color.OF.divider).padding(.vertical, CGFloat.OF.xs)
            Text("Who were you with?")
                .font(.OF.caption).foregroundStyle(Color.OF.textMuted)
            WrapLayout(hSpacing: CGFloat.OF.sm, vSpacing: CGFloat.OF.sm) {
                ForEach(ContextPeople.allCases) { p in
                    OFChip(label: p.displayName, isOn: peopleBinding(for: p))
                }
            }
        }
        .padding(CGFloat.OF.md)
        .background(Color.OF.surface,
                    in: RoundedRectangle(cornerRadius: CGFloat.OF.Radius.card, style: .continuous))
    }

    private func placeBinding(for p: ContextPlace) -> Binding<Bool> {
        Binding(
            get: { draft.contextPlaces.contains(p) },
            set: { isOn in
                if isOn { draft.contextPlaces.insert(p) } else { draft.contextPlaces.remove(p) }
            }
        )
    }

    private func peopleBinding(for p: ContextPeople) -> Binding<Bool> {
        Binding(
            get: { draft.contextPeople.contains(p) },
            set: { isOn in
                if isOn { draft.contextPeople.insert(p) } else { draft.contextPeople.remove(p) }
            }
        )
    }
}
