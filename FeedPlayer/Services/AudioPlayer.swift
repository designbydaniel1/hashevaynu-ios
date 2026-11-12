import AVFoundation
import MediaPlayer
import Observation
import UIKit

@MainActor @Observable
final class AudioPlayer {
    private(set) var current: Episode?
    private(set) var isPlaying = false
    private(set) var isBuffering = false
    var currentTime: TimeInterval = 0
    private(set) var duration: TimeInterval = 0
    var rate: Float = 1.0 { didSet { if isPlaying { player.rate = rate }; updateNowPlaying() } }

    @ObservationIgnored private let player = AVPlayer()
    @ObservationIgnored private var timeObserver: Any?
    @ObservationIgnored private var endObserver: NSObjectProtocol?
    @ObservationIgnored private var statusObservation: NSKeyValueObservation?
    @ObservationIgnored private var artwork: MPMediaItemArtwork?
    @ObservationIgnored private var isScrubbing = false
    @ObservationIgnored private let library: Library
    @ObservationIgnored private var lastSaved: TimeInterval = 0

    init(library: Library) {
        self.library = library
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        setupRemoteCommands()
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main
        ) { [weak self] time in
            MainActor.assumeIsolated {
                guard let self, !self.isScrubbing else { return }
                self.currentTime = time.seconds.isFinite ? time.seconds : 0
                if let d = self.player.currentItem?.duration.seconds, d.isFinite, d > 0 {
                    self.duration = d
                }
                if abs(self.currentTime - self.lastSaved) >= 5 { self.savePosition() }
            }
        }
        statusObservation = player.observe(\.timeControlStatus) { [weak self] p, _ in
            let buffering = p.timeControlStatus == .waitingToPlayAtSpecifiedRate
            Task { @MainActor in self?.isBuffering = buffering }
        }
    }

    // MARK: Controls

    func play(_ episode: Episode) {
        if current?.id == episode.id { play(); return }
        savePosition()
        current = episode
        if library.finished.contains(episode.id) { library.markFinished(episode, false) }
        let resumeAt = library.position(for: episode)
        currentTime = resumeAt
        lastSaved = resumeAt
        duration = episode.duration ?? 0
        artwork = nil

        let item = AVPlayerItem(url: episode.audioURL)
        player.replaceCurrentItem(with: item)
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        endObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification, object: item, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let ep = self.current else { return }
                self.isPlaying = false
                self.library.markFinished(ep)
                self.lastSaved = 0
                self.updateNowPlaying()
            }
        }
        if resumeAt > 5 {
            player.seek(to: CMTime(seconds: resumeAt - 3, preferredTimescale: 600))
        }
        play()
        loadArtwork(for: episode)
    }

    func play() {
        try? AVAudioSession.sharedInstance().setActive(true)
        player.playImmediately(atRate: rate)
        isPlaying = true
        updateNowPlaying()
    }

    func pause() {
        player.pause()
        isPlaying = false
        savePosition()
        updateNowPlaying()
    }

    func togglePlayPause() { isPlaying ? pause() : play() }

    func skip(by seconds: TimeInterval) { seek(to: currentTime + seconds) }

    func seek(to time: TimeInterval) {
        let t = max(0, duration > 0 ? min(time, duration) : time)
        currentTime = t
        player.seek(to: CMTime(seconds: t, preferredTimescale: 600)) { [weak self] _ in
            Task { @MainActor in self?.updateNowPlaying() }
        }
    }

    /// Call while the user drags the progress slider so the timer doesn't fight them.
    func setScrubbing(_ scrubbing: Bool) {
        isScrubbing = scrubbing
        if !scrubbing { seek(to: currentTime) }
    }

    private func savePosition() {
        guard let ep = current, currentTime > 0 else { return }
        // Within the last 30 seconds counts as finished.
        if duration > 0, currentTime > duration - 30 { library.markFinished(ep) }
        else { library.setPosition(currentTime, for: ep) }
        lastSaved = currentTime
    }

    // MARK: Lock screen / Control Center

    private func setupRemoteCommands() {
        let c = MPRemoteCommandCenter.shared()
        c.playCommand.addTarget { [weak self] _ in self?.play(); return .success }
        c.pauseCommand.addTarget { [weak self] _ in self?.pause(); return .success }
        c.togglePlayPauseCommand.addTarget { [weak self] _ in self?.togglePlayPause(); return .success }
        c.skipForwardCommand.preferredIntervals = [30]
        c.skipForwardCommand.addTarget { [weak self] _ in self?.skip(by: 30); return .success }
        c.skipBackwardCommand.preferredIntervals = [15]
        c.skipBackwardCommand.addTarget { [weak self] _ in self?.skip(by: -15); return .success }
        c.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let e = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            self?.seek(to: e.positionTime)
            return .success
        }
    }

    private func updateNowPlaying() {
        guard let ep = current else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: ep.title,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? Double(rate) : 0,
        ]
        if let artwork { info[MPMediaItemPropertyArtwork] = artwork }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func loadArtwork(for episode: Episode) {
        guard let url = episode.imageURL else { return }
        Task {
            guard let (data, _) = try? await URLSession.shared.data(from: url),
                  let image = UIImage(data: data),
                  current?.id == episode.id else { return }
            artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
            updateNowPlaying()
        }
    }
}
