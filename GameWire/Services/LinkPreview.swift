import Foundation

/// Title + image for a link card, read from the page's Open Graph tags
/// (the same info iMessage or Slack use for link previews).
struct LinkPreview: Sendable {
    let url: URL
    let title: String?
    let imageURL: URL?

    static func fetch(_ url: URL) async -> LinkPreview? {
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue("Mozilla/5.0 (iPhone) GameWire/0.1", forHTTPHeaderField: "User-Agent")
        guard let (data, _) = try? await URLSession.shared.data(for: request) else { return nil }
        let html = String(decoding: data, as: UTF8.self)

        let title = meta("og:title", in: html)?
            .replacingOccurrences(of: " - IGN", with: "")
            .decodingHTMLEntities
        let image = meta("og:image", in: html).flatMap { URL(string: $0.decodingHTMLEntities) }
        return LinkPreview(url: url, title: title, imageURL: image)
    }

    private static func meta(_ property: String, in html: String) -> String? {
        let pattern = "<meta[^>]+property=\"\(property)\"[^>]+content=\"([^\"]+)\""
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let range = Range(match.range(at: 1), in: html)
        else { return nil }
        return String(html[range])
    }
}
