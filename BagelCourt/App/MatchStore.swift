import SwiftData
import Foundation

/// SwiftData model. Stores the full match as a JSON blob so the engine's
/// value-type `Match` is persisted without a separate schema migration every
/// time a field changes.
@Model
final class MatchRecord {
    var id: UUID
    @Attribute(.unique) var matchID: String   // UUID string for @Predicate
    var matchData: Data                        // JSON-encoded Match
    var isCompleted: Bool
    var startDate: Date
    var endDate: Date?
    // Denormalised display fields for list rendering without decoding the blob.
    var homeDisplayName: String
    var awayDisplayName: String
    var formatLabel: String

    init(match: Match) throws {
        self.id              = UUID()
        self.matchID         = match.id.uuidString
        self.matchData       = try JSONEncoder().encode(match)
        self.isCompleted     = match.isOver
        self.startDate       = match.startDate
        self.endDate         = match.isOver ? Date() : nil
        self.homeDisplayName = match.homeDisplayName
        self.awayDisplayName = match.awayDisplayName
        self.formatLabel     = match.format.displayLabel
    }

    /// Overwrite stored data from a mutated match value.
    func update(with match: Match) throws {
        matchData       = try JSONEncoder().encode(match)
        isCompleted     = match.isOver
        homeDisplayName = match.homeDisplayName
        awayDisplayName = match.awayDisplayName
        if match.isOver && endDate == nil { endDate = Date() }
    }

    /// Decode the stored match. Returns nil if the data is corrupt.
    var decoded: Match? {
        try? JSONDecoder().decode(Match.self, from: matchData)
    }
}

// MARK: - MatchFormat display label (App layer; not in engine)

extension MatchFormat {
    /// "Best of 3", "Pro Set" and so on, plus " · No-Ad" when that rule is on.
    /// Named by sets, games and tiebreak only: comparing whole formats labelled a best of 3
    /// with a deciding-set tiebreak (or any no-ad match) as "Custom".
    var displayLabel: String {
        let name: String
        switch (bestOf, gamesPerSet, tiebreakAt) {
        case (3, 6, 6): name = "Best of 3"
        case (1, 6, 6): name = "Best of 1"
        case (1, 8, 8): name = "Pro Set"
        case (1, 4, 4): name = "Short Set"
        default:        name = "Custom"
        }
        return noAdScoring ? name + " · No-Ad" : name
    }
}
