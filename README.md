# FeedPlayer

A SwiftUI iOS app (iOS 17+) that plays the episodes in this SoundCloud RSS feed:
https://feeds.soundcloud.com/users/soundcloud:users:749441560/sounds.rss

## Features
- Episode list with artwork, date, and duration; pull to refresh; search
- Keeps the last downloaded feed so the list shows up offline
- Mini player plus a full-screen player: scrubbing, skip back 15s / forward 30s, playback speed
- Background audio, lock-screen and Control Center controls, Now Playing artwork

## Build (on a Mac with Xcode 15 or later)

Option A: XcodeGen
```bash
brew install xcodegen
```
```bash
xcodegen generate && open FeedPlayer.xcodeproj
```

Option B: by hand
1. In Xcode, choose File > New > Project > iOS App (SwiftUI, Swift) and name it `FeedPlayer`.
2. Delete the generated `ContentView.swift` and `FeedPlayerApp.swift`, then drag in the `FeedPlayer/` folder from this repo.
3. In Signing & Capabilities, add **Background Modes** and tick **Audio, AirPlay, and Picture in Picture**.

Choose your Team under Signing, then run on a simulator or device.

To use a different feed, change `FeedStore.feedURL`.
