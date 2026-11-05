import SwiftUI

/// Small round icon for a post's source (game / outlet / creator).
/// Uses the first letter for now; later this becomes the real game icon or outlet logo.
struct SourceAvatar: View {
    let item: NewsItem
    var size: CGFloat = 26

    var body: some View {
        Circle()
            .fill(LinearGradient(colors: item.avatarColors, startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: size, height: size)
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
