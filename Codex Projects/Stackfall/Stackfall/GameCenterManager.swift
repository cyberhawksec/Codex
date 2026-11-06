import SwiftUI
import GameKit

struct GameCenterPresentation: Identifiable {
    let id = UUID()
    let controller: UIViewController
    let isAuthentication: Bool
}

struct GameCenterController: UIViewControllerRepresentable {
    let controller: UIViewController
    func makeUIViewController(context: Context) -> UIViewController { controller }
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

@MainActor
final class GameCenterManager: NSObject, ObservableObject, GKGameCenterControllerDelegate {
    static let shared = GameCenterManager()
    // Create this exact leaderboard ID in App Store Connect or change it here.
    static let leaderboardID = "com.stackfall.highscore"
    private let pendingKey = "stackfall.gamecenter.pendingScores"
    private var submitting = false
    private var wantsLeaderboard = false
    private var started = false

    @Published var presentation: GameCenterPresentation?
    @Published var alertMessage: String?
    @Published private(set) var isAuthenticated = false

    var playerID: String? {
        GKLocalPlayer.local.isAuthenticated ? GKLocalPlayer.local.gamePlayerID : nil
    }

    func start() {
        guard !started else { return }
        started = true
        authenticate()
    }

    private func authenticate() {
        GKLocalPlayer.local.authenticateHandler = { [weak self] controller, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let controller = controller {
                    self.presentation = GameCenterPresentation(controller: controller, isAuthentication: true)
                    return
                }
                if self.presentation?.isAuthentication == true { self.presentation = nil }
                self.isAuthenticated = GKLocalPlayer.local.isAuthenticated
                if self.isAuthenticated {
                    self.flushPendingScore()
                    if self.wantsLeaderboard {
                        self.wantsLeaderboard = false
                        // Allow the sign-in sheet to finish dismissing before opening another.
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { self.presentLeaderboard() }
                    }
                } else if self.wantsLeaderboard {
                    self.wantsLeaderboard = false
                    self.alertMessage = error?.localizedDescription ?? "Sign in to Game Center in Settings to view the leaderboard."
                }
            }
        }
    }

    func showLeaderboard() {
        if GKLocalPlayer.local.isAuthenticated {
            flushPendingScore()
            presentLeaderboard()
        } else {
            wantsLeaderboard = true
            authenticate()
        }
    }

    private func presentLeaderboard() {
        guard GKLocalPlayer.local.isAuthenticated else { return }
        let controller = GKGameCenterViewController(leaderboardID: Self.leaderboardID, playerScope: .global, timeScope: .allTime)
        controller.gameCenterDelegate = self
        presentation = GameCenterPresentation(controller: controller, isAuthentication: false)
    }

    func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
        presentation = nil
    }

    // Keep pending scores separate by player. A run that began while signed out
    // remains local because it cannot be attributed safely to a Game Center account.
    func finish(score: Int, playerID: String?) {
        guard score > 0, let playerID = playerID else { return }
        var scores = pendingScores()
        scores[playerID] = max(scores[playerID] ?? 0, score)
        UserDefaults.standard.set(scores, forKey: pendingKey)
        flushPendingScore()
    }

    private func pendingScores() -> [String: Int] {
        UserDefaults.standard.dictionary(forKey: pendingKey) as? [String: Int] ?? [:]
    }

    func flushPendingScore() {
        guard !submitting, let playerID = playerID, let score = pendingScores()[playerID] else { return }
        submitting = true
        GKLeaderboard.submitScore(score, context: 0, player: GKLocalPlayer.local, leaderboardIDs: [Self.leaderboardID]) { [weak self] error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.submitting = false
                if error == nil {
                    var scores = self.pendingScores()
                    if let queued = scores[playerID], queued <= score {
                        scores.removeValue(forKey: playerID)
                        UserDefaults.standard.set(scores, forKey: self.pendingKey)
                    }
                    // Another completed game may have queued a higher score during submission.
                    self.flushPendingScore()
                }
                // On failure the score remains queued for the next sign-in or leaderboard visit.
            }
        }
    }
}
