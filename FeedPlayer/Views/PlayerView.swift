import SwiftUI

struct PlayerView: View {
    @Environment(AudioPlayer.self) private var player
    @Environment(Library.self) private var library
    @Environment(ToastCenter.self) private var toasts
    @State private var appeared = false
    private let rates: [Float] = [0.75, 1.0, 1.25, 1.5, 2.0]

    var body: some View {
        @Bindable var player = player
        if let ep = player.current {
            ScrollView {
                VStack(spacing: 24) {
                    Capsule().fill(.secondary).frame(width: 40, height: 5).padding(.top, 8)

                    Artwork(url: ep.imageURL, size: 280)
                        .shadow(radius: 12)
                        .scaleEffect(player.isPlaying ? 1 : 0.9)
                        .animation(.spring, value: player.isPlaying)

                    VStack(spacing: 6) {
                        Text(ep.title).font(.title3.bold()).multilineTextAlignment(.center)
                        if let d = ep.pubDate {
                            Text(d, style: .date).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }

                    VStack(spacing: 4) {
                        Slider(value: $player.currentTime,
                               in: 0...max(player.duration, 1),
                               onEditingChanged: { player.setScrubbing($0) })
                        HStack {
                            Text(player.currentTime.clock)
                            Spacer()
                            if player.isBuffering { ProgressView().controlSize(.mini) }
                            Spacer()
                            Text("-" + max(0, player.duration - player.currentTime).clock)
                        }
                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    }

                    HStack(spacing: 48) {
                        Button { player.skip(by: -15) } label: {
                            Image(systemName: "gobackward.15").font(.system(size: 32))
                        }
                        Button { player.togglePlayPause() } label: {
                            SwapIcon(name: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 72))
                        }
                        Button { player.skip(by: 30) } label: {
                            Image(systemName: "goforward.30").font(.system(size: 32))
                        }
                    }

                    HStack(spacing: 28) {
                    SaveButton(isSaved: library.isSaved(ep)) {
                        library.toggleSaved(ep)
                        toasts.show(library.isSaved(ep) ? "Saved for later" : "Removed from Saved",
                                    symbol: library.isSaved(ep) ? "bookmark.fill" : "bookmark.slash")
                    }
                    .font(.title3)

                    Menu {
                        ForEach(rates, id: \.self) { r in
                            Button { player.rate = r } label: {
                                if r == player.rate { Label(rateLabel(r), systemImage: "checkmark") }
                                else { Text(rateLabel(r)) }
                            }
                        }
                    } label: {
                        SwapText(rateLabel(player.rate))
                            .font(.subheadline.bold())
                            .padding(.horizontal, 14).padding(.vertical, 6)
                            .background(.secondary.opacity(0.15), in: Capsule())
                    }

                    if let link = ep.link {
                        ShareLink(item: link, subject: Text(ep.title), message: Text(ep.title)) {
                            Image(systemName: "square.and.arrow.up").font(.title3)
                        }
                    }
                    }

                    if !ep.summary.isEmpty {
                        Text(ep.summary)
                            .font(.body).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
                .scaleEffect(appeared ? 1 : 0.96)
                .opacity(appeared ? 1 : 0)
                .motion(Motion.modalOpen, value: appeared)
                .onAppear { appeared = true }
            }
            .presentationDragIndicator(.hidden)
        }
    }

    private func rateLabel(_ r: Float) -> String {
        r == r.rounded() ? "\(Int(r))×" : "\(r.formatted())×"
    }
}
