import SwiftUI

struct MiniPlayerView: View {
    @Environment(AudioPlayer.self) private var player

    var body: some View {
        if let ep = player.current {
            VStack(spacing: 0) {
                ProgressView(value: player.duration > 0 ? player.currentTime / player.duration : 0)
                    .tint(.accentColor)
                HStack(spacing: 12) {
                    Artwork(url: ep.imageURL, size: 44)
                    SwapText(ep.title).font(.subheadline.weight(.semibold)).lineLimit(1)
                    Spacer()
                    Button { player.togglePlayPause() } label: {
                        SwapIcon(name: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title2).frame(width: 44, height: 44)
                    }
                    Button { player.skip(by: 30) } label: {
                        Image(systemName: "goforward.30").font(.title3).frame(width: 44, height: 44)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .background(.regularMaterial)
            .contentShape(Rectangle())
        }
    }
}
