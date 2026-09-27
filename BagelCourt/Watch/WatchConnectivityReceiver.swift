import Combine
import Foundation
import WatchConnectivity

/// Receives score snapshots from the iOS app via WatchConnectivity.
/// Add this to the watchOS target only.
@MainActor
final class WatchConnectivityReceiver: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchConnectivityReceiver()

    @Published private(set) var snapshot: ScoreSnapshot? = nil

    private override init() { super.init() }

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    // MARK: - WCSessionDelegate

    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith state: WCSessionActivationState,
                             error: Error?) {}

    nonisolated func session(_ session: WCSession,
                             didReceiveApplicationContext context: [String: Any]) {
        guard let data = context["snapshot"] as? Data,
              let snap = try? JSONDecoder().decode(ScoreSnapshot.self, from: data)
        else { return }
        Task { @MainActor in self.snapshot = snap }
    }

#if os(iOS)
    // Required by WCSessionDelegate on iOS but not on watchOS.
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }
#endif
}
