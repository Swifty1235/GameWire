import SwiftUI
import SafariServices

/// 16:9 image loaded from the web, with a gray placeholder while loading or if it fails.
struct RemoteImage: View {
    let url: URL

    var body: some View {
        Color(.secondarySystemBackground)
            .aspectRatio(16 / 9, contentMode: .fit)
            .overlay {
                AsyncImage(url: url, transaction: Transaction(animation: .easeOut(duration: 0.2))) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        Image(systemName: "photo")
                            .font(.title2)
                            .foregroundStyle(.tertiary)
                    default:
                        EmptyView()
                    }
                }
            }
            .clipped()
    }
}

/// A link to open in the in-app browser (Identifiable so it can drive a fullScreenCover).
struct WebLink: Identifiable {
    let url: URL
    var id: URL { url }
}

/// In-app Safari. Reader mode strips ads and clutter so articles read cleanly.
struct SafariView: UIViewControllerRepresentable {
    let url: URL
    var readerMode = true

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = readerMode
        return SFSafariViewController(url: url, configuration: config)
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}
