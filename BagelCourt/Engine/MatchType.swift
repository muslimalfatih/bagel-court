/// The format of play — affects how many player names are collected.
/// Does not change scoring rules; the engine always operates on home vs away.
public enum MatchType: String, Sendable, Codable, Hashable, CaseIterable {
    case singles = "Singles"
    case doubles = "Doubles"
    case mixed   = "Mixed"
}
