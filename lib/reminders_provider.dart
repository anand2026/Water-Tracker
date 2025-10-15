import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'notification_service.dart';
import 'notification_permission_provider.dart';
import 'models/water_reminder.dart';

class RemindersProvider extends ChangeNotifier {
  List<WaterReminder> _reminders = [];
  bool _remindersEnabled = true;

  // Getters
  List<WaterReminder> get reminders => _reminders;
  bool get remindersEnabled => _remindersEnabled;
  bool get permissionsGranted => NotificationPermissionProvider.instance.isGranted;

  // Initialize with default reminders and load from storage
  void initialize() {
    // Notify listeners immediately for fast UI rendering
    notifyListeners();

    // Initialize asynchronously without blocking UI
    _initializeAsync();
  }

  void _initializeAsync() async {
    try {
      await _loadReminders();

      // Clean up any duplicate reminders and save if changed
      final originalCount = _reminders.length;
      _removeDuplicateReminders();
      if (_reminders.length != originalCount) {
        await _saveReminders();
      }

      // Schedule notifications if enabled and permissions are granted
      if (_remindersEnabled && permissionsGranted) {
        await _scheduleAllReminders();
      }

      // Notify listeners after initialization
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('RemindersProvider initialization error: $e');
      }
    }
  }

  void _removeDuplicateReminders() {
    final seen = <String>{};
    final uniqueReminders = <WaterReminder>[];

    for (final reminder in _reminders) {
      final key = '${reminder.time.hour}:${reminder.time.minute}';
      if (!seen.contains(key)) {
        seen.add(key);
        uniqueReminders.add(reminder);
      } else {
        if (kDebugMode) {
          print('Removing duplicate reminder at ${reminder.time}');
        }
      }
    }

    if (uniqueReminders.length != _reminders.length) {
      _reminders = uniqueReminders;
      if (kDebugMode) {
        print('Cleaned up duplicates. Now have ${_reminders.length} unique reminders');
      }
    }
  }



  Future<void> setRemindersEnabled(bool enabled) async {
    _remindersEnabled = enabled;

    if (enabled && permissionsGranted) {
      await _scheduleAllReminders();
    } else {
      await NotificationService.instance.cancelAllNotifications();
    }

    await _saveReminders();
    notifyListeners();
  }

  Future<void> addReminder(WaterReminder reminder) async {
    // Check for duplicates first
    final existingIndex = _reminders.indexWhere((r) =>
        r.time.hour == reminder.time.hour &&
        r.time.minute == reminder.time.minute);

    if (existingIndex != -1) {
      if (kDebugMode) {
        print('Duplicate reminder detected, updating existing one');
      }
      // Update existing instead of adding duplicate
      _reminders[existingIndex] = reminder;
    } else {
      // Add new reminder
      _reminders.add(reminder);
    }

    _sortReminders();
    notifyListeners();

    // Do background work without blocking UI
    _addReminderBackground(reminder);
  }

  void _addReminderBackground(WaterReminder reminder) async {
    try {
      if (_remindersEnabled && permissionsGranted && reminder.isEnabled) {
        await _scheduleReminder(reminder);
      }
      await _saveReminders();
    } catch (e) {
      if (kDebugMode) {
        print('Error in background add reminder: $e');
      }
    }
  }

  Future<void> updateReminder(int index, WaterReminder newReminder) async {
    final oldReminder = _reminders[index];
    _reminders[index] = newReminder;
    _sortReminders();

    // Cancel old notification with safety check
    try {
      final oldId = int.parse(oldReminder.id);
      await NotificationService.instance.cancelNotification(oldId);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error canceling old notification: $e');
      }
    }

    // Schedule new notification if enabled
    if (_remindersEnabled && permissionsGranted && newReminder.isEnabled) {
      await _scheduleReminder(newReminder);
    }

    await _saveReminders();
    notifyListeners();
  }

  void toggleReminder(int index, bool enabled) {
    final reminder = _reminders[index];

    // Update UI immediately
    _reminders[index] = reminder.copyWith(isEnabled: enabled);
    notifyListeners();

    // Do background work
    _toggleReminderBackground(reminder, enabled);
  }

  void _toggleReminderBackground(WaterReminder reminder, bool enabled) async {
    try {
      if (enabled && _remindersEnabled && permissionsGranted) {
        await _scheduleReminder(reminder.copyWith(isEnabled: enabled));
      } else {
        try {
          final reminderId = int.parse(reminder.id);
          await NotificationService.instance.cancelNotification(reminderId);
        } catch (e) {
          if (kDebugMode) {
            print('❌ Error canceling toggle notification: $e');
          }
        }
      }
      await _saveReminders();
    } catch (e) {
      if (kDebugMode) {
        print('Error in background toggle reminder: $e');
      }
    }
  }

  void deleteReminder(int index) {
    final reminder = _reminders[index];

    // Remove from UI immediately - completely synchronous
    _reminders.removeAt(index);
    notifyListeners();

    // Do cleanup in background but don't restore on failure
    _deleteReminderBackground(reminder);
  }

  void _deleteReminderBackground(WaterReminder reminder) async {
    try {
      // Cancel notification in background - if this fails, that's okay
      try {
        final reminderId = int.parse(reminder.id);
        await NotificationService.instance.cancelNotification(reminderId);
      } catch (parseError) {
        if (kDebugMode) {
          print('❌ Error parsing notification ID for deletion: $parseError');
        }
      }

      // Save changes
      await _saveReminders();

      if (kDebugMode) {
        print('✅ Reminder deleted successfully: ${reminder.time}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Error in background deletion (not critical): $e');
        // Don't restore the reminder - deletion should be final from user perspective
      }

      // Still try to save the current state
      try {
        await _saveReminders();
      } catch (saveError) {
        if (kDebugMode) {
          print('Error saving after failed deletion: $saveError');
        }
      }
    }
  }

  Future<void> _scheduleAllReminders() async {
    if (kDebugMode) {
      print('Scheduling all reminders...');
    }

    // Cancel all existing notifications first
    await NotificationService.instance.cancelAllNotifications();

    // Schedule all enabled reminders
    int scheduledCount = 0;
    for (final reminder in _reminders) {
      if (reminder.isEnabled) {
        await _scheduleReminder(reminder);
        scheduledCount++;
      }
    }

    if (kDebugMode) {
      print('Scheduled $scheduledCount reminders');
      final pending = await NotificationService.instance.getPendingNotifications();
      print('Total pending notifications: ${pending.length}');
    }
  }

  Future<void> _scheduleReminder(WaterReminder reminder) async {
    try {
      // Parse notification ID with safety checks
      int notificationId;
      try {
        notificationId = int.parse(reminder.id);
      } catch (e) {
        if (kDebugMode) {
          print('❌ Invalid notification ID format: ${reminder.id}, generating new ID');
        }
        // Generate a simple fallback ID if parsing fails
        notificationId = (reminder.time.hour * 100) + reminder.time.minute;
      }

      // Ensure ID is within safe bounds (Android notification IDs must be positive 32-bit integers)
      if (notificationId <= 0 || notificationId > 2147483647) {
        notificationId = (reminder.time.hour * 100) + reminder.time.minute;
        if (kDebugMode) {
          print('❌ Notification ID out of bounds, using fallback: $notificationId');
        }
      }

      final message = NotificationService.getRandomMessage();

      if (kDebugMode) {
        print('Scheduling reminder ID $notificationId for ${reminder.time.hour}:${reminder.time.minute}');
      }

      await NotificationService.instance.scheduleDailyWaterReminder(
        id: notificationId,
        title: '💧 Water Reminder',
        body: message,
        hour: reminder.time.hour,
        minute: reminder.time.minute,
        payload: 'water_reminder_${reminder.id}',
      );

      if (kDebugMode) {
        print('✅ Successfully scheduled reminder: ${reminder.time.hour}:${reminder.time.minute.toString().padLeft(2, '0')} - $message');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error scheduling reminder: $e');
      }
      // Don't rethrow to prevent app crashes
    }
  }

  void _sortReminders() {
    _reminders.sort((a, b) {
      final aMinutes = a.time.hour * 60 + a.time.minute;
      final bMinutes = b.time.hour * 60 + b.time.minute;
      return aMinutes.compareTo(bMinutes);
    });
  }

  // Storage methods - optimized for performance
  Future<void> _saveReminders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final remindersJson = _reminders.map((r) => r.toJson()).toList();

      // Use batch operations for better performance
      await Future.wait([
        prefs.setString('water_reminders', json.encode(remindersJson)),
        prefs.setBool('reminders_enabled', _remindersEnabled),
      ]);

      if (kDebugMode) {
        print('Saved ${_reminders.length} reminders to storage');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error saving reminders: $e');
      }
    }
  }

  Future<void> _loadReminders() async {
    final prefs = await SharedPreferences.getInstance();

    // Load reminders
    final remindersString = prefs.getString('water_reminders');
    if (remindersString != null) {
      final List<dynamic> remindersJson = json.decode(remindersString);
      _reminders = remindersJson.map((json) => WaterReminder.fromJson(json)).toList();
    }

    // Load enabled state
    _remindersEnabled = prefs.getBool('reminders_enabled') ?? true;
  }

  // Test notification (for debugging)
  Future<void> testNotification() async {
    if (permissionsGranted) {
      await NotificationService.instance.showInstantNotification(
        id: 999,
        title: 'Test Notification',
        body: '💧 This is a test water reminder!',
        payload: 'test',
      );
    } else {
      if (kDebugMode) {
        print('Cannot test notification: permissions not granted');
      }
    }
  }

  // Get pending notifications (for debugging)
  Future<void> debugPendingNotifications() async {
    final pending = await NotificationService.instance.getPendingNotifications();
    if (kDebugMode) {
      print('Pending notifications: ${pending.length}');
      for (final notification in pending) {
        print('ID: ${notification.id}, Title: ${notification.title}, Body: ${notification.body}');
      }
    }
  }
}