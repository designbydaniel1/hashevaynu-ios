import Foundation

extension TimeInterval {
    /// 75 -> "1:15", 3725 -> "1:02:05"
    var clock: String {
        guard isFinite, self >= 0 else { return "--:--" }
        let s = Int(self)
        return s >= 3600
            ? String(format: "%d:%02d:%02d", s / 3600, s / 60 % 60, s % 60)
            : String(format: "%d:%02d", s / 60, s % 60)
    }
}
