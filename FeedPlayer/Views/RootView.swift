import SwiftUI

struct RootView: View {
    @Environment(FeedStore.self) private var feed
    @Environment(PlaylistStore.self) private var playlists
    @Environment(AudioPlayer.self) private var player
    @State private var nav = AppNavigation()
    @State private var showPlayer = false

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
        .tint(Color.appBlue)
        .modifier(GlassTabBar(showPlayer: $showPlayer))
        .sheet(isPresented: $showPlayer) { PlayerView() }
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

/// On iOS 26 the tab bar is Liquid Glass: it shrinks while scrolling down,
/// and the mini player rides in its bottom accessory slot.
private struct GlassTabBar: ViewModifier {
    @Environment(AudioPlayer.self) private var player
    @Binding var showPlayer: Bool

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .tabBarMinimizeBehavior(.onScrollDown)
                .tabViewBottomAccessory {
                    if player.current != nil {
                        MiniPlayerView(style: .accessory)
                            .contentShape(Rectangle())
                            .onTapGesture { showPlayer = true }
                    }
                }
        } else {
            content
        }
    }
}

/// The off-white background on each tab, plus (before iOS 26) a floating glass
/// mini player above the tab bar that opens the full player when tapped.
struct MiniPlayerHost: ViewModifier {
    @Environment(AudioPlayer.self) private var player
    @State private var showPlayer = false

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.appBackground()
        } else {
            legacy(content.appBackground())
        }
    }

    private func legacy(_ content: some View) -> some View {
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
