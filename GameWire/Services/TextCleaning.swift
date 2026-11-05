import Foundation

extension String {
    /// Turns HTML from a feed into plain readable text.
    var strippingHTML: String {
        var s = replacingOccurrences(of: "<br\\s*/?>|</p>|</li>|</h[1-6]>", with: "\n", options: [.regularExpression, .caseInsensitive])
        s = s.replacingOccurrences(of: "<li[^>]*>", with: "• ", options: [.regularExpression, .caseInsensitive])
        s = s.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        return s.decodingHTMLEntities.tidyWhitespace
    }

    /// Turns Steam's BBCode ([p], [b], [list][*], [img]…) into plain readable text.
    var strippingSteamMarkup: String {
        var s = replacingOccurrences(of: "\\[img[^\\]]*\\].*?\\[/img\\]", with: "", options: [.regularExpression, .caseInsensitive])
        s = s.replacingOccurrences(of: "\\[(previewyoutube|video)[^\\]]*\\].*?\\[/(previewyoutube|video)\\]", with: "", options: [.regularExpression, .caseInsensitive])
        s = s.replacingOccurrences(of: "\\[/p\\]|\\[br\\]|\\[/h[1-6]\\]|\\[/list\\]|\\[/olist\\]|\\[hr\\]\\[/hr\\]", with: "\n", options: [.regularExpression, .caseInsensitive])
        s = s.replacingOccurrences(of: "\\[\\*\\]", with: "\n• ", options: .regularExpression)
        s = s.replacingOccurrences(
            of: "\\[/?(p|b|i|u|s|h[1-6]|list|olist|\\*|url[^\\]]*|quote[^\\]]*|code|noparse|hr|table[^\\]]*|tr|td|th|spoiler|strike|expand[^\\]]*|carousel[^\\]]*)\\]",
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
        s = s.replacingOccurrences(of: "\\{STEAM_CLAN_IMAGE\\}\\S*", with: "", options: .regularExpression)
        // Some Steam posts (from outlets) are HTML instead of BBCode.
        return s.strippingHTML
    }

    /// First <img src="..."> in an HTML string.
    var firstHTMLImageURL: URL? {
        guard let range = range(of: "<img[^>]+src=[\"']([^\"']+)[\"']", options: [.regularExpression, .caseInsensitive]) else { return nil }
        let tag = String(self[range])
        guard let srcRange = tag.range(of: "(?<=src=[\"'])[^\"']+", options: .regularExpression) else { return nil }
        return URL(string: String(tag[srcRange]).decodingHTMLEntities)
    }

    /// First image in a Steam post, e.g. {STEAM_CLAN_IMAGE}/44156989/abc.jpg
    var firstSteamImageURL: URL? {
        guard let range = range(of: "(?<=\\{STEAM_CLAN_IMAGE\\}/)[^\\s\"\\[\\]]+", options: .regularExpression) else { return nil }
        return URL(string: "https://clan.akamai.steamstatic.com/images/\(self[range])")
    }

    var decodingHTMLEntities: String {
        guard contains("&") else { return self }
        var s = self
        let named = [
            "&nbsp;": " ", "&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"", "&apos;": "'",
            "&rsquo;": "\u{2019}", "&lsquo;": "\u{2018}", "&rdquo;": "\u{201D}", "&ldquo;": "\u{201C}",
            "&hellip;": "\u{2026}", "&mdash;": "\u{2014}", "&ndash;": "\u{2013}", "&trade;": "\u{2122}",
            "&reg;": "\u{00AE}", "&copy;": "\u{00A9}",
        ]
        for (entity, char) in named {
            s = s.replacingOccurrences(of: entity, with: char)
        }
        // Numeric entities: &#39; &#x27;
        while let range = s.range(of: "&#(x[0-9a-fA-F]+|[0-9]+);", options: .regularExpression) {
            let body = s[range].dropFirst(2).dropLast()
            let value = body.hasPrefix("x") ? UInt32(body.dropFirst(), radix: 16) : UInt32(body)
            let replacement = value.flatMap(Unicode.Scalar.init).map { String(Character($0)) } ?? ""
            s.replaceSubrange(range, with: replacement)
        }
        return s
    }

    /// Collapses runs of spaces and blank lines.
    var tidyWhitespace: String {
        var s = replacingOccurrences(of: "[ \\t\\u{00A0}]+", with: " ", options: .regularExpression)
        s = s.replacingOccurrences(of: " *\\n *", with: "\n", options: .regularExpression)
        s = s.replacingOccurrences(of: "\\n{3,}", with: "\n\n", options: .regularExpression)
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
