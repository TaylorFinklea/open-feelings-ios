import SwiftUI

struct TriggersStep: View {
    @Binding var draft: CheckInDraft

    var body: some View {
        VStack(alignment: .leading, spacing: .OF.sm) {
            Text("What brought it on?")
                .font(.OF.caption).foregroundStyle(Color.OF.textMuted)
            WrapLayout(hSpacing: CGFloat.OF.sm, vSpacing: CGFloat.OF.sm) {
                ForEach(Trigger.allCases) { t in
                    OFChip(label: t.displayName, isOn: bindingFor(t))
                }
            }
        }
        .padding(CGFloat.OF.md)
        .background(Color.OF.surface,
                    in: RoundedRectangle(cornerRadius: CGFloat.OF.Radius.card, style: .continuous))
    }

    private func bindingFor(_ t: Trigger) -> Binding<Bool> {
        Binding(
            get: { draft.triggers.contains(t) },
            set: { isOn in
                if isOn { draft.triggers.insert(t) } else { draft.triggers.remove(t) }
            }
        )
    }
}
