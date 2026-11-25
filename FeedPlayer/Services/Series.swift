import Foundation

/// A group of related shiurim (e.g. all Daf Yomi episodes).
///
/// For now series are worked out from episode titles. Once SoundCloud API
/// access is set up, these can come from the real SoundCloud playlists instead.
struct Series: Identifiable, Hashable {
    var id: String { name }
    var name: String
    var subtitle: String
    var symbol: String
    var episodes: [Episode]
    /// Playlist thumbnail from SoundCloud, when available.
    var artworkURL: URL? = nil
    /// Section on the Series tab (daf, halacha, machshava, ...).
    var category: String = ""
    /// Designed tile: short text and colour (hex), used when there is no artwork.
    var badge: String = ""
    var tint: String? = nil
    /// Shorter title for tiles, e.g. "Eirachin" for "33. Daf Yomi- Eirachin".
    var shortName: String = ""
    /// When the playlist was published (yyyy-MM-dd), for Featured.
    var created: String = ""
}

enum SeriesCatalog {
    private struct Rule {
        let name: String, subtitle: String, symbol: String
        let matches: (String) -> Bool
    }

    private static let rules: [Rule] = [
        Rule(name: "Daf Yomi", subtitle: "Rabbi Avi Zakutinsky", symbol: "book.pages") {
            $0.contains("(daf yomi)") || $0.range(of: #"^\w+ \d+[ab]?(-\d+[ab]?)?$"#, options: .regularExpression) != nil
        },
        Rule(name: "Mishnah Berurah Yomi", subtitle: "Dirshu cycle", symbol: "calendar") {
            $0.hasPrefix("mishnah berurah") || $0.hasPrefix("mishnhah berurah")
        },
        Rule(name: "moonLight of Emuna", subtitle: "R' Dov Elias", symbol: "moon.stars") {
            $0.contains("moonlight of emuna")
        },
        Rule(name: "Semicha Shiurim", subtitle: "Basar B'Chalav and more", symbol: "graduationcap") {
            $0.hasPrefix("semicha shiurim")
        },
        Rule(name: "Assorted Halachos", subtitle: "Practical halacha", symbol: "list.bullet.rectangle") {
            $0.hasPrefix("assorted halachos")
        },
        Rule(name: "Chassidus", subtitle: "Parsha and Yomim Tovim", symbol: "flame") {
            $0.hasPrefix("chassidus")
        },
        Rule(name: "Maharal – Netzach Yisroel", subtitle: "Machshava", symbol: "text.book.closed") {
            $0.hasPrefix("maharal")
        },
        Rule(name: "Sefer V'Ani Tefillah", subtitle: "R' Yussie", symbol: "hands.sparkles") {
            $0.hasPrefix("sefer v'ani tefil")
        },
    ]

    static func build(from episodes: [Episode]) -> [Series] {
        var groups: [String: [Episode]] = [:]
        for ep in episodes {
            let t = ep.title.lowercased()
            let name = rules.first { $0.matches(t) }?.name ?? "More Shiurim"
            groups[name, default: []].append(ep)
        }
        var result = rules.compactMap { r in
            groups[r.name].map { Series(name: r.name, subtitle: r.subtitle, symbol: r.symbol, episodes: $0) }
        }
        if let other = groups["More Shiurim"] {
            result.append(Series(name: "More Shiurim", subtitle: "Parsha, Yomim Tovim and more",
                                 symbol: "square.stack", episodes: other))
        }
        return result
    }
}
