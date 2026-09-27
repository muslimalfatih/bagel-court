/// All the rules of a match in one value.
///
/// - `bestOf`: total sets to play (must be odd; winner takes majority).
/// - `gamesPerSet`: games required to win a set (with a 2-game lead).
/// - `tiebreakAt`: a tiebreak is played when both sides reach this game count.
/// - `decidingSetTiebreak`: when true and sets are tied at `setsToWin - 1` each,
///   the final set is replaced by a 10-point super tiebreak (first to 10, win by 2).
///   Only meaningful when `bestOf > 1`.
public struct MatchFormat: Sendable, Codable, Hashable, Equatable {
    public var bestOf: Int
    public var gamesPerSet: Int
    public var tiebreakAt: Int
    public var decidingSetTiebreak: Bool

    /// Number of sets a side must win to take the match.
    public var setsToWin: Int { (bestOf + 1) / 2 }

    public init(
        bestOf: Int,
        gamesPerSet: Int,
        tiebreakAt: Int,
        decidingSetTiebreak: Bool = false
    ) {
        let safeBestOf      = max(1, bestOf % 2 == 0 ? bestOf + 1 : bestOf)
        let safeGames       = max(1, gamesPerSet)
        let safeTiebreak    = max(1, min(tiebreakAt, safeGames))
        self.bestOf             = safeBestOf
        self.gamesPerSet        = safeGames
        self.tiebreakAt         = safeTiebreak
        self.decidingSetTiebreak = decidingSetTiebreak && safeBestOf > 1
    }

    // MARK: - Named presets

    /// Best of 3 sets, 6 games per set, tiebreak at 6-6.
    public static let bestOf3  = MatchFormat(bestOf: 3, gamesPerSet: 6, tiebreakAt: 6)
    /// Single set, 6 games, tiebreak at 6-6.
    public static let bestOf1  = MatchFormat(bestOf: 1, gamesPerSet: 6, tiebreakAt: 6)
    /// Pro set: single set of 8 games, tiebreak at 8-8.
    public static let proSet   = MatchFormat(bestOf: 1, gamesPerSet: 8, tiebreakAt: 8)
    /// Short set: single set of 4 games, tiebreak at 4-4.
    public static let shortSet = MatchFormat(bestOf: 1, gamesPerSet: 4, tiebreakAt: 4)
    /// Default starting values for the custom preset (matches old-app defaults).
    public static let custom   = MatchFormat(bestOf: 1, gamesPerSet: 4, tiebreakAt: 3)
}
