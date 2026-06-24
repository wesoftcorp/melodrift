# Crashlytics Integration - Error Monitoring

## Overview

The AppLogger now automatically sends error and fatal logs to **Firebase Crashlytics** for production monitoring. This enables real-time error tracking without exposing sensitive data.

## Features

### Automatic Error Capture
- **Errors**: `log.error()` calls → sent to Crashlytics
- **Fatal**: `log.fatal()` calls → marked as fatal crashes
- **Warnings & below**: Not sent (reduces noise)

### Smart Breadcrumb Logging
- Console output in debug mode (all levels)
- Breadcrumb trails in Crashlytics (errors/fatal only)
- Stack traces preserved when available
- Graceful fallback if Crashlytics fails

## Usage Examples

### Basic Error Logging
```dart
final log = AppLogger('MyService');

try {
  performSomeOperation();
} catch (e, stackTrace) {
  // This automatically sends to Crashlytics
  log.error('Operation failed', e, stackTrace);
}
```

### Fatal Errors
```dart
// Marks as fatal crash in Crashlytics
log.fatal('Critical failure in auth', exception, stackTrace);
```

### Message Only (No Exception)
```dart
// Breadcrumb logged to Crashlytics
log.error('Unexpected state detected - retrying');
```

## How It Works

### Log Levels & Routing

| Level | Console | Crashlytics | Fatal |
|-------|---------|-------------|-------|
| debug | ✅ (debug only) | ❌ | - |
| info | ✅ (debug only) | ❌ | - |
| warning | ✅ (debug only) | ❌ | - |
| error | ✅ (debug only) | ✅ | No |
| fatal | ✅ (all modes) | ✅ | Yes |

### Crashlytics Recording

1. **With Error + Stack Trace**
   ```dart
   crashlytics.recordError(
     error,
     stackTrace,
     reason: 'tag: message - error details',
     fatal: isFatal,
   );
   ```

2. **With Error Only**
   ```dart
   crashlytics.recordError(
     Exception('tag: message'),
     StackTrace.current,
     reason: 'Logged error: ERROR',
     fatal: isFatal,
   );
   ```

3. **Message Only (Breadcrumb)**
   ```dart
   crashlytics.log('[tag] ERROR: message');
   ```

## Production Configuration

### Firebase Setup Required
1. **Google Services Config**
   - `google-services.json` (Android)
   - `GoogleService-Info.plist` (iOS)

2. **Enable Crashlytics**
   - Add google-services plugin in `build.gradle`
   - Link to Firebase project in console

3. **View Dashboard**
   - Firebase Console → Crashlytics
   - Real-time error tracking & stack traces

### Privacy & Data Handling
- ✅ No sensitive user data is logged
- ✅ Errors are sanitized before sending
- ✅ Tags identify the source service
- ✅ Optional custom keys for debugging

## Error Handling

### Graceful Degradation
If Crashlytics fails to initialize or send:
- Error is silently caught
- Debug message printed (dev mode only)
- App continues normally
- Console logging still works

```dart
try {
  crashlytics.recordError(...);
} catch (e) {
  // Silent fail - don't crash the app
  debugPrint('Failed to send to Crashlytics: $e');
}
```

## Best Practices

### Do's ✅
```dart
// Good: Include context
log.error('Failed to download song: $songId', exception, stackTrace);

// Good: Use fatal for critical paths
log.fatal('Database corrupted, cannot recover', error, stackTrace);

// Good: Include retry logic
try {
  await retryOperation();
} catch (e, st) {
  log.error('Retry failed after 3 attempts', e, st);
}
```

### Don'ts ❌
```dart
// Bad: Don't log sensitive data
log.error('Auth failed for user: $userId'); // User ID exposed

// Bad: Don't flood with warnings
for (var item in items) {
  if (item.invalid) log.warning('Item invalid'); // Too many logs
}

// Bad: Don't ignore exceptions
try {
  operation();
} catch (e) {
  log.debug('Error: $e'); // Should be error level!
}
```

## Debugging

### Testing in Development
```dart
// Force test error reporting
final log = AppLogger('Test');
log.error('Test error', Exception('test'), StackTrace.current);

// Check Firebase Console → Crashlytics
// Should see the error appear within 30 seconds
```

### Local Testing
1. Run app with Firebase emulator
2. Trigger errors using `log.error()` or `log.fatal()`
3. Check Xcode Console (iOS) or Logcat (Android)
4. Verify Crashlytics receives events

### Disable for Testing
```dart
// Temporarily disable Crashlytics
await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(false);

// Enable after testing
await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
```

## Integration Points

### Audio Playback Errors
```dart
// In audio_handler.dart
try {
  await _player.play();
} catch (e, st) {
  _log.error('Audio playback failed', e, st);
  // Automatically sent to Crashlytics
}
```

### Network Errors
```dart
// In API services
try {
  final response = await dio.get(url);
} catch (e, st) {
  _log.error('Network request failed: $url', e, st);
}
```

### Database Errors
```dart
// In repository layer
try {
  await isar.writeTxn(() async {
    await songs.put(song);
  });
} catch (e, st) {
  _log.fatal('Database write failed', e, st);
}
```

## Monitoring Dashboard

### Firebase Console Access
1. Go to Firebase Console
2. Select Melodrift project
3. Navigate to Crashlytics section
4. View:
   - Error timeline
   - Affected users
   - Stack traces
   - Breadcrumbs trail
   - Crash statistics

### Alerts & Notifications
- Real-time alerts for new errors
- Regression detection
- User impact metrics
- Performance trends

## Implementation Status

- ✅ Crashlytics integration complete
- ✅ Error/Fatal logging to Crashlytics
- ✅ Stack trace preservation
- ✅ Graceful error handling
- ✅ No production performance impact
- ✅ Zero breaking changes

---

**Version:** 1.0  
**Status:** Production Ready  
**Last Updated:** June 23, 2026
