import SwiftUI

struct SeriesListView: View {
    @Environment(FeedStore.self) private var feed
    @Environment(PlaylistStore.self) private var playlists

    var body: some View {
        NavigationStack {
            ScrollView {
                if playlists.sections.isEmpty {
                    // Until the first playlist sync arrives: group the feed by title.
                    fallback
                } else {
                    LazyVStack(alignment: .leading, spacing: 26) {
                        SectionRow(title: "Featured", items: featured, large: true)
                        // Daf Yomi masechtos live on the Daf tab.
                        ForEach(playlists.sections.filter { $0.id != "daf" }) { section in
                            SectionRow(title: section.title, items: section.playlists)
                        }
                        SpeakersRow(playlists: playlists.playlists)
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Series")
            .navigationDestination(for: Series.self) { SeriesDetailView(series: $0) }
            .navigationDestination(for: SeriesSection.self) { SeriesSectionView(section: $0) }
            .refreshable { await playlists.refresh() }
            .withMiniPlayer()
        }
    }

    /// The 5 most recently published playlists, not counting Daf Yomi.
    private var featured: [Series] {
        Array(playlists.playlists.filter { $0.category != "daf" }.sorted { $0.created > $1.created }.prefix(5))
    }

    private var fallback: some View {
        let series = SeriesCatalog.build(from: feed.podcast?.episodes ?? [])
        return LazyVStack(spacing: 0) {
            ForEach(series) { s in
                NavigationLink(value: s) {
                    HStack(spacing: 14) {
                        PlaylistTile(series: s, size: 56)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(s.name).font(.headline)
                            Text("\(s.episodes.count) shiurim").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal).padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
        }
        .overlay { if series.isEmpty && feed.isLoading { ProgressView() } }
    }
}

/// Identifies a whole section for its "See all" screen.
struct SeriesSection: Hashable {
    let title: String
    let items: [Series]
}

/// A section header with a horizontal row of playlist tiles.
private struct SectionRow: View {
    let title: String
    let items: [Series]
    var large = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.title3.bold())
                Text("\(items.count)").font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                if items.count > 3 && !large {
                    NavigationLink("See all", value: SeriesSection(title: title, items: items))
                        .font(.subheadline.weight(.semibold))
                }
            }
            .padding(.horizontal)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 12) {
                    ForEach(items) { s in
                        NavigationLink(value: s) { PlaylistCard(series: s, width: large ? 220 : 140) }.buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

/// Speakers with their photos; each opens their own page.
private struct SpeakersRow: View {
    let playlists: [Series]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("By speaker").font(.title3.bold()).padding(.horizontal)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 18) {
                    ForEach(Speaker.all) { sp in
                        NavigationLink { SpeakerView(speaker: sp) } label: {
                            VStack(spacing: 8) {
                                AsyncImage(url: sp.photo) { $0.resizable().scaledToFill() } placeholder: { Color.secondary.opacity(0.2) }
                                    .frame(width: 88, height: 88)
                                    .clipShape(Circle())
                                Text(sp.name).font(.caption.weight(.semibold)).multilineTextAlignment(.center).frame(width: 96)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

/// All playlists in one section, as a two-column grid.
struct SeriesSectionView: View {
    let section: SeriesSection
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 16) {
                ForEach(section.items) { s in
                    NavigationLink(value: s) { PlaylistCard(series: s, width: nil) }.buttonStyle(.plain)
                }
            }
            .padding()
        }
        .navigationTitle(section.title)
        .appBackground()
    }
}

private struct PlaylistCard: View {
    let series: Series
    var width: CGFloat? = 140

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            PlaylistTile(series: series, size: width)
            Text(series.shortName.isEmpty ? series.name : series.shortName)
                .font(.subheadline.weight(.semibold)).lineLimit(2)
            Text(series.subtitle).font(.caption).foregroundStyle(.secondary)
        }
        .frame(width: width, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// Playlist artwork, or a designed tile with the masechta number or initials.
struct PlaylistTile: View {
    let series: Series
    var size: CGFloat?

    var body: some View {
        Group {
            if let art = series.artworkURL {
                AsyncImage(url: art) { $0.resizable().scaledToFill() } placeholder: { designed }
            } else {
                designed
            }
        }
        .frame(width: size, height: size)
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var designed: some View {
        let tint = Color(hex: series.tint) ?? .accentColor
        return ZStack(alignment: .bottomLeading) {
            tint
            VStack(alignment: .leading, spacing: 2) {
                Text(series.badge.isEmpty ? "HS" : series.badge)
                    .font(.system(size: series.category == "daf" ? 34 : 22, weight: .heavy))
                if series.category == "daf" {
                    Text(series.shortName).font(.subheadline.weight(.bold)).lineLimit(1).minimumScaleFactor(0.7)
                }
            }
            .foregroundStyle(.white)
            .padding(12)
        }
    }
}

struct SeriesDetailView: View {
    let series: Series
    @State private var oldestFirst = false

    var body: some View {
        let eps = oldestFirst ? Array(series.episodes.reversed()) : series.episodes
        List(eps) { EpisodeRow(episode: $0).listRowBackground(Color.clear) }
            .listStyle(.plain)
            .appBackground()
            .navigationTitle(series.shortName.isEmpty ? series.name : series.shortName)
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

extension Color {
    /// "#1D4E89" -> Color
    init?(hex: String?) {
        guard let hex, hex.hasPrefix("#"), hex.count == 7, let v = UInt32(hex.dropFirst(), radix: 16) else { return nil }
        self.init(red: Double((v >> 16) & 255) / 255, green: Double((v >> 8) & 255) / 255, blue: Double(v & 255) / 255)
    }
}
