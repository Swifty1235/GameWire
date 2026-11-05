import SwiftUI

/// Gradient + big faded icon, standing in for real game art in the draft.
struct ArtworkView: View {
    let artwork: Artwork

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            ZStack {
                LinearGradient(
                    colors: artwork.colors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Image(systemName: artwork.symbol)
                    .font(.system(size: side * 0.55, weight: .bold))
                    .foregroundStyle(.white.opacity(0.16))
                    .rotationEffect(.degrees(-12))
                    .offset(x: geo.size.width * 0.18, y: -geo.size.height * 0.08)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .clipped()
    }
}

#Preview {
    ArtworkView(artwork: SampleData.feed[0].artwork!)
        .frame(width: 300, height: 200)
}
