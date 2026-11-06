import Foundation

/// Fetches all sources in parallel and merges them into one list (HomeView orders it with FeedMixer).
/// A source that fails (offline, site down) is skipped instead of breaking the whole feed.
enum NewsService {
    /// How far back we keep posts. Discover only shows the past week (see `discoverPosts`); My Games can
    /// look back further when your games have had little news. Most sites' feeds only reach back a few
    /// hours to days anyway, so this mostly brings in older Steam posts (patch notes).
    static let historyAge: TimeInterval = 30 * 24 * 3600
    static let weekAge: TimeInterval = 7 * 24 * 3600
    /// Discover's per-site cap, so sites that publish 100 items a day don't drown out the rest.
    private static let discoverPerOutlet = 30
    private static let maxItemsPerGame = 20
    /// Below this, a feed only gave us a teaser, not the full article.
    private static let minFullArticleWords = 150

    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.httpAdditionalHeaders = ["User-Agent": "Mozilla/5.0 (iPhone) GameWire/0.1"]
        return URLSession(configuration: config)
    }()

    static func fetchAll(
        outlets: [Outlet] = DefaultFollows.outlets,
        games: [Game]
    ) async -> [NewsItem] {
        // Game icons come from one small request that runs alongside the news.
        async let gameIcons = steamIcons(for: games)

        var all = await withTaskGroup(of: [NewsItem].self) { group in
            for outlet in outlets {
                group.addTask { (try? await fetch(outlet)) ?? [] }
            }
            for game in games {
                guard let appID = game.steamAppID else { continue }
                group.addTask { (try? await fetch(game, appID: appID)) ?? [] }
            }
            var merged: [NewsItem] = []
            for await batch in group {
                merged += batch
            }
            return merged
        }

        let icons = await gameIcons
        for index in all.indices where all[index].origin == .game {
            all[index].logoURL = all[index].game.flatMap { icons[$0] }
        }

        // Drop duplicates (same link from two places).
        var seen = Set<String>()
        return all.filter { seen.insert($0.id).inserted }
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
                    articleHTML: wordCount >= minFullArticleWords ? html : nil,
                    logoAsset: outlet.logo
                )
            }
            .filter { $0.published > Date().addingTimeInterval(-historyAge) }
    }

    /// What Discover shows: the past week, and at most 30 posts per site.
    static func discoverPosts(_ posts: [NewsItem], now: Date = .now) -> [NewsItem] {
        let week = posts.filter { $0.published > now.addingTimeInterval(-weekAge) }
        return Dictionary(grouping: week, by: \.displayName).values.flatMap { sourcePosts in
            sourcePosts.sorted { $0.published > $1.published }.prefix(discoverPerOutlet)
        }
    }

    // MARK: - Steam games

    private struct SteamAppsResponse: Decodable {
        let response: Apps

        struct Apps: Decodable {
            let apps: [App]
        }

        struct App: Decodable {
            let appid: Int
            let icon: String?
        }
    }

    /// Official game icons (game name → icon URL) from Steam's Web API, in one request.
    private static func steamIcons(for games: [Game]) async -> [String: URL] {
        let games = games.filter { $0.steamAppID != nil }
        guard !games.isEmpty else { return [:] }
        var components = URLComponents(string: "https://api.steampowered.com/ICommunityService/GetApps/v1/")!
        components.queryItems = games.enumerated().map { index, game in
            URLQueryItem(name: "appids[\(index)]", value: String(game.steamAppID!))
        }
        guard let url = components.url,
              let (data, _) = try? await session.data(from: url),
              let response = try? JSONDecoder().decode(SteamAppsResponse.self, from: data)
        else { return [:] }

        var icons: [String: URL] = [:]
        for app in response.response.apps {
            guard let hash = app.icon, let game = games.first(where: { $0.steamAppID == app.appid }) else { continue }
            icons[game.name] = URL(string: "https://shared.akamai.steamstatic.com/community_assets/images/apps/\(app.appid)/\(hash).jpg")
        }
        return icons
    }

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

    private static func fetch(_ game: Game, appID: Int) async throws -> [NewsItem] {
        var components = URLComponents(string: "https://api.steampowered.com/ISteamNews/GetNewsForApp/v2/")!
        components.queryItems = [
            URLQueryItem(name: "appid", value: String(appID)),
            URLQueryItem(name: "count", value: String(maxItemsPerGame)),
            URLQueryItem(name: "maxlength", value: "0"),
            // Only the developer's own posts, not third-party news sites.
            URLQueryItem(name: "feeds", value: "steam_community_announcements"),
            URLQueryItem(name: "format", value: "json"),
        ]

        let (data, _) = try await session.data(from: components.url!)
        let response = try JSONDecoder().decode(SteamResponse.self, from: data)
        let cutoff = Date().addingTimeInterval(-historyAge)

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
                url: URL(string: "https://store.steampowered.com/news/app/\(appID)/view/\(item.gid)"),
                imageURL: item.contents.firstSteamImageURL ?? item.contents.firstHTMLImageURL ?? game.steamHeaderURL,
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
