import SwiftUI

struct RootView: View {
    @Environment(FeedStore.self) private var feed

    var body: some View {
        TabView {
            LatestView()
                .tabItem { Label("Shiurim", systemImage: "waveform") }
            SeriesListView()
                .tabItem { Label("Series", systemImage: "square.stack") }
            SavedView()
                .tabItem { Label("Saved", systemImage: "bookmark") }
            MoreView()
                .tabItem { Label("More", systemImage: "ellipsis.circle") }
        }
        .task { await feed.refresh() }
    }
}

/// Adds the mini player above the tab bar and opens the full player when tapped.
struct MiniPlayerHost: ViewModifier {
    @Environment(AudioPlayer.self) private var player
    @State private var showPlayer = false

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .bottom) {
                if player.current != nil {
                    MiniPlayerView().onTapGesture { showPlayer = true }
                }
            }
            .sheet(isPresented: $showPlayer) { PlayerView() }
    }
}

extension View {
    func withMiniPlayer() -> some View { modifier(MiniPlayerHost()) }
}
