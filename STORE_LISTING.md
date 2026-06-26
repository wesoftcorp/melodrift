# Microsoft Store Listing Draft

This document tracks the content and compliance items needed before submitting Melodrift to Microsoft Store.

## Package

- App name: Melodrift
- Package identity name: RajeevUpadhyay.Melodrift
- Publisher: CN=B5B77226-98E6-49B2-8097-AE0D40E6D727
- Publisher display name: Rajeev Upadhyay
- Version: 1.0.0.3
- Architecture: x64
- Store MSIX: `build\windows\msix\Melodrift-Store-1.0.0.3-x64.msix`

## Category

- Primary category: Music
- Secondary category: Entertainment

## Short Description

Melodrift is a polished desktop music client for discovering, playing, organizing, and managing your listening experience.

## Store Description

Melodrift brings a clean, modern music experience to Windows with fast discovery, smooth playback controls, local playlists, and app-managed offline playback support where available.

Explore music through curated home sections, moods, genres, search, recommendations, and artist or playlist views. Melodrift keeps playback focused with queue management, repeat and shuffle controls, media controls, and a responsive desktop layout designed for daily listening.

Saved offline items are managed by Melodrift for in-app playback only. The app also caches home content to improve startup speed and reduce repeated network usage.

Key features:

- Discover music through search, recommendations, moods, genres, playlists, and artist sections.
- Play songs with queue, repeat, shuffle, next, previous, and media controls.
- Manage app-supported offline items for in-app playback.
- Manage local playlists and your saved listening library.
- Use a polished Windows desktop interface with modern visuals and responsive layouts.
- Clear cache and manage local optimization settings from the app.

Melodrift is an independent music client and is not affiliated with, endorsed by, or sponsored by YouTube, YouTube Music, or Google.

## Search Terms

- music player
- music streaming
- playlist
- saved music
- desktop music
- audio player
- discovery
- melodrift

## Support Information

- Support email: rajeev.upadhyay@live.in
- Website: https://rajeevupadhyay.com
- Support URL: https://rajeevupadhyay.com
- Privacy policy URL: https://rockstarrajeev.github.io/melodrift/privacy-policy.html

## Privacy Policy Draft

Melodrift stores app data locally on your device, including preferences, cache data, local playlists, and downloaded app-only music files.

The Windows Store build does not require account sign-in for basic playback and local downloads. If optional online services are enabled in future builds, the privacy policy must be updated before release.

Melodrift may connect to online music sources to search for content, load metadata, stream songs, and retrieve artwork. Network requests may be subject to the privacy practices of the upstream service providers.

Melodrift does not sell personal data.

Public privacy policy page is live at https://rockstarrajeev.github.io/melodrift/privacy-policy.html.

## Age Rating Notes

- Recommended age rating: 12+ or equivalent, depending on Microsoft questionnaire outcome.
- Current Rating ID: 3bc14cf1-7c80-8bab-8da0-3f52d83eca34
- Rating type: IARC Rating
- IARC version: 10.3
- The app can access online music content that may include explicit lyrics or mature themes.
- The app does not include gambling, user-generated social feeds, or in-app purchases in the current Windows Store package.

Suggested questionnaire answers:

- User-generated content: No, unless future collaboration features expose public user content.
- Online interaction: No public social interaction in current Windows Store package.
- In-app purchases: No.
- Location: No.
- Unrestricted web access: No browser, but the app accesses online music sources.
- Mature content: Yes/possible, because streamed music may include explicit lyrics or mature themes.
- Microphone: Yes, if voice search/song recognition is exposed in the Store build.

## Screenshot Checklist

Required screenshots should be captured from the installed MSIX app at production scale.

- [x] Home screen with discovery sections: `D:\Melodrift\Melodrift Top.png` (1579 x 957)
- [x] Search results screen: `D:\Melodrift\Melodrift Search.png` (1575 x 960)
- [x] Player or playback controls screen: `D:\Melodrift\Melodrift Bottom.png` (1575 x 959)
- [x] Queue or playlist/library screen: `D:\Melodrift\Melodrift Library.png` (1581 x 961)
- [ ] Downloads/offline music screen.
- [x] Settings screen with app information and cache controls: `D:\Melodrift\Melodrift Settings.png` (1579 x 918)
- [x] Logo asset available: `D:\Melodrift\Melodrift-logo.png` (1024 x 1024)

Recommended screenshot size: 1366 x 768 or larger, with no developer overlays, debug banners, private user data, or copyrighted album art shown in a way that creates avoidable review risk.

All provided screenshots meet the recommended size threshold. Before upload, visually confirm no private user data, debug overlays, or third-party trademark/logo usage is visible.

## Compliance Checklist

- [x] Store package identity matches Partner Center.
- [x] Store MSIX generated with `store: true`.
- [x] Package manifest verified.
- [x] Local MSIX install and launch verified with test package.
- [x] Privacy policy draft created in `PRIVACY_POLICY.md`.
- [x] Public privacy policy URL created.
- [x] Store screenshots captured.
- [x] Store age rating guidance drafted.
- [x] Store age rating questionnaire completed in Partner Center.
- [x] App description reviewed for trademark and affiliation language.
- [x] Download/offline behavior reviewed for copyright and platform policy risk.
- [x] Final manual smoke test completed on installed package.

## Policy Risk Notes

- Store-facing copy avoids using third-party trademarks except in the required independence disclaimer.
- Offline wording has been reduced to app-managed in-app playback support and does not describe unrestricted content downloading.
- Melodrift uses online music discovery/playback integrations; Store review may ask about content source rights and API/terms compliance.
- Keep the independence disclaimer in the Store description.
- Do not use YouTube, Google, or other third-party logos in screenshots, icons, or promotional assets.

## Submission Notes

- Upload package: `build\windows\msix\Melodrift-Store-1.0.0.3-x64.msix`
- Do not upload the local test MSIX: `build\windows\msix\Melodrift-1.0.0.3-x64.msix`
- Microsoft Store signs the Store package during submission.
- If Partner Center requires a higher version, update both `pubspec.yaml` `version` and `msix_config.msix_version`, then regenerate the MSIX.
