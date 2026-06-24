# Firebase Setup Guide for Melodrift

## Overview

This guide will help you configure Firebase for Melodrift on Android. Firebase provides:
- ✅ Authentication (Google Sign-In)
- ✅ Real-time Database (optional)
- ✅ Crashlytics (error monitoring)
- ✅ Analytics (usage tracking)

---

## Prerequisites

1. **Google Account** - Required to create Firebase project
2. **Firebase CLI** - Optional but recommended
3. **Android Device/Emulator** - For testing

---

## Step 1: Create Firebase Project

### 1.1 Go to Firebase Console
1. Open https://console.firebase.google.com/
2. Click "Add project"
3. Enter project name: **"Melodrift"**
4. Accept terms and click "Create project"
5. Wait 1-2 minutes for setup to complete

### 1.2 Enable Required Services
After project is created:
1. Click "Develop" in left menu
2. Enable these services:
   - ✅ **Authentication** (Google provider)
   - ✅ **Cloud Firestore** (optional, for synced playlists)
   - ✅ **Crashlytics** (auto-enabled after first crash)
   - ✅ **Analytics** (tracks usage)

---

## Step 2: Register Android App

### 2.1 Add Android App to Firebase
1. Go to Firebase Console → Project Settings
2. Click "Add app" → Select "Android"
3. Fill in app details:
   - **Package name**: `com.melodrift.dev` (for devFull flavor)
   - **App nickname**: Melodrift Dev (or your choice)
   - **Debug signing certificate SHA-1**: See Step 2.2

### 2.2 Get Debug Signing Certificate SHA-1

Run this command:
```bash
cd D:\Code\Antigravity\My_Projects\melodrift

# For Windows
keytool -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
```

Look for line: `SHA1: XX:XX:XX:XX:...`

Copy the SHA-1 value and paste into Firebase console step 2.1.

### 2.3 Download google-services.json
1. After entering SHA-1, click "Register app"
2. Download the `google-services.json` file
3. Place it here: `android/app/google-services.json`

