# Melodrift - Microsoft Store Submission Ready

**Status: READY FOR UPLOAD**

Date: June 25, 2026

---

## Package Ready

- **MSIX Package:** `build\windows\msix\Melodrift-Store-1.0.0.3-x64.msix`
- **Size:** ~28.8 MB
- **Signature:** Unsigned locally (Microsoft Store will sign during submission)
- **Architecture:** x64
- **Package Identity:** RajeevUpadhyay.Melodrift
- **Publisher:** CN=B5B77226-98E6-49B2-8097-AE0D40E6D727
- **Version:** 1.0.0.3

---

## Listing Content Ready

### Basic Info
- **App Name:** Melodrift
- **Category:** Music
- **Secondary Category:** Entertainment
- **Short Description:** "Melodrift is a polished desktop music client for discovering, playing, organizing, and managing your listening experience."

### Full Store Description
Available in `STORE_LISTING.md` (lines 24-41)

Key points:
- Emphasizes discovery, playback, local playlists, and app-managed offline support.
- Avoids third-party trademark references except the required independence disclaimer.
- Describes offline behavior as app-managed in-app playback, not unrestricted downloading.

### Search Terms
- music player
- music streaming
- playlist
- saved music
- desktop music
- audio player
- discovery
- melodrift

### Support Information
- **Support Email:** rajeev.upadhyay@live.in
- **Website:** https://rajeevupadhyay.com
- **Support URL:** https://rajeevupadhyay.com
- **Privacy Policy URL:** https://rockstarrajeev.github.io/melodrift/privacy-policy.html

---

## Age Rating Ready

- **Rating ID:** 3bc14cf1-7c80-8bab-8da0-3f52d83eca34
- **Rating Type:** IARC Rating
- **IARC Version:** 10.3
- **Status:** Completed in Partner Center

---

## Screenshots Ready

All screenshots exceed 1366 x 768 recommended size and are ready to upload:

1. **Home / Discovery:** `D:\Melodrift\Melodrift Top.png` (1579 x 957)
2. **Search:** `D:\Melodrift\Melodrift Search.png` (1575 x 960)
3. **Playback Controls:** `D:\Melodrift\Melodrift Bottom.png` (1575 x 959)
4. **Library / Playlists:** `D:\Melodrift\Melodrift Library.png` (1581 x 961)
5. **Settings:** `D:\Melodrift\Melodrift Settings.png` (1579 x 918)
6. **Logo Asset:** `D:\Melodrift\Melodrift-logo.png` (1024 x 1024)

---

## Final Compliance Checklist

- [x] Store package identity matches Partner Center reserved app.
- [x] Store MSIX generated with `store: true`.
- [x] Package manifest verified (Name, Publisher, Version, Architecture).
- [x] Local MSIX install and launch verified with test package.
- [x] Privacy policy draft created.
- [x] Public privacy policy URL published and verified.
- [x] Store screenshots captured and ready.
- [x] Age rating guidance drafted.
- [x] Age rating questionnaire completed and IARC rating assigned.
- [x] App description reviewed for trademark and affiliation language.
- [x] Download/offline behavior reviewed and wording tightened for policy risk.
- [x] Final manual smoke test completed on installed Windows app.

**All items complete. Ready for Partner Center submission.**

---

## Partner Center Submission Steps

1. **Log in to Partner Center:** https://partner.microsoft.com/
2. **Open your Melodrift app submission:**
   - Navigate to your app overview.
   - Click "Submit to Store" or "Create new submission."
3. **Upload Package:**
   - Go to "Packages" section.
   - Upload: `build\windows\msix\Melodrift-Store-1.0.0.3-x64.msix`
4. **Fill Listing Details:**
   - **Description:** Use the Store description from `STORE_LISTING.md` (lines 24-41).
   - **Short description:** "Melodrift is a polished desktop music client for discovering, playing, organizing, and managing your listening experience."
   - **Search terms:** Use the list from `STORE_LISTING.md` (lines 43-52).
   - **Publisher display name:** Rajeev Upadhyay
   - **Support contact:** rajeev.upadhyay@live.in
   - **Website:** https://rajeevupadhyay.com
   - **Privacy policy URL:** https://rockstarrajeev.github.io/melodrift/privacy-policy.html
5. **Add Screenshots:**
   - Upload all 5 screenshots (1-5 above) in recommended order.
   - Logo asset (6) is optional supplementary material.
6. **Verify Age Rating:**
   - Confirm IARC rating ID: 3bc14cf1-7c80-8bab-8da0-3f52d83eca34
   - Status should show as verified from Partner Center questionnaire.
7. **Content Rating:**
   - Select appropriate Windows rating based on IARC (typically PEGI 12 / ESRB 12+).
8. **Pricing & Availability:**
   - Set to "Free" (no charges).
   - Select target regions/languages.
9. **Review & Submit:**
   - Do a final visual check of listing text and screenshots.
   - Click "Submit."

---

## Post-Submission

- Microsoft will review the submission (typically 1-3 days).
- Review may ask clarifying questions about:
  - Content source rights and API/terms compliance.
  - Offline playback mechanism and licensing.
  - Independence from third-party music services.
- If approved: App will be published to Microsoft Store.
- If changes needed: You'll receive feedback and can resubmit.

---

## Important Reminders

- **Do NOT upload** `build\windows\msix\Melodrift-1.0.0.3-x64.msix` (the local test package).
- **Always upload** `build\windows\msix\Melodrift-Store-1.0.0.3-x64.msix` (the Store package).
- Microsoft Store will sign the package during submission—do not attempt to sign it locally.
- If Partner Center rejects the version, increment both `pubspec.yaml` version and `msix_config.msix_version`, then regenerate the MSIX.
- Keep the independence disclaimer in all public-facing descriptions.

---

## Files & Artifacts

**Store-Ready Assets in Project:**
- `build\windows\msix\Melodrift-Store-1.0.0.3-x64.msix` ← **Upload this**
- `STORE_LISTING.md` ← Reference for listing copy
- `PRIVACY_POLICY.md` ← Privacy policy source
- `privacy-policy.html` ← Web-ready privacy page (already published)
- `D:\Melodrift\*.png` ← Screenshots ready

**Project Root Files:**
- `.git/` (source control)
- `pubspec.yaml` (version: 1.0.0+3)
- All source files and dependencies

---

## Success

All Store-readiness steps are complete. The Melodrift Windows app is ready for upload to Microsoft Store.

Good luck with your submission! 🎵
