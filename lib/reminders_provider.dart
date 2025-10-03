import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'notification_service.dart';

class WaterReminder {
  final String id;
  final TimeOfDay time;
  final String frequency;
  final bool isEnabled;

  WaterReminder({
    required this.id,
    required this.time,
    required this.frequency,
    required this.isEnabled,
  });

  WaterReminder copyWith({
    String? id,
    TimeOfDay? time,
    String? frequency,
    bool? isEnabled,
  }) {
    return WaterReminder(
      id: id ?? this.id,
      time: time ?? this.time,
      frequency: frequency ?? this.frequency,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  // Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'hour': time.hour,
      'minute': time.minute,
      'frequency': frequency,
      'isEnabled': isEnabled,
    };
  }

  // Create from JSON
  factory WaterReminder.fromJson(Map<String, dynamic> json) {
    return WaterReminder(
      id: json['id'],
      time: TimeOfDay(hour: json['hour'], minute: json['minute']),
      frequency: json['frequency'],
      isEnabled: json['isEnabled'],
    );
  }

  /// Generate a safe notification ID that fits within 32-bit integer limits
  /// Uses a hash-based approach to ensure uniqueness while staying within bounds
  static String generateSafeId() {
    final now = DateTime.now();
    // Create a unique identifier based on time components
    // Use seconds since epoch (smaller number) + milliseconds for uniqueness
    final baseId = now.millisecondsSinceEpoch ~/ 1000; // Seconds since epoch
    final millis = now.millisecondsSinceEpoch % 1000; // Just the milliseconds part

    // Combine with a simple hash to ensure we stay within 32-bit range
    // Max 32-bit signed int: 2,147,483,647
    final safeId = (baseId % 1000000) * 1000 + millis; // Keep under 1 billion

    return safeId.toString();
  }
}

class RemindersProvider extends ChangeNotifier {
  List<WaterReminder> _reminders = [];
  bool _remindersEnabled = true;
  bool _permissionsGranted = false;

  // Getters
  List<WaterReminder> get reminders => _reminders;
  bool get remindersEnabled => _remindersEnabled;
  bool get permissionsGranted => _permissionsGranted;

  // Initialize with default reminders and load from storage
  void initialize() {
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

      await _checkPermissions();

      // Start with empty reminders list - no default reminders

      // Schedule notifications if enabled
      if (_remindersEnabled && _permissionsGranted) {
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


  Future<void> _checkPermissions() async {
    // First check current status
    _permissionsGranted = await NotificationService.instance.checkPermissionStatus();

    if (kDebugMode) {
      print('Initial permission status: $_permissionsGranted');
    }

    // If not granted, try to request permissions
    if (!_permissionsGranted) {
      _permissionsGranted = await NotificationService.instance.requestPermissions();

      if (kDebugMode) {
        print('After permission request: $_permissionsGranted');
      }
    }

    // Also check battery optimization
    if (_permissionsGranted) {
      final batteryOptimized = await NotificationService.instance.isBatteryOptimizationIgnored();
      if (kDebugMode) {
        print('Battery optimization ignored: $batteryOptimized');
        if (!batteryOptimized) {
          print('⚠️ WARNING: Battery optimization may prevent notifications!');
        }
      }
    }

    if (kDebugMode) {
      print('Final notification permissions granted: $_permissionsGranted');
    }
  }

  Future<void> setRemindersEnabled(bool enabled) async {
    _remindersEnabled = enabled;

    if (enabled && _permissionsGranted) {
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
      if (_remindersEnabled && _permissionsGranted && reminder.isEnabled) {
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

    // Cancel old notification
    await NotificationService.instance.cancelNotification(int.parse(oldReminder.id));

    // Schedule new notification if enabled
    if (_remindersEnabled && _permissionsGranted && newReminder.isEnabled) {
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
      if (enabled && _remindersEnabled && _permissionsGranted) {
        await _scheduleReminder(reminder.copyWith(isEnabled: enabled));
      } else {
        await NotificationService.instance.cancelNotification(int.parse(reminder.id));
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
      await NotificationService.instance.cancelNotification(int.parse(reminder.id));

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
      final notificationId = int.parse(reminder.id);
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
    if (!_permissionsGranted) {
      await _checkPermissions();
    }

    if (_permissionsGranted) {
      await NotificationService.instance.showInstantNotification(
        id: 999,
        title: 'Test Notification',
        body: '💧 This is a test water reminder!',
        payload: 'test',
      );
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