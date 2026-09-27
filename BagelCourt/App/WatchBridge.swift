import WatchConnectivity
import Foundation

/// One-way phone → watch channel. Sends a `ScoreSnapshot` via
/// `updateApplicationContext` (latest-value-wins — perfect for a live mirror).
///
/// Call `WatchBridge.shared.activate()` once at app launch.
/// Call `send(_:)` after every point scored or undone.
final class WatchBridge: NSObject, WCSessionDelegate, @unchecked Sendable {
    static let shared = WatchBridge()

    private let encoder = JSONEncoder()

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func send(_ snapshot: ScoreSnapshot) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        guard let data = try? encoder.encode(snapshot) else { return }
        try? session.updateApplicationContext(["snapshot": data])
    }

    // MARK: WCSessionDelegate (phone-side)

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {}

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        // Re-activate after handoff on multi-Watch devices.
        WCSession.default.activate()
    }
}
