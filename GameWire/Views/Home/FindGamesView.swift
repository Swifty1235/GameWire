import SwiftUI

/// Sheet for following games from Home: search any platform, or pick a popular game.
struct FindGamesView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    var body: some View {
        NavigationStack {
            Group {
                if query.isEmpty {
                    List {
                        Section("Popular") {
                            ForEach(DefaultFollows.popularGames) { game in
                                GameRow(game: game)
                            }
                        }
                    }
                } else {
                    GameSearchResults(query: query)
                }
            }
            .navigationTitle("Find Games")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $query,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search any game"
            )
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    FindGamesView()
        .environment(FollowStore())
}
