# Firebase Setup - Quick Checklist

## 🚀 Quick Start (5 minutes)

### Step 1: Create Firebase Project (2 min)
- [ ] Go to https://console.firebase.google.com/
- [ ] Click "Add project" → Name: "Melodrift"
- [ ] Accept terms → Create project
- [ ] Wait for setup to complete

### Step 2: Get Debug Signing Certificate (1 min)
Run this command:
```bash
keytool -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
```
Copy the **SHA1** value

### Step 3: Register Android App (1 min)
1. In Firebase Console → Project Settings → Add app
2. Select Android
3. **Package name**: `com.melodrift.dev` (for testing)
4. **SHA-1**: Paste the value from Step 2
5. Click "Register app"
6. Download `google-services.json`

### Step 4: Add Config File (1 min)
1. Place `google-services.json` here: `android/app/google-services.json`
2. Update `lib/firebase_options.dart` with your project details

### Step 5: Build & Test (30 sec)
```bash
flutter run -d android --flavor devFull
```

---

## 📋 Detailed Setup Steps

### Step 1: Create Firebase Project

**1.1 - Go to Firebase Console**
- Open: https://console.firebase.google.com/
- Sign in with your Google account

**1.2 - Create New Project**
- Click "Add project"
- Project name: `Melodrift`
- Accept Google Analytics terms (optional)
- Click "Create project"
- Wait 1-2 minutes...

**1.3 - Project Created ✅**
- You'll see the Firebase dashboard
- Note your Project ID (visible in console)

---

### Step 2: Get Android Debug Certificate

**2.1 - Open Terminal/PowerShell**
```bash
keytool -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
```

**2.2 - Find SHA1**
Output will show:
```
Certificate fingerprints:
	SHA1: AB:CD:EF:12:34:56:78:90:...
```

Copy the entire SHA1 value (without spaces for Firebase)

---

### Step 3: Register Android App

**3.1 - Add Android App**
1. Firebase Console → Project Settings
2. Click "Add app" → Choose Android

**3.2 - Fill in App Details**
- **Android package name**: `com.melodrift.dev`
- **App nickname**: Melodrift Dev (optional)
- **Debug signing certificate SHA-1**: Paste from Step 2.2

**3.3 - Register & Download**
1. Click "Register app"
2. Firebase generates `google-services.json`
3. Click "Download google-services.json"
4. Save the file

---

### Step 4: Configure Firebase in App

**4.1 - Place google-services.json**
```
android/app/google-services.json  ← Place it here
```

**4.2 - Update firebase_options.dart**

From `google-services.json`, find these values:
```json
{
  "project_info": {
    "project_number": "123456789",
    "project_id": "melodrift-abc123"
  },
  "client": [{
    "client_info": {
      "mobilesdk_app_id": "1:123456789:android:abc123def456"
    },
    "api_key": [{ "current_key": "AIzaSyD..." }]
  }]
}
```

Update `lib/firebase_options.dart`:
```dart
case TargetPlatform.android:
  return const FirebaseOptions(
    apiKey: 'AIzaSyD_YOUR_API_KEY_HERE',
    appId: '1:123456789:android:abc123def456',
    messagingSenderId: '123456789',
    projectId: 'melodrift-abc123',
    databaseURL: 'https://melodrift-abc123-default-rtdb.firebaseio.com',
  );
```

---

### Step 5: Enable Firebase Services

**5.1 - Enable Google Authentication** (Optional but recommended)
1. Firebase Console → Build → Authentication
2. Click "Get Started"
3. Select "Google" provider
4. Toggle "Enable"
5. Add your email as test user

**5.2 - Crashlytics** (Automatic)
- First crash will auto-enable
- Check: Build → Crashlytics after testing

**5.3 - Realtime Database** (Optional)
1. Build → Realtime Database
2. Click "Create Database"
3. Start in test mode
4. Region: us-central1
5. Click "Enable"

---

### Step 6: Build & Test

**6.1 - Clean & Get Dependencies**
```bash
cd D:\Code\Antigravity\My_Projects\melodrift
flutter clean
flutter pub get
```

**6.2 - Build APK**
```bash
flutter build apk --flavor devFull -t lib/main_dev_full.dart --debug
```

**6.3 - Run on Device/Emulator**
```bash
flutter run -d android --flavor devFull
```

**6.4 - Verify in Console**
1. Watch console logs for: `Firebase initialized successfully`
2. Go to Firebase Console → Build → Crashlytics
3. Should see your app appear within 30 seconds

---

## 🔧 File Reference

| File | Location | Purpose |
|------|----------|---------|
| Config JSON | `android/app/google-services.json` | Firebase project credentials |
| Options | `lib/firebase_options.dart` | Dart Firebase configuration |
| Init | `lib/main.dart` | Firebase initialization & error handling |
| Build | `android/app/build.gradle.kts` | Android build configuration |

---

## ✅ Verification Checklist

After setup, verify these work:

- [ ] `google-services.json` placed in `android/app/`
- [ ] `firebase_options.dart` has real credentials (not mock)
- [ ] `flutter analyze` passes (0 errors)
- [ ] `flutter build apk --flavor devFull --debug` succeeds
- [ ] App launches without Firebase errors
- [ ] Console shows: `Firebase initialized successfully`
- [ ] Firebase Console shows app in Crashlytics
- [ ] Authentication is enabled (optional)

---

## 🚨 Troubleshooting

### Error: "google-services.json not found"
✅ **Solution**: 
```bash
# Make sure file is at:
android/app/google-services.json
# Not at:
android/google-services.json  ← Wrong!
```

### Error: "Firebase initialization failed"
✅ **Solution**:
1. Verify `google-services.json` is valid JSON
2. Check `firebase_options.dart` has correct project ID
3. Ensure Android package name matches Firebase config
4. Run: `flutter clean && flutter pub get && flutter run -d android --flavor devFull`

### Error: "Crashlytics not showing events"
✅ **Solution**:
1. First event takes 2-5 minutes to appear
2. Refresh Firebase Console
3. Check app has internet connection
4. Verify Crashlytics is enabled in Firebase

### Error: "MissingPluginException"
✅ **Solution**:
```bash
flutter clean
flutter pub get
flutter run -d android --flavor devFull
```

### Firebase not initializing (using FOSS flavor)
✅ **This is expected** - FOSS flavors don't use Firebase
- Use `devFull` or `prodFull` for Firebase

---

## 📱 Which Flavor to Use?

| Flavor | Firebase | Use Case |
|--------|----------|----------|
| **devFoss** | ❌ No | Quick testing, no setup needed |
| **devFull** | ✅ Yes | Testing with Firebase |
| **prodFoss** | ❌ No | Production, no Google services |
| **prodFull** | ✅ Yes | Production with Firebase |

---

## 🎯 Next Steps

After Firebase is set up:

1. ✅ Test app launches without errors
2. ✅ Verify Crashlytics receives errors
3. ✅ Test Google Sign-In (if implementing)
4. ✅ Test Realtime Database (if implementing)
5. ✅ Build release APK for Play Store

---

## 📚 Resources

- Firebase Docs: https://firebase.flutter.dev/
- Setup Guide: `.planning/FIREBASE_SETUP.md`
- Options Template: `lib/firebase_options.dart`
- JSON Template: `android/app/google-services.json.template`

---

**Time to complete: ~5-10 minutes**  
**Status: Quick Setup Ready**  
**Last Updated: June 23, 2026**
