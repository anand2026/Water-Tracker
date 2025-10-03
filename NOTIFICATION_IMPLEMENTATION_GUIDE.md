# Flutter Water Tracker Notification System - Complete Implementation Guide

## Overview

This is a production-ready notification system for Flutter water tracker apps with comprehensive features including scheduling, actions, persistence, and reboot handling.

## Package Requirements

Add these dependencies to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_local_notifications: ^17.2.3
  timezone: ^0.9.2
  shared_preferences: ^2.2.2

dev_dependencies:
  flutter_test: ^3.0.0
```

## Core Components

### 1. Data Model (`models/water_reminder.dart`)
- `WaterReminder` class with scheduling logic
- `NotificationAction` enum for different actions
- `SnoozeDuration` helper class

### 2. Notification Manager (`services/notification_manager.dart`)
- Complete notification scheduling and management
- Permission handling for Android/iOS
- Interactive notification actions
- Persistence and storage

### 3. Navigation Service (`services/app_navigation_service.dart`)
- Deep linking from notifications
- App state management
- Example water logging screen

### 4. Reboot Handler (`services/reboot_handler.dart`)
- Handles device reboots
- App update scenarios
- Troubleshooting utilities

## Quick Setup

### 1. Initialize in your main.dart:

```dart
import 'services/notification_manager.dart';
import 'services/app_navigation_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize notification system
  final notificationManager = NotificationManager();
  await notificationManager.initialize();
  await notificationManager.requestPermissions();

  runApp(MyApp());
}
```

### 2. Set up in your app widget:

```dart
class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();

    // Set up navigation for deep links
    AppNavigationService().setNavigatorKey(_navigatorKey);

    // Handle notification taps
    NotificationManager.onNotificationTap = _handleNotificationTap;
  }

  void _handleNotificationTap(NotificationResponse response) {
    // Handle different notification actions
    switch (response.actionId) {
      case 'log_drink':
        AppNavigationService().navigateToWaterLogging();
        break;
      case 'snooze_5':
        AppNavigationService().showMessage('Snoozed for 5 minutes');
        break;
      // Handle other actions...
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      // Your app routes and screens...
    );
  }
}
```

### 3. Create and schedule reminders:

```dart
// Create a reminder
final reminder = WaterReminder(
  id: DateTime.now().millisecondsSinceEpoch.toString(),
  time: TimeOfDay(hour: 9, minute: 0),
  isEnabled: true,
);

// Add to notification manager
final notificationManager = NotificationManager();
await notificationManager.addReminder(reminder);
```

## Android Configuration

### 1. Update `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
<uses-permission android:name="android.permission.VIBRATE" />
<uses-permission android:name="android.permission.USE_EXACT_ALARM" />
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />

<application>
    <!-- Boot receiver for notification persistence -->
    <receiver android:name=".BootReceiver"
              android:enabled="true"
              android:exported="true">
        <intent-filter android:priority="1000">
            <action android:name="android.intent.action.BOOT_COMPLETED" />
            <action android:name="android.intent.action.QUICKBOOT_POWERON" />
        </intent-filter>
    </receiver>
</application>
```

### 2. Create `android/app/src/main/kotlin/.../BootReceiver.kt`:

```kotlin
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED ||
            intent.action == "android.intent.action.QUICKBOOT_POWERON") {

            // Launch app to reschedule notifications
            val launchIntent = context.packageManager
                .getLaunchIntentForPackage(context.packageName)
            launchIntent?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(launchIntent)
        }
    }
}
```

## iOS Configuration

### Update `ios/Runner/Info.plist`:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>background-processing</string>
</array>
```

## Features

### ✅ Multiple Daily Reminders
- Support for unlimited reminders
- Custom times and frequencies
- Active days configuration

### ✅ Interactive Notifications
- **Log Drink**: Direct navigation to logging screen
- **Snooze**: 5/10/15 minute options
- **Dismiss**: Cancel current notification

