import SwiftUI

/// Tab 2: the games you follow as a grid of box art, 3 per row, with a search bar to add more.
/// Long-press a cover to unfollow. (Later: tap a game for its page and notification settings.)
struct MyGamesView: View {
    @Environment(FollowStore.self) private var follows
    @State private var query = ""
    @FocusState private var searchFocused: Bool

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    var body: some View {
        NavigationStack {
            Group {
                if !query.isEmpty {
                    GameSearchResults(query: query)
                } else if follows.games.isEmpty {
                    emptyState
                } else {
                    grid
                }
            }
            .navigationTitle("My Games")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $query,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Add a game"
            )
            .searchFocused($searchFocused)
        }
    }

    private var grid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                // Newest follows first.
                ForEach(follows.games.reversed()) { game in
                    BoxArt(game: game)
                        .contextMenu {
                            Button("Unfollow \(game.name)", systemImage: "star.slash", role: .destructive) {
                                withAnimation { follows.toggle(game) }
                            }
                        }
                }
            }
            .padding(16)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No games yet", systemImage: "gamecontroller")
        } description: {
            Text("Add the games you play on any platform (Nintendo, PlayStation, Xbox or PC) to see their news here.")
        } actions: {
            Button("Add Games") { searchFocused = true }
                .buttonStyle(.borderedProminent)
        }
    }
}

#Preview {
    MyGamesView()
        .environment(FollowStore())
}
