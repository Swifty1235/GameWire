import SwiftUI

/// One post in the Home feed, Reddit-style:
/// source line → type label → title → image → Save / Share.
struct PostRow: View {
    let item: NewsItem
    let isSaved: Bool
    let onToggleSave: () -> Void
    let onHideSource: () -> Void
    /// Whether you follow this post's game; nil when it isn't a game's own post (outlet news).
    var isFollowingGame: Bool? = nil
    var onToggleFollow: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            VStack(alignment: .leading, spacing: 4) {
                Label(item.kindLine, systemImage: item.kind.systemImage)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.accent)
                Text(item.title)
                    .font(.headline)
                    .multilineTextAlignment(.leading)
            }

            // Teaser-only posts open the website, so they look like a link preview.
            if !item.hasFullText, item.url != nil {
                LinkPreviewCard(item: item)
            } else {
                PostImage(item: item)
            }

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
                if let following = isFollowingGame, let game = item.game {
                    Button(
                        following ? "Unfollow \(game)" : "Follow \(game)",
                        systemImage: following ? "star.slash" : "star",
                        action: onToggleFollow
                    )
                }
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

/// How posts that open a website look in the feed: the image joined to a bar showing the
/// site's address, like a link preview in Messages.
struct LinkPreviewCard: View {
    let item: NewsItem

    var body: some View {
        VStack(spacing: 0) {
            if let url = item.imageURL {
                RemoteImage(url: url)
                    .overlay(alignment: .topTrailing) {
                        // "Web" badge on the image, so it's clear before tapping that this opens the site.
                        Label("Web", systemImage: "safari")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.black.opacity(0.6), in: .capsule)
                            .padding(10)
                    }
            }
            HStack(spacing: 8) {
                Image(systemName: "safari")
                    .foregroundStyle(.secondary)
                Text(item.siteName ?? item.source)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.secondarySystemBackground))
        }
        .clipShape(.rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
        )
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens \(item.siteName ?? item.source) in the browser")
    }
}

#Preview {
    PostRow(item: SampleData.feed[0], isSaved: false, onToggleSave: {}, onHideSource: {})
}
