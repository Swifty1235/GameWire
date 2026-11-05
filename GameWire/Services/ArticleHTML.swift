import Foundation

/// Builds the HTML page the article reader shows: GameWire's own styling around the
/// article HTML from the feed, so headings, lists, tables, images and videos all render.
enum ArticleHTML {
    static func page(for item: NewsItem) -> String {
        let body = clean(item.articleHTML ?? "<p>\(escape(item.summary))</p>")

        var hero = ""
        if let imageURL = item.imageURL, !body.contains(imageURL.absoluteString), !leadsWithImage(body) {
            hero = "<img class=\"hero\" src=\"\(escape(imageURL.absoluteString))\">"
        }

        var original = ""
        if let url = item.url {
            original = "<a class=\"original\" href=\"\(escape(url.absoluteString))\">View original on \(escape(item.source)) ↗</a>"
        }

        return """
        <!doctype html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>\(css)</style>
        </head>
        <body>
        <div class="meta"><strong>\(escape(item.displayName))</strong> · \(escape(item.subtitleLine))</div>
        <div class="kind">\(escape(item.kindLine))</div>
        <h1 class="title">\(escape(item.title))</h1>
        \(hero)
        <article>\(body)</article>
        \(original)
        <script>\(carouselScript)</script>
        \(embedScripts(for: body))
        </body>
        </html>
        """
    }

    /// Steam announcements use BBCode ([p], [b], [list][*], [img], [previewyoutube]…). Convert to HTML.
    static func steamHTML(fromBBCode bbcode: String) -> String {
        var s = bbcode.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\n", with: "<br>")
        s = s.replacingOccurrences(of: "{STEAM_CLAN_IMAGE}", with: "https://clan.akamai.steamstatic.com/images")
        // "\[ GAMEPLAY ]" is Steam's way of writing a literal bracket, not a tag.
        s = s.replacingOccurrences(of: "\\[", with: "&#91;").replacingOccurrences(of: "\\]", with: "&#93;")
        // Videos: [previewyoutube="VIDEO_ID;full"][/previewyoutube]
        s = s.regex("\\[previewyoutube=[\"']?([A-Za-z0-9_-]+)[^\\]]*\\]\\s*\\[/previewyoutube\\]",
                    "<iframe class=\"youtube\" src=\"https://www.youtube-nocookie.com/embed/$1\" allowfullscreen></iframe>")
        s = s.regex("\\[/?previewyoutube[^\\]]*\\]", "")
        s = s.regex("\\[video[^\\]]*?mp4=\"([^\"]+)\"[^\\]]*\\]\\s*\\[/video\\]",
                    "<video controls playsinline preload=\"metadata\" src=\"$1\"></video>")
        s = s.regex("\\[video[^\\]]*\\][\\s\\S]*?\\[/video\\]", "")
        // [dynamiclink href="…"][/dynamiclink]: Steam's rich link (YouTube, Twitch, store pages…).
        s = s.replacingMatches(of: "\\[dynamiclink[^\\]]*?href=[\"']([^\"']+)[\"'][^\\]]*\\]\\s*(\\[/dynamiclink\\])?") { groups in
            linkEmbed(for: groups[1])
        }
        // Images and links
        s = s.regex("\\[img[^\\]]*?src=[\"']?([^\"'\\]\\s]+)[\"']?[^\\]]*\\]\\s*\\[/img\\]", "<img src=\"$1\">")
        s = s.regex("\\[img\\]([^\\[]+)\\[/img\\]", "<img src=\"$1\">")
        s = s.regex("\\[url=[\"']?([^\"'\\]]+)[\"']?[^\\]]*\\]", "<a href=\"$1\">")
        s = s.regex("\\[/url\\]", "</a>")
        // Text formatting and structure
        s = s.regex("\\[(/?)(p|b|i|u|s|code|table|tr|td|th)(\\s[^\\]]*)?\\]", "<$1$2>")
        s = s.regex("\\[(/?)strike\\]", "<$1s>")
        s = s.regex("\\[(/?)h([1-6])\\]", "<$1h$2>")
        s = s.regex("\\[(/?)list[^\\]]*\\]", "<$1ul>")
        s = s.regex("\\[(/?)olist[^\\]]*\\]", "<$1ol>")
        s = s.regex("\\[\\*\\]", "<li>")
        s = s.regex("\\[/\\*\\]", "</li>")
        s = s.regex("\\[quote[^\\]]*\\]", "<blockquote>")
        s = s.regex("\\[/quote\\]", "</blockquote>")
        s = s.regex("\\[hr\\]\\s*\\[/hr\\]|\\[hr\\]", "<hr>")
        s = s.regex("\\[/?(spoiler|noparse|expand[^\\]]*|carousel[^\\]]*|dynamiclink[^\\]]*)\\]", "")
        return s
    }

