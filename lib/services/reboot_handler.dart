import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'notification_manager.dart';
import '../models/water_reminder.dart';

/// Handles notification persistence across device reboots
class RebootHandler {
  static final RebootHandler _instance = RebootHandler._internal();
  factory RebootHandler() => _instance;
  RebootHandler._internal();

  static const String _lastBootTimeKey = 'last_boot_time';
  static const String _appVersionKey = 'app_version';

  /// Initialize reboot handling - call this in your app's initState
  Future<void> initialize() async {
    await _checkForRebootAndReschedule();
  }

  /// Check if device was rebooted and reschedule notifications if needed
  Future<void> _checkForRebootAndReschedule() async {
    try {
      final currentBootTime = await _getCurrentBootTime();
      final lastKnownBootTime = await _getLastKnownBootTime();

      // If boot time is different or this is first run, reschedule
      if (currentBootTime != lastKnownBootTime) {
        if (kDebugMode) {
          print('🔄 Device reboot detected, rescheduling notifications...');
        }

        // Reschedule all notifications
        final notificationManager = NotificationManager();
        await notificationManager.rescheduleAllReminders();

        // Store new boot time
        await _storeBootTime(currentBootTime);

        if (kDebugMode) {
          print('✅ Notifications rescheduled after reboot');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error handling reboot: $e');
      }
    }
  }

  /// Get current device boot time (simplified implementation)
  Future<int> _getCurrentBootTime() async {
    // This is a simplified implementation
    // In a real app, you might want to use a more robust method
    // such as checking system uptime or using platform-specific APIs

    if (Platform.isAndroid) {
      // On Android, you could use platform channels to get boot time
      // For now, we'll use a simplified approach
      return DateTime.now().millisecondsSinceEpoch ~/ 86400000; // Day-based approximation
    } else if (Platform.isIOS) {
      // iOS handles notification persistence automatically in most cases
      return DateTime.now().millisecondsSinceEpoch ~/ 86400000;
    }

    return 0;
  }

  /// Get last known boot time from storage
  Future<int> _getLastKnownBootTime() async {
    try {
      // This would typically use SharedPreferences
      // For this example, we'll return 0 (indicating first run)
      return 0;
    } catch (e) {
      return 0;
    }
  }

  /// Store current boot time
  Future<void> _storeBootTime(int bootTime) async {
    try {
      // This would typically use SharedPreferences
      // await prefs.setInt(_lastBootTimeKey, bootTime);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to store boot time: $e');
      }
    }
  }

  /// Handle app update scenarios
  Future<void> handleAppUpdate(String newVersion) async {
    try {
      final lastVersion = await _getLastAppVersion();

      if (lastVersion != newVersion) {
        if (kDebugMode) {
          print('📱 App update detected: $lastVersion -> $newVersion');
        }

        // Reschedule notifications after app update
        final notificationManager = NotificationManager();
        await notificationManager.rescheduleAllReminders();

        // Store new version
        await _storeAppVersion(newVersion);

        if (kDebugMode) {
          print('✅ Notifications rescheduled after app update');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error handling app update: $e');
      }
    }
  }

  Future<String> _getLastAppVersion() async {
    // This would typically use SharedPreferences
    return '';
  }

  Future<void> _storeAppVersion(String version) async {
    // This would typically use SharedPreferences
    // await prefs.setString(_appVersionKey, version);
  }
}

/// Android-specific broadcast receiver handling (requires native implementation)
/// Add this to your Android manifest and implement in MainActivity:
/*
<receiver android:name=".BootReceiver" android:enabled="true" android:exported="true">
    <intent-filter android:priority="1000">
        <action android:name="android.intent.action.BOOT_COMPLETED" />
        <action android:name="android.intent.action.QUICKBOOT_POWERON" />
        <category android:name="android.intent.category.DEFAULT" />
    </intent-filter>
</receiver>

<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
*/

/// Edge cases and troubleshooting guide
class NotificationTroubleshooting {
  /// Common edge cases and their solutions
  static const Map<String, String> edgeCases = {
    'notifications_not_showing': '''
    1. Check notification permissions
    2. Verify device is not in Do Not Disturb mode
    3. Check if app is whitelisted from battery optimization
    4. Ensure notifications are enabled for the app in system settings
    5. Test with immediate notification first
    ''',

    'notifications_stop_after_reboot': '''
    1. Implement proper reboot handling (RebootHandler)
    2. Add RECEIVE_BOOT_COMPLETED permission in Android manifest
    3. Ensure notifications are rescheduled in app initialization
    4. Test on actual device (not emulator)
    ''',

    'timezone_changes': '''
    1. Listen for timezone change events
    2. Reschedule all notifications when timezone changes
    3. Use timezone-aware scheduling with proper TZDateTime
    4. Test with different timezones
    ''',

    'battery_optimization': '''
    1. Request to disable battery optimization for your app
    2. Guide users to whitelist the app manually
    3. Use exact alarms permission on Android 12+
    4. Implement fallback mechanisms
    ''',

    'notifications_inconsistent': '''
    1. Use exact scheduling mode (exactAllowWhileIdle)
    2. Avoid scheduling too many notifications at once
    3. Handle notification limits on different Android versions
    4. Implement proper error handling and retry logic
    ''',

    'deep_links_not_working': '''
    1. Ensure proper app state management
    2. Handle both foreground and background navigation
    3. Test notification actions thoroughly
    4. Implement proper payload parsing
    ''',
  };

  /// Debug information helper
  static Future<Map<String, dynamic>> getDebugInfo() async {
    final notificationManager = NotificationManager();
    final pendingNotifications = await notificationManager.getPendingNotifications();

    return {
      'platform': Platform.operatingSystem,
      'permissions_granted': await notificationManager.arePermissionsGranted(),
      'globally_enabled': notificationManager.isGloballyEnabled(),
      'pending_notifications_count': pendingNotifications.length,
      'reminders_count': notificationManager.getReminders().length,
      'timezone': DateTime.now().timeZoneName,
    };
  }

  /// Test all notification functionality
  static Future<Map<String, bool>> runDiagnostics() async {
    final results = <String, bool>{};
    final notificationManager = NotificationManager();

    try {
      // Test initialization
      results['initialization'] = await notificationManager.initialize();

      // Test permissions
      results['permissions'] = await notificationManager.arePermissionsGranted();

      // Test immediate notification
      await notificationManager.showTestNotification();
      results['immediate_notification'] = true;

      // Test scheduling
      final testReminder = WaterReminder(
        id: 'test_${DateTime.now().millisecondsSinceEpoch}',
        time: TimeOfDay(
          hour: DateTime.now().hour,
          minute: DateTime.now().minute + 1,
        ),
        isEnabled: true,
      );

      results['scheduling'] = await notificationManager.addReminder(testReminder);

      // Clean up test reminder
      await notificationManager.removeReminder(testReminder.id);

      return results;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Diagnostics error: $e');
      }
      return results;
    }
  }
}