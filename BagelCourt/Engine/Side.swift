/// Which side of the net a player/team stands on.
/// "Home" = the local/first player; "Away" = the opponent.
public enum Side: String, Sendable, Codable, Hashable, CaseIterable {
    case home
    case away

    public var opposite: Side { self == .home ? .away : .home }
}
