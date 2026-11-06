import Foundation
import Observation

/// The games you follow, saved on the phone so they survive relaunches.
/// Shared by the whole app (see GameWireApp), so following from any screen updates every feed.
@Observable
final class FollowStore {
    private(set) var games: [Game]

    private let defaults: UserDefaults
    private static let key = "followedGames"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        games = defaults.data(forKey: Self.key)
            .flatMap { try? JSONDecoder().decode([Game].self, from: $0) } ?? []
    }

    func isFollowing(_ game: Game) -> Bool {
        games.contains { $0.isSame(as: game) }
    }

    func toggle(_ game: Game) {
        if isFollowing(game) {
            games.removeAll { $0.isSame(as: game) }
        } else {
            games.append(game)
        }
        defaults.set(try? JSONEncoder().encode(games), forKey: Self.key)
    }
}
