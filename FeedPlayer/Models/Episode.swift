import Foundation

struct Episode: Identifiable, Hashable, Codable {
    var id: String { guid.isEmpty ? audioURL.absoluteString : guid }
    var guid: String
    var title: String
    var summary: String
    var pubDate: Date?
    var duration: TimeInterval?
    var audioURL: URL
    var imageURL: URL?
    /// The track's page on SoundCloud — this is what gets shared.
    var link: URL?
    /// Designed-tile text and colour (hex) for shiurim whose playlist has no artwork.
    var badge: String? = nil
    var tint: String? = nil
}

struct Podcast: Codable {
    var title: String
    var author: String
    var imageURL: URL?
    var episodes: [Episode]
}
