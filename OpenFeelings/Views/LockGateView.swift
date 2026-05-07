import SwiftUI

struct LockGateView<Content: View>: View {
    @AppStorage("appLockEnabled") private var appLockEnabled = false
    @Environment(\.scenePhase) private var scenePhase

    @State private var isUnlocked = false
    @State private var isUnlocking = false

    let content: () -> Content

    var body: some View {
        Group {
            if appLockEnabled && !isUnlocked {
                lockedView
            } else {
                content()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            // Re-lock only on actual backgrounding. The Face ID system prompt,
            // control center, incoming calls, and notification center all pass
            // the scene through .inactive — using `!= .active` here would undo
            // a successful unlock right as the prompt dismisses.
            if appLockEnabled && newPhase == .background {
                isUnlocked = false
            }
        }
    }

    private var lockedView: some View {
        VStack(spacing: .OF.xl) {
            glyphBadge
            titles
            OFButton(isUnlocking ? "Unlocking…" : "Unlock", style: .primary) {
                unlock()
            }
            .padding(.horizontal, CGFloat.OF.xxxl)
            .padding(.top, CGFloat.OF.lg)
            .disabled(isUnlocking)
            .opacity(isUnlocking ? 0.6 : 1)
        }
        .padding(.horizontal, CGFloat.OF.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.OF.background, ignoresSafeAreaEdges: .all)
    }

    private var glyphBadge: some View {
        ZStack {
            Circle()
                .fill(Color.OF.accentSoft)
                .frame(width: 96, height: 96)
            Image(systemName: "lock.fill")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(Color.OF.accent)
        }
    }

    private var titles: some View {
        VStack(spacing: .OF.sm) {
            Text("Locked")
                .font(.OF.display)
                .foregroundStyle(Color.OF.text)
            Text("Use Face ID to continue.")
                .font(.OF.body)
                .foregroundStyle(Color.OF.textMuted)
                .multilineTextAlignment(.center)
        }
    }

    private func unlock() {
        isUnlocking = true
        Task {
            let unlocked = await AppLockService.unlock()
            await MainActor.run {
                isUnlocked = unlocked
                isUnlocking = false
            }
        }
    }
}
