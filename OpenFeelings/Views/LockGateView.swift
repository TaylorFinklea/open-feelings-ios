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
            if appLockEnabled && newPhase != .active {
                isUnlocked = false
            }
        }
    }

    private var lockedView: some View {
        VStack(spacing: 24) {
            Image(systemName: "lock.shield")
                .font(.system(size: 56, weight: .semibold))
                .foregroundStyle(.tint)

            VStack(spacing: 8) {
                Text("Open Feelings is locked")
                    .font(.title2.weight(.semibold))

                Text("Unlock to view your feeling logs.")
                    .foregroundStyle(.secondary)
            }

            Button {
                unlock()
            } label: {
                Label(isUnlocking ? "Unlocking" : "Unlock", systemImage: "faceid")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isUnlocking)
        }
        .padding(32)
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