### ✅ Persistence & Reboot Handling
- Automatic rescheduling after device reboot
- SharedPreferences storage
- App update handling

### ✅ Permission Management
- Android 13+ notification permissions
- iOS permission requests
- Battery optimization handling

### ✅ Deep Linking
- Navigation to specific screens
- Payload handling
- App state management

## Usage Examples

### Managing Reminders:

```dart
final notificationManager = NotificationManager();

// Add reminder
await notificationManager.addReminder(reminder);

// Update reminder
await notificationManager.updateReminder(oldReminder, newReminder);

// Remove reminder
await notificationManager.removeReminder(reminderId);

// Enable/disable all notifications
await notificationManager.setGloballyEnabled(true);

// Check permissions
final granted = await notificationManager.arePermissionsGranted();

// Show test notification
await notificationManager.showTestNotification();
```

### Handling Snooze:

```dart
// Snooze for 5 minutes
await notificationManager.snoozeReminder(
  reminderId,
  SnoozeDuration.five
);
```

## Edge Cases Handled

### 🔄 Device Reboot
- Automatic detection and rescheduling
- Boot completed receiver implementation
- Persistent storage verification

### 🔋 Battery Optimization
- Detection of battery optimization settings
- User guidance for whitelisting
- Exact alarm permissions (Android 12+)

### 🌍 Timezone Changes
- Timezone-aware scheduling
- Automatic rescheduling on timezone change
- UTC to local time conversion

### 📱 App Updates
- Version tracking
- Notification rescheduling after updates
- Migration handling

### ⚠️ Permission Changes
- Runtime permission checking
- Graceful degradation
- User guidance for enabling permissions

## Troubleshooting

### Common Issues:

1. **Notifications not showing:**
   - Check permissions
   - Verify Do Not Disturb settings
   - Test battery optimization settings
   - Use test notification first

2. **Notifications stop after reboot:**
   - Implement boot receiver
   - Add RECEIVE_BOOT_COMPLETED permission
   - Test on physical device

3. **Deep links not working:**
   - Verify navigation setup
   - Check payload parsing
   - Test both foreground/background states

### Debug Utilities:

```dart
// Get debug information
final debugInfo = await NotificationTroubleshooting.getDebugInfo();

// Run full diagnostics
final results = await NotificationTroubleshooting.runDiagnostics();

// Get pending notifications
final pending = await notificationManager.getPendingNotifications();
```

## Testing Checklist

- [ ] Permissions request and check
- [ ] Immediate notifications
- [ ] Scheduled notifications
- [ ] Notification actions (Log, Snooze, Dismiss)
- [ ] Deep linking navigation
- [ ] Device reboot persistence
- [ ] Battery optimization scenarios
- [ ] Timezone changes
- [ ] App background/foreground states
- [ ] Multiple reminders
- [ ] Enable/disable functionality

## Production Deployment

### Pre-launch Checklist:

1. **Test on multiple devices:**
   - Different Android versions (8+)
   - iOS versions (12+)
   - Various manufacturers (Samsung, Xiaomi, etc.)

2. **Test edge cases:**
   - Device reboot
   - App force close
   - Battery optimization
   - Do Not Disturb mode
   - Airplane mode scenarios

3. **Performance testing:**
   - Multiple reminders (20+)
   - Memory usage
   - Battery impact
   - Notification delivery reliability

4. **User experience:**
   - Permission request flow
   - Onboarding guidance
   - Error handling
   - Graceful degradation

## Support and Maintenance

### Monitoring:
- Track notification delivery rates
- Monitor permission grant rates
- Log edge case occurrences
- User feedback collection

### Updates:
- Keep flutter_local_notifications updated
- Monitor Android/iOS policy changes
- Test with new OS versions
- Update permission handling as needed

This implementation provides a robust, production-ready notification system that handles all major edge cases and provides excellent user experience for water tracking reminders.