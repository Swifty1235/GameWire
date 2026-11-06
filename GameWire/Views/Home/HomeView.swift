import SwiftUI

/// The two feeds at the top of Home.
enum FeedTab: CaseIterable, Identifiable {
    /// Everything: news sites + popular games, with games you follow ranked higher.
    case discover
    /// Only games you follow: their Steam posts, and news articles that name them.
    case myGames

    var id: Self { self }

    var title: String {
        switch self {
        case .discover: "Discover"
        case .myGames: "My Games"
        }
    }
}

/// Tab 1: news as Reddit-style feeds, Discover and My Games. Shows a page of posts at a time and
/// loads the next page as you scroll near the bottom.
struct HomeView: View {
    /// Posts shown per page.
    private static let pageSize = 10

    @Environment(FollowStore.self) private var follows

    @State private var path: [NewsItem] = []
    @State private var tab: FeedTab = .discover
    /// Everything downloaded, unordered. Both feeds are built from it.
    @State private var posts: [NewsItem] = []
    /// The Steam games we downloaded posts for (followed + popular), to follow from a post.
    @State private var fetchedGames: [Game] = []
    @State private var discoverFeed: [NewsItem] = []
    @State private var myGamesFeed: [NewsItem] = []
    /// My Games looked back a month (instead of a week) because your games had little recent news.
    @State private var myGamesShowsMonth = false
    @State private var hasLoaded = false
    @State private var visibleCount: [FeedTab: Int] = [:]
    @State private var isLoadingMore = false
    @State private var savedIDs: Set<String> = []
    @State private var hiddenSources: Set<String> = []
    @State private var webLink: WebLink?
    @State private var showFindGames = false
    /// The pills hide while scrolling down the feed and come back when scrolling up.
    @State private var showTabs = true
    /// Whether the feed is moving because of your finger (vs. the app scrolling or swapping the feed).
    @State private var scrollPhase: ScrollPhase = .idle
    /// How far the feed is scrolled, and the measured heights of the logo row and the pills. The pills
    /// float above the feed (not inside it) so swapping Discover ↔ My Games can't make them flicker.
    @State private var scrollOffset: CGFloat = 0
    @State private var headerHeight: CGFloat = 60
    @State private var tabBarHeight: CGFloat = 54

    private var items: [NewsItem] {
        (tab == .discover ? discoverFeed : myGamesFeed)
            .filter { !hiddenSources.contains($0.displayName) }
    }

