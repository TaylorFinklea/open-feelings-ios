import Foundation
import LocalAuthentication

enum AppLockService {
    static func unlock() async -> Bool {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            return false
        }

        return await withCheckedContinuation { continuation in
            context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "Unlock Open Feelings"
            ) { success, _ in
                continuation.resume(returning: success)
            }
        }
    }
}
