/// The final game (or point) score for one set.
/// `isSuperTiebreak` is true when this entry represents a 10-point match tiebreak
/// played in lieu of a full deciding set — the `home`/`away` values are tiebreak
/// points, not games, and the UI should render them accordingly.
public struct SetResult: Sendable, Codable, Equatable {
    public let home: Int
    public let away: Int
    public let isSuperTiebreak: Bool

    public init(home: Int, away: Int, isSuperTiebreak: Bool = false) {
        self.home = home
        self.away = away
        self.isSuperTiebreak = isSuperTiebreak
    }

    public var homeWon: Bool { home > away }
    public var awayWon: Bool { away > home }
}
