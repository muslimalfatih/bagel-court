import Foundation
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

    // MARK: 2b. No-ad scoring

    @Test("No-ad: 40–40 still shows, then the next point wins the game", arguments: Side.allCases)
    func noAdDecidingPoint(winner: Side) {
        var m = makeMatch(format: MatchFormat(bestOf: 3, gamesPerSet: 6, noAdScoring: true))
        m.home(3); m.away(3)
        #expect(m.currentGameScore == .deuce)
        #expect(m.currentGameScore.homeLabel(server: .home) == "40")
        #expect(m.currentGameScore.awayLabel(server: .home) == "40")

        m.score(point: winner)   // deciding point: game, never advantage
        #expect(m.currentGameScore == .regular(home: 0, away: 0))
        #expect(m.allSets.last?.home == (winner == .home ? 1 : 0))
        #expect(m.allSets.last?.away == (winner == .away ? 1 : 0))
    }

    @Test("Standard scoring: the point after 40–40 is advantage, not game")
    func adScoringDeuceGivesAdvantage() {
        var m = makeMatch()   // no-ad is off by default
        m.home(3); m.away(3)
        m.home()
        #expect(m.currentGameScore == .advantage(.home))
        #expect(m.allSets.last?.home == 0)
    }

    @Test("No-ad leaves tiebreaks win-by-two")
    func noAdTiebreakStillWinByTwo() {
        var m = makeMatch(format: MatchFormat(bestOf: 3, gamesPerSet: 6, noAdScoring: true))
        for _ in 0..<6 { m.winGame(for: .home); m.winGame(for: .away) }   // 6–6 → tiebreak

        m.interleaved(home: 6, away: 6)
        m.home()   // 7–6: one ahead is not enough
        #expect(m.currentGameScore == .tiebreak(home: 7, away: 6))
        m.home()   // 8–6
        #expect(!m.isInTiebreak)
        #expect(m.allSets.first?.home == 7 && m.allSets.first?.away == 6)
    }

    @Test("Matches saved before no-ad existed load with standard scoring")
    func formatDecodesWithoutNoAdKey() throws {
        let saved = #"{"bestOf":3,"gamesPerSet":6,"tiebreakAt":6,"decidingSetTiebreak":false}"#
        let format = try JSONDecoder().decode(MatchFormat.self, from: Data(saved.utf8))
        #expect(format == .bestOf3)   // noAdScoring defaults to false; the old tiebreakAt key is ignored
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

    @Test("The tiebreak follows the games per set: a custom set to 5 goes to one at 5–5")
    func tiebreakFollowsGamesPerSet() {
        var m = makeMatch(format: MatchFormat(bestOf: 1, gamesPerSet: 5))
        for _ in 0..<4 { m.winGame(for: .home); m.winGame(for: .away) }   // 4–4: no tiebreak yet
        #expect(!m.isInTiebreak)
        m.winGame(for: .home); m.winGame(for: .away)                       // 5–5
        #expect(m.isInTiebreak)
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

    // MARK: 8. Correcting a finished match from History

    @Test("Correcting names and date keeps the points")
    func correctedDetails() {
        var m = makeMatch()
        m.winGames(6, for: .home)
        let date = Date(timeIntervalSince1970: 0)
        let edited = m.withDetails(homePlayer: "Alexandra", homePlayer2: nil,
                                   awayPlayer: "Maria", awayPlayer2: nil, startDate: date)
        #expect(edited.homeDisplayName == "Alexandra" && edited.startDate == date && edited.id == m.id)
        #expect(edited.points == m.points)
    }

    @Test("A corrected final score replays to exactly those sets")
    func correctedFinalScore() throws {
        let sets = [SetResult(home: 6, away: 4), SetResult(home: 3, away: 6), SetResult(home: 7, away: 6)]
        let m = try #require(makeMatch().withFinalScore(sets))
        #expect(m.isOver && m.winner == .home)
        #expect(m.allSets == sets)
    }

    @Test("A corrected match tiebreak is scored in points")
    func correctedMatchTiebreak() throws {
        let format = MatchFormat(bestOf: 3, gamesPerSet: 6, decidingSetTiebreak: true)
        let sets = [SetResult(home: 6, away: 4), SetResult(home: 4, away: 6), SetResult(home: 10, away: 12)]
        let m = try #require(makeMatch(format: format).withFinalScore(sets))
        #expect(m.winner == .away)
        #expect(m.allSets.last == SetResult(home: 10, away: 12, isSuperTiebreak: true))
    }

    @Test("Scores that can't finish a match are rejected", arguments: [
        [[6, 5]],           // no winner yet in a set to 6
        [[6, 6]],           // a tie
        [[8, 6]],           // 6–6 goes to a tiebreak, so a set can't reach 8–6
        [[6, 4], [6, 4]],   // a second set after a best of 1 was won
    ])
    func impossibleFinalScore(sets: [[Int]]) {
        let scores = sets.map { SetResult(home: $0[0], away: $0[1]) }
        #expect(makeMatch(format: .bestOf1).withFinalScore(scores) == nil)
        #expect(makeMatch().withFinalScore([SetResult(home: 6, away: 4)]) == nil)   // best of 3 not finished
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