    /// A bare link turned into something worth looking at: a YouTube player, a Steam store card
    /// with the game's banner, or a tappable link card.
    private static func linkEmbed(for rawURL: String) -> String {
        let link = rawURL.replacingOccurrences(of: "&amp;", with: "&")
        if let videoID = link.firstCapture(of: "(?:youtube\\.com/(?:watch\\?(?:.*&)?v=|live/|shorts/|embed/)|youtu\\.be/)([A-Za-z0-9_-]{11})") {
            return "<iframe class=\"youtube\" src=\"https://www.youtube-nocookie.com/embed/\(videoID)\" allowfullscreen></iframe>"
        }

        let url = URL(string: link)
        let host = (url?.host() ?? link).replacingOccurrences(of: "www.", with: "")
        let path = url?.path().trimmingCharacters(in: CharacterSet(charactersIn: "/")) ?? ""

        if let appID = link.firstCapture(of: "store\\.steampowered\\.com/app/(\\d+)") {
            let banner = "https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/\(appID)/header.jpg"
            return """
            <a class="card" href="\(escape(link))">
              <img class="preview-image" src="\(banner)" alt="">
              <span class="card-label">Steam Store</span>
              <span class="preview-title">View on Steam</span>
              <span class="card-cta">store.steampowered.com ↗</span>
            </a>
            """
        }

        let siteNames = ["twitch.tv": "Twitch", "x.com": "X", "twitter.com": "X", "discord.gg": "Discord",
                         "discord.com": "Discord", "instagram.com": "Instagram", "tiktok.com": "TikTok",
                         "reddit.com": "Reddit", "store.steampowered.com": "Steam Store"]
        let site = siteNames[host] ?? host
        let title = path.isEmpty ? site : "\(site) · \(path)"
        return """
        <a class="card" href="\(escape(link))">
          <span class="card-label">Link</span>
          <span class="preview-title">\(escape(title))</span>
          <span class="card-cta">\(escape(host)) ↗</span>
        </a>
        """
    }

    // MARK: - Carousels

    /// Groups images that sit next to each other in an article (2 or more, with nothing but empty
    /// space between them) into a swipeable carousel with a "1 / 5" counter.
    private static let carouselScript = """
    (() => {
      const article = document.querySelector('article');
      if (!article) return;

      // Text of an element, ignoring image captions.
      const textOf = el => {
        const copy = el.cloneNode(true);
        copy.querySelectorAll('figcaption').forEach(f => f.remove());
        return copy.textContent.trim();
      };
      const isBlank = el => !el.querySelector('img, iframe, video') && el.textContent.trim() === '';

      // The outermost element that holds just this one image (e.g. <p><img></p> or <figure>…).
      const blockFor = img => {
        let block = img;
        while (block.parentElement && block.parentElement !== article &&
               block.parentElement.querySelectorAll('img, iframe, video').length === 1 &&
               textOf(block.parentElement) === '') {
          block = block.parentElement;
        }
        return block;
      };

      const images = [...article.querySelectorAll('img')].filter(img => !img.closest('.carousel, .card, blockquote, a[href*="twitter"], iframe'));
      const blocks = new Set(images.map(blockFor));
      const used = new Set();

      for (const first of blocks) {
        if (used.has(first)) continue;
        const group = [first];
        used.add(first);
        for (let next = first.nextElementSibling; next; next = next.nextElementSibling) {
          if (blocks.has(next)) { group.push(next); used.add(next); }
          else if (!isBlank(next)) break;
        }
        if (group.length < 2) continue;

        const carousel = document.createElement('div');
        carousel.className = 'carousel';
        const track = document.createElement('div');
        track.className = 'carousel-track';
        first.parentElement.insertBefore(carousel, first);
        for (const block of group) {
          const slide = document.createElement('div');
          slide.className = 'carousel-slide';
          slide.appendChild(block);
          track.appendChild(slide);
        }
        const counter = document.createElement('div');
        counter.className = 'carousel-counter';
        counter.textContent = `1 / ${group.length}`;
        carousel.append(track, counter);

        track.addEventListener('scroll', () => {
          const step = track.firstElementChild.offsetWidth + 8;
          const index = Math.min(group.length - 1, Math.round(track.scrollLeft / step));
          counter.textContent = `${index + 1} / ${group.length}`;
        }, { passive: true });
      }
    })();
    """

