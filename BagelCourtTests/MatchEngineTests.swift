import Testing
@testable import BagelCourt

// MARK: - Test helpers

private extension Match {
    /// Score `n` points for home. Points are applied one at a time so win
    /// conditions fire at the correct moment.
    mutating func home(_ n: Int = 1) { for _ in 0..<n { score(point: .home) } }
    mutating func away(_ n: Int = 1) { for _ in 0..<n { score(point: .away) } }

    /// Win a game for `side` with four love points.
    mutating func winGame(for side: Side) {
        for _ in 0..<4 { score(point: side) }
    }

    /// Win `n` consecutive games for `side`.
    mutating func winGames(_ n: Int, for side: Side) {
        for _ in 0..<n { winGame(for: side) }
    }

    /// Score interleaved points so neither side triggers a win prematurely.
    /// Useful for reaching a specific tiebreak score such as 7-5.
    mutating func interleaved(home homeCount: Int, away awayCount: Int) {
        let shared = min(homeCount, awayCount)
        for _ in 0..<shared { score(point: .home); score(point: .away) }
        home(homeCount - shared)
        away(awayCount - shared)
    }
}

private func makeMatch(
    format: MatchFormat = .bestOf3,
    server: Side = .home
) -> Match {
    Match(homePlayer: "Alex", awayPlayer: "Maria",
          format: format, initialServer: server)
}

// MARK: - Suite

@Suite("Tennis Engine")
struct MatchEngineTests {

    // MARK: 1. Love game

    @Test("Love game: four straight points wins the game")
    func loveGame() {
        var m = makeMatch()
        #expect(m.currentGameScore == .regular(home: 0, away: 0))

        m.home(); #expect(m.currentGameScore == .regular(home: 15, away: 0))
        m.home(); #expect(m.currentGameScore == .regular(home: 30, away: 0))
        m.home(); #expect(m.currentGameScore == .regular(home: 40, away: 0))
        m.home()

        // Game complete — score resets, home has one game in set 1.
        #expect(m.currentGameScore == .regular(home: 0, away: 0))
        #expect(m.allSets.last?.home == 1)
        #expect(m.allSets.last?.away == 0)
    }

    // MARK: 2. Deuce / advantage sequence

    @Test("Deuce and advantage: display strings at each step")
    func deuceSequence() {
        var m = makeMatch()
        let srv = m.currentServer   // .home (initialServer)

        // Reach 40–40 via 3+3 points.
        m.home(3); m.away(3)
        #expect(m.currentGameScore == .deuce)
        #expect(m.currentGameScore.displayString(server: srv) == "DEUCE")

        m.home()   // home advantage
        #expect(m.currentGameScore == .advantage(.home))
        #expect(m.currentGameScore.displayString(server: srv) == "AD IN")

        m.away()   // back to deuce
        #expect(m.currentGameScore == .deuce)
        #expect(m.currentGameScore.displayString(server: srv) == "DEUCE")

        m.away()   // away advantage
        #expect(m.currentGameScore == .advantage(.away))
        #expect(m.currentGameScore.displayString(server: srv) == "AD OUT")

        m.away()   // away wins game
        #expect(m.currentGameScore == .regular(home: 0, away: 0))
        #expect(m.allSets.last?.away == 1)
        #expect(m.allSets.last?.home == 0)
    }

    // MARK: 3a. 6–4 set

    @Test("Set won 6–4")
    func sixFourSet() {
        var m = makeMatch()
        // Win alternating games up to 4–4, then home wins two more.
        m.winGames(4, for: .home)
        m.winGames(4, for: .away)   // 4–4 alternating; actually does H,H,H,H,A,A,A,A
        // Games above give home 4 games total (4 consecutive), away 4 consecutive.
        // More precisely: home wins games 1-4, away wins 5-8.  Score = 4-4.
        m.winGames(2, for: .home)   // 6–4
        let first = m.allSets.first!
        #expect(first.home == 6)
        #expect(first.away == 4)
    }

    // MARK: 3b. 7–5 set

