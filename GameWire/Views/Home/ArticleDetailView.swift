import SwiftUI

/// Full article reader for sources that give us the whole text (IGN, PC Gamer, GameSpot, Steam).
/// Rendered with WebKit so headings, lists, tables, images and videos all show.
struct ArticleDetailView: View {
    let item: NewsItem
    @State private var webLink: WebLink?
    @State private var previews: [LinkPreview] = []
    private let html: String

    init(item: NewsItem) {
        self.item = item
        self.html = ArticleHTML.page(for: item)
    }

    var body: some View {
        ArticleWebView(
            html: html,
            baseURL: item.url,
            previews: previews,
            onOpenLink: { webLink = WebLink(url: $0) }
        )
        .ignoresSafeArea(edges: .bottom)
        .task {
            // Cover images + titles for gallery cards (IGN slideshows).
            await withTaskGroup(of: LinkPreview?.self) { group in
                for url in ArticleHTML.ignGalleryURLs(in: item.articleHTML ?? "") {
                    group.addTask { await LinkPreview.fetch(url) }
                }
                for await preview in group {
                    if let preview { previews.append(preview) }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        // Home hides the nav bar for its logo header; bring it back here for the back button.
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            if let url = item.url {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: url)
                }
            }
        }
        .fullScreenCover(item: $webLink) { link in
            SafariView(url: link.url, readerMode: false)
                .ignoresSafeArea()
        }
    }
}

#Preview {
    NavigationStack {
        ArticleDetailView(item: SampleData.feed[0])
    }
}
