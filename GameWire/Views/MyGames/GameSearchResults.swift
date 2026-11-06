import SwiftUI

/// Search results for a typed query, with a Follow button on each game. Waits until you stop typing
/// for a moment before searching, so every letter doesn't send a request.
struct GameSearchResults: View {
    let query: String

    @State private var results: [Game] = []
    @State private var isSearching = false
    @State private var failure: GameSearch.SearchError?

    var body: some View {
        List {
            Section {
                ForEach(results) { game in
                    GameRow(game: game)
                }
            } footer: {
                if !results.isEmpty {
                    // IGDB's terms ask apps to credit them.
                    Text("Game data from IGDB.com")
                }
            }
        }
        .overlay {
            if isSearching && results.isEmpty {
                ProgressView()
            } else if failure == .notSetUp {
                ContentUnavailableView(
                    "Search isn't set up yet",
                    systemImage: "wrench.and.screwdriver",
                    description: Text("Add the Supabase project URL and key in SupabaseConfig.")
                )
            } else if failure == .unavailable {
                ContentUnavailableView(
                    "Search is unavailable",
                    systemImage: "wifi.exclamationmark",
                    description: Text("Check your connection and try again.")
                )
            } else if !isSearching && results.isEmpty && query.count >= 2 {
                ContentUnavailableView.search(text: query)
            }
        }
        .task(id: query) {
            await search()
        }
    }

    private func search() async {
        let text = query.trimmingCharacters(in: .whitespaces)
        guard text.count >= 2 else {
            results = []
            isSearching = false
            return
        }
        isSearching = true
        failure = nil
        // Typing another letter cancels this task, so only the last pause actually searches.
        try? await Task.sleep(for: .milliseconds(350))
        guard !Task.isCancelled else { return }
        do {
            results = try await GameSearch.search(text)
            failure = nil
        } catch is CancellationError {
            return
        } catch let error as GameSearch.SearchError {
            failure = error
        } catch {
            // A newer search cancelled this request; it isn't a real failure.
            if (error as? URLError)?.code == .cancelled { return }
            failure = .unavailable
        }
        isSearching = false
    }
}
