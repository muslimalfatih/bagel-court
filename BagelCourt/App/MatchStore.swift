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
    var displayLabel: String {
        if self == .bestOf3  { return "Best of 3" }
        if self == .bestOf1  { return "Best of 1" }
        if self == .proSet   { return "Pro Set" }
        if self == .shortSet { return "Short Set" }
        return "Custom"
    }
}
