import Foundation
import Combine

enum LegacyMatchFormat: String, CaseIterable {
    case bestOf3 = "Best of 3"
    case bestOf5 = "Best of 5"
    var setsToWin: Int { self == .bestOf3 ? 2 : 3 }
}

struct SetScore {
    var player1Games: Int = 0
    var player2Games: Int = 0
}

private struct Snapshot {
    let sets: [SetScore]
    let p1Points: Int
    let p2Points: Int
    let server: Int
    let isInTiebreak: Bool
    let winner: Int?
}

class TennisMatch: ObservableObject {
    let player1Name: String
    let player2Name: String
    let format: LegacyMatchFormat

    @Published var sets: [SetScore] = [SetScore()]
    @Published var p1Points: Int = 0
    @Published var p2Points: Int = 0
    @Published var server: Int
    @Published var isInTiebreak: Bool = false
    @Published var winner: Int? = nil

    private var history: [Snapshot] = []

    init(player1: String, player2: String, format: LegacyMatchFormat, firstServer: Int = 1) {
        self.player1Name = player1
        self.player2Name = player2
        self.format = format
        self.server = firstServer
    }

    var currentSetIndex: Int { sets.count - 1 }

    var gameScore: (p1: String, p2: String) {
        if isInTiebreak { return (p1: "\(p1Points)", p2: "\(p2Points)") }
        if p1Points >= 3 && p2Points >= 3 {
            if p1Points == p2Points { return (p1: "40", p2: "40") }
            return p1Points > p2Points ? (p1: "Ad", p2: "–") : (p1: "–", p2: "Ad")
        }
        let pts = ["0", "15", "30", "40"]
        return (p1: pts[min(p1Points, 3)], p2: pts[min(p2Points, 3)])
    }

    var canUndo: Bool { !history.isEmpty }

    func scorePoint(for player: Int) {
        guard winner == nil else { return }
        history.append(Snapshot(
            sets: sets, p1Points: p1Points, p2Points: p2Points,
            server: server, isInTiebreak: isInTiebreak, winner: winner
        ))
        if player == 1 { p1Points += 1 } else { p2Points += 1 }
        if isInTiebreak { processTiebreak() } else { processGame() }
    }

    func undo() {
        guard let snap = history.popLast() else { return }
        sets = snap.sets
        p1Points = snap.p1Points
        p2Points = snap.p2Points
        server = snap.server
        isInTiebreak = snap.isInTiebreak
        winner = snap.winner
    }

    private func processTiebreak() {
        let total = p1Points + p2Points
        if total % 2 == 1 { server = server == 1 ? 2 : 1 }
        if p1Points >= 7 && p1Points - p2Points >= 2 { gameWon(by: 1) }
        else if p2Points >= 7 && p2Points - p1Points >= 2 { gameWon(by: 2) }
    }

    private func processGame() {
        if p1Points >= 4 && p1Points - p2Points >= 2 { gameWon(by: 1) }
        else if p2Points >= 4 && p2Points - p1Points >= 2 { gameWon(by: 2) }
    }

    private func gameWon(by player: Int) {
        if player == 1 { sets[currentSetIndex].player1Games += 1 }
        else { sets[currentSetIndex].player2Games += 1 }
        p1Points = 0
        p2Points = 0
        isInTiebreak = false
        server = server == 1 ? 2 : 1
        checkSetOver()
    }

    private func checkSetOver() {
        let g1 = sets[currentSetIndex].player1Games
        let g2 = sets[currentSetIndex].player2Games

        if g1 == 6 && g2 == 6 { isInTiebreak = true; return }

        let over = (g1 >= 6 && g1 - g2 >= 2) || (g2 >= 6 && g2 - g1 >= 2) || g1 == 7 || g2 == 7
        guard over else { return }

        let p1Sets = sets.filter { $0.player1Games > $0.player2Games }.count
        let p2Sets = sets.filter { $0.player2Games > $0.player1Games }.count

        if p1Sets >= format.setsToWin { winner = 1 }
        else if p2Sets >= format.setsToWin { winner = 2 }
        else { sets.append(SetScore()) }
    }
}
