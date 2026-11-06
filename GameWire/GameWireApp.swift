import SwiftUI

@main
struct GameWireApp: App {
    @State private var follows = FollowStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(follows)
        }
    }
}
