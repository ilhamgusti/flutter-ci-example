# PRD: Music Sync Flutter App

## Overview
A Flutter-based music sync app that allows multiple users to listen to YouTube music together in real-time. This is a port/reimplementation of the existing web-based Music Sync app (`music-sync`) into Flutter, with CI/CD via GitHub Actions.

## Background
The existing web app (`music-sync`) uses:
- Express.js + WebSocket server
- YouTube IFrame API for streaming
- Document Picture-in-Picture API
- Real-time sync via WebSocket (play/pause/seek)

The Flutter app will replicate this functionality natively.

## Goals
1. **Real-time music sync** — multiple users can listen together
2. **YouTube streaming** — no download required, stream directly
3. **Cross-platform** — Android (primary), iOS (secondary), Web (stretch)
4. **CI/CD pipeline** — GitHub Actions builds APK on every push
5. **Picture-in-Picture support** — floating player on Android

## Non-Goals
- Audio extraction/download
- Non-YouTube sources
- Offline playback
- User authentication (use name-based like web version)

## Features

### Core Features (MVP)
1. **Name Entry** — User enters their name on first launch (persisted locally)
2. **YouTube Search** — Search for songs, see results with thumbnails
3. **Now Playing** — Current track with title, channel, controls
4. **Playback Controls** — Play, pause, seek, next track
5. **Queue System** — Add/remove songs from shared queue
6. **Real-time Sync** — WebSocket-based play/pause/seek sync across users
7. **User Presence** — See who's online

### Phase 2 (Post-MVP)
8. **Picture-in-Picture** — Floating mini-player (Android PiP API)
9. **YouTube URL paste** — Direct play from URL
10. **Share link** — Copy room URL

## Technical Architecture

### Frontend (Flutter)
- **State Management:** Provider or Riverpod
- **YouTube Playback:** `youtube_player_flutter` or `youtube_explode_dart`
- **WebSocket:** `web_socket_channel`
- **HTTP:** `http` or `dio` for search API
- **Local Storage:** `shared_preferences` for name persistence
- **PiP:** Native Android PiP channel (MethodChannel)

### Backend (Reuse Existing)
- Keep existing Express.js + WebSocket server from `music-sync`
- Same API endpoints: `/api/search`, `/api/stream-url`
- Same WebSocket protocol for sync

### CI/CD (GitHub Actions)
- **Trigger:** Push to `main` / `master`
- **Steps:**
  1. Setup Java 17 + Flutter SDK (cached)
  2. `flutter pub get`
  3. `flutter analyze`
  4. `flutter test`
  5. `flutter build apk --debug`
  6. Upload APK as artifact
- **File:** `.github/workflows/flutter-ci.yml`

## Screens

### 1. Name Entry Screen
- App logo + name
- Text field for name
- "Gabung" button

### 2. Main Screen (Single Page)
- **Player section** — YouTube player embed + now playing info
- **Search bar** — Search songs or paste YouTube URL
- **Search results** — List with thumbnail, title, channel, duration
- **Queue section** — Current queue with remove buttons
- **Header** — App name + online users indicator

## WebSocket Protocol (Same as Web)
```
// Client → Server
{ "type": "hello", "name": "username" }
{ "type": "action", "action": "play|pause|seek", "time": 0 }
{ "type": "loadVideo", "video": { "id", "title", "channel" } }
{ "type": "queue", "op": "add|remove|clear", "video": {}, "index": 0 }
{ "type": "next" }
{ "type": "ended" }

// Server → Client
{ "type": "state", "state": { currentVideo, isPlaying, currentTime, queue, lastSyncTime } }
{ "type": "action", "action": "...", "time": 0, "timestamp": 0 }
{ "type": "loadVideo", "video": {}, "timestamp": 0 }
{ "type": "queue", "queue": [] }
{ "type": "users", "users": ["name1", "name2"] }
```

## Dependencies (pubspec.yaml)
```yaml
dependencies:
  flutter:
    sdk: flutter
  youtube_player_flutter: ^9.0.1  # YouTube playback
  web_socket_channel: ^3.0.1      # WebSocket client
  http: ^1.2.0                    # API calls
  shared_preferences: ^2.3.0      # Local storage
  provider: ^6.1.0                # State management

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0
```

## Success Criteria
- [ ] App builds successfully via GitHub Actions
- [ ] APK artifact available for download from Actions tab
- [ ] Users can search and play YouTube music
- [ ] Playback syncs across 2+ devices in real-time
- [ ] Queue management works (add/remove/clear)
- [ ] User presence indicator works
- [ ] Name persists across app restarts

## References
- Web app source: `music-sync/` (existing)
- GitHub repo: https://github.com/ilhamgusti/flutter-ci-example
- CI reference: https://medium.com/@abhayshankur/automating-flutter-android-builds-with-github-actions-77c172653525
