// OpenFeelings/Design/Components/OFListRow.swift
import SwiftUI

struct OFListRow<Trailing: View>: View {
    let title: String
    var subtitle: String? = nil
    var systemImage: String? = nil
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: .OF.md) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Color.OF.accent)
                    .frame(width: 28, height: 28)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.OF.body).foregroundStyle(Color.OF.text)
                if let subtitle {
                    Text(subtitle).font(.OF.caption).foregroundStyle(Color.OF.textMuted)
                }
            }
            Spacer()
            trailing()
        }
        .padding(.horizontal, .OF.lg)
        .padding(.vertical, .OF.md)
        .frame(maxWidth: .infinity)
        .background(Color.OF.surface)
        .contentShape(Rectangle())
    }
}

// No-trailing convenience
extension OFListRow where Trailing == EmptyView {
    init(title: String, subtitle: String? = nil, systemImage: String? = nil) {
        self.init(title: title, subtitle: subtitle, systemImage: systemImage) { EmptyView() }
    }
}

// Chevron convenience — wraps a styled chevron in a concrete View type so
// the generic OFListRow<Trailing> can be specialized to a stable type.
struct OFChevronTrailing: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color.OF.textMuted)
    }
}

extension OFListRow where Trailing == OFChevronTrailing {
    static func chevron(title: String, subtitle: String? = nil, systemImage: String? = nil) -> OFListRow<OFChevronTrailing> {
        OFListRow<OFChevronTrailing>(title: title, subtitle: subtitle, systemImage: systemImage) {
            OFChevronTrailing()
        }
    }
}

#Preview {
    VStack(spacing: 1) {
        OFListRow.chevron(title: "Display name",
                          subtitle: "Taylor",
                          systemImage: "person.crop.circle")
        OFListRow(title: "Daily reminder", systemImage: "bell") {
            Toggle("", isOn: .constant(true)).labelsHidden()
        }
        OFListRow(title: "Coming soon", systemImage: "leaf")
            .opacity(0.45)
    }
    .background(Color.OF.background)
}
