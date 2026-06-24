# Melodrift Cross-Platform Fix Plan

## Goal
Make Melodrift more production-ready on Android and Windows by fixing release-blocking playback, offline download, logging, and metadata issues before adding larger best-in-class features.

## Developer Details
- Developer: Rajeev Upadhyay
- Email: rajeev.upadhyay@live.in
- Website: rajeevupadhyay.com

## Phase 1: Stabilize Downloads and Offline Playback
- Unify the visible download flow so the app does not save plain MP3 downloads for offline use when encrypted downloads are expected.
- Replace misleading AES-256 comments around XOR encryption with accurate language or implement proper encryption if package support is available without destabilizing builds.
- Ensure downloaded songs are marked consistently in Isar and visible in the existing downloads UI.
- Ensure Android and Windows playback use a playable local source for offline files.

## Phase 2: Playback Reliability
- Guard next/previous behavior at queue boundaries.
- Stop treating empty stream URLs as successful playback.
- Make completed-track behavior respect repeat/shuffle/queue limits.
- Avoid queue hash skips when meaningful metadata changes.

## Phase 3: Logging and Diagnostics
- Replace direct `print()` calls in production code with `AppLogger`.
- Remove or isolate duplicate logging services.
- Gate Crashlytics calls so logging remains safe when Firebase is disabled or uninitialized.

## Phase 4: UI and Developer Metadata
- Add developer details to the app's About section.
- Keep the UI consistent with the current Material/glassmorphism design.
- Prefer small changes over redesigns during this stabilization pass.

## Phase 5: Verification
- Run `flutter analyze`.
- Run `flutter test` if tests are configured.
- Build or smoke-check Android and Windows where feasible in the current environment.
- Update `MEMORY.md` with exact status, files changed, verification results, and next action.

## Deferred Best-In-Class Work
- Personalized recommendations from local listening history.
- Playlist/radio generation, smart mixes, crossfade, equalizer, replay gain.
- Synced lyrics, richer onboarding, and polished release-store metadata.
- Full legal/compliance review for YouTube-based streaming and downloads.
