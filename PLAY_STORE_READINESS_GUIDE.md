# 🚀 Melodrift — Google Play Store Publishing Guide

This guide contains everything you need to register, configure, and publish **Melodrift** on the **Google Play Console** after creating your developer account ($25).

---

## 📦 1. Pre-Compiled Production Binary

Your production Android App Bundle (`.aab`) is signed with your official upload keystore and ready to upload:

* **File Location:**
  [`dist_release\play_store\Melodrift-PlayStore-v1.2.1.aab`](file:///d:/Code/Antigravity/My_Projects/melodrift/dist_release/play_store/Melodrift-PlayStore-v1.2.1.aab)
* **Package Name:** `com.melodrift`
* **Version:** `1.2.1` (Build `122`)
* **Target SDK:** `36` (Android 16) — Fully compliant with Play Store requirements ($\ge 34$).
* **Minimum SDK:** `24` (Android 7.0 Nougat) — 98%+ global device reach.
* **Architecture:** Full 64-bit support (`arm64-v8a`, `x86_64`, `armeabi-v7a`).

---

## 🔑 2. Production Keystore Credentials & Fingerprints

> [!IMPORTANT]
> Keep this safe! Back up `android/app/upload-keystore.jks` and `android/key.properties` to a private, secure cloud drive (e.g. Google Drive / 1Password).

* **Keystore File:** `android/app/upload-keystore.jks`
* **Alias:** `upload`
* **Store Password:** `melodrift2026`
* **Key Password:** `melodrift2026`
* **Certificate Owner:** `CN=Rajeev Upadhyay, OU=Melodrift, O=Melodrift, L=Bangalore, ST=Karnataka, C=IN`
* **SHA-1 Fingerprint:**
  ```text
  EE:A7:49:37:F2:6D:53:C2:CD:5F:2B:A1:79:E5:F3:31:0C:4C:FC:42
  ```
* **SHA-256 Fingerprint:**
  ```text
  B3:C2:25:C6:4A:CC:7F:35:3D:12:A0:53:42:18:B8:2F:29:ED:7A:CB:5C:5C:37:99:5F:10:BF:25:5D:8F:13:F6
  ```

*(Note: Add the SHA-1 and SHA-256 fingerprints to your [Firebase Console](https://console.firebase.google.com/project/melodrift-melody) under Project Settings → Your Android apps → `com.melodrift` so Google Sign-In and Crashlytics authenticate seamlessly).*

---

## 📝 3. Play Store Listing Metadata

### App Details
* **App Name:** `Melodrift - Lossless Music Player`
* **Default Language:** English (United States) — `en-US`
* **App or Game:** App
* **Free or Paid:** Free

### Short Description (Max 80 characters)
```text
Stream lossless music, curated playlists, synchronized lyrics & 10-band equalizer.
```

### Full Description (Max 4000 characters)
```text
Melodrift is a sleek, modern, and high-fidelity music streaming client and audio player engineered for true music enthusiasts. 

Key Highlights & Features:
🎵 High-Fidelity Lossless Audio: Experience studio-grade playback up to 320kbps CD-quality audio with seamless buffering.
📜 Synced Dynamic Lyrics: Sing along in real-time with synchronized, line-by-line scrolling lyrics.
🎚️ 10-Band Professional Equalizer: Fine-tune every frequency with custom acoustic presets, Bass Boost, and Virtualizer.
🔍 Instant Universal Search: Discover millions of songs, albums, top artists, and curated playlists across Bollywood, Retro 90s, Punjabi Hits, Indie, Rock, and International charts.
🎙️ Voice Search: Quickly find your favorite tracks with integrated voice search.
🎧 Offline Cache & Background Playback: Enjoy uninterrupted listening with background media notification controls and offline caching.
🌙 Glassmorphic Aesthetic: Gorgeous, fluid dark-mode design with responsive album art gradients and micro-animations.

Privacy & Safety:
Melodrift respects your privacy. No personal data, tracking identifiers, or listening history is sold or shared with third parties.

Website & Support:
https://melodrift.rajeevupadhyay.com
```

### Official Links
* **Privacy Policy URL:** `https://melodrift.rajeevupadhyay.com/privacy.html`
* **Terms of Service URL:** `https://melodrift.rajeevupadhyay.com/terms.html`
* **Developer Email:** `contact@rajeevupadhyay.com` (or your preferred developer contact email)

---

## 🎨 4. Store Graphics Checklist

1. **App Icon:**
   * Dimensions: `512 x 512 px` (32-bit PNG with alpha).
   * Source: Available at `assets/logo/melodrift.png`.
2. **Feature Graphic:**
   * Dimensions: `1024 x 500 px` (JPEG or 24-bit PNG, no alpha).
   * Visual: Melodrift logo and tagline against a dark gradient background.
3. **Phone Screenshots:**
   * Minimum 2 screenshots (Recommended: 4 to 8 screenshots).
   * Aspect ratio 16:9 or 9:16 (e.g. `1080 x 2400 px`).
   * Key screens to showcase:
     - Home Feed (Fresh Releases, Top 100, Trending)
     - Now Playing screen with Synced Lyrics
     - 10-band Equalizer
     - Browse All / Search Categories

---

## 📋 5. Play Console Policy & Questionnaire Cheat Sheet

When filling out **Policy and Programs → App Content** in Play Console, use these exact answers:

| Policy Section | Recommended Answer | Note |
| :--- | :--- | :--- |
| **Privacy Policy** | Enter `https://melodrift.rajeevupadhyay.com/privacy.html` | Mandatory |
| **App Access** | "All functionality is available without special access" | No login credentials required to use app |
| **Ads** | "No, my app does not contain ads" | We removed the transitive `AD_ID` permission |
| **Content Rating (IARC)** | Category: **Consumer / Streaming Audio Player** | No violence, no profanity, no user-to-user chat |
| **Target Audience & Content** | Target Age: **13 and older** | Avoids stricter COPPA / Families policy review |
| **News Apps** | "No" | App is not a news app |
| **COVID-19 Contact Tracing** | "No" | Standard negative response |
| **Financial Features** | "My app does not provide any financial features" | No in-app financial transactions |
| **Government Apps** | "No" | Not government affiliated |
| **Data Safety Questionnaire** | • Data collected: **No personal info**<br>• Diagnostics: Crashlytics collects crash logs & diagnostics<br>• Audio data: Voice search audio is processed ephemerally on-device and NOT stored or transmitted | Meets Data Safety compliance |
| **Foreground Services** | Select: **Media playback** (`FOREGROUND_SERVICE_MEDIA_PLAYBACK`) | Required to play music in background with notification controls |

---

## 🚀 6. Step-by-Step Publishing Steps (Tomorrow)

1. Go to [Google Play Console](https://play.google.com/console/signup) and pay the one-time $25 developer registration fee.
2. Complete your identity verification (Government ID).
3. Click **"Create app"**:
   - App name: `Melodrift`
   - Default language: English (United States)
   - App or game: App
   - Free or paid: Free
4. Complete the **Set up your app** tasks (Privacy Policy, App Access, Content Rating, Target Audience, Data Safety).
5. Go to **Grow → Store presence → Main store listing** and paste the text and graphics.
6. Go to **Release → Production** (or **Testing → Closed testing**):
   - Click **"Create new release"**.
   - Upload [`dist_release\play_store\Melodrift-PlayStore-v1.2.1.aab`](file:///d:/Code/Antigravity/My_Projects/melodrift/dist_release/play_store/Melodrift-PlayStore-v1.2.1.aab).
   - Add release notes:
     ```text
     Initial release of Melodrift:
     - High-fidelity lossless music streaming
     - Real-time synchronized lyrics
     - 10-band audio equalizer with bass boost
     - Instant voice search & category browsing
     ```
   - Click **Review and save** → **Start rollout to Production**!
