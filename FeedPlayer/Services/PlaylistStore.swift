import Foundation
import Observation

/// Loads the real SoundCloud playlists that the daily GitHub Action publishes
/// to data/playlists.json in this repository.
@MainActor @Observable
final class PlaylistStore {
    static let url = URL(string: "https://raw.githubusercontent.com/designbydaniel1/hashevaynu-ios/main/data/playlists.json")!

    private(set) var playlists: [Series] = []

    private let cacheURL = FileManager.default
        .urls(for: .cachesDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("playlists.json")

    init() {
        if let data = try? Data(contentsOf: cacheURL) { playlists = Self.decode(data) }
    }

    func refresh() async {
        guard let (data, response) = try? await URLSession.shared.data(from: Self.url),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return }
        let decoded = Self.decode(data)
        guard !decoded.isEmpty else { return }
        playlists = decoded
        try? data.write(to: cacheURL)
    }

    // MARK: JSON shape written by scripts/sync_playlists.py

    private struct File: Decodable { let playlists: [Playlist] }
    private struct Playlist: Decodable {
        let id: String, title: String, link: URL?, artwork: URL?, trackCount: Int?
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

    private static func decode(_ data: Data) -> [Series] {
        guard let file = try? JSONDecoder().decode(File.self, from: data) else { return [] }
        return file.playlists.compactMap { p in
            let episodes = p.tracks.compactMap { t -> Episode? in
                guard let audio = t.audio else { return nil }
                return Episode(
                    // Same id format as the RSS feed, so saved shiurim and resume positions match.
                    guid: "tag:soundcloud,2010:tracks/\(t.id)",
                    title: t.title, summary: "",
                    pubDate: t.date.flatMap(dateFormat.date(from:)),
                    duration: t.duration, audioURL: audio,
                    imageURL: t.artwork ?? p.artwork, link: t.link)
            }
            guard !episodes.isEmpty else { return nil }
            let count = p.trackCount ?? episodes.count
            return Series(name: p.title, subtitle: "\(count) shiurim", symbol: "music.note.list",
                          episodes: episodes, artworkURL: p.artwork)
        }
    }
}
