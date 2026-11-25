import SwiftUI

struct LatestView: View {
    @Environment(FeedStore.self) private var feed
    @Environment(PlaylistStore.self) private var playlists
    @State private var search = ""

    private var episodes: [Episode] {
        let all = feed.podcast?.episodes ?? []
        guard !search.isEmpty else { return all }
        return all.filter { $0.title.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        NavigationStack {
            List {
                if let p = feed.podcast, search.isEmpty {
                    header(p).listRowSeparator(.hidden)
                }
                ForEach(episodes) { EpisodeRow(episode: $0) }
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

    private func header(_ p: Podcast) -> some View {
        HStack(spacing: 16) {
            Artwork(url: p.imageURL, size: 96)
            VStack(alignment: .leading, spacing: 4) {
                Text(p.title).font(.title2.bold())
                if !p.author.isEmpty { Text(p.author).foregroundStyle(.secondary) }
                Text("\(p.episodes.count) shiurim").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}
