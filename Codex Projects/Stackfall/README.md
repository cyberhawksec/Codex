# Stackfall

A small, native SwiftUI falling-fruit game for iPhone, targeting iOS 16 and later. No third-party dependencies are required.

## Run on a Mac

1. Open `Stackfall.xcodeproj` in Xcode 15 or later.
2. Select the **Stackfall** scheme and an iPhone simulator, then press Run.
3. To run on an iPhone, select the target's **Signing & Capabilities** tab, choose your Apple development team, and change the bundle identifier if needed. Select your connected iPhone and run.

This is source code for an Xcode project; it is not a prebuilt or App Store-ready binary. The project was prepared on Windows and has not been built or run in Xcode.

## Play

- Use the arrow buttons to move, rotate, or drop a piece one row.
- Tap the board to rotate, swipe sideways to move one column, or swipe down for a hard drop. The DROP button also hard-drops.
- The outlined cells show where the current piece will land.
- Clear complete rows to score. Every 10 lines advances the level and increases the falling speed. Clear 100 lines to complete level 10 and win. Soft and hard drops earn points too.
- Pieces use a shuffled seven-piece bag. The best score is stored locally on the device. The game pauses when you leave the app.

Each shape is made from 3D-style fruit sprites: apples, lemons, grapes, kiwis, strawberries, blueberries, or oranges.

## Game Center setup

The trophy button opens the Game Center leaderboard. The app requests Game Center sign-in and sends a finished run's score to the all-time leaderboard. If a submission fails, the score is kept on the device and retried on the next successful sign-in or leaderboard visit. Scores are queued separately for each Game Center player. Runs started while signed out stay local, and the local best score is not automatically uploaded.

Before Game Center works, you must configure your own Apple developer account:

1. In Xcode, choose your development team and a unique bundle identifier under **Signing & Capabilities**. Confirm that the **Game Center** capability is enabled. The project includes the Game Center entitlement; Xcode must provision it for your App ID.
2. Create an app record in App Store Connect with the same bundle identifier, enable Game Center for the app version, and create a **classic leaderboard**. Set its leaderboard ID to `com.stackfall.highscore`, score format to integer, and submission type to best/highest score. If you choose a different ID, update `leaderboardID` in `GameCenterManager.swift` to match it exactly.
3. Sign in to Game Center on your test device. Run the app, play a game to completion, and use the trophy button to open the leaderboard. Game Center also supports local testing with a GameKit configuration file in Xcode; configure the same leaderboard ID there.

The account setup and actual Game Center integration require an Apple developer account and have not been configured or tested from this Windows machine. The game remains playable without Game Center. See Apple's [Game Center setup guide](https://developer.apple.com/help/app-store-connect/configure-game-center/overview-of-game-center) and [Xcode setup and local testing guide](https://developer.apple.com/documentation/gamekit/initializing-and-configuring-game-center).

The current fruit gently bobs; hard drops, landings, and cleared lines have animated feedback. The app respects iOS Reduce Motion. The fruit is rendered artwork, not interactive 3D models.
