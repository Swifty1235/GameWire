import Foundation

/// Spots "big stories": the same news covered by several outlets, so FeedMixer can boost them.
///
/// Two headlines count as the same story when they come from different outlets, were posted within
/// 36 hours of each other, and share at least two *specific* words. A word isn't specific when it
/// only names this week's hot topic: one outlet using it in 3+ headlines (Kotaku's many "Ocarina of
/// Time" posts), or it showing up far more often than there are outlets using it. That way ten
/// different Zelda guides don't count as one story, but "Rockstar … GTA 6 screenshots" on 3 sites does.
enum StoryMatcher {
    private static let window: TimeInterval = 36 * 3600

    /// For each outlet post id: the other outlets' posts on the same story (missing = none).
    static func sameStory(in items: [NewsItem]) -> [String: [NewsItem]] {
        let posts = items.filter { $0.origin == .outlet }
        let words = posts.map { keywords(in: $0.title) }

        // word → outlet → number of headlines using it
        var uses: [String: [String: Int]] = [:]
        for (post, set) in zip(posts, words) {
            for word in set { uses[word, default: [:]][post.source, default: 0] += 1 }
        }
        let specific = Set(uses.compactMap { word, perOutlet -> String? in
            let total = perOutlet.values.reduce(0, +)
            let isTopic = perOutlet.values.max()! >= 3 || Double(total) > 1.5 * Double(perOutlet.count)
            return isTopic ? nil : word
        })

        var matches: [String: [NewsItem]] = [:]
        for i in posts.indices {
            for j in posts.indices where j > i && posts[i].source != posts[j].source {
                guard abs(posts[i].published.timeIntervalSince(posts[j].published)) <= window else { continue }
                let shared = words[i].intersection(words[j]).filter(specific.contains)
                if shared.count >= 2 {
                    matches[posts[i].id, default: []].append(posts[j])
                    matches[posts[j].id, default: []].append(posts[i])
                }
            }
        }
        return matches
    }

    // MARK: - Headline → keywords

    /// Different spellings of the same name, so "Grand Theft Auto 6" matches "GTA 6".
    private static let aliases = [
        ("grand theft auto", "gta"), ("world of warcraft", "wow"), ("call of duty", "cod"),
        ("the elder scrolls", "tes"), ("elder scrolls", "tes"),
    ]

    /// Words that say nothing about which story it is.
    private static let stopWords: Set<String> = Set("""
        a an the and or but of to in on for with at by from as is are was were be been it its this that \
        these those you your my i we our they their he his she her them us me not no so if than then just \
        now new out up off over into about after before more most all any some can will would could should \
        has have had do does did how why what when who which there here gets get got make makes one first \
        says say said finally official officially next even still already way people fan fans year years \
        day days week weeks time game games really very much many big biggest best only also like look \
        looks back great start free play playing playable dlc version update
        """.split(whereSeparator: \.isWhitespace).map(String.init))

    /// "Rockstar Dumps 40 New GTA 6 Screenshots" → ["rockstar", "dump", "40", "gta", "6", "screenshot"]
    static func keywords(in title: String) -> Set<String> {
        var text = title.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .replacingOccurrences(of: "’", with: "'")
        for (long, short) in aliases {
            text = text.replacingOccurrences(of: long, with: short)
        }
        text = text.replacing(#/'s\b/#, with: "")

        var result = Set<String>()
        for piece in text.split(whereSeparator: { !$0.isLetter && !$0.isNumber }) {
            var word = String(piece)
            let isNumber = word.allSatisfy(\.isNumber)
            if stopWords.contains(word) || (word.count < 3 && !isNumber) { continue }
            // Years ("2027") link unrelated stories.
            if isNumber && word.count == 4 && (word.hasPrefix("19") || word.hasPrefix("20")) { continue }
            // Plural → singular, roughly: "screenshots" = "screenshot".
            if word.count > 3 && word.hasSuffix("s") && !word.hasSuffix("ss") { word.removeLast() }
            if !stopWords.contains(word) { result.insert(word) }
        }
        return result
    }
}
