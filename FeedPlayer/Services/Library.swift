import Foundation
import Observation

/// The listener's personal data: saved episodes and where they stopped in each one.
@MainActor @Observable
final class Library {
    /// Saved episodes, newest-saved first. Stored in full so they survive
    /// after the episode drops off the end of the RSS feed.
    private(set) var saved: [Episode] = []
    /// Episode id -> seconds listened.
    private(set) var positions: [String: TimeInterval] = [:]
    /// Episode ids the listener finished.
    private(set) var finished: Set<String> = []

    private let defaults = UserDefaults.standard

    init() {
        if let data = defaults.data(forKey: "saved"),
           let list = try? JSONDecoder().decode([Episode].self, from: data) { saved = list }
        positions = defaults.dictionary(forKey: "positions") as? [String: TimeInterval] ?? [:]
        finished = Set(defaults.stringArray(forKey: "finished") ?? [])
    }

    // MARK: Save for later

    func isSaved(_ ep: Episode) -> Bool { saved.contains { $0.id == ep.id } }

    func toggleSaved(_ ep: Episode) {
        if let i = saved.firstIndex(where: { $0.id == ep.id }) { saved.remove(at: i) }
        else { saved.insert(ep, at: 0) }
        if let data = try? JSONEncoder().encode(saved) { defaults.set(data, forKey: "saved") }
    }

    // MARK: Resume where you left off

    func position(for ep: Episode) -> TimeInterval { positions[ep.id] ?? 0 }

    /// 0...1, or nil if never started.
    func progress(for ep: Episode) -> Double? {
        if finished.contains(ep.id) { return 1 }
        guard let p = positions[ep.id], p > 0, let d = ep.duration, d > 0 else { return nil }
        return min(p / d, 1)
    }

    func setPosition(_ t: TimeInterval, for ep: Episode) {
        positions[ep.id] = t
        defaults.set(positions, forKey: "positions")
    }

    func markFinished(_ ep: Episode, _ done: Bool = true) {
        if done { finished.insert(ep.id); positions[ep.id] = nil }
        else { finished.remove(ep.id) }
        defaults.set(Array(finished), forKey: "finished")
        defaults.set(positions, forKey: "positions")
    }
}
