import Foundation

/// A news site with an RSS feed.
struct Outlet: Hashable, Sendable {
    let name: String
    let feedURL: URL
    /// Logo image in Assets.xcassets/Logos.
    let logo: String
}

/// The news sites every feed uses (picking sites comes later), and popular games to discover.
enum DefaultFollows {
    static let outlets: [Outlet] = [
        Outlet(name: "IGN", feedURL: URL(string: "https://feeds.feedburner.com/ign/all")!, logo: "logo-ign"),
        Outlet(name: "GameSpot", feedURL: URL(string: "https://www.gamespot.com/feeds/mashup/")!, logo: "logo-gamespot"),
        Outlet(name: "Polygon", feedURL: URL(string: "https://www.polygon.com/rss/index.xml")!, logo: "logo-polygon"),
        Outlet(name: "Kotaku", feedURL: URL(string: "https://kotaku.com/rss")!, logo: "logo-kotaku"),
        Outlet(name: "Eurogamer", feedURL: URL(string: "https://www.eurogamer.net/feed")!, logo: "logo-eurogamer"),
        Outlet(name: "PC Gamer", feedURL: URL(string: "https://www.pcgamer.com/rss/")!, logo: "logo-pcgamer"),
        Outlet(name: "Rock Paper Shotgun", feedURL: URL(string: "https://www.rockpapershotgun.com/feed")!, logo: "logo-rps"),
        Outlet(name: "VG247", feedURL: URL(string: "https://www.vg247.com/feed")!, logo: "logo-vg247"),
    ]

    /// Shown in Discover even when not followed, and suggested in "Find games".
    static let popularGames: [Game] = [
        Game(name: "Helldivers 2", steamAppID: 553850),
        Game(name: "Counter-Strike 2", steamAppID: 730, aliases: ["CS2"]),
        Game(name: "Marvel Rivals", steamAppID: 2767030),
        Game(name: "Baldur's Gate 3", steamAppID: 1086940, aliases: ["BG3"]),
        Game(name: "Cyberpunk 2077", steamAppID: 1091500),
        Game(name: "Elden Ring", steamAppID: 1245620),
    ]
}
