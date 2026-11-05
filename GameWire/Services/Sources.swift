import Foundation

/// A news site with an RSS feed.
struct Outlet: Hashable, Sendable {
    let name: String
    let feedURL: URL
}

/// A game we pull official news / patch notes for from Steam.
struct SteamGame: Hashable, Sendable {
    let name: String
    let appID: Int

    var headerImageURL: URL {
        URL(string: "https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/\(appID)/header.jpg")!
    }
}

/// What the feed follows until onboarding / "follow" exists.
enum DefaultFollows {
    static let outlets: [Outlet] = [
        Outlet(name: "IGN", feedURL: URL(string: "https://feeds.feedburner.com/ign/all")!),
        Outlet(name: "GameSpot", feedURL: URL(string: "https://www.gamespot.com/feeds/mashup/")!),
        Outlet(name: "Polygon", feedURL: URL(string: "https://www.polygon.com/rss/index.xml")!),
        Outlet(name: "Kotaku", feedURL: URL(string: "https://kotaku.com/rss")!),
        Outlet(name: "Eurogamer", feedURL: URL(string: "https://www.eurogamer.net/feed")!),
        Outlet(name: "PC Gamer", feedURL: URL(string: "https://www.pcgamer.com/rss/")!),
        Outlet(name: "Rock Paper Shotgun", feedURL: URL(string: "https://www.rockpapershotgun.com/feed")!),
        Outlet(name: "VG247", feedURL: URL(string: "https://www.vg247.com/feed")!),
    ]

    static let games: [SteamGame] = [
        SteamGame(name: "Helldivers 2", appID: 553850),
        SteamGame(name: "Counter-Strike 2", appID: 730),
        SteamGame(name: "Marvel Rivals", appID: 2767030),
        SteamGame(name: "Baldur's Gate 3", appID: 1086940),
        SteamGame(name: "Cyberpunk 2077", appID: 1091500),
        SteamGame(name: "Elden Ring", appID: 1245620),
    ]
}
