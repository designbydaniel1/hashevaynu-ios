import SwiftUI

struct LatestView: View {
    @Environment(FeedStore.self) private var feed
    @Environment(PlaylistStore.self) private var playlists
    @Environment(AppNavigation.self) private var nav
    @State private var search = ""

    /// The home feed covers the last 30 days; older shiurim live in Series.
    private var episodes: [Episode] {
        let all = feed.podcast?.episodes ?? []
        guard !search.isEmpty else {
            let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .distantPast
            return all.filter { ($0.pubDate ?? .now) >= cutoff }
        }
        return all.filter { $0.title.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        NavigationStack {
            List {
                if let p = feed.podcast, search.isEmpty {
                    header(p).listRowSeparator(.hidden)
                }
                ForEach(episodes) { EpisodeRow(episode: $0) }
                if search.isEmpty && !episodes.isEmpty {
                    caughtUp.listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .navigationTitle("Hashevaynu")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $search, prompt: "Search shiurim")
            // Pull down to check for new shiurim and playlists right away.
            .refreshable {
                async let shiurim: Void = feed.refresh()
                async let lists: Void = playlists.refresh()
                _ = await (shiurim, lists)
            }
            .overlay {
                if feed.podcast == nil {
                    if feed.isLoading {
                        List(0..<8, id: \.self) { _ in SkeletonRow() }
                            .listStyle(.plain)
                            .scrollDisabled(true)
                            .transition(.reveal)
                    } else if let err = feed.errorMessage {
                        ContentUnavailableView {
                            Label("Couldn't load shiurim", systemImage: "wifi.exclamationmark")
                        } description: { Text(err) } actions: {
                            Button("Retry") { Task { await feed.refresh() } }
                        }
                    }
                }
            }
            .motion(Motion.reveal, value: feed.podcast == nil)
            .withMiniPlayer()
        }
    }

    /// Shown at the end of the 30-day feed: points listeners to the full archive.
    private var caughtUp: some View {
        let total = playlists.playlists.reduce(0) { $0 + $1.episodes.count }
        return VStack(spacing: 8) {
            Image(systemName: "square.stack.fill")
                .font(.title2).foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(Color.accentColor, in: Circle())
            Text("You’re all caught up").font(.headline)
            Text(playlists.playlists.isEmpty
                 ? "That’s everything from the last 30 days. Browse every playlist for older shiurim."
                 : "That’s everything from the last 30 days. Browse \(playlists.playlists.count) playlists with \(total.formatted()) shiurim.")
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button("Browse all series") { nav.tab = .series }
                .buttonStyle(.borderedProminent).padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 20))
        .padding(.vertical, 16)
    }

    private func header(_ p: Podcast) -> some View {
        HStack(spacing: 16) {
            Artwork(url: p.imageURL, size: 96)
            VStack(alignment: .leading, spacing: 4) {
                Text(p.title).font(.title2.bold())
                if !p.author.isEmpty { Text(p.author).foregroundStyle(.secondary) }
                // Live totals from the synced SoundCloud playlists.
                Text(playlists.playlists.isEmpty
                     ? "\(p.episodes.count) shiurim"
                     : "\(playlists.playlists.count) playlists · \(playlists.playlists.reduce(0) { $0 + $1.episodes.count }.formatted()) shiurim")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}
