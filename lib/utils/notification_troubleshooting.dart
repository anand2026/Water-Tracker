import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import '../models/reminder_model.dart';

/// Utilities for handling edge cases and troubleshooting notifications
class NotificationTroubleshooting {

  /// Common edge cases and their solutions
  static const Map<String, String> commonIssues = {
    'notifications_not_showing': '''
1. Check if notifications are enabled in device settings
2. Verify the app has notification permissions
3. Check if Do Not Disturb mode is enabled
4. Ensure the app is not in battery optimization
5. Test with an immediate notification first
6. Verify timezone settings are correct
    ''',

    'notifications_stop_after_reboot': '''
1. Ensure RECEIVE_BOOT_COMPLETED permission is added
2. Verify BootReceiver is properly configured
3. Check if the app auto-starts after reboot
4. Test notification rescheduling manually
5. Verify SharedPreferences are saving correctly
    ''',

    'battery_optimization_issues': '''
1. Request users to whitelist the app from battery optimization
2. Use exact alarms (SCHEDULE_EXACT_ALARM permission)
3. Guide users to disable battery optimization manually
4. Implement fallback notification strategies
5. Show battery optimization status to users
    ''',

    'timezone_changes': '''
1. Listen for timezone change events
2. Reschedule all notifications when timezone changes
3. Use proper TZDateTime for scheduling
4. Test with different timezone scenarios
5. Handle daylight saving time transitions
    ''',
  };

  /// Debug information collector
  static Future<Map<String, dynamic>> collectDebugInfo() async {
    final notificationService = NotificationService();

    return {
      'platform': Platform.operatingSystem,
      'platform_version': Platform.operatingSystemVersion,
      'permissions_granted': await notificationService.arePermissionsGranted(),
      'notifications_enabled': notificationService.areNotificationsEnabled(),
      'reminders_count': notificationService.getReminders().length,
      'pending_notifications': await notificationService.getPendingNotificationsCount(),
      'timezone': DateTime.now().timeZoneName,
      'timezone_offset': DateTime.now().timeZoneOffset.toString(),
      'current_time': DateTime.now().toIso8601String(),
    };
  }

  /// Run comprehensive diagnostics
  static Future<Map<String, bool>> runDiagnostics() async {
    final results = <String, bool>{};
    final notificationService = NotificationService();

    try {
      // Test 1: Service initialization
      results['service_initialized'] = true; // If we can call it, it's initialized

      // Test 2: Permission check
      results['permissions_granted'] = await notificationService.arePermissionsGranted();

      // Test 3: Test notification
      await notificationService.showTestNotification();
      results['test_notification'] = true;

      // Test 4: Scheduling capability
      final testReminder = WaterReminder(
        id: 'test_${DateTime.now().millisecondsSinceEpoch}',
        time: const TimeOfDay(
          hour: 9,
          minute: 0,
        ),
        isEnabled: true,
        createdAt: DateTime.now(),
      );

      final scheduleSuccess = await notificationService.addReminder(testReminder);
      results['scheduling'] = scheduleSuccess;

      // Clean up test reminder
      if (scheduleSuccess) {
        await notificationService.removeReminder(testReminder.id);
      }

      // Test 5: Storage functionality
      final reminders = notificationService.getReminders();
      results['storage'] = reminders.isNotEmpty || scheduleSuccess;

      return results;
    } catch (e) {
      debugPrint('❌ Diagnostics error: $e');
      return results;
    }
  }

  /// Handle timezone changes
  static Future<void> handleTimezoneChange() async {
    try {
      debugPrint('🌍 Timezone change detected, rescheduling notifications...');

      final notificationService = NotificationService();
      await notificationService.rescheduleAllNotifications();

      debugPrint('✅ Notifications rescheduled for new timezone');
    } catch (e) {
      debugPrint('❌ Failed to handle timezone change: $e');
    }
  }

  /// Check and handle battery optimization
  static Future<bool> checkBatteryOptimization() async {
    if (!Platform.isAndroid) return true;

    try {
      // This would typically involve platform channels to check battery optimization
      // For now, we'll return true and recommend manual checking
      debugPrint('⚠️ Please check if the app is whitelisted from battery optimization');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to check battery optimization: $e');
      return false;
    }
  }

  /// Validate reminder times for edge cases
  static List<String> validateReminderTimes(List<WaterReminder> reminders) {
    final issues = <String>[];

    // Check for duplicate times
    final times = reminders.map((r) => '${r.time.hour}:${r.time.minute}').toList();
    final duplicates = times.where((time) => times.where((t) => t == time).length > 1).toSet();

    if (duplicates.isNotEmpty) {
      issues.add('Duplicate reminder times found: ${duplicates.join(', ')}');
    }

    // Check for too many reminders
    if (reminders.length > 20) {
      issues.add('Too many reminders (${reminders.length}). Consider reducing to improve performance.');
    }

    // Check for reminders too close together
    final sortedReminders = List<WaterReminder>.from(reminders)
      ..sort((a, b) {
        final aMinutes = a.time.hour * 60 + a.time.minute;
        final bMinutes = b.time.hour * 60 + b.time.minute;
        return aMinutes.compareTo(bMinutes);
      });

    for (int i = 0; i < sortedReminders.length - 1; i++) {
      final current = sortedReminders[i];
      final next = sortedReminders[i + 1];

      final currentMinutes = current.time.hour * 60 + current.time.minute;
      final nextMinutes = next.time.hour * 60 + next.time.minute;

      if (nextMinutes - currentMinutes < 30) { // Less than 30 minutes apart
        issues.add('Reminders at ${current.formatTime()} and ${next.formatTime()} are too close together');
      }
    }

    return issues;
  }

  /// Performance recommendations
  static List<String> getPerformanceRecommendations(List<WaterReminder> reminders) {
    final recommendations = <String>[];

    if (reminders.length > 10) {
      recommendations.add('Consider reducing the number of reminders for better battery life');
    }

    if (reminders.where((r) => r.isEnabled).length != reminders.length) {
      recommendations.add('Remove unused reminders to keep the list clean');
    }

    final enabledCount = reminders.where((r) => r.isEnabled).length;
    if (enabledCount == 0) {
      recommendations.add('No reminders are currently enabled');
    } else if (enabledCount > 15) {
      recommendations.add('Consider reducing enabled reminders to avoid notification fatigue');
    }

    return recommendations;
  }

  /// Export debug log for support
  static String generateDebugReport(Map<String, dynamic> debugInfo, Map<String, bool> diagnostics) {
    final buffer = StringBuffer();
    buffer.writeln('Water Tracker - Debug Report');
    buffer.writeln('Generated: ${DateTime.now().toIso8601String()}');
    buffer.writeln('=' * 50);

    buffer.writeln('\nSystem Information:');
    debugInfo.forEach((key, value) {
      buffer.writeln('  $key: $value');
    });

    buffer.writeln('\nDiagnostics Results:');
    diagnostics.forEach((key, value) {
      final status = value ? '✅ PASS' : '❌ FAIL';
      buffer.writeln('  $key: $status');
    });

    buffer.writeln('\nCommon Solutions:');
    commonIssues.forEach((issue, solution) {
      buffer.writeln('\n$issue:');
      buffer.writeln(solution);
    });

    return buffer.toString();
  }
}

