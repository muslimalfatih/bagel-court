/// Internal state machine produced by replaying the point log.
/// Never expose this type; use `Match`'s computed properties instead.
struct MatchState {

    // MARK: - Fields

    var server: Side                    // current game server
    var tiebreakFirstServer: Side?      // first server when a tiebreak started
    var completedSets: [SetResult]
    var currentSetHome: Int
    var currentSetAway: Int
    var homePoints: Int                 // raw points in the current game / tiebreak
    var awayPoints: Int
    var isInTiebreak: Bool              // regular or super tiebreak is active
    var isSuperTiebreak: Bool           // match-deciding 10-point tiebreak
    var winner: Side?

    let format: MatchFormat

    // MARK: - Init (replay constructor)

    init(replaying points: [Side], format: MatchFormat, initialServer: Side) {
        self.server             = initialServer
        self.format             = format
        self.tiebreakFirstServer = nil
        self.completedSets      = []
        self.currentSetHome     = 0
        self.currentSetAway     = 0
        self.homePoints         = 0
        self.awayPoints         = 0
        self.isInTiebreak       = false
        self.isSuperTiebreak    = false
        self.winner             = nil

        for point in points {
            guard winner == nil else { break }
            apply(point)
        }
    }

    // MARK: - Derived properties

    /// Who is serving the current point, accounting for tiebreak rotation.
    var currentServer: Side {
        guard isInTiebreak, let ts = tiebreakFirstServer else { return server }
        // Serve switches after point 1, then every 2 points.
        // After `played` total points, the number of switches that have occurred
        // equals ceil(played / 2) = (played + 1) / 2  (integer division).
        let played = homePoints + awayPoints
        let switches = (played + 1) / 2
        return switches % 2 == 0 ? ts : ts.opposite
    }

    var gameScore: GameScore {
        if isInTiebreak {
            return .tiebreak(home: homePoints, away: awayPoints)
        }
        let h = homePoints, a = awayPoints
        if h >= 3 && a >= 3 {
            return h == a ? .deuce : .advantage(h > a ? .home : .away)
        }
        let pts = [0, 15, 30, 40]
        return .regular(home: pts[min(h, 3)], away: pts[min(a, 3)])
    }

    /// All sets to display: completed sets, then the current set (or tiebreak points).
    var allSets: [SetResult] {
        guard winner == nil else { return completedSets }
        if isSuperTiebreak {
            // Live tiebreak points — flag so the UI can render them differently.
            return completedSets + [SetResult(home: homePoints, away: awayPoints, isSuperTiebreak: true)]
        }
        return completedSets + [SetResult(home: currentSetHome, away: currentSetAway)]
    }

    var homeSetsWon: Int { completedSets.filter(\.homeWon).count }
    var awaySetsWon: Int { completedSets.filter(\.awayWon).count }

    // MARK: - Point application

    mutating func apply(_ scorer: Side) {
        if scorer == .home { homePoints += 1 } else { awayPoints += 1 }
        if isSuperTiebreak  { checkSuperTiebreak() }
        else if isInTiebreak { checkTiebreak() }
        else                 { checkGame() }
    }

    // MARK: - Win-condition checks

    private mutating func checkGame() {
        let h = homePoints, a = awayPoints
        if h >= 4 && h - a >= 2 { gameWon(by: .home) }
        else if a >= 4 && a - h >= 2 { gameWon(by: .away) }
    }

    private mutating func checkTiebreak() {
        let h = homePoints, a = awayPoints
        // Regular tiebreak: first to 7, win by 2.
        // Winning is handled via gameWon so the set-game increment is consistent.
        if h >= 7 && h - a >= 2 { gameWon(by: .home) }
        else if a >= 7 && a - h >= 2 { gameWon(by: .away) }
    }

    private mutating func checkSuperTiebreak() {
        let h = homePoints, a = awayPoints
        // Super tiebreak: first to 10, win by 2.  It IS the deciding set.
        if h >= 10 && h - a >= 2 { superTiebreakEnded(winner: .home) }
        else if a >= 10 && a - h >= 2 { superTiebreakEnded(winner: .away) }
    }

    // MARK: - Game / tiebreak completion

    /// Called when a regular game or regular tiebreak is won.
    /// Increments the winner's game count in the current set, then checks whether the set is over.
    private mutating func gameWon(by scorer: Side) {
        if scorer == .home { currentSetHome += 1 } else { currentSetAway += 1 }
        homePoints = 0
        awayPoints = 0

        // After a regular tiebreak the non-first-server serves the new set.
        // After a normal game the server just rotates.
        if let ts = tiebreakFirstServer {
            server = ts.opposite
        } else {
            server = server.opposite
        }
        isInTiebreak    = false
        tiebreakFirstServer = nil

        checkSetOver()
    }

    /// Called when the 10-point super tiebreak ends. The tiebreak points become the set result.
    private mutating func superTiebreakEnded(winner: Side) {
        let result = SetResult(home: homePoints, away: awayPoints, isSuperTiebreak: true)
        homePoints = 0
        awayPoints = 0

        if let ts = tiebreakFirstServer { server = ts.opposite }
        isInTiebreak    = false
        isSuperTiebreak = false
        tiebreakFirstServer = nil

        completedSets.append(result)

        // The super tiebreak is always the deciding set, so the match must end here.
        let homeSets = completedSets.filter(\.homeWon).count
        let awaySets = completedSets.filter(\.awayWon).count
        if homeSets >= format.setsToWin      { self.winner = .home }
        else if awaySets >= format.setsToWin { self.winner = .away }
    }

    // MARK: - Set completion

    private mutating func checkSetOver() {
        let h = currentSetHome, a = currentSetAway

        // Reached tiebreakAt–tiebreakAt → enter the regular tiebreak.
        if h == format.tiebreakAt && a == format.tiebreakAt {
            isInTiebreak    = true
            tiebreakFirstServer = server
            return
        }

        // Check if someone won the set.
        let post = format.tiebreakAt + 1          // game count after winning a tiebreak (e.g. 7)
        let setOver = (h >= format.gamesPerSet && h - a >= 2)
                   || (a >= format.gamesPerSet && a - h >= 2)
                   || h == post || a == post
        guard setOver else { return }

        completedSets.append(SetResult(home: h, away: a))
        currentSetHome = 0
        currentSetAway = 0

        let homeSets = completedSets.filter(\.homeWon).count
        let awaySets = completedSets.filter(\.awayWon).count

        if homeSets >= format.setsToWin {
            self.winner = .home
        } else if awaySets >= format.setsToWin {
            self.winner = .away
        } else if format.decidingSetTiebreak
                    && homeSets == format.setsToWin - 1
                    && awaySets == format.setsToWin - 1 {
            // Deciding set → replace with a 10-point super tiebreak.
            isSuperTiebreak     = true
            isInTiebreak        = true
            tiebreakFirstServer = server
        }
        // Otherwise a new regular set begins (currentSet already reset to 0–0).
    }
}
