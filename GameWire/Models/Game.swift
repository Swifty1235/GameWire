import Foundation

/// A game you can follow, on any platform. Found through game search (IGDB) or one of the built-in
/// popular Steam games. Games on Steam also get their official news and patch notes from Steam.
struct Game: Hashable, Codable, Sendable, Identifiable {
    let name: String
    /// IGDB's id; nil for the built-in Steam games and follows saved before search existed.
    var igdbID: Int? = nil
    var steamAppID: Int? = nil
    /// IGDB box art id (see `coverURL`).
    var coverImageID: String? = nil
    var year: Int? = nil
    /// Short platform names, e.g. ["Switch", "PS5", "PC"].
    var platforms: [String] = []
    /// Short names outlets use in headlines ("CS2"), so their articles count as being about this game.
    var aliases: [String] = []

    var id: String {
        if let igdbID { return "igdb-\(igdbID)" }
        if let steamAppID { return "steam-\(steamAppID)" }
        return "name-\(name)"
    }

    /// Same game, even when one copy came from Steam and the other from search.
    func isSame(as other: Game) -> Bool {
        if let a = igdbID, let b = other.igdbID { return a == b }
        if let a = steamAppID, let b = other.steamAppID { return a == b }
        return name.caseInsensitiveCompare(other.name) == .orderedSame
    }

    /// Tall box art: IGDB's cover, or Steam's library art for Steam-only games.
    var coverURL: URL? {
        if let coverImageID {
            return URL(string: "https://images.igdb.com/igdb/image/upload/t_cover_big_2x/\(coverImageID).jpg")
        }
        if let steamAppID {
            return URL(string: "https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/\(steamAppID)/library_600x900_2x.jpg")
        }
        return nil
    }

    /// Steam's wide banner, used as a fallback image on Steam posts.
    var steamHeaderURL: URL? {
        steamAppID.flatMap {
            URL(string: "https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/\($0)/header.jpg")
        }
    }

    /// "2024 · Switch, PS5"
    var detailLine: String {
        [year.map(String.init), platforms.isEmpty ? nil : platforms.prefix(4).joined(separator: ", ")]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    /// Names headlines might use, since they rarely print the full official name:
    /// - without a leading "The"
    /// - Roman numerals as numbers: "Grand Theft Auto VI" → "Grand Theft Auto 6"
    /// - common short forms: "Grand Theft Auto 6" → "GTA 6", "Call of Duty" → "CoD"
    /// - a long-enough subtitle: "The Legend of Zelda: Tears of the Kingdom" → "Tears of the Kingdom"
    /// - the main title when the subtitle is just an edition: "Minecraft: Java Edition" → "Minecraft"
    var headlineNames: [String] {
        var names = [name] + aliases
        if name.hasPrefix("The ") { names.append(String(name.dropFirst(4))) }

        if let colon = name.firstIndex(of: ":") {
            let title = name[..<colon].trimmingCharacters(in: .whitespaces)
            let subtitle = name[name.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            if Self.editionWords.contains(where: { subtitle.localizedCaseInsensitiveContains($0) }) {
                names.append(title)
            } else if subtitle.split(separator: " ").count >= 2 && subtitle.count >= 8 {
                names.append(subtitle)
            }
        }

        let numbered = names.map(Self.romanToNumbers)
        names += numbered
        for (long, short) in Self.shortForms {
            names += names.compactMap { name in
                name.range(of: long, options: .caseInsensitive).map { name.replacingCharacters(in: $0, with: short) }
            }
        }
        return Array(Set(names))
    }

    private static let editionWords = [
        "Edition", "Remastered", "Remaster", "Definitive", "Deluxe", "Complete", "Director's Cut",
        "Game of the Year", "Anniversary", "Enhanced",
    ]
    private static let shortForms = [
        ("Grand Theft Auto", "GTA"), ("Call of Duty", "CoD"), ("World of Warcraft", "WoW"),
        ("Counter-Strike", "CS"), ("Final Fantasy", "FF"),
    ]
    private static let romanNumerals = [
        "II": "2", "III": "3", "IV": "4", "V": "5", "VI": "6", "VII": "7", "VIII": "8", "IX": "9",
        "XI": "11", "XII": "12", "XIII": "13", "XIV": "14", "XV": "15", "XVI": "16",
    ]

    /// "Grand Theft Auto VI" → "Grand Theft Auto 6" (whole words only, so "Vice" stays "Vice"). "X" is left
    /// alone: it's usually part of a name ("Mega Man X"), not a 10.
    private static func romanToNumbers(_ name: String) -> String {
        name.split(separator: " ", omittingEmptySubsequences: false)
            .map { word in romanNumerals[String(word)] ?? String(word) }
            .joined(separator: " ")
    }

    // Follows saved before search existed were Steam games stored as {"name", "appID", "aliases"}.
    private enum CodingKeys: String, CodingKey {
        case name, igdbID, steamAppID, coverImageID, year, platforms, aliases
        case appID
    }

    init(
        name: String, igdbID: Int? = nil, steamAppID: Int? = nil, coverImageID: String? = nil,
        year: Int? = nil, platforms: [String] = [], aliases: [String] = []
    ) {
        self.name = name
        self.igdbID = igdbID
        self.steamAppID = steamAppID
        self.coverImageID = coverImageID
        self.year = year
        self.platforms = platforms
        self.aliases = aliases
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        igdbID = try c.decodeIfPresent(Int.self, forKey: .igdbID)
        steamAppID = try c.decodeIfPresent(Int.self, forKey: .steamAppID)
            ?? c.decodeIfPresent(Int.self, forKey: .appID)
        coverImageID = try c.decodeIfPresent(String.self, forKey: .coverImageID)
        year = try c.decodeIfPresent(Int.self, forKey: .year)
        platforms = try c.decodeIfPresent([String].self, forKey: .platforms) ?? []
        aliases = try c.decodeIfPresent([String].self, forKey: .aliases) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(name, forKey: .name)
        try c.encodeIfPresent(igdbID, forKey: .igdbID)
        try c.encodeIfPresent(steamAppID, forKey: .steamAppID)
        try c.encodeIfPresent(coverImageID, forKey: .coverImageID)
        try c.encodeIfPresent(year, forKey: .year)
        try c.encode(platforms, forKey: .platforms)
        try c.encode(aliases, forKey: .aliases)
    }
}

extension [Game] {
    /// Whether a post is about one of these games: the game's own Steam post, or a headline that
    /// names it as whole words ("Baldur's Gate 3" or "BG3", but not "Elden Ringtone").
    func anyAbout(_ post: NewsItem) -> Bool {
        if let game = post.game, contains(where: { $0.name == game }) { return true }
        let title = searchable(post.title)
        return contains { game in
            game.headlineNames.contains { title.contains(searchable($0)) }
        }
    }
}

/// "Baldur's Gate 3: Patch 8!" → " baldurs gate 3 patch 8 ", so names match whole words only.
private func searchable(_ text: String) -> String {
    let folded = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
        .replacingOccurrences(of: "'", with: "")
        .replacingOccurrences(of: "’", with: "")
        .replacingOccurrences(of: "™", with: "")
        .replacingOccurrences(of: "®", with: "")
    let words = folded.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
    return " " + words.joined(separator: " ") + " "
}
