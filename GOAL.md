# Active Goal (goal mode)

> Preserved 2026-08-11 after `/guided-goal` tool was dropped/unmounted while updating the token budget. Objective unchanged; budget raised from 200k to 5,000,000 per user request.

## Objective
Build a Flutter Music Sync app at the repo root of `flutter-ci-example/` (`flutter_ci_example`) that ports the existing web app's core flows against the read-only backend at `/home/ilham/.openclaw/workspace/ichi-core/music-sync/` (Express.js + WebSocket on port 3456). Implement: name-based auth (persisted locally), YouTube search (`/api/search`) + playback (`youtube_player_flutter`), real-time WebSocket sync (`web_socket_channel`) for play/pause/seek, shared queue (add/remove/clear), and user presence. State management via `provider`. Reconcile the GitHub Actions CI to trigger on `master`.

## Success criteria
- `flutter build apk --debug` exits 0 (debug APK compiles).
- `flutter test` exits 0 with tests covering: name-login (persisted), YouTube search results rendering, playback start, and sync state transitions (play/pause/seek + queue ops + users list) asserted against a mocked `web_socket_channel`.
- `flutter analyze` reports no errors.
- The WebSocket message shapes sent/received by the Flutter client exactly match the backend protocol (PRD lines 84-100, confirmed in `server.js`/`public/app.js`): client→server `{type:hello|action|loadVideo|queue|next|ended}`, server→client `{type:state|action|loadVideo|queue|users}`.
- `.github/workflows/*.yml` runs `flutter test` and `flutter build apk --debug` on push to `master` (the repo's default branch; CI currently triggers on `main` — change it).
- The backend at `music-sync/` is byte-for-byte unchanged (read-only).

## Verification
- `flutter test` in repo root — must exit 0.
- `flutter build apk --debug` — must exit 0 and produce `build/app/outputs/flutter-apk/app-debug.apk`.
- `flutter analyze` — no errors.
- `git diff --stat /home/ilham/.openclaw/workspace/ichi-core/music-sync/` — empty (backend untouched).
- Validate the CI workflow YAML parses, triggers on `push` to `master`, and runs `flutter pub get` → `flutter test` → `flutter build apk --debug`.

## Boundaries
- **In scope:** everything under `/home/ilham/flutter-ci-example/` (repo root) — `lib/`, `test/`, `pubspec.yaml`, `.github/workflows/`.
- **Read-only (never modify):** `/home/ilham/.openclaw/workspace/ichi-core/music-sync/`. Read only to learn the WebSocket protocol and REST endpoints (`/api/search`, `/api/stream-url`).
- If a sync feature requires a backend capability that does not exist, mark it out-of-scope, skip it, and keep the app compatible with the backend as-is.

## Stop conditions
- **Attempt cap:** stop after 3 consecutive failed attempts at the same gate (`flutter test`, `flutter build`, or CI), then surface a blocking summary.
- **Token budget:** 5,000,000 tokens. No per-attempt cap; self-pace within budget.
- **Hard-stop escalation (surface immediately):** (a) PRD/feature ambiguity where two reasonable implementations diverge; (b) a required Flutter/Dart package that won't resolve or is incompatible with the backend protocol; (c) a core flow that provably can't work against the read-only backend as-is, forcing an out-of-scope skip that breaks the success bar; (d) any CI/credentials issue (signing, Flutter SDK setup) unresolvable without user input.
