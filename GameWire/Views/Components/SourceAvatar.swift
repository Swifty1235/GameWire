import SwiftUI

/// Small rounded icon for a post's source: the outlet's logo or the game's Steam icon,
/// falling back to a colored letter when there's no logo.
struct SourceAvatar: View {
    let item: NewsItem
    var size: CGFloat = 26

    var body: some View {
        logo
            .frame(width: size, height: size)
            .clipShape(.rect(cornerRadius: size * 0.25))
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.25)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
            )
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var logo: some View {
        if let asset = item.logoAsset {
            Image(asset)
                .resizable()
                .scaledToFit()
                .background(.white)
        } else if let url = item.logoURL {
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    letter
                }
            }
        } else {
            letter
        }
    }

    private var letter: some View {
        LinearGradient(colors: item.avatarColors, startPoint: .topLeading, endPoint: .bottomTrailing)
            .overlay {
                Text(item.displayName.prefix(1))
                    .font(.system(size: size * 0.48, weight: .bold))
                    .foregroundStyle(.white)
            }
    }
}

/// Play button drawn over video thumbnails.
struct PlayOverlay: View {
    var body: some View {
        Image(systemName: "play.fill")
            .font(.title2)
            .foregroundStyle(.white)
            .frame(width: 56, height: 56)
            .background(.black.opacity(0.5), in: .circle)
    }
}
