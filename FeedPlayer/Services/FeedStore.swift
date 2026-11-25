import Foundation
import Observation

@MainActor @Observable
final class FeedStore {
    nonisolated static let feedURL = URL(string: "https://feeds.soundcloud.com/users/soundcloud:users:749441560/sounds.rss")!

    private(set) var podcast: Podcast?
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private let cacheURL = FileManager.default
        .urls(for: .cachesDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("feed.xml")

    init() {
        // Show the last downloaded feed immediately (works offline).
        if let data = try? Data(contentsOf: cacheURL) {
            podcast = try? FeedParser.parse(data)
        }
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let (data, response) = try await URLSession.shared.data(from: Self.feedURL)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                throw URLError(.badServerResponse)
            }
            let parsed = try FeedParser.parse(data)
            podcast = parsed
            NewShiurNotifier.markSeen(parsed.episodes)
            try? data.write(to: cacheURL)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
