import SwiftUI

/// Tab 1: everything you follow, as one simple feed (newest first).
struct HomeView: View {
    @State private var path: [NewsItem] = []
    @State private var feed: [NewsItem] = []
    @State private var hasLoaded = false
    @State private var savedIDs: Set<String> = []
    @State private var hiddenSources: Set<String> = []
    @State private var webLink: WebLink?

    private var items: [NewsItem] {
        feed.filter { !hiddenSources.contains($0.displayName) }
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                header

                LazyVStack(spacing: 0) {
                    ForEach(items) { item in
                        PostRow(
                            item: item,
                            isSaved: savedIDs.contains(item.id),
                            onToggleSave: { toggleSave(item) },
                            onHideSource: {
                                withAnimation { _ = hiddenSources.insert(item.displayName) }
                            }
                        )
                        .contentShape(.rect)
                        .onTapGesture { open(item) }

                        Divider()
                    }
                }

                if !hasLoaded {
                    ProgressView()
                        .controlSize(.large)
                        .padding(.top, 120)
                } else if items.isEmpty {
                    ContentUnavailableView {
                        Label("Couldn't load news", systemImage: "wifi.exclamationmark")
                    } description: {
                        Text("Check your connection and try again.")
                    } actions: {
                        Button("Try Again") {
                            Task { await load() }
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.top, 80)
                }
            }
            // Solid strip behind the status bar so scrolled posts don't show through.
            .overlay(alignment: .top) {
                GeometryReader { geo in
                    Theme.background
                        .frame(height: geo.safeAreaInsets.top)
                        .ignoresSafeArea(edges: .top)
                }
                .allowsHitTesting(false)
            }
            .toolbar(.hidden, for: .navigationBar)
            .task {
                if !hasLoaded { await load() }
            }
            .refreshable {
                await load()
            }
            .navigationDestination(for: NewsItem.self) { item in
                ArticleDetailView(item: item)
            }
            .fullScreenCover(item: $webLink) { link in
                SafariView(url: link.url)
                    .ignoresSafeArea()
            }
        }
    }

    /// Full-text posts open in the app's reader; teaser-only posts open the site in Reader mode.
    private func open(_ item: NewsItem) {
        if !item.hasFullText, let url = item.url {
            webLink = WebLink(url: url)
        } else {
            path.append(item)
        }
    }

    /// GAMEWIRE logo + settings button.
    private var header: some View {
        HStack {
            Text("\(Text("GAME"))\(Text("WIRE").foregroundStyle(Theme.accent))")
                .font(.system(size: 30, weight: .black))
                .italic()
                .accessibilityLabel("GameWire")
            Spacer()
            Button {
                // Settings comes later.
            } label: {
                Image(systemName: "gearshape")
                    .font(.title3)
                    .foregroundStyle(.primary)
                    .frame(width: 40, height: 40)
                    .background(Color(.secondarySystemBackground), in: .circle)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Settings")
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 4)
    }

    private func load() async {
        let fetched = await NewsService.fetchFeed()
        // Keep the old feed if a refresh comes back empty (e.g. briefly offline).
        if !fetched.isEmpty || feed.isEmpty {
            feed = fetched
        }
        hasLoaded = true
    }

    private func toggleSave(_ item: NewsItem) {
        if savedIDs.contains(item.id) {
            savedIDs.remove(item.id)
        } else {
            savedIDs.insert(item.id)
        }
    }
}

#Preview {
    HomeView()
}
