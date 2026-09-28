/// All the rules of a match in one value.
///
/// - `bestOf`: total sets to play (must be odd; winner takes majority).
/// - `gamesPerSet`: games required to win a set (with a 2-game lead). It also fixes when the
///   tiebreak comes: at games-all (6-6 in a set to 6), exposed as `tiebreakThreshold`. There's no
///   separate setting, so the two can't disagree.
/// - `decidingSetTiebreak`: when true and sets are tied at `setsToWin - 1` each,
///   the final set is replaced by a 10-point super tiebreak (first to 10, win by 2).
///   Only meaningful when `bestOf > 1`.
/// - `noAdScoring`: how a game is won from deuce (40-40).
///   Off (standard, advantage scoring): a side needs two points in a row, going through
///   advantage (Ad In / Ad Out) before the game.
///   On (no-ad, "sudden" deuce): the next point after deuce wins the game; there is no
///   advantage. Tiebreaks are not affected.
public struct MatchFormat: Sendable, Codable, Hashable, Equatable {
    public var bestOf: Int
    public var gamesPerSet: Int
    public var decidingSetTiebreak: Bool
    public var noAdScoring: Bool

    /// Number of sets a side must win to take the match.
    public var setsToWin: Int { (bestOf + 1) / 2 }

    /// A set goes to a tiebreak when both sides reach this many games.
    public var tiebreakThreshold: Int { gamesPerSet }

    public init(
        bestOf: Int,
        gamesPerSet: Int,
        decidingSetTiebreak: Bool = false,
        noAdScoring: Bool = false
    ) {
        let safeBestOf      = max(1, bestOf % 2 == 0 ? bestOf + 1 : bestOf)
        self.bestOf             = safeBestOf
        self.gamesPerSet        = max(1, gamesPerSet)
        self.decidingSetTiebreak = decidingSetTiebreak && safeBestOf > 1
        self.noAdScoring        = noAdScoring
    }

    /// Matches saved before no-ad scoring existed have no `noAdScoring` key; they load as standard
    /// scoring. Older saves also carry a `tiebreakAt` key, which is ignored.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        bestOf              = try c.decode(Int.self, forKey: .bestOf)
        gamesPerSet         = try c.decode(Int.self, forKey: .gamesPerSet)
        decidingSetTiebreak = try c.decode(Bool.self, forKey: .decidingSetTiebreak)
        noAdScoring         = try c.decodeIfPresent(Bool.self, forKey: .noAdScoring) ?? false
    }

    // MARK: - Named presets

    /// Best of 3 sets, 6 games per set, tiebreak at 6-6.
    public static let bestOf3  = MatchFormat(bestOf: 3, gamesPerSet: 6)
    /// Single set, 6 games, tiebreak at 6-6.
    public static let bestOf1  = MatchFormat(bestOf: 1, gamesPerSet: 6)
    /// Pro set: single set of 8 games, tiebreak at 8-8.
    public static let proSet   = MatchFormat(bestOf: 1, gamesPerSet: 8)
    /// Short set: single set of 4 games, tiebreak at 4-4.
    public static let shortSet = MatchFormat(bestOf: 1, gamesPerSet: 4)
    /// Starting values for the custom preset.
    public static let custom   = MatchFormat(bestOf: 1, gamesPerSet: 6)
}
