import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../models/water_reminder.dart';

/// Production-ready notification manager for water reminders
class NotificationManager {
  static final NotificationManager _instance = NotificationManager._internal();
  factory NotificationManager() => _instance;
  NotificationManager._internal();

  static const String _channelId = 'water_reminders';
  static const String _channelName = 'Water Reminders';
  static const String _channelDescription = 'Notifications to remind you to drink water';
  static const String _remindersKey = 'water_reminders_list';
  static const String _globalEnabledKey = 'notifications_globally_enabled';

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;
  List<WaterReminder> _reminders = [];
  bool _globallyEnabled = true;

  /// Callback for handling notification taps and actions
  static void Function(NotificationResponse)? onNotificationTap;

  /// Initialize the notification manager
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Initialize timezone data
      tz.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('UTC')); // Will be updated to local timezone

      // Android initialization settings
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

      // iOS initialization settings
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: false, // We'll request manually
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      // Initialize with callback for handling notification taps
      final initialized = await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationResponse,
        onDidReceiveBackgroundNotificationResponse: _onBackgroundNotificationResponse,
      );

      if (initialized == true) {
        await _createNotificationChannels();
        await _loadReminders();
        await _updateLocalTimezone();
        _isInitialized = true;

        if (kDebugMode) {
          print('✅ NotificationManager initialized successfully');
        }
      }

      return initialized == true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ NotificationManager initialization failed: $e');
      }
      return false;
    }
  }

  /// Request notification permissions
  Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      return await _requestAndroidPermissions();
    } else if (Platform.isIOS) {
      return await _requestIOSPermissions();
    }
    return false;
  }

  /// Check if notifications are permitted
  Future<bool> arePermissionsGranted() async {
    if (Platform.isAndroid) {
      return await _checkAndroidPermissions();
    } else if (Platform.isIOS) {
      return await _checkIOSPermissions();
    }
    return false;
  }

  /// Add a new reminder
  Future<bool> addReminder(WaterReminder reminder) async {
    if (!_isInitialized) {
      throw StateError('NotificationManager not initialized');
    }

    try {
      // Remove existing reminder with same ID
      _reminders.removeWhere((r) => r.id == reminder.id);

      // Add new reminder
      _reminders.add(reminder);

      // Save to storage
      await _saveReminders();

      // Schedule notification if enabled
      if (_globallyEnabled && reminder.isEnabled) {
        await _scheduleReminder(reminder);
      }

      if (kDebugMode) {
        print('✅ Added reminder: ${_formatTime(reminder.time)} (ID: ${reminder.id})');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to add reminder: $e');
      }
      return false;
    }
  }

  /// Update an existing reminder
  Future<bool> updateReminder(WaterReminder oldReminder, WaterReminder newReminder) async {
    if (!_isInitialized) {
      throw StateError('NotificationManager not initialized');
    }

    try {
      // Cancel old notification
      await _cancelReminder(oldReminder.id);

      // Update in list
      final index = _reminders.indexWhere((r) => r.id == oldReminder.id);
      if (index != -1) {
        _reminders[index] = newReminder;
      } else {
        _reminders.add(newReminder);
      }

      // Save to storage
      await _saveReminders();

      // Schedule new notification if enabled
      if (_globallyEnabled && newReminder.isEnabled) {
        await _scheduleReminder(newReminder);
      }

      if (kDebugMode) {
        print('✅ Updated reminder: ${_formatTime(newReminder.time)} (ID: ${newReminder.id})');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to update reminder: $e');
      }
      return false;
    }
  }

  /// Remove a reminder
  Future<bool> removeReminder(String reminderId) async {
    if (!_isInitialized) {
      throw StateError('NotificationManager not initialized');
    }

    try {
      // Cancel notification
      await _cancelReminder(reminderId);

      // Remove from list
      _reminders.removeWhere((r) => r.id == reminderId);

      // Save to storage
      await _saveReminders();

      if (kDebugMode) {
        print('✅ Removed reminder: $reminderId');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to remove reminder: $e');
      }
      return false;
    }
  }

  /// Enable/disable all notifications globally
  Future<bool> setGloballyEnabled(bool enabled) async {
    if (!_isInitialized) {
      throw StateError('NotificationManager not initialized');
    }

    try {
      _globallyEnabled = enabled;

      // Save setting
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_globalEnabledKey, enabled);

      if (enabled) {
        // Schedule all active reminders
        await _rescheduleAllReminders();
      } else {
        // Cancel all notifications
        await _notifications.cancelAll();
      }

      if (kDebugMode) {
        print('✅ Global notifications ${enabled ? 'enabled' : 'disabled'}');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to set global notification state: $e');
      }
      return false;
    }
  }

  /// Get all reminders
  List<WaterReminder> getReminders() => List.unmodifiable(_reminders);

  /// Check if notifications are globally enabled
  bool isGloballyEnabled() => _globallyEnabled;

  /// Handle snooze action
  Future<bool> snoozeReminder(String reminderId, Duration snoozeDuration) async {
    try {
      final reminder = _reminders.firstWhere((r) => r.id == reminderId);

      // Cancel current notification
      await _cancelReminder(reminderId);

      // Calculate snooze time
      final snoozeTime = DateTime.now().add(snoozeDuration);

      // Schedule snoozed notification
      await _scheduleOneTimeNotification(
        id: int.parse(reminderId),
        scheduledDate: snoozeTime,
        title: 'Time to drink water 💧 (Snoozed)',
        body: 'Stay hydrated! Log your water intake now.',
        payload: 'snooze_$reminderId',
      );

      // Update reminder with snooze count
      final updatedReminder = reminder.copyWith(
        snoozeCount: reminder.snoozeCount + 1,
      );
      await updateReminder(reminder, updatedReminder);

      if (kDebugMode) {
        print('✅ Snoozed reminder $reminderId for ${snoozeDuration.inMinutes} minutes');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to snooze reminder: $e');
      }
      return false;
    }
  }

  /// Reschedule all reminders (useful after reboot or timezone change)
  Future<void> rescheduleAllReminders() async {
    if (!_isInitialized || !_globallyEnabled) return;

    try {
      await _rescheduleAllReminders();
      if (kDebugMode) {
        print('✅ Rescheduled all reminders');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to reschedule reminders: $e');
      }
    }
  }

  /// Get pending notifications (for debugging)
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }

  /// Show immediate test notification
  Future<void> showTestNotification() async {
    if (!_isInitialized) return;

    try {
      await _notifications.show(
        999999, // Test notification ID
        'Test Water Reminder 💧',
        'This is a test notification to verify everything is working!',
        _getNotificationDetails(),
        payload: 'test_notification',
      );

      if (kDebugMode) {
        print('✅ Test notification shown');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to show test notification: $e');
      }
    }
  }

  // PRIVATE METHODS

  /// Helper method to format TimeOfDay for logging
  String _formatTime(TimeOfDay time) {
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }

  Future<void> _createNotificationChannels() async {
    if (Platform.isAndroid) {
      const androidChannel = AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.high,
        sound: RawResourceAndroidNotificationSound('notification_sound'),
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 250, 250, 250]),
        enableLights: true,
        ledColor: Color.fromARGB(255, 66, 165, 245),
      );

      await _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);
    }
  }

  Future<bool> _requestAndroidPermissions() async {
    if (Platform.isAndroid) {
      // For Android 13+, we need to request notification permission
      // This is a simplified implementation - in production you might want to use
      // the permission_handler package for more robust permission handling

      final plugin = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (plugin != null) {
        final granted = await plugin.requestNotificationsPermission();
        return granted ?? false;
      }

      // For older Android versions, permissions are granted by default
      return true;
    }
    return false;
  }

  Future<bool> _requestIOSPermissions() async {
    final result = await _notifications
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
    return result == true;
  }

  Future<bool> _checkAndroidPermissions() async {
    if (Platform.isAndroid) {
      final plugin = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (plugin != null) {
        final granted = await plugin.areNotificationsEnabled();
        return granted ?? false;
      }
      return true; // Assume granted for older versions
    }
    return false;
  }

  Future<bool> _checkIOSPermissions() async {
    // For iOS, we check if we can show notifications
    try {
      final plugin = _notifications.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      if (plugin != null) {
        final granted = await plugin.checkPermissions();
        return granted.alert;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<int> _getAndroidInfo() async {
    // This is a simplified version - in production, use device_info_plus package
    return 33; // Assume Android 13+ for this example
  }

  Future<void> _scheduleReminder(WaterReminder reminder) async {
    if (!reminder.isEnabled || !reminder.shouldTriggerToday()) return;

    try {
      final scheduledDate = reminder.getNextScheduledTime();
      final tzScheduledDate = tz.TZDateTime.from(scheduledDate, tz.local);

      await _notifications.zonedSchedule(
        int.parse(reminder.id),
        'Time to drink water 💧',
        'Stay hydrated! Log your water intake now.',
        tzScheduledDate,
        _getNotificationDetails(),
        payload: 'reminder_${reminder.id}',
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time, // Repeat daily
      );

      if (kDebugMode) {
        print('✅ Scheduled notification for ${_formatTime(reminder.time)} at $scheduledDate');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to schedule reminder ${reminder.id}: $e');
      }
    }
  }

  Future<void> _scheduleOneTimeNotification({
    required int id,
    required DateTime scheduledDate,
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      final tzScheduledDate = tz.TZDateTime.from(scheduledDate, tz.local);

      await _notifications.zonedSchedule(
        id,
        title,
        body,
        tzScheduledDate,
        _getNotificationDetails(),
        payload: payload,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to schedule one-time notification: $e');
      }
    }
  }

  Future<void> _cancelReminder(String reminderId) async {
    try {
      await _notifications.cancel(int.parse(reminderId));
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to cancel reminder $reminderId: $e');
      }
    }
  }

  Future<void> _rescheduleAllReminders() async {
    // Cancel all existing notifications
    await _notifications.cancelAll();

    // Schedule all enabled reminders
    for (final reminder in _reminders) {
      if (reminder.isEnabled) {
        await _scheduleReminder(reminder);
      }
    }
  }

  NotificationDetails _getNotificationDetails() {
    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      ticker: 'Water Reminder',
      icon: '@mipmap/ic_launcher',
      largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      color: const Color.fromARGB(255, 66, 165, 245),
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 250, 250, 250]),
      enableLights: true,
      ledColor: const Color.fromARGB(255, 66, 165, 245),
      when: null,
      usesChronometer: false,
      chronometerCountDown: false,
      ongoing: false,
      autoCancel: true,
      silent: false,
      actions: const [
        AndroidNotificationAction(
          'log_drink',
          'Log Drink',
          contextual: true,
        ),
        AndroidNotificationAction(
          'snooze_5',
          'Snooze 5m',
        ),
        AndroidNotificationAction(
          'snooze_10',
          'Snooze 10m',
        ),
        AndroidNotificationAction(
          'dismiss',
          'Dismiss',
          cancelNotification: true,
        ),
      ],
    );

    const iosDetails = DarwinNotificationDetails(
      categoryIdentifier: 'water_reminder_category',
      interruptionLevel: InterruptionLevel.active,
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    return NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
  }

  Future<void> _loadReminders() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load global enabled state
      _globallyEnabled = prefs.getBool(_globalEnabledKey) ?? true;

      // Load reminders
      final remindersJson = prefs.getString(_remindersKey);
      if (remindersJson != null) {
        final List<dynamic> remindersList = json.decode(remindersJson);
        _reminders = remindersList
            .map((json) => WaterReminder.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      if (kDebugMode) {
        print('✅ Loaded ${_reminders.length} reminders from storage');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to load reminders: $e');
      }
      _reminders = [];
    }
  }

  Future<void> _saveReminders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final remindersJson = json.encode(_reminders.map((r) => r.toJson()).toList());
      await prefs.setString(_remindersKey, remindersJson);

      if (kDebugMode) {
        print('✅ Saved ${_reminders.length} reminders to storage');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to save reminders: $e');
      }
    }
  }

  Future<void> _updateLocalTimezone() async {
    try {
      // In production, you might want to use a more robust timezone detection
      final String timezoneName = DateTime.now().timeZoneName;
      final location = tz.getLocation(timezoneName);
      tz.setLocalLocation(location);
    } catch (e) {
      // Fallback to system timezone
      if (kDebugMode) {
        print('⚠️ Could not set specific timezone, using system default: $e');
      }
    }
  }

  // STATIC CALLBACK METHODS

  static void _onNotificationResponse(NotificationResponse response) {
    if (kDebugMode) {
      print('📱 Notification tapped: ${response.payload}');
    }

    _handleNotificationAction(response);
  }

  @pragma('vm:entry-point')
  static void _onBackgroundNotificationResponse(NotificationResponse response) {
    if (kDebugMode) {
      print('📱 Background notification tapped: ${response.payload}');
    }

    _handleNotificationAction(response);
  }


  static void _handleNotificationAction(NotificationResponse response) {
    final payload = response.payload;
    final actionId = response.actionId;

    if (kDebugMode) {
      print('🔔 Handling notification action: $actionId, payload: $payload');
    }

    // Extract reminder ID from payload
    String? reminderId;
    if (payload?.startsWith('reminder_') == true) {
      reminderId = payload!.substring('reminder_'.length);
    } else if (payload?.startsWith('snooze_') == true) {
      reminderId = payload!.substring('snooze_'.length);
    }

    // Handle different actions
    if (actionId != null && reminderId != null) {
      switch (actionId) {
        case 'log_drink':
          _handleLogDrink(reminderId);
          break;
        case 'snooze_5':
          _handleSnooze(reminderId, SnoozeDuration.five);
          break;
        case 'snooze_10':
          _handleSnooze(reminderId, SnoozeDuration.ten);
          break;
        case 'snooze_15':
          _handleSnooze(reminderId, SnoozeDuration.fifteen);
          break;
        case 'dismiss':
          _handleDismiss(reminderId);
          break;
      }
    }

    // Call external callback if set
    onNotificationTap?.call(response);
  }

  static void _handleLogDrink(String reminderId) {
    // This will be handled by the app's navigation system
    if (kDebugMode) {
      print('🥤 Log drink action for reminder: $reminderId');
    }
  }

  static void _handleSnooze(String reminderId, Duration duration) {
    // Handle snooze - this requires accessing the instance
    NotificationManager()._handleSnoozeAction(reminderId, duration);
  }

  static void _handleDismiss(String reminderId) {
    if (kDebugMode) {
      print('🚫 Dismiss action for reminder: $reminderId');
    }
    // Notification is automatically cancelled due to cancelNotification: true
  }

  void _handleSnoozeAction(String reminderId, Duration duration) {
    // Schedule this to run after the callback completes
    Future.microtask(() async {
      await snoozeReminder(reminderId, duration);
    });
  }
}