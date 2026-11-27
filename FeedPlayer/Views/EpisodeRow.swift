import SwiftUI

struct EpisodeRow: View {
    let episode: Episode
    @Environment(AudioPlayer.self) private var player
    @Environment(Library.self) private var library
    @Environment(ToastCenter.self) private var toasts

    private func toggleSaved() {
        library.toggleSaved(episode)
        let saved = library.isSaved(episode)
        toasts.show(saved ? "Saved for later" : "Removed from Saved",
                    symbol: saved ? "bookmark.fill" : "bookmark.slash")
    }

    private var isCurrent: Bool { player.current?.id == episode.id }

    var body: some View {
        Button { player.play(episode) } label: { content }
            .buttonStyle(.plain)
            .swipeActions(edge: .trailing) {
                Button { toggleSaved() } label: {
                    library.isSaved(episode)
                        ? Label("Unsave", systemImage: "bookmark.slash")
                        : Label("Save", systemImage: "bookmark")
                }
                .tint(.orange)
            }
            .swipeActions(edge: .leading) {
                if let link = episode.link {
                    ShareLink(item: link, subject: Text(episode.title), message: Text(episode.title)) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    .tint(.blue)
                }
            }
            .contextMenu {
                Button { player.play(episode) } label: { Label("Play", systemImage: "play") }
                Button { toggleSaved() } label: {
                    library.isSaved(episode)
                        ? Label("Remove from Saved", systemImage: "bookmark.slash")
                        : Label("Save for Later", systemImage: "bookmark")
                }
                if let link = episode.link {
                    ShareLink(item: link, subject: Text(episode.title), message: Text(episode.title)) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                }
                let done = library.progress(for: episode) == 1
                Button { library.markFinished(episode, !done) } label: {
                    done ? Label("Mark as Unplayed", systemImage: "circle")
                         : Label("Mark as Played", systemImage: "checkmark.circle")
                }
            }
    }

    private var content: some View {
        HStack(spacing: 12) {
            Artwork(url: episode.imageURL, size: 56, badge: episode.badge, tint: episode.tint)
            VStack(alignment: .leading, spacing: 4) {
                Text(episode.title)
                    .font(.headline)
                    .foregroundStyle(isCurrent ? Color.appBlue : .primary)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    if let d = episode.pubDate { Text(d, style: .date) }
                    if let dur = episode.duration { Text("· \(dur.clock)") }
                    if library.isSaved(episode) {
                        Image(systemName: "bookmark.fill").foregroundStyle(.orange)
                            .transition(.iconSwap)
                    }
                }
                .font(.caption).foregroundStyle(.secondary)
                .motion(Motion.iconSwap, value: library.isSaved(episode))
                progressBar
                    .motion(Motion.check, value: library.progress(for: episode) == 1)
            }
            Spacer()
            SwapIcon(name: isCurrent && player.isPlaying ? "waveform" : "play.circle")
                .font(.title2)
                .foregroundStyle(Color.appBlue)
                .symbolEffect(.variableColor.iterative, isActive: isCurrent && player.isPlaying)
        }
        .contentShape(Rectangle())
        .padding(.vertical, 4)
    }

    @ViewBuilder private var progressBar: some View {
        if let p = library.progress(for: episode) {
            if p >= 1 {
                Label("Played", systemImage: "checkmark.circle.fill")
                    .font(.caption2).foregroundStyle(.secondary)
                    .transition(.successCheck)
            } else {
                ProgressView(value: p).tint(Color.appBlue).frame(maxWidth: 120)
            }
        }
    }
}

struct Artwork: View {
    let url: URL?
    let size: CGFloat
    /// Designed tile shown when there is no artwork.
    var badge: String? = nil
    var tint: String? = nil

    var body: some View {
        AsyncImage(url: url) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            if let badge, url == nil {
                ZStack {
                    Color(hex: tint) ?? Color.appBlue
                    Text(badge).font(.system(size: size * 0.32, weight: .heavy)).foregroundStyle(.white)
                }
            } else {
                ZStack {
                    Color.secondary.opacity(0.2)
                    Image(systemName: "music.note").foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.12))
    }
}