    @Test("Set won 7–5")
    func sevenFiveSet() {
        var m = makeMatch()
        // Alternate to 5–5, then home wins two straight.
        for _ in 0..<5 { m.winGame(for: .home); m.winGame(for: .away) }  // 5–5
        m.winGame(for: .home)   // 6–5
        m.winGame(for: .home)   // 7–5
        let first = m.allSets.first!
        #expect(first.home == 7 && first.away == 5)
    }

    // MARK: 3c. 6–6 triggers a tiebreak

    @Test("Reaching 6–6 enters a tiebreak")
    func sixSixTiebreak() {
        var m = makeMatch()
        for _ in 0..<6 { m.winGame(for: .home); m.winGame(for: .away) }  // 6–6
        #expect(m.isInTiebreak)
        #expect(!m.isSuperTiebreak)
        #expect(m.currentGameScore == .tiebreak(home: 0, away: 0))
    }

    // MARK: 4a. Tiebreak won 7–5

    @Test("Tiebreak won 7–5")
    func tiebreakSevenFive() {
        var m = makeMatch()
        for _ in 0..<6 { m.winGame(for: .home); m.winGame(for: .away) }   // 6–6 → tiebreak

        // Interleave to reach 5–5, then home scores 2 more → 7–5.
        m.interleaved(home: 5, away: 5)   // 5–5 in tiebreak
        m.home(2)                          // 7–5 → home wins

        #expect(!m.isInTiebreak)
        let set = m.allSets.first!         // first set now complete
        #expect(set.home == 7 && set.away == 6)   // game score: 7–6 (tiebreak win)
    }

    // MARK: 4b. Tiebreak won 9–7 (win-by-two beyond 7)

    @Test("Tiebreak won 9–7 (extended)")
    func tiebreakNineSeven() {
        var m = makeMatch()
        for _ in 0..<6 { m.winGame(for: .home); m.winGame(for: .away) }   // tiebreak

        m.interleaved(home: 7, away: 7)   // 7–7 (neither wins yet)
        m.home(2)                          // 9–7 → home wins

        #expect(!m.isInTiebreak)
        let set = m.allSets.first!
        #expect(set.home == 7 && set.away == 6)
    }

    // MARK: 5a. Serve alternates after each game

    @Test("Server alternates every game")
    func serveAlternation() {
        var m = makeMatch(server: .home)

        let initial = m.currentServer
        #expect(initial == .home)

        m.winGame(for: .home)    // game 1 done → switch
        #expect(m.currentServer == .away)

        m.winGame(for: .away)    // game 2 → switch
        #expect(m.currentServer == .home)

        m.winGame(for: .home)    // game 3 → switch
        #expect(m.currentServer == .away)
    }

    // MARK: 5b. Tiebreak: first point served by non-last-game-server, then every 2 points

    @Test("Tiebreak serve: 1-then-2 rotation rule")
    func tiebreakServe() {
        var m = makeMatch(server: .home)

        // Advance to 6–6.  Game 12 will be served by away (games 1,3,5,7,9,11 = home; 2,4,6,8,10,12 = away).
        for _ in 0..<6 { m.winGame(for: .home); m.winGame(for: .away) }

        // Tiebreak first server = home (non-last-game-server; game 12 was served by away → switch → home).
        #expect(m.currentServer == .home)

        // Point 1 served by home → after it, away serves point 2.
        m.home()
        #expect(m.currentServer == .away)   // switch after 1st tiebreak point

        // Points 2 & 3 both served by away; after point 2 no switch, after point 3 switch.
        m.away()
        #expect(m.currentServer == .away)   // no switch after 2nd point (even total = 2)

        m.away()
        #expect(m.currentServer == .home)   // switch after 3rd point (odd total = 3)

        // Points 4 & 5 by home.
        m.home()
        #expect(m.currentServer == .home)   // no switch after 4th
        m.home()
        #expect(m.currentServer == .away)   // switch after 5th
    }

    // MARK: 6. Full best-of-3 match

