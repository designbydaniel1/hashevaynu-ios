import SwiftUI

/// A Hashevaynu speaker, with bio and sefarim from hashevaynu.org.
struct Speaker: Identifiable, Hashable {
    let id: String
    let name: String
    let photo: URL?
    let bio: String
    let links: [Link]
    let books: [Book]
    /// Which playlist titles belong to this speaker.
    let pattern: String

    struct Link: Hashable { let title: String; let url: URL }
    struct Book: Hashable {
        let title: String, hebrew: String?, subtitle: String, about: String, cover: URL?
        let actions: [Link]
    }

    func owns(_ series: Series) -> Bool {
        let match = series.name.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
        return id == "avi" ? !Speaker.others.contains { $0.owns(series) } : match
    }

    private static let cdn = "https://images.squarespace-cdn.com/content/v1/5d6b53a89e0b8f0001645836/"
    private static func url(_ s: String) -> URL { URL(string: s)! }

    static let avi = Speaker(
        id: "avi", name: "Rabbi Avi Zakutinsky",
        photo: url(cdn + "1603762635352-UFOM3MG8PY7K2ZLZURSJ/image-asset.png?format=500w"),
        bio: "Rabbi Avi Zakutinsky is the author of the Hebrew Seforim Umekareiv Biyamin (3 volumes) on halachic questions posed to those in kiruv and The Gates of Joy, an English Sefer on the laws and customs of the Jewish wedding. He currently teaches at Yeshivas Hashevaynu in Queens.",
        links: [Link(title: "Email Rabbi Avi", url: url("mailto:avizakutinsky@gmail.com")),
                Link(title: "Halacha blog", url: url("https://halachablog.com"))],
        books: [
            Book(title: "Umekareiv Biyamin", hebrew: "ומקרב בימין", subtitle: "Sefer on Kiruv · 3 volumes · Hebrew",
                 about: "An in-depth analysis of the questions most often asked of kiruv rabbanim, such as pidyon haben when one does not know if the child is a kohen, levi or yisrael, and naming children after non-observant Jews.",
                 cover: url(cdn + "1625371110395-A59GWHERKS6YNP6XSK5C/WhatsApp+Image+2021-07-03+at+11.45.10+PM.jpeg?format=500w"),
                 actions: [Link(title: "Volume 1 · Read free", url: url("https://hebrewbooks.org/pdfpager.aspx?pgnum=1&req=51347")),
                           Link(title: "Volume 2 · Read free", url: url("https://hebrewbooks.org/pdfpager.aspx?pgnum=1&req=58755")),
                           Link(title: "Volume 3 · Buy", url: url("mailto:avizakutinsky@gmail.com?subject=Umekareiv%20Biyamin%20Volume%203"))]),
            Book(title: "The Gates of Joy", hebrew: nil, subtitle: "The laws and customs of the Jewish wedding · 400 pages",
                 about: "Walks any couple through engagement and marriage, explaining the halachos and customs of Ashkenazim, Sephardim and Chassidim.",
                 cover: url(cdn + "1625371812104-GE924PFIWOAC0Q3XOEXU/Sefarim1.jpeg?format=500w"),
                 actions: [Link(title: "Buy · contact Rabbi Avi", url: url("mailto:avizakutinsky@gmail.com?subject=The%20Gates%20of%20Joy"))]),
            Book(title: "Toras Hashevaynu", hebrew: nil, subtitle: "Torah journal for the Seder",
                 about: "Halacha and hashkafa for Pesach and the Seder, written by Rabbi Avi.",
                 cover: url(cdn + "473ff1d5-1a00-4302-b6f7-330062662f6c/Hagadah.png?format=500w"),
                 actions: [Link(title: "Download free", url: url("https://www.hashevaynu.org/s/FINAL-BOOKLET-Peasch-Pamphlet-FULL.pdf"))]),
        ],
        pattern: "")

