import Foundation

/// Decides the order of the Home feed.
///
/// It's still a shuffle (different on every open and refresh), but a weighted one: every post gets
/// "raffle tickets", and posts with more tickets tend to land nearer the top.
/// - Fresh posts get the most; a post loses half its tickets every 2 days.
/// - Posts about a game you follow get double (its Steam posts, and outlet headlines naming it).
/// - Big stories (the same story on other outlets, see StoryMatcher) get +50% per extra outlet, up to 3×.
///   Once one version of a story is shown, the other outlets' versions drop to half, so the same news
///   doesn't show up three times in a row.
///
/// Each next post comes from a source (outlet or game) drawn by the tickets of its best remaining post,
/// so a site that posts 30 times a day can't take over, and the same source never shows twice in a row.
enum FeedMixer {
    private static let freshnessHalfLife: TimeInterval = 48 * 3600
    private static let followBoost = 2.0
    private static let storyBoostPerOutlet = 0.5
    private static let maxStoryBoost = 3.0
    private static let alreadySeenStory = 0.5

    private struct Entry {
        let post: NewsItem
        /// Tickets from freshness and follows.
        let base: Double
        let storyBoost: Double
        /// 0.5...1, fixed per post: lets posts with similar tickets swap places.
        let jitter: Double
        var storyShown = false

        var tickets: Double { base * (storyShown ? FeedMixer.alreadySeenStory : storyBoost) }
        var sortKey: Double { tickets * jitter }
    }

    static func mix(_ items: [NewsItem], followedGames: [Game], now: Date = .now) -> [NewsItem] {
        var random = SystemRandomNumberGenerator()
        return mix(items, followedGames: followedGames, now: now, using: &random)
    }

    static func mix(
        _ items: [NewsItem], followedGames: [Game], now: Date,
        using random: inout some RandomNumberGenerator
    ) -> [NewsItem] {
        let sameStory = StoryMatcher.sameStory(in: items)

        func entry(for post: NewsItem) -> Entry {
            let age = max(0, now.timeIntervalSince(post.published))
            var base = pow(0.5, age / freshnessHalfLife)
            if followedGames.anyAbout(post) {
                base *= followBoost
            }
            let otherOutlets = Set((sameStory[post.id] ?? []).map(\.source)).count
            let storyBoost = min(1 + storyBoostPerOutlet * Double(otherOutlets), maxStoryBoost)
            return Entry(post: post, base: base, storyBoost: storyBoost, jitter: .random(in: 0.5...1, using: &random))
        }

        // Each source's posts, best first but loosely: a post with twice the tickets always goes first,
        // closer ones can swap. Sorted with the next post last.
        var queues = Dictionary(grouping: items, by: \.displayName).mapValues { posts in
            posts.map(entry).sorted { $0.sortKey < $1.sortKey }
        }

        var result: [NewsItem] = []
        result.reserveCapacity(items.count)
        var lastSource: String?

        while !queues.isEmpty {
            var choices = queues.keys.filter { $0 != lastSource }
            // Only the last source has posts left → it has to repeat.
            if choices.isEmpty { choices = Array(queues.keys) }

            let total = choices.reduce(0) { $0 + queues[$1]!.last!.tickets }
            var draw = Double.random(in: 0..<total, using: &random)
            var source = choices[choices.count - 1]
            for choice in choices {
                draw -= queues[choice]!.last!.tickets
                if draw < 0 { source = choice; break }
            }

            let shown = queues[source]!.removeLast().post
            result.append(shown)
            if queues[source]!.isEmpty { queues[source] = nil }
            lastSource = source

            // Other outlets' versions of this story lose their boost and move down their queue.
            for other in sameStory[shown.id] ?? [] {
                guard var queue = queues[other.displayName],
                      let index = queue.firstIndex(where: { $0.post.id == other.id }),
                      !queue[index].storyShown else { continue }
                queue[index].storyShown = true
                queue.sort { $0.sortKey < $1.sortKey }
                queues[other.displayName] = queue
            }
        }
        return result
    }
}
