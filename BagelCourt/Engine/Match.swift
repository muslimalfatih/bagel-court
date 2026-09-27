import Foundation

// MARK: - Match

/// A tennis match. Value type; the point log is the single source of truth.
/// All score state is derived by replaying the log through `MatchState`.
///
/// Usage:
/// ```swift
/// var match = Match(homePlayer: "Alex", awayPlayer: "Maria",
///                   format: .bestOf3, initialServer: .home)
/// match.score(point: .home)   // Alex wins a point
/// match.undoLastPoint()        // ← oops, hit wrong button
/// ```
public struct Match: Sendable, Codable {

    // MARK: - Identity (immutable after init)

    public let id: UUID
    public let type: MatchType
    public let homePlayer: String
    public let homePlayer2: String?     // doubles / mixed only
    public let awayPlayer: String
    public let awayPlayer2: String?     // doubles / mixed only
    public let format: MatchFormat
    public let initialServer: Side
    public let startDate: Date

    // MARK: - Source of truth

    /// The full ordered log of which side won each point.
    /// Everything else is derived from this.
    public private(set) var points: [Side]

    // MARK: - Init

    public init(
        type: MatchType          = .singles,
        homePlayer: String,
        homePlayer2: String?     = nil,
        awayPlayer: String,
        awayPlayer2: String?     = nil,
        format: MatchFormat,
        initialServer: Side,
        id: UUID                 = UUID(),
        startDate: Date          = Date()
    ) {
        self.id            = id
        self.type          = type
        self.homePlayer    = homePlayer
        self.homePlayer2   = homePlayer2
        self.awayPlayer    = awayPlayer
        self.awayPlayer2   = awayPlayer2
        self.format        = format
        self.initialServer = initialServer
        self.startDate     = startDate
        self.points        = []
    }

    // MARK: - Computed state (replays point log)

    private var state: MatchState {
        MatchState(replaying: points, format: format, initialServer: initialServer)
    }

    public var currentServer: Side   { state.currentServer }
    public var allSets: [SetResult]  { state.allSets }
    public var currentGameScore: GameScore { state.gameScore }
    public var winner: Side?         { state.winner }
    public var isOver: Bool          { state.winner != nil }
    public var isInTiebreak: Bool    { state.isInTiebreak }
    public var isSuperTiebreak: Bool { state.isSuperTiebreak }
    public var homeSetsWon: Int      { state.homeSetsWon }
    public var awaySetsWon: Int      { state.awaySetsWon }

    // MARK: - Display helpers

    public var homeDisplayName: String {
        guard let p2 = homePlayer2 else { return homePlayer }
        return "\(homePlayer) / \(p2)"
    }

    public var awayDisplayName: String {
        guard let p2 = awayPlayer2 else { return awayPlayer }
        return "\(awayPlayer) / \(p2)"
    }

    // MARK: - Mutations

    /// Award a point to `winner`. No-op if the match is already over.
    public mutating func score(point winner: Side) {
        guard !isOver else { return }
        points.append(winner)
    }

    /// Remove the last scored point. No-op if no points have been scored.
    public mutating func undoLastPoint() {
        guard !points.isEmpty else { return }
        points.removeLast()
    }

    // MARK: - Watch snapshot

    public var scoreSnapshot: ScoreSnapshot {
        let s = state
        return ScoreSnapshot(
            matchID: id,
            homeDisplayName: homeDisplayName,
            awayDisplayName: awayDisplayName,
            gameScore: s.gameScore,
            allSets: s.allSets,
            server: s.currentServer,
            isOver: s.winner != nil,
            winner: s.winner,
            isInTiebreak: s.isInTiebreak
        )
    }
}

// MARK: - ScoreSnapshot

/// A small Codable value sent to the Apple Watch via WatchConnectivity.
/// Contains only what the watch needs to render a glanceable score.
public struct ScoreSnapshot: Sendable, Codable {
    public let matchID: UUID
    public let homeDisplayName: String
    public let awayDisplayName: String
    public let gameScore: GameScore
    public let allSets: [SetResult]
    public let server: Side
    public let isOver: Bool
    public let winner: Side?
    public let isInTiebreak: Bool

    public init(
        matchID: UUID,
        homeDisplayName: String,
        awayDisplayName: String,
        gameScore: GameScore,
        allSets: [SetResult],
        server: Side,
        isOver: Bool,
        winner: Side?,
        isInTiebreak: Bool
    ) {
        self.matchID         = matchID
        self.homeDisplayName = homeDisplayName
        self.awayDisplayName = awayDisplayName
        self.gameScore       = gameScore
        self.allSets         = allSets
        self.server          = server
        self.isOver          = isOver
        self.winner          = winner
        self.isInTiebreak    = isInTiebreak
    }
}
