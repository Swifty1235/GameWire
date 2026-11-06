import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Home", systemImage: "house") {
                HomeView()
            }
            Tab("My Games", systemImage: "gamecontroller") {
                MyGamesView()
            }
            Tab("Releases", systemImage: "calendar") {
                ComingSoonView(title: "Releases", systemImage: "calendar")
            }
            Tab("Deals", systemImage: "tag") {
                ComingSoonView(title: "Free & Deals", systemImage: "tag")
            }
        }
        .tint(Theme.accent)
    }
}

struct ComingSoonView: View {
    let title: String
    let systemImage: String

    var body: some View {
        ContentUnavailableView(title, systemImage: systemImage, description: Text("Coming soon"))
    }
}

#Preview {
    ContentView()
        .environment(FollowStore())
}
