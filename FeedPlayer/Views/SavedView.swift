import SwiftUI

struct SavedView: View {
    @Environment(Library.self) private var library
    @Environment(FeedStore.self) private var feed

    var body: some View {
        NavigationStack {
            List(library.saved) { EpisodeRow(episode: $0) }
                .listStyle(.plain)
                .navigationTitle("Saved")
                .refreshable { await feed.refresh() }
                .overlay {
                    if library.saved.isEmpty {
                        ContentUnavailableView("Nothing saved yet",
                            systemImage: "bookmark",
                            description: Text("Swipe left on a shiur, or tap the bookmark in the player, to save it for later."))
                    }
                }
                .withMiniPlayer()
        }
    }
}
