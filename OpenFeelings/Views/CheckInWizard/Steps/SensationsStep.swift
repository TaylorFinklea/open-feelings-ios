import SwiftUI

struct SensationsStep: View {
    @Binding var draft: CheckInDraft

    var body: some View {
        VStack(alignment: .leading, spacing: .OF.sm) {
            Text("How does it feel?")
                .font(.OF.caption).foregroundStyle(Color.OF.textMuted)
            WrapLayout(hSpacing: CGFloat.OF.sm, vSpacing: CGFloat.OF.sm) {
                ForEach(BodySensation.allCases) { s in
                    OFChip(label: s.displayName, isOn: bindingFor(s))
                }
            }
        }
        .padding(CGFloat.OF.md)
        .background(Color.OF.surface,
                    in: RoundedRectangle(cornerRadius: CGFloat.OF.Radius.card, style: .continuous))
    }

    private func bindingFor(_ s: BodySensation) -> Binding<Bool> {
        Binding(
            get: { draft.bodySensations.contains(s) },
            set: { isOn in
                if isOn { draft.bodySensations.insert(s) } else { draft.bodySensations.remove(s) }
            }
        )
    }
}