    // MARK: - Social embeds

    /// Social posts arrive as plain <blockquote> placeholders. Each platform's official script
    /// swaps the placeholder for the real post, so we load only the ones an article uses.
    private static let embedProviders: [(marker: String, script: String)] = [
        ("twitter-tweet", "https://platform.twitter.com/widgets.js"),
        ("instagram-media", "https://www.instagram.com/embed.js"),
        ("reddit-embed-bq", "https://embed.reddit.com/widgets.js"),
        ("reddit-card", "https://embed.redditmedia.com/widgets/platform.js"),
        ("bluesky-embed", "https://embed.bsky.app/static/embed.js"),
        ("tiktok-embed", "https://www.tiktok.com/embed.js"),
    ]

    private static func embedScripts(for body: String) -> String {
        let scripts = embedProviders
            .filter { body.contains($0.marker) }
            .map { "<script async src=\"\($0.script)\" charset=\"utf-8\"></script>" }
        guard !scripts.isEmpty else { return "" }

        // Ask the platforms that support it for dark-mode posts. Runs before their scripts do.
        let theme = """
        <script>
        if (matchMedia('(prefers-color-scheme: dark)').matches) {
          document.querySelectorAll('blockquote.twitter-tweet').forEach(b => b.setAttribute('data-theme', 'dark'));
          document.querySelectorAll('blockquote.reddit-embed-bq').forEach(b => b.setAttribute('data-embed-theme', 'dark'));
        }
        document.querySelectorAll('blockquote.bluesky-embed').forEach(b => b.setAttribute('data-bluesky-embed-color-mode', 'system'));
        </script>
        """
        return theme + scripts.joined(separator: "\n")
    }

    // MARK: - Helpers

    /// Removes the site's own scripts/styles and fixes lazy-loaded embeds that would otherwise stay blank.
    private static func clean(_ html: String) -> String {
        var s = html.regex("<(script|style)[^>]*>[\\s\\S]*?</\\1>", "")
        // PC Gamer puts YouTube URLs in data-lazy-src, which only their site's JavaScript fills in.
        s = s.regex("<iframe([^>]*?)\\sdata-lazy-src=", "<iframe$1 src=")
        return expandIGNPlaceholders(s)
    }

    // MARK: - IGN

    /// IGN's feed leaves empty <section data-transform="…"> placeholders that only their website fills in.
    /// Swap the ones we can show for real HTML.
    private static func expandIGNPlaceholders(_ html: String) -> String {
        guard html.contains("data-transform=") else { return html }
        var s = html

        // Videos → IGN's official embeddable player.
        s = s.regex(
            "<section(?=[^>]*data-transform=\"ignvideo\")[^>]*data-slug=\"([^\"]+)\"[^>]*>\\s*</section>",
            "<iframe class=\"ign-video\" src=\"https://widgets.ign.com/video/embed/content.html?url=/videos/$1\" allowfullscreen></iframe>"
        )

        // Galleries → the cover image (the only one IGN shares, via its link preview) with a
        // "View full gallery" link below. The cover and real title are filled in after the page
        // loads (see `ignGalleryURLs` and LinkPreview).
        s = s.replacingMatches(of: "<section(?=[^>]*data-transform=\"slideshow\")[^>]*data-slug=\"([^\"]+)\"[^>]*>\\s*</section>") { groups in
            let slug = groups[1]
            let url = escape(ignGalleryURL(slug).absoluteString)
            let title = slug.split(separator: "-").map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ")
            return """
            <a class="card" href="\(url)" data-preview-url="\(url)">
              <img class="preview-image" alt="">
              <span class="card-label">Gallery</span>
              <span class="preview-title">\(escape(title))</span>
              <span class="card-cta">View full gallery on IGN ↗</span>
            </a>
            """
        }

        // Images with captions (the caption is URL-encoded HTML).
        s = s.replacingMatches(of: "<section(?=[^>]*data-transform=\"image-with-caption\")[^>]*>\\s*</section>") { groups in
            let tag = groups[0]
            guard let image = tag.firstCapture(of: "data-image-url=\"([^\"]+)\"") else { return "" }
            let caption = tag.firstCapture(of: "data-caption=\"([^\"]*)\"")?.removingPercentEncoding ?? ""
            let figcaption = caption.isEmpty || caption == "undefined" ? "" : "<figcaption>\(caption)</figcaption>"
            return "<figure><img src=\"\(image)\">\(figcaption)</figure>"
        }

        // Pull quotes and dividers.
        s = s.regex("<section[^>]*data-transform=\"quoteBox\"[^>]*>([\\s\\S]*?)</section>", "<blockquote class=\"pullquote\">$1</blockquote>")
        s = s.regex("<section[^>]*data-transform=\"divider\"[^>]*>\\s*</section>", "<hr>")
        return s
    }

