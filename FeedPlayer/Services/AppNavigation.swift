import Observation

/// Which tab is showing, so screens can send the listener to another tab.
@MainActor @Observable
final class AppNavigation {
    enum Tab: Hashable { case shiurim, series, saved, more }
    var tab: Tab = .shiurim
}
