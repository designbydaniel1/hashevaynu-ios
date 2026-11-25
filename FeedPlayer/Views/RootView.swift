import SwiftUI

struct RootView: View {
    @Environment(FeedStore.self) private var feed
    @Environment(PlaylistStore.self) private var playlists
    @State private var nav = AppNavigation()

    var body: some View {
        @Bindable var nav = nav
        TabView(selection: $nav.tab) {
            LatestView()
                .tabItem { Label("Shiurim", systemImage: "waveform") }
                .tag(AppNavigation.Tab.shiurim)
            SeriesListView()
                .tabItem { Label("Series", systemImage: "square.stack") }
                .tag(AppNavigation.Tab.series)
            SavedView()
                .tabItem { Label("Saved", systemImage: "bookmark") }
                .tag(AppNavigation.Tab.saved)
            MoreView()
                .tabItem { Label("More", systemImage: "ellipsis.circle") }
                .tag(AppNavigation.Tab.more)
        }
        .environment(nav)
        .overlay { ToastOverlay() }
        .task { await feed.refresh() }
        .task { await playlists.refresh() }
        .task {
            NewShiurNotifier.schedule()
            // Ask once, a moment after the first launch, with the standard iOS prompt.
            guard !NewShiurNotifier.hasAsked else { return }
            try? await Task.sleep(for: .seconds(3))
            await NewShiurNotifier.requestPermission()
        }
    }
}

/// Adds the mini player above the tab bar and opens the full player when tapped.
struct MiniPlayerHost: ViewModifier {
    @Environment(AudioPlayer.self) private var player
    @State private var showPlayer = false

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .bottom) {
                ZStack {
                    if player.current != nil {
                        MiniPlayerView()
                            .onTapGesture { showPlayer = true }
                            .transition(.toast)
                    }
                }
                .motion(Motion.toastOpen, value: player.current != nil)
            }
            .sheet(isPresented: $showPlayer) { PlayerView() }
    }
}

extension View {
    func withMiniPlayer() -> some View { modifier(MiniPlayerHost()) }
}