    /// IGN gallery slugs in an article, for fetching their cover images.
    static func ignGalleryURLs(in html: String) -> [URL] {
        html.allCaptures(of: "data-transform=\"slideshow\"[^>]*data-slug=\"([^\"]+)\"").map(ignGalleryURL)
    }

    private static func ignGalleryURL(_ slug: String) -> URL {
        URL(string: "https://www.ign.com/slideshows/\(slug)")!
    }

    /// True when the article opens with an image before any text (usually the same hero image).
    private static func leadsWithImage(_ html: String) -> Bool {
        guard let range = html.range(of: "<img", options: .caseInsensitive) else { return false }
        return String(html[..<range.lowerBound]).strippingHTML.isEmpty
    }

    private static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private static let css = """
    :root {
      color-scheme: light dark;
      --accent: #FF7A00;
      --text: #000;
      --secondary: rgba(60, 60, 67, 0.6);
      --separator: rgba(60, 60, 67, 0.2);
      --fill: rgba(120, 120, 128, 0.12);
    }
    @media (prefers-color-scheme: dark) {
      :root {
        --text: #fff;
        --secondary: rgba(235, 235, 245, 0.6);
        --separator: rgba(84, 84, 88, 0.6);
        --fill: rgba(120, 120, 128, 0.24);
      }
    }
    * { box-sizing: border-box; }
    html { -webkit-text-size-adjust: 100%; }
    body {
      font: -apple-system-body;
      line-height: 1.55;
      color: var(--text);
      background: transparent;
      margin: 0;
      padding: 12px 16px 48px;
      overflow-wrap: break-word;
    }
    .meta { font: -apple-system-subheadline; color: var(--secondary); }
    .meta strong { color: var(--text); }
    .kind { font: -apple-system-caption1; color: var(--secondary); margin-top: 10px; }
    h1.title { font: -apple-system-title1; font-weight: 700; line-height: 1.2; margin: 4px 0 16px; }
    h1, h2, h3, h4, h5, h6 { line-height: 1.25; margin: 1.4em 0 0.5em; }
    h2 { font-size: 1.3em; }
    h3 { font-size: 1.15em; }
    h4, h5, h6 { font-size: 1em; }
    p { margin: 0 0 1em; }
    a { color: var(--accent); text-decoration: none; }
    strong, b { font-weight: 600; }
    ul, ol { padding-left: 1.3em; margin: 0 0 1em; }
    li { margin-bottom: 0.4em; }
    li > p { margin: 0; }
    img, video, iframe, picture, svg { max-width: 100%; }
    img, video { height: auto; border-radius: 10px; display: block; margin: 0 auto; }
    img.hero { width: 100%; margin-bottom: 16px; }
    article img:not(figure img) { margin-bottom: 1em; }
    iframe { width: 100%; border: 0; border-radius: 10px; margin: 0.5em 0 1em; }
    iframe[src*="youtube"], iframe.youtube, iframe.ign-video { aspect-ratio: 16 / 9; height: auto; }
    blockquote.pullquote { font-size: 1.15em; font-weight: 600; color: var(--text); font-style: normal; }
    /* Swipeable image carousels. Slides are a bit narrower than the screen so the next one peeks in. */
    .carousel { position: relative; margin: 1.2em 0; }
    .carousel-track {
      display: flex;
      gap: 8px;
      overflow-x: auto;
      scroll-snap-type: x mandatory;
      scrollbar-width: none;
    }
    .carousel-track::-webkit-scrollbar { display: none; }
    .carousel-slide { flex: 0 0 88%; scroll-snap-align: start; margin: 0; color: var(--text); }
    .carousel-slide:only-child { flex-basis: 100%; }
    .carousel-slide img {
      width: 100%;
      aspect-ratio: 16 / 9;
      object-fit: cover;
      background: var(--fill);
      border-radius: 10px;
      margin: 0 !important;
    }
    .carousel-slide figure { margin: 0; }
    .carousel-counter {
      position: absolute;
      top: 8px;
      right: calc(12% + 8px);
      background: rgba(0, 0, 0, 0.6);
      color: #fff;
      font: -apple-system-caption1;
      font-weight: 600;
      padding: 3px 8px;
      border-radius: 10px;
      pointer-events: none;
    }
    /* Tappable cards (IGN galleries, Steam links): optional image, label, title and a link line. */
    a.card {
      display: block;
      margin: 1.2em 0;
      border: 1px solid var(--separator);
      border-radius: 12px;
      overflow: hidden;
      color: var(--text);
      background: var(--fill);
    }
    a.card img.preview-image {
      width: 100%;
      aspect-ratio: 16 / 9;
      object-fit: cover;
      border-radius: 0;
      margin: 0 !important;
    }
    a.card img.preview-image:not([src]) { background: var(--fill); }
    a.card span { display: block; padding: 0 14px; }
    a.card .card-label { font: -apple-system-caption1; color: var(--secondary); padding-top: 12px; }
    a.card .preview-title { font-weight: 600; margin: 2px 0 4px; }
    a.card .card-cta { font: -apple-system-footnote; color: var(--accent); padding-bottom: 12px; }
    /* Steam posts stack empty [p][/p] lines as spacers; keep them small. */
    p:empty { margin: 0; height: 0.5em; }
    p:empty + p:empty { display: none; }
    figure { margin: 1.2em 0; }
    figcaption, small, .caption { font: -apple-system-footnote; color: var(--secondary); margin-top: 6px; display: block; }
    /* Social posts: let the platform's own card styling show once it loads. */
    .twitter-tweet-rendered, .instagram-media-rendered, .bluesky-embed, .tiktok-embed { margin: 1.2em auto !important; }
    .twitter-tweet-rendered iframe, .instagram-media-rendered, iframe.instagram-media { border-radius: 12px; }
    blockquote {
      margin: 1.2em 0;
      padding: 0.2em 0 0.2em 14px;
      border-left: 3px solid var(--accent);
      color: var(--secondary);
    }
    table {
      display: block;
      overflow-x: auto;
      border-collapse: collapse;
      font: -apple-system-subheadline;
      margin: 1em 0;
      max-width: 100%;
    }
    th, td { padding: 8px 10px; border-bottom: 1px solid var(--separator); text-align: left; vertical-align: top; }
    th, thead td { font-weight: 600; background: var(--fill); }
    hr { border: 0; border-top: 1px solid var(--separator); margin: 1.5em 0; }
    pre, code { font-family: ui-monospace, Menlo, monospace; font-size: 0.9em; }
    pre { white-space: pre-wrap; background: var(--fill); padding: 10px; border-radius: 8px; }
    .original {
      display: block;
      margin-top: 28px;
      padding-top: 16px;
      border-top: 1px solid var(--separator);
      font: -apple-system-subheadline;
      font-weight: 600;
    }
    """
}

private extension String {
    func regex(_ pattern: String, _ template: String) -> String {
        replacingOccurrences(of: pattern, with: template, options: [.regularExpression, .caseInsensitive])
    }

    /// Like `regex`, but builds each replacement in code. `groups[0]` is the whole match.
    func replacingMatches(of pattern: String, with transform: ([String]) -> String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return self }
        var result = self
        for match in regex.matches(in: self, range: NSRange(startIndex..., in: self)).reversed() {
            let groups = (0..<match.numberOfRanges).map { i in
                Range(match.range(at: i), in: self).map { String(self[$0]) } ?? ""
            }
            if let range = Range(match.range, in: result) {
                result.replaceSubrange(range, with: transform(groups))
            }
        }
        return result
    }

    func firstCapture(of pattern: String) -> String? {
        allCaptures(of: pattern).first
    }

    func allCaptures(of pattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        return regex.matches(in: self, range: NSRange(startIndex..., in: self)).compactMap { match in
            Range(match.range(at: 1), in: self).map { String(self[$0]) }
        }
    }
}
