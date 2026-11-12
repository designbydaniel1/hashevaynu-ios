import Foundation

/// Parses a podcast-style RSS feed (the format SoundCloud publishes).
final class FeedParser: NSObject, XMLParserDelegate {
    private var podcast = Podcast(title: "", author: "", imageURL: nil, episodes: [])
    private var inItem = false
    private var text = ""
    private var item: [String: String] = [:]
    private var itemAudio: URL?
    private var itemImage: URL?

    static func parse(_ data: Data) throws -> Podcast {
        let delegate = FeedParser()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        guard parser.parse() else {
            throw parser.parserError ?? URLError(.cannotParseResponse)
        }
        return delegate.podcast
    }

    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?,
                qualifiedName: String?, attributes: [String: String] = [:]) {
        text = ""
        switch name {
        case "item":
            inItem = true
            item = [:]; itemAudio = nil; itemImage = nil
        case "enclosure" where inItem:
            if let u = attributes["url"] { itemAudio = URL(string: u) }
        case "itunes:image":
            let url = attributes["href"].flatMap(URL.init(string:))
            if inItem { itemImage = url } else if podcast.imageURL == nil { podcast.imageURL = url }
        default: break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) { text += string }

    func parser(_ parser: XMLParser, foundCDATA data: Data) {
        text += String(decoding: data, as: UTF8.self)
    }

    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?,
                qualifiedName: String?) {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if inItem {
            if name == "item" {
                inItem = false
                if let audio = itemAudio {
                    podcast.episodes.append(Episode(
                        guid: item["guid"] ?? "",
                        title: item["title"] ?? "Untitled",
                        summary: item["itunes:summary"] ?? item["description"] ?? "",
                        pubDate: item["pubDate"].flatMap(Self.parseDate),
                        duration: item["itunes:duration"].flatMap(Self.parseDuration),
                        audioURL: audio,
                        imageURL: itemImage ?? podcast.imageURL,
                        link: item["link"].flatMap(URL.init(string:))))
                }
            } else if !value.isEmpty {
                item[name] = value
            }
        } else {
            switch name {
            case "title" where podcast.title.isEmpty: podcast.title = value
            case "itunes:author": podcast.author = value
            case "url" where podcast.imageURL == nil: podcast.imageURL = URL(string: value)
            default: break
            }
        }
        text = ""
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        return f
    }()

    static func parseDate(_ s: String) -> Date? { dateFormatter.date(from: s) }

    /// Accepts "HH:MM:SS", "MM:SS" or plain seconds.
    static func parseDuration(_ s: String) -> TimeInterval? {
        let parts = s.split(separator: ":").compactMap { Double($0) }
        guard !parts.isEmpty else { return nil }
        return parts.reduce(0) { $0 * 60 + $1 }
    }
}
