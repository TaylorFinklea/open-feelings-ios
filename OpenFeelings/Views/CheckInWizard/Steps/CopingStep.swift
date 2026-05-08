import SwiftUI

struct CopingStep: View {
    @Binding var draft: CheckInDraft

    var body: some View {
        VStack(alignment: .leading, spacing: .OF.sm) {
            Text("What helped?")
                .font(.OF.caption).foregroundStyle(Color.OF.textMuted)
            WrapLayout(hSpacing: CGFloat.OF.sm, vSpacing: CGFloat.OF.sm) {
                ForEach(Coping.allCases) { c in
                    OFChip(label: c.displayName, isOn: bindingFor(c))
                }
            }
        }
        .padding(CGFloat.OF.md)
        .background(Color.OF.surface,
                    in: RoundedRectangle(cornerRadius: CGFloat.OF.Radius.card, style: .continuous))
    }

    private func bindingFor(_ c: Coping) -> Binding<Bool> {
        Binding(
            get: { draft.coping.contains(c) },
            set: { isOn in
                if isOn { draft.coping.insert(c) } else { draft.coping.remove(c) }
            }
        )
    }
}
