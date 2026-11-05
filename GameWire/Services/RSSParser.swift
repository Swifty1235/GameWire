import Foundation

/// One raw entry from an RSS or Atom feed, before it becomes a NewsItem.
struct RSSEntry {
    var title = ""
    var link = ""
    var summary = ""
    var content = ""
    var dateString = ""
    var imageURL: String?
}

/// Minimal RSS 2.0 / Atom parser built on Foundation's XMLParser.
/// Picks up the image from media:thumbnail, media:content or an image enclosure.
final class RSSParser: NSObject, XMLParserDelegate {
    private var entries: [RSSEntry] = []
    private var current: RSSEntry?
    private var text = ""

    static func parse(_ data: Data) -> [RSSEntry] {
        let delegate = RSSParser()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.parse()
        return delegate.entries
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes: [String: String] = [:]
    ) {
        text = ""
        switch elementName {
        case "item", "entry":
            current = RSSEntry()
        case "media:thumbnail":
            setImageIfMissing(attributes["url"])
        case "media:content":
            let isImage = attributes["medium"] == "image"
                || attributes["type"]?.hasPrefix("image") == true
                || (attributes["medium"] == nil && attributes["type"] == nil)
            if isImage { setImageIfMissing(attributes["url"]) }
        case "enclosure":
            if attributes["type"]?.hasPrefix("image") == true { setImageIfMissing(attributes["url"]) }
        case "link":
            // Atom puts the URL in an attribute: <link rel="alternate" href="..."/>
            if let href = attributes["href"], attributes["rel"] == nil || attributes["rel"] == "alternate" {
                current?.link = href
            }
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        text += string
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        text += String(decoding: CDATABlock, as: UTF8.self)
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        defer { text = "" }
        guard current != nil else { return }
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)

        switch elementName {
        case "title":
            current?.title = value
        case "link":
            if !value.isEmpty { current?.link = value }
        case "description", "summary":
            current?.summary = value
        case "content:encoded", "content":
            current?.content = value
        case "pubDate", "published", "dc:date", "updated":
            if current?.dateString.isEmpty == true { current?.dateString = value }
        case "item", "entry":
            if let entry = current { entries.append(entry) }
            current = nil
        default:
            break
        }
    }

    private func setImageIfMissing(_ url: String?) {
        guard let url, current != nil, current?.imageURL == nil else { return }
        current?.imageURL = url
    }
}

/// Parses the date formats feeds use: RFC 822 ("Wed, 04 Nov 2026 20:33:10 +0000") and ISO 8601.
enum FeedDate {
    private static let rfc822: [DateFormatter] = [
        "EEE, d MMM yyyy HH:mm:ss Z",
        "EEE, d MMM yyyy HH:mm:ss zzz",
        "d MMM yyyy HH:mm:ss Z",
        "EEE, d MMM yyyy HH:mm Z",
    ].map { format in
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = format
        return formatter
    }

    private static let iso8601 = ISO8601DateFormatter()
    private static let iso8601Fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static func parse(_ string: String) -> Date? {
        for formatter in rfc822 {
            if let date = formatter.date(from: string) { return date }
        }
        return iso8601.date(from: string) ?? iso8601Fractional.date(from: string)
    }
}
