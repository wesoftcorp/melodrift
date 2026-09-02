# 🎵 Melodrift

**Let the music drift.**  
*A modern, high-fidelity music streaming client and audio player crafted with speed, rich aesthetics, and privacy in mind.*

[![Release](https://img.shields.io/github/v/release/wesoftcorp/melodrift?color=6366F1&label=Latest%20Release)](https://github.com/wesoftcorp/melodrift/releases/latest)
[![Platform](https://img.shields.io/badge/Platforms-Android%20%7C%20Windows-blue)](https://github.com/wesoftcorp/melodrift)
[![License](https://img.shields.io/badge/Privacy-100%25%20Ad--Free-success)](https://melodrift.rajeevupadhyay.com/privacy.html)
[![Website](https://img.shields.io/badge/Official%20Website-melodrift.rajeevupadhyay.com-purple)](https://melodrift.rajeevupadhyay.com)

---

## 🌟 Key Features

### ⚡ Ultra-Fast Audio Engine (<300ms)
- **Zero-Buffering Playback:** Sub-300ms track initiation powered by in-memory audio chunking and smart lookahead queue prefetching.
- **Smart Search Aggregation:** Intelligent multi-source catalog discovery with automated deduplication so you never see repetitive songs.
- **High-Fidelity Audio:** Crystal-clear streaming with dynamic bitrate scaling up to lossless quality.

### 🎚️ 10-Band Studio Equalizer
- **Fine-Grained Control:** 10 customizable frequency bands, bass boost, and audio virtualizer.
- **Genre Presets:** Built-in acoustic profiles for Rock, Pop, Classical, EDM, Acoustic, and Bass Boost, plus custom user presets.

### 🎤 Synchronized Real-Time Lyrics
- **Karaoke-Style Highlights:** Real-time lyric synchronization with active line and word tracking.
- **Offline Lyric Cache:** Automatically saves lyrics alongside downloaded audio files.

### 🔄 Real-Time Cloud Library Sync
- **Cross-Platform Synchronization:** Seamlessly sync your playlists, favorites, and listening history across Android and Windows.
- **Privacy-First Authentication:** Secure Google SSO authentication into a private, isolated cloud partition.

### 📥 Encrypted Offline Music Storage
- **Offline Mode:** Download your favorite tracks and full albums for zero-data listening.
- **App-Managed Security:** Downloads are stored in high-performance encrypted formats managed directly by Melodrift.

### 🚀 1-Tap In-App Live Updates
- **Zero Interruption:** Receive instant feature enhancements and bug fixes directly over the air with Shorebird Code Push.
- **Manual Verification:** Check for live patches directly in **Settings → Check for Updates**.

### 🛡️ 100% Ad-Free & Privacy-Focused
- **No Ads:** Completely ad-free interface with no banner ads or audio interruptions.
- **No Tracking:** Google Advertising Identifier (`AD_ID`) is completely omitted. No cross-app tracking or user profiling.
- **Ephemeral Voice Search:** Microphone access is used strictly on-device to transcribe voice search queries.

---

## 📱 Supported Platforms

| Platform | Target Architecture | Distribution Channel |
| :--- | :--- | :--- |
| **Android** | `arm64-v8a`, `armeabi-v7a`, `x86_64` | [Google Play Store](https://melodrift.rajeevupadhyay.com) & [Direct APK](https://github.com/wesoftcorp/melodrift/releases/latest) |
| **Windows** | `x64` (Windows 10 & 11) | [Microsoft Store](https://partner.microsoft.com) & [Direct MSIX / ZIP](https://github.com/wesoftcorp/melodrift/releases/latest) |

---

## 🏗️ Architecture & Tech Stack

Melodrift is built using modern Flutter and native platform integrations:

* **Framework:** Flutter 3.44+ / Dart 3
* **State Management:** Riverpod & Flutter Hooks
* **Navigation:** AutoRoute declarative routing
* **Audio Playback:** Just Audio, Audio Service, and Just Audio Windows
* **Local Storage:** Isar Database, SharedPreferences, and Flutter Secure Storage
* **Cloud Infrastructure:** Firebase Core, Authentication, and Realtime Database
* **OTA Updates:** Shorebird Code Push (`shorebird_code_push`)
* **Design & UI:** Fluid Dark Theme, Glassmorphism, Google Fonts (Inter), Lottie, and Rive vector animations

---

## 📁 Repository Structure

```text
lib/
  ├── app/                  # Application routing and dependency injection
  ├── core/                 # Services (Audio, Update, Cache, Equalizer, Theme)
  ├── data/                 # Repositories, models, and remote/local data sources
  ├── domain/               # Domain contracts and entities
  └── presentation/         # UI Screens, widgets, state providers, and hooks
android/                    # Android native project, Gradle build configs, keystores
windows/                    # Windows native C++ runner, CMake configurations
assets/                     # Brand assets, animations, icons, and shaders
dist_release/               # Production binaries (.apk, .aab, .msix, .zip)
docs/                       # Official website & documentation (melodrift.rajeevupadhyay.com)
```

---

## 🚀 Building from Source

### Prerequisites
* Flutter SDK (3.24+ recommended)
* Android SDK (Target SDK 36, Min SDK 24)
* Visual Studio 2022 (with Desktop development with C++ for Windows)

### 1. Clone the Repository
```bash
git clone https://github.com/wesoftcorp/melodrift.git
cd melodrift
```

### 2. Install Dependencies
```bash
flutter pub get
```

### 3. Run Locally
```bash
# Run on Windows Desktop
flutter run -d windows

# Run on Android
flutter run -d android --flavor prodFull -t lib/main.dart
```

### 4. Build Production Packages
```bash
# Android Release APK
flutter build apk --flavor prodFull --target lib/main.dart --release

# Google Play Store App Bundle (AAB)
flutter build appbundle --flavor prodFull --target lib/main.dart --release

# Windows MSIX Package
flutter pub run msix:create
```

---

## 🌐 Official Links

* **Official Website:** [https://melodrift.rajeevupadhyay.com](https://melodrift.rajeevupadhyay.com)
* **Privacy Policy:** [https://melodrift.rajeevupadhyay.com/privacy.html](https://melodrift.rajeevupadhyay.com/privacy.html)
* **Terms of Service:** [https://melodrift.rajeevupadhyay.com/terms.html](https://melodrift.rajeevupadhyay.com/terms.html)
* **GitHub Releases:** [https://github.com/wesoftcorp/melodrift/releases](https://github.com/wesoftcorp/melodrift/releases)

---

## 📄 License & Disclaimer

Melodrift is an independent audio player and media streaming application. All product names, logos, and brands are property of their respective owners.

Developed with ❤️ by **Rajeev Upadhyay**.
