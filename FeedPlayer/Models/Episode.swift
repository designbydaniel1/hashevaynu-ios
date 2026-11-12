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
}

struct Podcast: Codable {
    var title: String
    var author: String
    var imageURL: URL?
    var episodes: [Episode]
}