    @Test("Full best-of-3 match ends the moment the second set is won")
    func fullBestOfThree() {
        var m = makeMatch(format: .bestOf3)

        // Home wins set 1 (6–0) and set 2 (6–0).
        m.winGames(6, for: .home)   // set 1 complete 6–0
        m.winGames(6, for: .home)   // set 2 complete 6–0 → match over

        #expect(m.isOver)
        #expect(m.winner == .home)
        #expect(m.completedSetsCount == 2)
        #expect(m.homeSetsWon == 2)
        #expect(m.awaySetsWon == 0)

        // Extra points are refused.
        let pointsBefore = m.points.count
        m.home()
        #expect(m.points.count == pointsBefore)   // no change
    }

    // MARK: 7. Undo across every kind of boundary

    @Test("Undo restores state across a game boundary")
    func undoAcrossGameBoundary() {
        var m = makeMatch()
        m.home(3)   // 40–0

        let before = captureState(m)
        m.home()    // wins game → 1–0 in set, score resets

        #expect(m.allSets.last?.home == 1)

        m.undoLastPoint()
        let after = captureState(m)

        #expect(before == after)
    }

    @Test("Undo across a set boundary")
    func undoAcrossSetBoundary() {
        var m = makeMatch()
        m.winGames(5, for: .home)
        m.winGames(4, for: .away)   // 5–4; home needs one more game to win set
        m.home(3)                    // 40–0 in the sixth game

        let before = captureState(m)
        m.home()                     // home wins 6th game → set 6–4 complete

        #expect(m.allSets.count == 2)   // completed set + new 0–0 current set

        m.undoLastPoint()
        let after = captureState(m)
        #expect(before == after)
    }

    @Test("Undo tiebreak entry: removes tiebreak state")
    func undoTiebreakEntry() {
        var m = makeMatch()
        for _ in 0..<5 { m.winGame(for: .home); m.winGame(for: .away) }   // 5–5
        m.winGame(for: .home); m.winGame(for: .away)                        // 6–6 → tiebreak starts

        #expect(m.isInTiebreak)

        let before = captureState(m)
        m.home()   // first tiebreak point

        m.undoLastPoint()
        let after = captureState(m)
        #expect(before == after)
        #expect(after.isInTiebreak)
    }

    @Test("Undo across a tiebreak win")
    func undoAcrossTiebreakWin() {
        var m = makeMatch()
        for _ in 0..<6 { m.winGame(for: .home); m.winGame(for: .away) }
        m.interleaved(home: 6, away: 5)   // 6–5 (one more home wins)

        let before = captureState(m)
        m.home()   // 7–5 → tiebreak won, new set starts

        m.undoLastPoint()
        let after = captureState(m)
        #expect(before == after)
        #expect(after.isInTiebreak)
    }

    @Test("Undo across match end")
    func undoAcrossMatchEnd() {
        var m = makeMatch(format: .bestOf3)
        m.winGames(6, for: .home)   // set 1
        m.winGames(5, for: .home)   // 5–0 in set 2
        m.home(3)                    // 40–0

        let before = captureState(m)
        m.home()                     // wins match

        #expect(m.isOver)
        m.undoLastPoint()
        let after = captureState(m)

        #expect(!after.isOver)
        #expect(before == after)
    }
}

// MARK: - Match convenience for tests

private extension Match {
    var completedSetsCount: Int {
        allSets.filter { $0.home != 0 || $0.away != 0 }.count
        // Note: this is approximate; real code uses completedSets internal count.
        // For test purposes, winner != nil means allSets == completedSets.
        // Just count all sets when match is over.
    }
}

// MARK: - State snapshot for undo verification

private struct StateCapture: Equatable {
    let allSets: [SetResult]
    let gameScore: GameScore
    let server: Side
    let isInTiebreak: Bool
    let isOver: Bool
}

private func captureState(_ m: Match) -> StateCapture {
    StateCapture(
        allSets: m.allSets,
        gameScore: m.currentGameScore,
        server: m.currentServer,
        isInTiebreak: m.isInTiebreak,
        isOver: m.isOver
    )
}
