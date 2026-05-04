import SwiftUI

/// Mirror of the icon rendered by `scripts/generate-app-icon.swift`. SwiftUI
/// preview-only; not used at runtime. Keep visually in sync with the script
/// when tuning colors or radii.
struct AppIconView: View {
    var body: some View {
        ZStack {
            Color(red: 250/255, green: 246/255, blue: 240/255)
            ringStroke(diameter: 880, color: Color(red: 0x93/255, green: 0xAA/255, blue: 0xBF/255))
            ringStroke(diameter: 640, color: Color(red: 0xC4/255, green: 0x6A/255, blue: 0x55/255))
            ringStroke(diameter: 400, color: Color(red: 0xD9/255, green: 0xA4/255, blue: 0x3A/255))
            Circle()
                .fill(Color(red: 0x8E/255, green: 0x4F/255, blue: 0x2C/255))
                .frame(width: 160, height: 160)
        }
        .frame(width: 1024, height: 1024)
    }

    private func ringStroke(diameter: CGFloat, color: Color) -> some View {
        Circle()
            .stroke(color, lineWidth: 56)
            .frame(width: diameter, height: diameter)
    }
}

#Preview {
    AppIconView()
        .scaleEffect(0.4)
        .frame(width: 410, height: 410)
}
