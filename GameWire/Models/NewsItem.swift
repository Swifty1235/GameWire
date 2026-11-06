import SwiftUI

/// What kind of story a feed item is. Shown as a small gray label on each post.
enum NewsKind: Hashable {
    case news, patch, video

    var label: String {
        switch self {
        case .news: "News"
        case .patch: "Patch notes"
        case .video: "Video"
        }
    }

    var systemImage: String {
        switch self {
        case .news: "newspaper"
        case .patch: "wrench.and.screwdriver"
        case .video: "play.rectangle"
        }
    }
}

/// Where an item came from: a game you follow, a news outlet, or a creator.
enum NewsOrigin: Hashable {
    case game, outlet, creator
}

/// Gradient + icon placeholder art (used by sample data and for source avatars).
struct Artwork: Hashable {
    let colors: [Color]
    let symbol: String

    private static let palettes: [[Color]] = [
        [Color(hex: 0xFF7A00), Color(hex: 0xC2410C)],
        [Color(hex: 0x6366F1), Color(hex: 0x312E81)],
        [Color(hex: 0x10B981), Color(hex: 0x065F46)],
        [Color(hex: 0xEF4444), Color(hex: 0x7F1D1D)],
        [Color(hex: 0x0EA5E9), Color(hex: 0x0C4A6E)],
        [Color(hex: 0xA855F7), Color(hex: 0x581C87)],
        [Color(hex: 0xEAB308), Color(hex: 0x854D0E)],
        [Color(hex: 0x64748B), Color(hex: 0x1E293B)],
    ]

    /// A stable color pair for a source name, so "IGN" always gets the same avatar color.
    static func colors(for name: String) -> [Color] {
        let hash = name.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0x7FFF_FFFF }
        return palettes[hash % palettes.count]
    }
}

struct NewsItem: Identifiable, Hashable {
    var id: String = UUID().uuidString
    let kind: NewsKind
    let origin: NewsOrigin
    let title: String
    let summary: String
    let source: String
    var game: String? = nil
    let published: Date
    /// Link to the full article / Steam post.
    var url: URL? = nil
    /// Real image from the feed. When nil, `artwork` (sample data) or nothing is shown.
    var imageURL: URL? = nil
    var artwork: Artwork? = nil
    var duration: String? = nil
    /// The full article as HTML, when the source gives us all of it (IGN, PC Gamer, GameSpot, Steam).
    /// nil for teaser-only sources, which open in the in-app browser instead.
    var articleHTML: String? = nil
    /// Source logo: a bundled image for outlets, or a web image (Steam game icons).
    var logoAsset: String? = nil
    var logoURL: URL? = nil

    var hasFullText: Bool { articleHTML != nil }

    /// "kotaku.com", for posts that open on the source's website.
    var siteName: String? {
        url?.host()?.replacingOccurrences(of: "www.", with: "")
    }

    /// The name shown first on a post: the game if there is one, otherwise the outlet/creator.
    var displayName: String { game ?? source }

    var avatarColors: [Color] { artwork?.colors ?? Artwork.colors(for: displayName) }

    /// "Patch notes" or "Video · 18:42"
    var kindLine: String {
        [kind.label, duration].compactMap { $0 }.joined(separator: " · ")
    }

    /// "Epic Games · 2h" (source is skipped when it's already the display name)
    var subtitleLine: String {
        [game == nil ? nil : source, published.shortAgo]
            .compactMap { $0 }
            .joined(separator: " · ")
    }
}