    static let yehuda = Speaker(
        id: "yehuda", name: "Rabbi Yehuda Zakutinsky",
        photo: url(cdn + "1603768842375-01HDXFIZO93S2S4IKKOC/Rabbi+Yehuda+Zakutinsky.png?format=500w"),
        bio: "Rabbi Yehuda Zakutinsky is the founding Director of Hashevaynu. He is one of the pioneers of the kiruv movement and a leading authority on Jewish outreach. Hashevaynu’s ultimate goal is to make all Jews who pass through its doors feel like cherished members of the family who know that their problems are our problems and their joys are our joys.",
        links: [], books: [], pattern: "rabbi zakutinsky")

    static let dov = Speaker(
        id: "dov", name: "R’ Dov Elias",
        photo: url(cdn + "1603752858225-0HQKCIQ0S2T5YX6BYS31/image-asset.png?format=500w"),
        bio: "R’ Dov Elias is an attorney by training, a real estate investor by trade, but his passion is in chesed and teaching. He is a lecturer at Hashevaynu in Queens, NY, a Daf Yomi maggid shiur, and the translator and adaptor of the Light of Emuna. The “moonLight of Emuna” recordings developed out of a weekly shiur he gives.",
        links: [Link(title: "The Light of Emuna", url: url("https://www.tloe.us"))], books: [],
        pattern: "dov elias|moonlight|nesivos|chovas")

    static let all = [avi, yehuda, dov]
    private static let others = [yehuda, dov]
}

/// A speaker's page: photo, bio, links, playlists and sefarim.
struct SpeakerView: View {
    let speaker: Speaker
    @Environment(PlaylistStore.self) private var playlists

    var body: some View {
        let theirs = playlists.playlists.filter(speaker.owns)
        let daf = theirs.filter { $0.category == "daf" }
        let other = theirs.filter { $0.category != "daf" }
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(spacing: 8) {
                    AsyncImage(url: speaker.photo) { $0.resizable().scaledToFill() } placeholder: { Color.secondary.opacity(0.2) }
                        .frame(width: 120, height: 120).clipShape(Circle())
                    Text(speaker.name).font(.title2.bold())
                    if !theirs.isEmpty {
                        Text("\(theirs.count) playlists · \(theirs.reduce(0) { $0 + $1.episodes.count }.formatted()) shiurim")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 12) {
                    Text(speaker.bio).font(.body)
                    if !speaker.links.isEmpty {
                        HStack {
                            ForEach(speaker.links, id: \.self) { l in
                                SwiftUI.Link(l.title, destination: l.url).buttonStyle(.bordered).font(.subheadline)
                            }
                        }
                    }
                }
                .padding(.horizontal)

                if !other.isEmpty { row("Playlists", other, width: 140) }
                if !daf.isEmpty { row("Daf Yomi", daf, width: 120) }

                if !speaker.books.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Sefarim").font(.title3.bold())
                        ForEach(speaker.books, id: \.self) { BookCard(book: $0) }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle(speaker.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ title: String, _ items: [Series], width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(title) \(items.count)").font(.title3.bold()).padding(.horizontal)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 12) {
                    ForEach(items) { s in
                        NavigationLink(value: s) {
                            VStack(alignment: .leading, spacing: 6) {
                                PlaylistTile(series: s, size: width)
                                Text(s.shortName.isEmpty ? s.name : s.shortName).font(.subheadline.weight(.semibold)).lineLimit(2)
                            }
                            .frame(width: width, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

private struct BookCard: View {
    let book: Speaker.Book
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            AsyncImage(url: book.cover) { $0.resizable().scaledToFill() } placeholder: { Color.secondary.opacity(0.2) }
                .frame(width: 92, height: 130)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .accessibilityLabel("\(book.title) cover")
            VStack(alignment: .leading, spacing: 4) {
                Text(book.title).font(.headline) + Text(book.hebrew.map { "  \($0)" } ?? "").font(.headline).foregroundColor(.secondary)
                Text(book.subtitle).font(.caption).foregroundStyle(.secondary)
                Text(book.about).font(.footnote).padding(.top, 2)
                ForEach(book.actions, id: \.self) { a in
                    SwiftUI.Link(a.title, destination: a.url).font(.footnote.weight(.semibold)).padding(.top, 2)
                }
            }
        }
        .padding(14)
        .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 18))
    }
}
