/// The score state of the current game (or tiebreak).
public enum GameScore: Sendable, Codable, Equatable {
    /// Regular game points: 0, 15, 30, or 40 for each side.
    case regular(home: Int, away: Int)
    /// Both sides have reached 40; next point gives advantage.
    case deuce
    /// One side holds the advantage point.
    case advantage(Side)
    /// A tiebreak or super-tiebreak is in progress; values are raw points.
    case tiebreak(home: Int, away: Int)
}

public extension GameScore {
    /// "40–30", "DEUCE", "AD IN"/"AD OUT" (server-relative), or "5–3" for a tiebreak.
    func displayString(server: Side) -> String {
        switch self {
        case .regular(let h, let a):    return "\(h)–\(a)"
        case .deuce:                    return "DEUCE"
        case .advantage(let side):      return side == server ? "AD IN" : "AD OUT"
        case .tiebreak(let h, let a):   return "\(h)–\(a)"
        }
    }

    /// Score label shown for the home side (used in side-by-side scoreboards).
    func homeLabel(server: Side) -> String {
        switch self {
        case .regular(let h, _):    return "\(h)"
        case .deuce:                return "40"
        case .advantage(let side):  return side == .home ? "Ad" : "–"
        case .tiebreak(let h, _):   return "\(h)"
        }
    }

    /// Score label shown for the away side.
    func awayLabel(server: Side) -> String {
        switch self {
        case .regular(_, let a):    return "\(a)"
        case .deuce:                return "40"
        case .advantage(let side):  return side == .away ? "Ad" : "–"
        case .tiebreak(_, let a):   return "\(a)"
        }
    }

    var isDeuceOrAdvantage: Bool {
        switch self {
        case .deuce, .advantage: return true
        default: return false
        }
    }
}
