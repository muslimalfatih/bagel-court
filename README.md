# BagelCourt

**Live tennis scoring for iPhone, with an Apple Watch mirror.**

BagelCourt keeps score so you can keep playing. Tap who won the point, and the app takes care of the rest: deuce and advantage, tiebreaks, service rotation, sets and match point. If you tap the wrong side, one undo puts it right, even across a game, set or match boundary.

![Platform](https://img.shields.io/badge/platform-iOS%2026.5%2B-black)
![Swift](https://img.shields.io/badge/Swift-5-orange)
![UI](https://img.shields.io/badge/UI-SwiftUI-blue)
![Persistence](https://img.shields.io/badge/storage-SwiftData-green)

> [!NOTE]
> BagelCourt is in early development. The iPhone app is usable today; the watchOS companion target is not yet part of the project (see [Roadmap](#roadmap)).

---

## Contents

- [Features](#features)
- [Requirements](#requirements)
- [Getting started](#getting-started)
- [Running the tests](#running-the-tests)
- [Architecture](#architecture)
- [Project structure](#project-structure)
- [Using the scoring engine](#using-the-scoring-engine)
- [Roadmap](#roadmap)
- [Contributing](#contributing)
- [License](#license)

## Features

- **One-tap scoring.** Score a point for either side; the display follows tennis conventions (`15–30`, `DEUCE`, `AD IN` / `AD OUT`).
- **Complete rules engine.** Advantage scoring, tiebreaks (including extended ones like 9–7), the 1-then-2 tiebreak serve rotation, and an optional 10-point super tiebreak in place of a deciding set.
- **Match formats.** Presets for best of 3, best of 1, pro set (8 games) and short set (4 games), plus a custom format.
- **Singles, doubles and mixed.** The match type only changes how many names are collected; scoring is identical.
- **Unlimited undo.** Undo works across any boundary because every score is derived from the point log.
- **Match history.** Matches are saved on device with SwiftData. Unfinished matches can be resumed or discarded.
- **Shareable scorecard.** Export a finished match as an image through the system share sheet.
- **Apple Watch mirror.** The phone pushes a live score snapshot to the watch over WatchConnectivity.

## Requirements

| Tool | Version |
| --- | --- |
| Xcode | 26.6 or later |
| iOS deployment target | 26.5 |
| Swift | 5 (Swift 6 approachable concurrency enabled, default `MainActor` isolation) |

There are no third-party dependencies. Everything is built on Apple frameworks: SwiftUI, SwiftData, WatchConnectivity and Swift Testing.

## Getting started

1. Clone the repository.

   ```bash
   git clone <repository-url> bagel-court
   cd bagel-court
   ```

2. Open the project.

   ```bash
   open BagelCourt.xcodeproj
   ```

3. Select the **BagelCourt** scheme and an iPhone simulator, then press <kbd>⌘</kbd><kbd>R</kbd>.

To run on a physical device, change the **Team** under *Signing & Capabilities* to your own. You may also need to change the bundle identifier (`com.muslimalfatih.bagelcourt`) to one your team owns.

Building from the command line:

```bash
xcodebuild build \
  -project BagelCourt.xcodeproj \
  -scheme BagelCourt \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

## Running the tests

The scoring engine is covered by a [Swift Testing](https://developer.apple.com/documentation/testing) suite in [`BagelCourtTests/MatchEngineTests.swift`](BagelCourtTests/MatchEngineTests.swift). It covers love games, deuce and advantage, set wins, tiebreaks, serve rotation, full matches, and undo across every boundary.

In Xcode, press <kbd>⌘</kbd><kbd>U</kbd>. From the command line:

```bash
# Unit tests only (fast)
xcodebuild test \
  -project BagelCourt.xcodeproj \
  -scheme BagelCourt \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:BagelCourtTests

# Everything, including UI tests
xcodebuild test \
  -project BagelCourt.xcodeproj \
  -scheme BagelCourt \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

## Architecture

BagelCourt is split into a pure scoring engine and a thin SwiftUI app around it.

```
 ┌──────────────────────────── App (SwiftUI) ─────────────────────────────┐
 │  HistoryView ─► SetupView ─► InMatchView ─► ResultView                 │
 │                                   │                                    │
 │                         LiveMatchController                            │
 │                    (@Observable, caches MatchState)                    │
 │                      │                      │                          │
 │          MatchStore (SwiftData)     WatchBridge (WatchConnectivity)    │
 └──────────────────────┼──────────────────────┼──────────────────────────┘
                        ▼                      ▼
 ┌──────────── Engine (pure Swift) ─────┐   Apple Watch
 │  Match ── point log ──► MatchState    │   WatchScoreView
 │  MatchFormat · GameScore · SetResult  │
 └───────────────────────────────────────┘
```

**The point log is the single source of truth.** `Match` is a value type that stores only its setup (players, format, first server) and the ordered list of points won. The current score, the server, completed sets and the winner are all derived by replaying that log through the internal `MatchState` machine. As a result:

- Undo is just removing the last point, so it can't leave the score in an inconsistent state.
- Persistence is simple: the whole `Match` is `Codable` and stored as one JSON blob in a SwiftData `MatchRecord`, so engine changes don't need schema migrations.
- The engine has no UI or framework dependencies, which makes it easy to test.

`LiveMatchController` owns the match while it is being played. It replays the log once per mutation, not once per render, and then persists the result and pushes a snapshot to the watch.

## Project structure

```
BagelCourt/
├── BagelCourtApp.swift        App entry point
├── ContentView.swift          Root navigation and presentation
├── App/                       Screens, design system, persistence, watch sync
│   ├── DesignSystem.swift     Colour tokens (bc*), radii, layout, text styles
│   ├── HistoryView.swift      Match list (home screen)
│   ├── SetupView.swift        New match setup
│   ├── InMatchView.swift      Live scoring screen
│   ├── ResultView.swift       Final score and shareable scorecard
│   ├── SettingsView.swift
│   ├── LiveMatchController.swift
│   ├── MatchStore.swift       SwiftData model
│   └── WatchBridge.swift      Phone → watch channel
├── Engine/                    Pure scoring engine (no UI dependencies)
│   ├── Match.swift            Public API; the point log
│   ├── MatchState.swift       Replay state machine (internal)
│   ├── MatchFormat.swift      Rules and presets
│   ├── GameScore.swift        Game score and display strings
│   ├── SetResult.swift
│   ├── MatchType.swift
│   └── Side.swift
├── Watch/                     watchOS views (for the future watch target)
└── Assets.xcassets
BagelCourtTests/               Engine unit tests (Swift Testing)
BagelCourtUITests/             UI and launch tests (XCTest)
```

## Using the scoring engine

The engine can be used on its own:

```swift
var match = Match(homePlayer: "Alex", awayPlayer: "Maria",
                  format: .bestOf3, initialServer: .home)

match.score(point: .home)   // Alex wins the point: 15–0
match.score(point: .away)   // 15–15
match.undoLastPoint()       // back to 15–0
```

Custom rules are a single value:

```swift
// Best of 3, deciding set replaced by a 10-point super tiebreak
let format = MatchFormat(bestOf: 3, gamesPerSet: 6, tiebreakAt: 6,
                         decidingSetTiebreak: true)
```

`MatchFormat` clamps invalid input (for example, an even `bestOf` or a tiebreak threshold above the games per set), so any value you build produces a playable match.

## Roadmap

- [ ] watchOS app target that hosts `WatchScoreView` and `WatchConnectivityReceiver`
- [ ] Score points from the watch (currently phone → watch only)
- [ ] App icon
- [ ] Remove the legacy prototype files (`TennisMatch.swift`, `LiveScoreView.swift`, `MatchSetupView.swift`) once nothing depends on them
- [ ] No-ad scoring option

## Contributing

Contributions are welcome. To keep things smooth:

1. **Open an issue first** for anything larger than a small fix, so the approach can be agreed before you write code.
2. **Keep engine changes tested.** Any change to scoring rules needs a test in `MatchEngineTests.swift` that fails without the change.
3. **Keep the engine pure.** Files in `Engine/` must not import SwiftUI, SwiftData or other app frameworks.
4. **Run the tests** (`⌘U`) before opening a pull request, and describe what you changed and why.

Bug reports are most useful with the match format, the sequence of points, and the score you expected versus the score you saw.

## License

No license has been chosen yet. Until one is added, all rights are reserved by the author. If you would like to use this code, please open an issue.

---

Made by Muslim Alfatih.
