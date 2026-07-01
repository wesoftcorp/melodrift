# Melodrift

Melodrift is a premium cross-platform YouTube Music client built with Flutter for Android and Windows. It focuses on a polished music experience with local-first playback, offline downloads, playlists, rich discovery sections, and optional Firebase-powered full features.

> Let the music drift.

## Highlights

- Cross-platform Flutter app for Android and Windows desktop.
- YouTube Music discovery powered by `youtube_explode_dart`.
- Background audio playback with queue, repeat, shuffle, and media controls.
- Offline downloads stored as encrypted `.melodrift` files for app-only playback.
- Local playlists, downloaded music management, and playlist detail screens.
- Moods & Genres discovery row with horizontal tile reordering.
- Daily home-feed caching for faster startup and lower network usage.
- Optional Firebase integration for Full flavors, including Auth, Analytics, Crashlytics, and Realtime Database collaboration paths.
- Multiple product flavors for FOSS and Full builds.

## Screens And Platforms

| Platform | Status | Notes |
| --- | --- | --- |
| Android | Supported | Primary mobile target, release APK builds verified. |
| Windows | Supported | Native desktop target using Flutter Windows and `just_audio_windows`. |
| iOS/macOS | Present in project | Not the current primary release target. |

## Tech Stack

- Flutter and Dart
- Riverpod, Hooks Riverpod, and Flutter Hooks for state management
- AutoRoute for navigation
- Just Audio, Audio Service, and Just Audio Windows for playback
- Isar for local database storage
- Shared Preferences and Flutter Secure Storage for local persistence
- Dio for network requests
- Firebase packages for optional Full flavor services
- Flex Color Scheme, Google Fonts, cached network images, BlurHash, Lottie, and Rive for UI

## Integrated Service Providers

| Service Provider | Role in Melodrift | Status | Module |
| --- | --- | --- | --- |
| **YouTube Music (InnerTube)** | Core metadata, search, and default streaming. | **Core/Active** | `:innertube` |
| **JioSaavn** | High-quality audio streaming (up to 320kbps). | **Active** | `:jiosaavn` |
| **Apple Music** | Motion Artwork (animated album covers/canvases). | **Active** | `:applecanvas` |
| **YouLyPlus** | Synced lyrics (via community-hosted KPoe API). | **Active** | `:youlyplus` |
| **LRCLib** | Open-source synced lyrics database. | **Active** | `:lrclib` |
| **KuGou** | Lyrics provider (popular for Chinese/regional songs). | **Active** | `:kugou` |
| **ShazamKit** | Song recognition (Music ID). | **Active** | `:shazamkit` |

## Project Structure

```text
lib/
  app/                    App routing and app-level wiring
  core/                   Services, theme, utilities, and shared infrastructure
  data/                   Datasources, repositories, and local/remote integration
  domain/                 Entities and repository contracts
  presentation/           Screens, providers, widgets, hooks, and UI logic
android/                  Android flavors, Gradle config, icons, manifests
windows/                  Windows runner, native resources, app icon
assets/                   Images, animations, and app branding
test/                     Widget and unit tests
```

## Build Flavors

Melodrift defines four flavors:

| Flavor | Android App ID | Purpose |
| --- | --- | --- |
| `devFoss` | `com.melodrift.dev.foss` | Development FOSS build without Firebase requirements. |
| `prodFoss` | `com.melodrift.foss` | Production FOSS build. |
| `devFull` | `com.melodrift.dev` | Development Full build with Firebase/Google services support. |
| `prodFull` | `com.melodrift` | Production Full build. |

The current verified Android install flow uses `devFoss`.

## Prerequisites

- Flutter SDK with Dart 3 support
- Android Studio and Android SDK for Android builds
- Visual Studio 2022 with Desktop development with C++ for Windows builds
- ADB if installing directly on a physical Android device
- Optional: Firebase project credentials for Full flavors

Check your environment:

```powershell
flutter doctor
```

Install dependencies:

```powershell
flutter pub get
```

## Run Locally

Run on Windows:

```powershell
flutter run -d windows
```

Run on Android with the FOSS development flavor:

```powershell
flutter run -d android --flavor devFoss -t lib/main.dart
```

If multiple Android devices are attached, list devices first:

```powershell
flutter devices
```

## Build Release Outputs

Build Android devFoss APK:

```powershell
flutter build apk --flavor devFoss -t lib/main.dart --release
```

Build optimized Android devFoss APK with obfuscation symbols:

```powershell
flutter build apk --flavor devFoss -t lib/main.dart --release --obfuscate --split-debug-info=build\symbols\android
```

Install the APK on a connected Android device:

```powershell
adb install -r -d build\app\outputs\flutter-apk\app-devfoss-release.apk
```

Build Windows release:

```powershell
flutter build windows --release
```

Build optimized Windows release with obfuscation symbols:

```powershell
flutter build windows --release --obfuscate --split-debug-info=build\symbols\windows
```

Windows output is generated at:

```text
build\windows\x64\runner\Release\melodrift.exe
```

Distribute the full `Release` folder, not only the `.exe`, because the app depends on companion DLLs and data files.

## Firebase Setup

Firebase is optional and intended for Full flavors. FOSS flavors should run without Firebase credentials.

For Full flavor builds:

- Create a Firebase project.
- Register the Android package for the desired Full flavor.
- Add local Firebase config files such as `android/app/google-services.json`.
- Keep real credentials out of source control.
- Use the setup guides under `.planning/` for detailed configuration notes.

## Quality Checks

Run static analysis:

```powershell
flutter analyze
```

Run tests:

```powershell
flutter test
```

Regenerate app icons after changing `assets/logo/melodrift.png`:

```powershell
dart run flutter_launcher_icons
```

## Current Notes

- Android and Windows share the same Flutter UI, so feature changes in `lib/` apply to both platforms.
- Android has flavor-specific launcher icons under `android/app/src/<flavor>/res/mipmap-*`; keep these in sync when updating branding.
- Home feed data is cached daily, while Moods & Genres uses the current static category list to avoid stale cached tiles.
- Windows release builds may show an `MSVCRT.lib` `.voltbl` linker warning; current builds still complete successfully.

## Documentation

Additional project notes are available in:

- `DEPLOYMENT_GUIDE.md` for Windows and Android build walkthroughs.
- `ANALYSIS.md` and `EXECUTIVE_SUMMARY.md` for architecture and optimization analysis.
- `OPTIMIZATION_GUIDE.md` and optimization completion docs for performance work.
- `MEMORY.md` for local session checkpoints and development context.

## License

No license file is currently included. Treat the repository as private/proprietary unless a license is added.
