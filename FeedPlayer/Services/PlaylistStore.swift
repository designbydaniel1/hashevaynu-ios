import Foundation
import Observation

/// Loads the real SoundCloud playlists that the daily GitHub Action publishes
/// to data/playlists.json in this repository.
struct PlaylistSection: Identifiable {
    let id: String
    let title: String
    let playlists: [Series]
}

@MainActor @Observable
final class PlaylistStore {
    static let url = URL(string: "https://raw.githubusercontent.com/designbydaniel1/hashevaynu-ios/main/data/playlists.json")!

    private(set) var playlists: [Series] = []
    /// Sections for the Series tab, in order, each with its playlists.
    private(set) var sections: [PlaylistSection] = []

    private let cacheURL = FileManager.default
        .urls(for: .cachesDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("playlists.json")

    init() {
        if let data = try? Data(contentsOf: cacheURL) { apply(Self.decode(data)) }
    }

    func refresh() async {
        guard let (data, response) = try? await URLSession.shared.data(from: Self.url),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return }
        let decoded = Self.decode(data)
        guard !decoded.playlists.isEmpty else { return }
        apply(decoded)
        try? data.write(to: cacheURL)
    }

    private func apply(_ d: (playlists: [Series], categories: [(String, String)])) {
        playlists = d.playlists
        sections = d.categories.compactMap { id, title in
            let items = d.playlists.filter { $0.category == id }
            return items.isEmpty ? nil : PlaylistSection(id: id, title: title, playlists: items)
        }
    }

    // MARK: JSON shape written by scripts/sync_playlists.py

    private struct File: Decodable { let categories: [Category]?; let playlists: [Playlist] }
    private struct Category: Decodable { let id: String, title: String }
    private struct Playlist: Decodable {
        let id: String, title: String, link: URL?, artwork: URL?, trackCount: Int?
        let category: String?, short: String?, badge: String?, color: String?, created: String?
        let tracks: [Track]
    }
    private struct Track: Decodable {
        let id: String, title: String, link: URL?, date: String?, duration: Double?, audio: URL?, artwork: URL?
    }

    private static let dateFormat: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static func decode(_ data: Data) -> (playlists: [Series], categories: [(String, String)]) {
        guard let file = try? JSONDecoder().decode(File.self, from: data) else { return ([], []) }
        let categories = (file.categories ?? []).map { ($0.id, $0.title) }
        let playlists: [Series] = file.playlists.compactMap { p in
            let episodes = p.tracks.compactMap { t -> Episode? in
                guard let audio = t.audio else { return nil }
                return Episode(
                    // Same id format as the RSS feed, so saved shiurim and resume positions match.
                    guid: "tag:soundcloud,2010:tracks/\(t.id)",
                    title: t.title, summary: "",
                    pubDate: t.date.flatMap(dateFormat.date(from:)),
                    duration: t.duration, audioURL: audio,
                    imageURL: t.artwork ?? p.artwork, link: t.link,
                    badge: p.badge, tint: p.color)
            }
            guard !episodes.isEmpty else { return nil }
            let count = p.trackCount ?? episodes.count
            return Series(name: p.title, subtitle: "\(count) shiurim", symbol: "music.note.list",
                          episodes: episodes, artworkURL: p.artwork,
                          category: p.category ?? "more", badge: p.badge ?? "", tint: p.color,
                          shortName: p.short ?? p.title, created: p.created ?? "")
        }
        return (playlists, categories.isEmpty ? [("more", "Playlists")] : categories)
    }
}
