import Foundation

/// Fetches all followed sources in parallel and merges them into one feed, newest first.
/// A source that fails (offline, site down) is skipped instead of breaking the whole feed.
enum NewsService {
    /// Per-outlet cap so sites that publish 100 items a day don't drown out the rest.
    private static let maxItemsPerOutlet = 12
    private static let maxItemsPerGame = 5
    /// Older Steam announcements aren't "news" anymore.
    private static let maxSteamAge: TimeInterval = 60 * 24 * 3600
    /// Below this, a feed only gave us a teaser, not the full article.
    private static let minFullArticleWords = 150

    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.httpAdditionalHeaders = ["User-Agent": "Mozilla/5.0 (iPhone) GameWire/0.1"]
        return URLSession(configuration: config)
    }()

    static func fetchFeed(
        outlets: [Outlet] = DefaultFollows.outlets,
        games: [SteamGame] = DefaultFollows.games
    ) async -> [NewsItem] {
        let all = await withTaskGroup(of: [NewsItem].self) { group in
            for outlet in outlets {
                group.addTask { (try? await fetch(outlet)) ?? [] }
            }
            for game in games {
                group.addTask { (try? await fetch(game)) ?? [] }
            }
            var merged: [NewsItem] = []
            for await batch in group {
                merged += batch
            }
            return merged
        }

        // Drop duplicates (same link from two places), then newest first.
        var seen = Set<String>()
        return all
            .filter { seen.insert($0.id).inserted }
            .sorted { $0.published > $1.published }
    }

    // MARK: - Outlets (RSS)

    private static func fetch(_ outlet: Outlet) async throws -> [NewsItem] {
        let (data, _) = try await session.data(from: outlet.feedURL)
        return RSSParser.parse(data)
            .compactMap { entry -> NewsItem? in
                guard !entry.title.isEmpty,
                      let date = FeedDate.parse(entry.dateString),
                      let link = URL(string: entry.link)
                else { return nil }

                // Some feeds put the article in <content:encoded>, others (GameSpot) in <description>.
                let html = entry.content.count > entry.summary.count ? entry.content : entry.summary
                let imageURL = entry.imageURL.flatMap { URL(string: $0.decodingHTMLEntities) } ?? html.firstHTMLImageURL
                let wordCount = html.strippingHTML.split(whereSeparator: \.isWhitespace).count

                return NewsItem(
                    id: link.absoluteString,
                    kind: .news,
                    origin: .outlet,
                    title: entry.title.strippingHTML,
                    summary: entry.summary.strippingHTML,
                    source: outlet.name,
                    published: date,
                    url: link,
                    imageURL: imageURL,
                    // Only teasers come in under this; those open on the website instead.
                    articleHTML: wordCount >= minFullArticleWords ? html : nil
                )
            }
            .sorted { $0.published > $1.published }
            .prefix(maxItemsPerOutlet)
            .map { $0 }
    }

    // MARK: - Steam games

    private struct SteamResponse: Decodable {
        let appnews: AppNews

        struct AppNews: Decodable {
            let newsitems: [Item]
        }

        struct Item: Decodable {
            let gid: String
            let title: String
            let contents: String
            let date: TimeInterval
            let tags: [String]?
        }
    }

    private static func fetch(_ game: SteamGame) async throws -> [NewsItem] {
        var components = URLComponents(string: "https://api.steampowered.com/ISteamNews/GetNewsForApp/v2/")!
        components.queryItems = [
            URLQueryItem(name: "appid", value: String(game.appID)),
            URLQueryItem(name: "count", value: String(maxItemsPerGame)),
            URLQueryItem(name: "maxlength", value: "0"),
            // Only the developer's own posts, not third-party news sites.
            URLQueryItem(name: "feeds", value: "steam_community_announcements"),
            URLQueryItem(name: "format", value: "json"),
        ]

        let (data, _) = try await session.data(from: components.url!)
        let response = try JSONDecoder().decode(SteamResponse.self, from: data)
        let cutoff = Date().addingTimeInterval(-maxSteamAge)

        return response.appnews.newsitems.compactMap { item in
            let date = Date(timeIntervalSince1970: item.date)
            guard date > cutoff else { return nil }

            return NewsItem(
                id: "steam-\(item.gid)",
                kind: isPatch(item) ? .patch : .news,
                origin: .game,
                title: item.title,
                summary: item.contents.strippingSteamMarkup,
                source: "Steam",
                game: game.name,
                published: date,
                url: URL(string: "https://store.steampowered.com/news/app/\(game.appID)/view/\(item.gid)"),
                imageURL: item.contents.firstSteamImageURL ?? item.contents.firstHTMLImageURL ?? game.headerImageURL,
                articleHTML: ArticleHTML.steamHTML(fromBBCode: item.contents)
            )
        }
    }

    private static func isPatch(_ item: SteamResponse.Item) -> Bool {
        if item.tags?.contains("patchnotes") == true { return true }
        return item.title.range(
            of: "patch|hotfix|update \\d|\\bv?\\d+\\.\\d+(\\.\\d+)?\\b",
            options: [.regularExpression, .caseInsensitive]
        ) != nil
    }
}
