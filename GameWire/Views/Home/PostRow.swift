import SwiftUI

/// One post in the Home feed, Reddit-style:
/// source line → type label → title → image → Save / Share.
struct PostRow: View {
    let item: NewsItem
    let isSaved: Bool
    let onToggleSave: () -> Void
    let onHideSource: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Label(item.kindLine, systemImage: item.kind.systemImage)
                    // Teaser-only posts open the website, so say where.
                    if !item.hasFullText, let site = item.siteName {
                        Text("· \(site)")
                        Image(systemName: "arrow.up.right")
                            .imageScale(.small)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                Text(item.title)
                    .font(.headline)
                    .multilineTextAlignment(.leading)
            }

            PostImage(item: item)

            actions
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 6)
    }

    private var header: some View {
        HStack(spacing: 8) {
            SourceAvatar(item: item)
            HStack(spacing: 4) {
                Text(item.displayName)
                    .font(.subheadline.weight(.semibold))
                Text("· " + item.subtitleLine)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)
            Spacer(minLength: 0)
            Menu {
                Button("Hide posts from \(item.displayName)", systemImage: "eye.slash", action: onHideSource)
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
                    .contentShape(.rect)
            }
            .tint(.secondary)
            .accessibilityLabel("More")
        }
    }

    private var actions: some View {
        HStack(spacing: 24) {
            Button(action: onToggleSave) {
                Label(isSaved ? "Saved" : "Save", systemImage: isSaved ? "bookmark.fill" : "bookmark")
                    .foregroundStyle(isSaved ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(.secondary))
            }
            if let url = item.url {
                ShareLink(item: url) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            }
            Spacer()
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .buttonStyle(.plain)
        .frame(minHeight: 36)
    }
}

/// The post's picture: the real image if the feed has one, placeholder art for sample data,
/// or nothing (text-only post).
struct PostImage: View {
    let item: NewsItem

    var body: some View {
        Group {
            if let url = item.imageURL {
                RemoteImage(url: url)
            } else if let artwork = item.artwork {
                ArtworkView(artwork: artwork)
                    .aspectRatio(16 / 9, contentMode: .fit)
            }
        }
        .overlay {
            if item.kind == .video { PlayOverlay() }
        }
        .clipShape(.rect(cornerRadius: 12))
    }
}

#Preview {
    PostRow(item: SampleData.feed[0], isSaved: false, onToggleSave: {}, onHideSource: {})
}
