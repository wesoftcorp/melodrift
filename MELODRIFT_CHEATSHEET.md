# 🎵 Melodrift — Developer & Deployment Cheatsheet

A complete reference guide for **Shorebird OTA Patches**, **Build Commands**, **Cloud Services**, and **Official Links**.

---

## 🌐 Official Project Links

| Resource | URL |
| :--- | :--- |
| **Official Website** | [https://melodrift.rajeevupadhyay.com](https://melodrift.rajeevupadhyay.com) |
| **Privacy Policy** | [https://melodrift.rajeevupadhyay.com/privacy.html](https://melodrift.rajeevupadhyay.com/privacy.html) |
| **Terms of Service** | [https://melodrift.rajeevupadhyay.com/terms.html](https://melodrift.rajeevupadhyay.com/terms.html) |
| **GitHub Repository** | [https://github.com/wesoftcorp/melodrift](https://github.com/wesoftcorp/melodrift) |
| **GitHub Releases** | [https://github.com/wesoftcorp/melodrift/releases](https://github.com/wesoftcorp/melodrift/releases) |
| **Shorebird Console** | [https://console.shorebird.dev](https://console.shorebird.dev) |
| **Firebase Console** | [https://console.firebase.google.com/project/melodrift-melody](https://console.firebase.google.com/project/melodrift-melody) |
| **Microsoft Partner Center** | [https://partner.microsoft.com/dashboard](https://partner.microsoft.com/dashboard) |

---

## ⚡ Shorebird Over-The-Air (OTA) Commands

Shorebird allows you to push instant Dart code fixes and UI changes to users' phones **without requiring them to download or reinstall an APK**.

### 1. Push an Instant Live Patch (Daily Workflow)
Whenever you make changes to Dart code or fix a bug:
```powershell
shorebird patch android --flavor prodFull --target lib/main.dart --release-version 1.2.0+120
```

### 2. Build a New Major/Minor Base Release (When updating version in `pubspec.yaml`)
When you increment the version in `pubspec.yaml` (e.g. to `1.3.0+130`):
```powershell
shorebird release android --flavor prodFull --target lib/main.dart --flutter-version=3.44.2 '--' --android-skip-build-dependency-validation
```

### 3. Check Shorebird Status & Diagnostics
```powershell
shorebird doctor
```

### 4. Account Management
```powershell
# Log in (Google Account)
shorebird login

# Log out
shorebird logout
```

---

## 📦 Local Platform Build Commands

### 📱 Android Release APK
Compiles the standalone full production APK:
```powershell
flutter build apk --flavor prodFull -t lib/main.dart --no-tree-shake-icons
```
* **Output Path**: `build\app\outputs\flutter-apk\app-prodfull-release.apk`

### 💻 Windows Desktop Release (.EXE)
Compiles the high-performance Windows desktop executable:
```powershell
flutter build windows --release
```
* **Output Path**: `build\windows\x64\runner\Release\melodrift.exe`

### 🪟 Microsoft Store Package (.MSIX)
Generates the validated Store submission bundle:
```powershell
dart run msix:create
```
* **Output Path**: `build\windows\msix\Melodrift-Store-1.2.0.0-x64.msix`

---

## 🔥 Firebase & Cloud Credentials

* **Firebase Project ID**: `melodrift-melody`
* **Realtime Database**: `https://melodrift-melody-default-rtdb.asia-southeast1.firebasedatabase.app/`
* **Google OAuth 2.0 Web Client ID**:
  ```text
  606758484923-6i764cbhhqa30thjn5nssljvcre593p7.apps.googleusercontent.com
  ```
* **Android Signing Fingerprints**:
  * **SHA-1**: `60:F5:D9:80:EF:A9:D4:3A:38:A6:B3:0F:AC:66:8C:CF:6E:A2:83:6A`
  * **SHA-256**: `A4:F1:EC:94:E8:49:FF:4F:50:C1:2D:D3:A2:73:FC:D3:CD:ED:38:9F:2B:10:52:3E:1A:2B:BA:6A:A8:97:FB:BC`

---

## 📂 Project Directory Quick Links

* [`lib/main.dart`](file:///d:/Code/Antigravity/My_Projects/melodrift/lib/main.dart) — Application entry point
* [`lib/core/services/update_service.dart`](file:///d:/Code/Antigravity/My_Projects/melodrift/lib/core/services/update_service.dart) — In-app 1-tap auto-updater
* [`lib/core/services/audio_handler.dart`](file:///d:/Code/Antigravity/My_Projects/melodrift/lib/core/services/audio_handler.dart) — Core audio engine & equalizer
* [`lib/presentation/providers/player_notifier.dart`](file:///d:/Code/Antigravity/My_Projects/melodrift/lib/presentation/providers/player_notifier.dart) — State manager & playback caching
* [`dist_release/`](file:///d:/Code/Antigravity/My_Projects/melodrift/dist_release) — Packaged distribution binaries folder
* [`web_landing_page/`](file:///d:/Code/Antigravity/My_Projects/melodrift/web_landing_page) & [`docs/`](file:///d:/Code/Antigravity/My_Projects/melodrift/docs) — Website, Privacy & Terms source files
