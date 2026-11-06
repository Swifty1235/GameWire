import SwiftUI

/// A game's tall box art. Shows the game's name on a colored tile while loading or when there's no art.
struct BoxArt: View {
    let game: Game
    var cornerRadius: CGFloat = 8

    var body: some View {
        Color(.secondarySystemBackground)
            .aspectRatio(0.7, contentMode: .fit)
            .overlay {
                AsyncImage(url: game.coverURL) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else if phase.error != nil || game.coverURL == nil {
                        placeholder
                    }
                }
            }
            .clipShape(.rect(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
            )
            .accessibilityLabel(game.name)
    }

    private var placeholder: some View {
        LinearGradient(colors: Artwork.colors(for: game.name), startPoint: .topLeading, endPoint: .bottomTrailing)
            .overlay {
                Text(game.name)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(4)
            }
    }
}

/// "Follow" / "Following" capsule used wherever games are listed.
struct FollowButton: View {
    let game: Game
    @Environment(FollowStore.self) private var follows

    var body: some View {
        let following = follows.isFollowing(game)
        Button {
            follows.toggle(game)
        } label: {
            Text(following ? "Following" : "Follow")
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
        }
        .fixedSize()
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .controlSize(.small)
        .tint(following ? .secondary : Theme.accent)
        .accessibilityLabel(following ? "Unfollow \(game.name)" : "Follow \(game.name)")
    }
}

/// One game in a list: small box art, name, year · platforms, Follow button.
struct GameRow: View {
    let game: Game

    var body: some View {
        HStack(spacing: 12) {
            BoxArt(game: game, cornerRadius: 5)
                .frame(width: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(game.name)
                    .font(.body.weight(.medium))
                    .lineLimit(2)
                if !game.detailLine.isEmpty {
                    Text(game.detailLine)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            FollowButton(game: game)
        }
        .padding(.vertical, 2)
    }
}
