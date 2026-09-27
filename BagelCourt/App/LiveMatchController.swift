import SwiftUI
import SwiftData
import UIKit

/// Observable controller for an in-progress match.
/// Holds the `Match` value, caches derived `MatchState` so every render
/// pays for exactly one replay (at mutation time, not observation time),
/// and coordinates persistence + watch sync.
@Observable @MainActor
final class LiveMatchController: Identifiable {
    private(set) var match: Match
    private var cached: MatchState

    private weak var modelContext: ModelContext?

    var id: UUID { match.id }

    init(match: Match, modelContext: ModelContext? = nil) {
        self.match        = match
        self.cached       = MatchState(replaying: match.points,
                                       format: match.format,
                                       initialServer: match.initialServer)
        self.modelContext = modelContext
    }

    // MARK: - Derived properties (all from cached state)

    var currentServer: Side   { cached.currentServer }
    var allSets: [SetResult]  { cached.allSets }
    var gameScore: GameScore  { cached.gameScore }
    var winner: Side?         { cached.winner }
    var isOver: Bool          { cached.winner != nil }
    var isInTiebreak: Bool    { cached.isInTiebreak }
    var isSuperTiebreak: Bool { cached.isSuperTiebreak }
    var homeSetsWon: Int      { cached.homeSetsWon }
    var awaySetsWon: Int      { cached.awaySetsWon }
    var canUndo: Bool         { !match.points.isEmpty }

    var homeDisplayName: String { match.homeDisplayName }
    var awayDisplayName: String { match.awayDisplayName }
    var format: MatchFormat     { match.format }

    // MARK: - Mutations

    func scorePoint(for side: Side) {
        guard !isOver else { return }

        // Snapshot pre-state for haptic classification.
        let preHomeSets  = homeSetsWon
        let preAwaySets  = awaySetsWon

        match.score(point: side)
        recache()
        fireHaptic(preHomeSets: preHomeSets, preAwaySets: preAwaySets)
        afterMutation()
    }

    func undo() {
        guard canUndo else { return }
        match.undoLastPoint()
        recache()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        afterMutation()
    }

    // MARK: - Internals

    private func recache() {
        cached = MatchState(replaying: match.points,
                            format: match.format,
                            initialServer: match.initialServer)
    }

    private func afterMutation() {
        WatchBridge.shared.send(match.scoreSnapshot)
        persist()
    }

    private func fireHaptic(preHomeSets: Int, preAwaySets: Int) {
        if isOver {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } else if homeSetsWon > preHomeSets || awaySetsWon > preAwaySets {
            // A set just completed.
            let g = UIImpactFeedbackGenerator(style: .heavy)
            g.impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { g.impactOccurred() }
        } else if gameScore == .regular(home: 0, away: 0) {
            // Game won (score reset to 0–0 within the same set).
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } else {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    private func persist() {
        guard let ctx = modelContext else { return }
        let uuidString = match.id.uuidString
        let descriptor = FetchDescriptor<MatchRecord>(
            predicate: #Predicate { $0.matchID == uuidString }
        )
        if let existing = try? ctx.fetch(descriptor).first {
            try? existing.update(with: match)
        } else if let record = try? MatchRecord(match: match) {
            ctx.insert(record)
        }
        try? ctx.save()
    }
}