    private var shownCount: Int { visibleCount[tab, default: Self.pageSize] }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollViewReader { scroll in
                ScrollView {
                    VStack(spacing: 0) {
                        header
                            .id("top")
                            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { headerHeight = $0 }

                        // Room for the floating pills.
                        Color.clear
                            .frame(height: tabBarHeight)

                        LazyVStack(spacing: 0) {
                            ForEach(items.prefix(shownCount)) { item in
                                row(for: item)
                                Divider()
                            }

                            if hasLoaded && !items.isEmpty {
                                feedFooter
                            }
                        }

                        if !hasLoaded {
                            ProgressView()
                                .controlSize(.large)
                                .padding(.top, 120)
                        } else if items.isEmpty {
                            emptyState
                                .padding(.top, 80)
                        }
                    }
                }
                .overlay(alignment: .top) {
                    tabBar(scroll: scroll)
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { tabBarHeight = $0 }
                        .offset(y: tabBarY)
                        .allowsHitTesting(tabBarY > -tabBarHeight)
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
            .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y + $0.contentInsets.top } action: { old, new in
                scrollOffset = new
                updateTabVisibility(from: old, to: new)
            }
            .onScrollPhaseChange { _, phase in
                scrollPhase = phase
            }
            .refreshable {
                await load()
            }
            .onChange(of: follows.games) { old, new in
                if new.count < old.count {
                    // Unfollowed: just drop that game's posts, keep the order you were reading.
                    myGamesFeed = myGamesFeed.filter { new.anyAbout($0) }
                } else {
                    buildMyGamesFeed()
                    Task { await fetchNewlyFollowedGames() }
                }
            }
            .navigationDestination(for: NewsItem.self) { item in
                ArticleDetailView(item: item)
            }
            .fullScreenCover(item: $webLink) { link in
                SafariView(url: link.url)
                    .ignoresSafeArea()
            }
            .sheet(isPresented: $showFindGames) {
                FindGamesView()
            }
        }
    }

    private func row(for item: NewsItem) -> some View {
        let game = item.game.flatMap { name in fetchedGames.first { $0.name == name } }
        return PostRow(
            item: item,
            isSaved: savedIDs.contains(item.id),
            onToggleSave: { toggleSave(item) },
            onHideSource: {
                withAnimation { _ = hiddenSources.insert(item.displayName) }
            },
            isFollowingGame: game.map(follows.isFollowing),
            onToggleFollow: {
                if let game { follows.toggle(game) }
            }
        )
        .contentShape(.rect)
        .onTapGesture { open(item) }
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

    /// Discover | My Games as two slim pills splitting the width; the selected one is filled orange.
    /// Sticks to the top while scrolling. Tapping a pill (or the current one again) jumps to the top.
    private func tabBar(scroll: ScrollViewProxy) -> some View {
        HStack(spacing: 8) {
            ForEach(FeedTab.allCases) { option in
                let selected = tab == option
                Button {
                    withAnimation(.snappy(duration: 0.25)) { tab = option }
                    scroll.scrollTo("top", anchor: .top)
                    showTabs = true
                } label: {
                    Text(option.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(selected ? .white : .primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background {
                            Capsule()
                                .fill(selected ? Theme.accent : Color(.secondarySystemBackground))
                        }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        // No slide: the colors swap with a very quick fade, plus a light tap of haptic feedback.
        .animation(.easeOut(duration: 0.1), value: tab)
        .sensoryFeedback(.selection, trigger: tab)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Theme.background)
    }

    /// Where the pills are drawn: right under the logo, moving with the feed, until they reach the top;
    /// then stuck to the top, or slid up out of sight (behind the status-bar strip) when hidden.
    private var tabBarY: CGFloat {
        let underLogo = headerHeight - scrollOffset
        if underLogo > 0 { return underLogo }
        return showTabs ? 0 : -(tabBarHeight + 20)
    }

    /// Hide the pills when you scroll down, show them on any scroll up or near the top.
    /// Only your own scrolling counts: switching tabs also moves the feed (it jumps to the top and the
    /// posts change), and that used to hide the pills. Small moves are ignored so they don't flicker.
    private func updateTabVisibility(from old: CGFloat, to new: CGFloat) {
        let byFinger = scrollPhase == .interacting || scrollPhase == .decelerating
        let show: Bool
        if new < headerHeight + tabBarHeight {
            show = true
        } else if !byFinger {
            return
        } else if new - old > 6 {
            show = false
        } else if old - new > 6 {
            show = true
        } else {
            return
        }
        if show != showTabs {
            withAnimation(.snappy(duration: 0.2)) { showTabs = show }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if posts.isEmpty {
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
        } else if tab == .myGames {
            ContentUnavailableView {
                Label(
                    follows.games.isEmpty ? "No games yet" : "Nothing new this week",
                    systemImage: "gamecontroller"
                )
            } description: {
                Text(follows.games.isEmpty
                    ? "Follow games to see their news and patch notes here."
                    : "Your games haven't had news in the past month. Follow more to fill this up.")
            } actions: {
                Button("Find Games") { showFindGames = true }
                    .buttonStyle(.borderedProminent)
            }
        } else {
            ContentUnavailableView(
                "All hidden",
                systemImage: "eye.slash",
                description: Text("You've hidden every source in this feed.")
            )
        }
    }

    /// Downloads everything once, then builds both feeds from it.
    private func load() async {
        var games = follows.games
        for game in DefaultFollows.popularGames where !games.contains(where: { $0.isSame(as: game) }) {
            games.append(game)
        }
        let fetched = await NewsService.fetchAll(games: games)
        // Keep the old feeds if a refresh comes back empty (e.g. briefly offline).
        if !fetched.isEmpty || posts.isEmpty {
            posts = fetched
            fetchedGames = games
            discoverFeed = FeedMixer.mix(NewsService.discoverPosts(posts), followedGames: follows.games)
            buildMyGamesFeed()
            visibleCount = [:]
        }
        hasLoaded = true
    }

    /// A game you just followed (e.g. from search) whose Steam news we haven't downloaded yet:
    /// fetch it now so it shows up in My Games without a pull-to-refresh.
    private func fetchNewlyFollowedGames() async {
        let missing = follows.games.filter { game in
            game.steamAppID != nil && !fetchedGames.contains { $0.isSame(as: game) }
        }
        guard !missing.isEmpty else { return }
        fetchedGames += missing
        let known = Set(posts.map(\.id))
        let extra = await NewsService.fetchAll(outlets: [], games: missing).filter { !known.contains($0.id) }
        guard !extra.isEmpty else { return }
        posts += extra
        buildMyGamesFeed()
    }

    /// My Games: news about your games, mixed like Discover (fresher posts tend to come first). Shows the
    /// past week, or the past month when the week has fewer than 20 posts (e.g. you follow just a few games).
    private func buildMyGamesFeed() {
        let followed = follows.games
        let about = posts.filter { followed.anyAbout($0) }
        let week = about.filter { $0.published > Date().addingTimeInterval(-NewsService.weekAge) }
        myGamesShowsMonth = week.count < 20
        myGamesFeed = FeedMixer.mix(myGamesShowsMonth ? about : week, followedGames: followed)
        visibleCount[.myGames] = nil
    }

    /// Bottom of the feed: a spinner that loads the next page when it scrolls into view,
    /// or an end message once everything from the past week has been shown.
    @ViewBuilder
    private var feedFooter: some View {
        if shownCount < items.count {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .onAppear { loadMore() }
        } else {
            VStack(spacing: 6) {
                Image(systemName: "checkmark.circle")
                    .font(.title2)
                    .foregroundStyle(Theme.accent)
                Text("You're all caught up")
                    .font(.headline)
                Text("That's everything from the past \(tab == .myGames && myGamesShowsMonth ? "month" : "week"). Pull down to refresh.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                if tab == .myGames {
                    Button("Find More Games") { showFindGames = true }
                        .buttonStyle(.bordered)
                        .padding(.top, 8)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
            .padding(.horizontal, 32)
        }
    }

    private func loadMore() {
        guard !isLoadingMore else { return }
        isLoadingMore = true
        let feed = tab, total = items.count
        Task {
            // Everything is already downloaded; the short pause just lets the spinner read as "loading".
            try? await Task.sleep(for: .milliseconds(350))
            visibleCount[feed] = min(visibleCount[feed, default: Self.pageSize] + Self.pageSize, total)
            isLoadingMore = false
        }
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
        .environment(FollowStore())
}
