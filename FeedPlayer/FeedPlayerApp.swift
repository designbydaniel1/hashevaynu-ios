import SwiftUI

@main
struct FeedPlayerApp: App {
    @State private var library: Library
    @State private var player: AudioPlayer
    @State private var feed = FeedStore()

    init() {
        let library = Library()
        _library = State(initialValue: library)
        _player = State(initialValue: AudioPlayer(library: library))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(player)
                .environment(feed)
                .environment(library)
        }
    }
}
