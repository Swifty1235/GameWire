import SwiftUI

/// Dummy feed for designing the Home screen. Replaced by real RSS / Steam data later.
enum SampleData {
    private static func ago(hours: Double) -> Date {
        Date().addingTimeInterval(-hours * 3600)
    }

    static let feed: [NewsItem] = [
        NewsItem(
            kind: .patch, origin: .game,
            title: "Chapter 7 Season 2 is live: new map zones, weapons and a mech mode",
            summary: "The new season adds three map zones, a vaulted weapon return and a limited-time mech mode. Full patch notes inside.",
            source: "Epic Games", game: "Fortnite",
            published: ago(hours: 1),
            artwork: Artwork(colors: [Color(hex: 0x7B2FF7), Color(hex: 0x1E3CFF)], symbol: "bolt.fill")
        ),
        NewsItem(
            kind: .news, origin: .outlet,
            title: "The 25 most anticipated games of 2027",
            summary: "From long-awaited sequels to surprise indies, here's everything we can't wait to play next year.",
            source: "IGN",
            published: ago(hours: 2),
            artwork: Artwork(colors: [Color(hex: 0xFF7A18), Color(hex: 0xC2185B)], symbol: "star.fill")
        ),
        NewsItem(
            kind: .video, origin: .creator,
            title: "Every Nightreign boss ranked from easiest to hardest",
            summary: "We fought them all so you don't have to. Here's the definitive ranking.",
            source: "BossFight TV", game: "Elden Ring",
            published: ago(hours: 3),
            artwork: Artwork(colors: [Color(hex: 0xD4A017), Color(hex: 0x5D2E0C)], symbol: "flame.fill"),
            duration: "18:42"
        ),
        NewsItem(
            kind: .patch, origin: .game,
            title: "Java Edition 1.22.3 patch notes",
            summary: "Bug fixes for redstone, performance improvements and a fix for the disappearing chest bug.",
            source: "Mojang", game: "Minecraft",
            published: ago(hours: 4),
            artwork: Artwork(colors: [Color(hex: 0x2E7D32), Color(hex: 0x0B3D0B)], symbol: "cube.fill")
        ),
        NewsItem(
            kind: .news, origin: .outlet,
            title: "Why cozy games keep taking over the charts",
            summary: "Farming, decorating and fishing games are some of the most played titles of the year. We look at why.",
            source: "Polygon",
            published: ago(hours: 5),
            artwork: Artwork(colors: [Color(hex: 0xFF8FB1), Color(hex: 0xB24592)], symbol: "leaf.fill")
        ),
        NewsItem(
            kind: .video, origin: .creator,
            title: "10 hidden gems on Steam you've never heard of",
            summary: "Great indie games under $20 that deserve way more attention.",
            source: "PixelPlays",
            published: ago(hours: 6),
            artwork: Artwork(colors: [Color(hex: 0x00C9FF), Color(hex: 0x0A1F44)], symbol: "gamecontroller.fill"),
            duration: "12:05"
        ),
        NewsItem(
            kind: .news, origin: .game,
            title: "New agent revealed ahead of the next act",
            summary: "A first look at the new agent's abilities, plus map rotation changes coming next act.",
            source: "Riot Games", game: "Valorant",
            published: ago(hours: 7),
            artwork: Artwork(colors: [Color(hex: 0xFF4655), Color(hex: 0x1A0A0C)], symbol: "scope")
        ),
        NewsItem(
            kind: .news, origin: .outlet,
            title: "The best budget gaming PCs this holiday season",
            summary: "Our picks for every price range, from $600 starter builds to 1440p powerhouses.",
            source: "PC Gamer",
            published: ago(hours: 9),
            artwork: Artwork(colors: [Color(hex: 0x11998E), Color(hex: 0x0B2E2B)], symbol: "desktopcomputer")
        ),
        NewsItem(
            kind: .patch, origin: .game,
            title: "Patch 1.004: weapon balance changes and bug fixes",
            summary: "Buffs to several support weapons, enemy spawn tweaks and crash fixes.",
            source: "Arrowhead", game: "Helldivers 2",
            published: ago(hours: 11),
            artwork: Artwork(colors: [Color(hex: 0xF7D51D), Color(hex: 0x3A3A0A)], symbol: "shield.lefthalf.filled")
        ),
        NewsItem(
            kind: .video, origin: .creator,
            title: "The speedrun world record just fell again",
            summary: "Breaking down the new route and the trick that saved four seconds.",
            source: "Speedrun Weekly",
            published: ago(hours: 14),
            artwork: Artwork(colors: [Color(hex: 0xE53935), Color(hex: 0x4A0E0E)], symbol: "timer"),
            duration: "9:31"
        ),
        NewsItem(
            kind: .news, origin: .outlet,
            title: "Every free game you can claim this week",
            summary: "Free-to-keep games on Epic, Steam and GOG, plus when each offer ends.",
            source: "GameSpot",
            published: ago(hours: 26),
            artwork: Artwork(colors: [Color(hex: 0x8E2DE2), Color(hex: 0x2A0845)], symbol: "gift.fill")
        ),
    ]
}
