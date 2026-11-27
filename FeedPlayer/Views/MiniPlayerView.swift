import SwiftUI

struct MiniPlayerView: View {
    enum Style { case floating, accessory }
    var style: Style = .floating
    @Environment(AudioPlayer.self) private var player

    var body: some View {
        if let ep = player.current {
            let progress = player.duration > 0 ? player.currentTime / player.duration : 0
            HStack(spacing: 10) {
                Artwork(url: ep.imageURL, size: style == .accessory ? 32 : 42)
                SwapText(ep.title).font(.subheadline.weight(.semibold)).lineLimit(1)
                Spacer(minLength: 4)
                Button { player.togglePlayPause() } label: {
                    SwapIcon(name: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title3).frame(width: 40, height: 40)
                }
                .accessibilityLabel(player.isPlaying ? "Pause" : "Play")
                Button { player.skip(by: 30) } label: {
                    Image(systemName: "goforward.30").font(.body.weight(.semibold)).frame(width: 40, height: 40)
                }
                .accessibilityLabel("Skip forward 30 seconds")
            }
            .foregroundStyle(.primary)
            .padding(.leading, style == .accessory ? 10 : 9)
            .padding(.trailing, 6)
            .padding(.vertical, style == .accessory ? 0 : 8)
            .overlay(alignment: .bottom) {
                // Thin progress line along the bottom edge.
                GeometryReader { g in
                    Capsule().fill(Color.appBlue)
                        .frame(width: max(0, (g.size.width - 44) * progress), height: 2.5)
                        .offset(x: 22, y: g.size.height - 2.5)
                }
                .allowsHitTesting(false)
            }
            .modifier(FloatingGlass(enabled: style == .floating))
            .contentShape(Capsule())
        }
    }
}

/// Before iOS 26 the mini player floats as its own glass capsule above the tab bar.
private struct FloatingGlass: ViewModifier {
    let enabled: Bool
    func body(content: Content) -> some View {
        if enabled {
            content.glass(in: Capsule()).padding(.horizontal, 12).padding(.bottom, 6)
        } else {
            content
        }
    }
}