**Important**: Commit this to version control (it's app-specific, not a secret)

---

## Step 3: Update Firebase Configuration

### 3.1 Update firebase_options.dart
Replace mock values with your Firebase project details from `google-services.json`:

```dart
// From google-services.json, find these values:
// "client_id", "api_key", "firebase_database_url", etc.
```

File location: `lib/firebase_options.dart`

Example values (replace with yours):
```dart
case TargetPlatform.android:
  return const FirebaseOptions(
    apiKey: 'AIzaSyD..._YOUR_API_KEY_HERE',
    appId: '1:123456789:android:abc123...',
    messagingSenderId: '123456789',
    projectId: 'melodrift-abc123',
    databaseURL: 'https://melodrift-abc123-default-rtdb.firebaseio.com',
  );
```

### 3.2 Verify main.dart Firebase Initialization
Check `lib/main.dart` - Firebase initialization is already set up:
```dart
if (F.isFull && useFirebase) {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}
```

✅ Already configured - no changes needed

---

## Step 4: Android Build Setup

### 4.1 Verify build.gradle.kts
The app's `build.gradle.kts` already has:
```gradle
plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}
```

✅ Already configured - no changes needed

### 4.2 Add google-services.json
1. Place `google-services.json` in: `android/app/google-services.json`
2. The build system will automatically process it

---

## Step 5: Enable Firebase Services

### In Firebase Console:

#### 5.1 Authentication
1. Go to **Build** → **Authentication**
2. Click "Get Started"
3. Select **Google** provider
4. Enable it
5. Add your test email (your Gmail account)

#### 5.2 Crashlytics (Optional - Auto-enabled)
- First crash will automatically enable Crashlytics
- Check **Build** → **Crashlytics** after app crashes once

#### 5.3 Cloud Firestore (Optional - For Playlists Sync)
1. Go to **Build** → **Firestore Database**
2. Click "Create Database"
3. Start in **test mode** (development)
4. Select region: **us-central1** (default)
5. Click "Enable"

**Note**: Test mode allows read/write without authentication. Later, set up security rules.

---

## Step 6: Build & Test Android APK

### 6.1 Build with Firebase
```bash
cd D:\Code\Antigravity\My_Projects\melodrift

# Build APK with Full flavor (includes Firebase)
flutter build apk --flavor devFull -t lib/main_dev_full.dart --debug
```

Output: `build/app/outputs/flutter-apk/app-devFull-debug.apk`

### 6.2 Install on Device
```bash
# Connect device or start emulator, then:
flutter run -d android --flavor devFull
```

### 6.3 Verify Firebase Works
1. Open app
2. Check console for "Firebase initialized successfully"
3. Go to Firebase Console → Build → Crashlytics
4. Should see your app appear within 30 seconds

---

## Environment-Specific Setup

### Development (devFull)
- Firebase enabled
- Uses mock data
- Firebase Console access required
- Crashes logged to Crashlytics

### Production (prodFull)
- Firebase enabled
- Release build configuration
- Signing certificate required
- Real authentication

### FOSS Flavors (devFoss, prodFoss)
- Firebase disabled
- No dependency on Google services
- Can build without `google-services.json`
- All features work offline

---

## Using Firebase in Code

### Enable Firebase in Shared Preferences
```dart
// In app, user enables Firebase (if devFull/prodFull)
final prefs = await SharedPreferences.getInstance();
await prefs.setBool('use_firebase', true);
```

### Check Firebase Status
```dart
final isInitialized = prefs.getBool('firebase_initialized') ?? false;
if (isInitialized) {
  // Use Firebase services
}
```

### Access Current User (After Login)
```dart
import 'package:firebase_auth/firebase_auth.dart';

final user = FirebaseAuth.instance.currentUser;
if (user != null) {
  print('Logged in as: ${user.email}');
}
```

---

## Troubleshooting

### Issue: "google-services.json not found"
**Solution**: 
1. Download from Firebase Console
2. Place at: `android/app/google-services.json`
3. Run: `flutter clean && flutter pub get`

### Issue: "Firebase initialization failed"
**Solution**:
1. Verify `google-services.json` is valid JSON
2. Check API key is correct
3. Verify Android package name matches Firebase config
4. Check internet connectivity

### Issue: "MissingPluginException: No implementation found"
**Solution**:
1. Clean project: `flutter clean`
2. Get dependencies: `flutter pub get`
3. Rebuild: `flutter run -d android --flavor devFull`

### Issue: "Crashlytics not showing crashes"
**Solution**:
1. First crash may take 2-5 minutes to appear
2. Refresh Firebase Console
3. Check device internet connection
4. Verify app can reach Firebase

### Issue: "Authentication fails"
**Solution**:
1. Enable Google provider in Firebase Console
2. Add your test email to authorized testers
3. Verify app is using correct Firebase project
4. Check SHA-1 certificate matches

---

## File Locations

| File | Path | Purpose |
|------|------|---------|
| Config | `lib/firebase_options.dart` | Firebase project credentials |
| Init | `lib/main.dart` | Firebase initialization logic |
| Manifest | `android/app/src/main/AndroidManifest.xml` | Permissions & services |
| Build config | `android/app/build.gradle.kts` | Android build settings |
| Services JSON | `android/app/google-services.json` | Android Firebase config |

---

## Security Notes

### Do's ✅
- ✅ Commit `google-services.json` to git (not a secret)
- ✅ Use test mode for Firestore in development
- ✅ Enable security rules before production
- ✅ Use Firebase Auth for user verification

### Don'ts ❌
- ❌ Don't commit `KeyStore` files to git
- ❌ Don't hardcode API keys in Dart code
- ❌ Don't use test mode Firestore in production
- ❌ Don't expose private keys in version control

---

## Next Steps

1. ✅ Create Firebase project
2. ✅ Register Android app with SHA-1
3. ✅ Download `google-services.json`
4. ✅ Place in `android/app/google-services.json`
5. ✅ Update `firebase_options.dart` with credentials
6. ✅ Enable Google Authentication
7. ✅ Build and test: `flutter run -d android --flavor devFull`
8. ✅ Verify in Firebase Console

---

## Support

For detailed setup help:
- Firebase Docs: https://firebase.flutter.dev/
- Google Sign-In: https://pub.dev/packages/google_sign_in
- Crashlytics: https://firebase.google.com/docs/crashlytics

---

**Version:** 1.0  
**Status:** Complete Setup Guide  
**Last Updated:** June 23, 2026
