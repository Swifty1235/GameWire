import Foundation

/// GameWire's Supabase project. Both values are public by design (they ship inside every app);
/// the IGDB/Twitch secret stays on the server (see supabase/functions/igdb-search).
enum SupabaseConfig {
    /// e.g. "https://abcdefgh.supabase.co"
    static let url = "https://rvxucodpumyiuqffbvwo.supabase.co"
    /// Project Settings → API → the public "anon" / "publishable" key.
    static let publicKey = "sb_publishable_BqiXrGc_p1Si_d0Z0rz6Vg_SYqJErXR"

    static var isSet: Bool { !url.isEmpty && !publicKey.isEmpty }
}

/// Searches every platform's games (Nintendo, PlayStation, Xbox, PC) through our Supabase function,
/// which asks IGDB. Results come with box art, platforms, and a Steam id when the game is on Steam.
enum GameSearch {
    enum SearchError: Error {
        case notSetUp, unavailable
    }

    private struct Result: Decodable {
        let igdbID: Int
        let name: String
        let coverImageID: String?
        let year: Int?
        let platforms: [String]
        let steamAppID: Int?
    }

    static func search(_ query: String) async throws -> [Game] {
        guard SupabaseConfig.isSet, let url = URL(string: SupabaseConfig.url + "/functions/v1/igdb-search") else {
            throw SearchError.notSetUp
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SupabaseConfig.publicKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(SupabaseConfig.publicKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(["q": query])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw SearchError.unavailable }
        return try JSONDecoder().decode([Result].self, from: data).map {
            Game(
                name: $0.name, igdbID: $0.igdbID, steamAppID: $0.steamAppID,
                coverImageID: $0.coverImageID, year: $0.year, platforms: $0.platforms
            )
        }
    }
}
