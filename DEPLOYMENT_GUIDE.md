# Melodrift Deployment & Rollout Guide

This guide provides step-by-step instructions to set up your environment, run the app in development, and compile release builds of **Melodrift** for both **Windows Desktop** and **Android**.

---

## Table of Contents
1. [Phase 1: Prerequisites & Installations](#phase-1-prerequisites--installations)
2. [Phase 2: Windows Desktop Deployment](#phase-2-windows-desktop-deployment)
3. [Phase 3: Android App Deployment](#phase-3-android-app-deployment)
4. [Troubleshooting & Common Issues](#troubleshooting--common-issues)

---

## Phase 1: Prerequisites & Installations

Before building the app, you need to install the build toolchains for Windows and Android on your PC.

### 1. Windows Build Tools (C++)
To compile native C++ code for Windows, you need **Visual Studio**:
1. Download and install **Visual Studio Community 2022** from [visualstudio.microsoft.com](https://visualstudio.microsoft.com/).
2. During the installation wizard, check the workload:
   * **Desktop development with C++** (this installs the necessary C++ compilers, MSBuild toolchain, and Windows SDKs).
3. Complete the installation and restart your computer if prompted.

### 2. Android Build Tools (SDK)
To compile and package the app for Android, you need the **Android SDK**:
1. Download and install **Android Studio** from [developer.android.com/studio](https://developer.android.com/studio).
2. Launch Android Studio, go through the setup wizard (default options are fine).
3. Install the SDK Command-line Tools:
   * Open Android Studio.
   * Go to **Tools > SDK Manager** (or **Settings > Appearance & Behavior > System Settings > Android SDK**).
   * Select the **SDK Tools** tab.
   * Check **Android SDK Command-line Tools (latest)**.
   * Click **Apply** and follow the prompts to install.

### 3. Verify Your Environment
Run the Flutter doctor tool to verify that both toolchains are correctly configured:
```powershell
# Run from the melodrift directory
..\.flutter_sdk\bin\flutter doctor
```
Ensure that both **Windows Version / Visual Studio** and **Android toolchain** have green checkmarks.

---

## Phase 2: Windows Desktop Deployment

Once the C++ toolchain is ready, you can run or build the desktop variant of Melodrift.

### 1. Run in Development (Debug Mode)
To launch the app directly on your desktop screen with hot-reload enabled:
```powershell
..\.flutter_sdk\bin\flutter run -d windows
```

### 2. Build Release Executable
To package the app into a high-performance standalone application:
```powershell
..\.flutter_sdk\bin\flutter build windows --release
```
* **Output Path:** `build\windows\x64\runner\Release\`
* **How to Distribute:** 
  Copy the entire `Release` folder. The folder contains `melodrift.exe` and required `.dll` companion files. If you move `melodrift.exe` out of this folder without its accompanying files, the app will fail to run.

---

## Phase 3: Android App Deployment

### 1. Set Up Your Phone (Developer Mode)
To run the app directly on your physical Android phone:
1. Connect your phone to your computer using a USB cable.
2. Enable Developer Options:
   * Go to **Settings > About Phone** on your phone.
   * Tap **Build Number** 7 times until you see the toast "You are now a developer!".
3. Enable USB Debugging:
   * Go back to Settings, search for **Developer Options**.
   * Turn on **USB Debugging**.
   * A prompt will appear on your phone asking to trust your computer. Select **Always allow from this computer** and tap **OK**.

### 2. Verify Connection
Check if your phone is recognized:
```powershell
..\.flutter_sdk\bin\flutter devices
```
You should see your mobile device list name and ID in the terminal.

### 3. Run on Phone (Debug Mode)
To install and run the app directly on your connected phone:
```powershell
..\.flutter_sdk\bin\flutter run -d <your-device-id>
```

### 4. Build Release Installer (APK)
Melodrift supports two distinct flavors: FOSS (Free and Open Source Software) and Full (with Firebase/Google services).

#### A. Build FOSS Variant
*Completely free of proprietary dependencies (does not attempt to contact Firebase/Google Auth).*
```powershell
..\.flutter_sdk\bin\flutter build apk --flavor foss -t lib/main.dart
```
* **Output Path:** `build\app\outputs\flutter-apk\app-foss-release.apk`

#### B. Build Full Variant
*Supports Google Sign-in and online collaborative rooms synchronization.*
```powershell
..\.flutter_sdk\bin\flutter build apk --flavor full -t lib/main.dart
```
* **Output Path:** `build\app\outputs\flutter-apk\app-full-release.apk`

---

## Troubleshooting & Common Issues

### 1. "Visual Studio is missing" / Windows build fails
* Ensure you installed **Visual Studio 2022** and checked the **Desktop development with C++** workload. VS Code is not sufficient to compile desktop apps.

### 2. "Android SDK not found" / Licenses not accepted
* Open Android Studio, open the terminal, and run:
  ```powershell
  ..\.flutter_sdk\bin\flutter doctor --android-licenses
  ```
  Press `y` to accept all licenses.

### 3. App crashes on Android startup (Full Flavor)
* If you run the **Full** flavor with Firebase enabled but haven't loaded native `google-services.json` credentials, the app's initialization catches the error and runs in local fallback guest mode. If you see crashes, make sure you configure your Firebase console credentials or run the **FOSS** flavor.
