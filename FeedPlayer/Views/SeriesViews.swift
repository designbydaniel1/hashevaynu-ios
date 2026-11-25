import SwiftUI

struct SeriesListView: View {
    @Environment(FeedStore.self) private var feed
    @Environment(PlaylistStore.self) private var playlists

    var body: some View {
        // Real SoundCloud playlists once synced; grouping by title until then.
        let series = playlists.playlists.isEmpty
            ? SeriesCatalog.build(from: feed.podcast?.episodes ?? [])
            : playlists.playlists
        NavigationStack {
            List(series) { s in
                NavigationLink(value: s) {
                    HStack(spacing: 14) {
                        if let art = s.artworkURL {
                            Artwork(url: art, size: 56)
                        } else {
                            Image(systemName: s.symbol)
                                .font(.title2)
                                .foregroundStyle(Color.accentColor)
                                .frame(width: 56, height: 56)
                                .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(s.name).font(.headline)
                            Text(s.subtitle).font(.subheadline).foregroundStyle(.secondary)
                            Text("\(s.episodes.count) shiurim").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Series")
            .navigationDestination(for: Series.self) { SeriesDetailView(series: $0) }
            .overlay {
                if series.isEmpty && feed.isLoading { ProgressView() }
            }
            .withMiniPlayer()
        }
    }
}

struct SeriesDetailView: View {
    let series: Series
    @State private var oldestFirst = false

    var body: some View {
        let eps = oldestFirst ? Array(series.episodes.reversed()) : series.episodes
        List(eps) { EpisodeRow(episode: $0) }
            .listStyle(.plain)
            .navigationTitle(series.name)
            .toolbar {
                Menu {
                    Picker("Order", selection: $oldestFirst) {
                        Text("Newest first").tag(false)
                        Text("Oldest first").tag(true)
                    }
                } label: { Image(systemName: "arrow.up.arrow.down") }
            }
    }
}
