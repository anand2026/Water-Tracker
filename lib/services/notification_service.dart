import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../models/reminder_model.dart';

/// Complete notification service for water tracker app
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  // Plugin instance
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  // Configuration constants
  static const String _channelId = 'water_reminders';
  static const String _channelName = 'Water Reminders';
  static const String _channelDescription = 'Daily water intake reminders';
  static const String _remindersKey = 'water_reminders';
  static const String _enabledKey = 'notifications_enabled';

  // State variables
  bool _isInitialized = false;
  List<WaterReminder> _reminders = [];
  bool _notificationsEnabled = true;

  // Callback for handling notification taps
  static Function(String action, String? reminderId)? onNotificationAction;

  /// Initialize the notification service
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Initialize timezone data
      tz.initializeTimeZones();
      _setLocalTimeZone();

      // Initialize the plugin
      await _initializePlugin();

      // Create notification channels
      await _createNotificationChannels();

      // Load saved reminders and settings
      await _loadStoredData();

      // Reschedule notifications (important for reboot handling)
      await _rescheduleAllNotifications();

      _isInitialized = true;
      debugPrint('✅ NotificationService initialized successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to initialize NotificationService: $e');
      return false;
    }
  }

  /// Request notification permissions
  Future<bool> requestPermissions() async {
    if (!_isInitialized) {
      throw StateError('NotificationService not initialized. Call initialize() first.');
    }

    try {
      if (Platform.isAndroid) {
        return await _requestAndroidPermissions();
      } else if (Platform.isIOS) {
        return await _requestIOSPermissions();
      }
      return false;
    } catch (e) {
      debugPrint('❌ Failed to request permissions: $e');
      return false;
    }
  }

  /// Check if permissions are granted
  Future<bool> arePermissionsGranted() async {
    if (!_isInitialized) return false;

    try {
      if (Platform.isAndroid) {
        final plugin = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        final granted = await plugin?.areNotificationsEnabled();
        return granted ?? false;
      } else if (Platform.isIOS) {
        final plugin = _notifications.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
        final settings = await plugin?.checkPermissions();
        return settings != null;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Failed to check permissions: $e');
      return false;
    }
  }

  /// Add a new reminder
  Future<bool> addReminder(WaterReminder reminder) async {
    if (!_isInitialized) {
      throw StateError('NotificationService not initialized');
    }

    try {
      // Remove existing reminder with same ID if exists
      _reminders.removeWhere((r) => r.id == reminder.id);

      // Add new reminder
      _reminders.add(reminder);

      // Sort reminders by time
      _sortReminders();

      // Save to storage
      await _saveReminders();

      // Schedule notification if enabled
      if (_notificationsEnabled && reminder.isEnabled) {
        await _scheduleNotification(reminder);
      }

      debugPrint('✅ Added reminder: ${reminder.formatTime()} (ID: ${reminder.id})');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to add reminder: $e');
      return false;
    }
  }

  /// Update an existing reminder
  Future<bool> updateReminder(String id, WaterReminder newReminder) async {
    if (!_isInitialized) {
      throw StateError('NotificationService not initialized');
    }

    try {
      final index = _reminders.indexWhere((r) => r.id == id);
      if (index == -1) {
        debugPrint('⚠️ Reminder with ID $id not found');
        return false;
      }

      // Cancel old notification
      await _cancelNotification(int.parse(id));

      // Update reminder
      _reminders[index] = newReminder;

      // Sort reminders by time
      _sortReminders();

      // Save to storage
      await _saveReminders();

      // Schedule new notification if enabled
      if (_notificationsEnabled && newReminder.isEnabled) {
        await _scheduleNotification(newReminder);
      }

      debugPrint('✅ Updated reminder: ${newReminder.formatTime()} (ID: ${newReminder.id})');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to update reminder: $e');
      return false;
    }
  }

  /// Remove a reminder
  Future<bool> removeReminder(String id) async {
    if (!_isInitialized) {
      throw StateError('NotificationService not initialized');
    }

    try {
      // Cancel notification
      await _cancelNotification(int.parse(id));

      // Remove from list
      _reminders.removeWhere((r) => r.id == id);

      // Save to storage
      await _saveReminders();

      debugPrint('✅ Removed reminder with ID: $id');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to remove reminder: $e');
      return false;
    }
  }

  /// Enable or disable all notifications
  Future<bool> setNotificationsEnabled(bool enabled) async {
    if (!_isInitialized) {
      throw StateError('NotificationService not initialized');
    }

    try {
      _notificationsEnabled = enabled;

      // Save setting
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enabledKey, enabled);

      if (enabled) {
        // Schedule all enabled reminders
        await _rescheduleAllNotifications();
      } else {
        // Cancel all notifications
        await _notifications.cancelAll();
      }

      debugPrint('✅ Notifications ${enabled ? 'enabled' : 'disabled'}');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to set notifications enabled: $e');
      return false;
    }
  }

  /// Get all reminders
  List<WaterReminder> getReminders() => List.unmodifiable(_reminders);

  /// Check if notifications are enabled
  bool areNotificationsEnabled() => _notificationsEnabled;

  /// Schedule multiple default reminders
  Future<bool> scheduleDefaultReminders() async {
    final defaultTimes = [
      const TimeOfDay(hour: 9, minute: 0),   // 9:00 AM
      const TimeOfDay(hour: 11, minute: 30), // 11:30 AM
      const TimeOfDay(hour: 14, minute: 0),  // 2:00 PM
      const TimeOfDay(hour: 16, minute: 30), // 4:30 PM
      const TimeOfDay(hour: 19, minute: 0),  // 7:00 PM
    ];

    bool allSuccess = true;

    for (int i = 0; i < defaultTimes.length; i++) {
      final reminder = WaterReminder(
        id: (i + 1).toString(),
        time: defaultTimes[i],
        isEnabled: true,
        createdAt: DateTime.now(),
      );

      final success = await addReminder(reminder);
      if (!success) allSuccess = false;
    }

    debugPrint('✅ Scheduled ${defaultTimes.length} default reminders');
    return allSuccess;
  }

  /// Handle snooze action (delay by 10 minutes)
  Future<bool> snoozeReminder(String reminderId) async {
    try {
      // Cancel current notification
      await _cancelNotification(int.parse(reminderId));

      // Schedule new notification 10 minutes from now
      final snoozeTime = DateTime.now().add(const Duration(minutes: 10));

      await _scheduleOneTimeNotification(
        id: int.parse(reminderId),
        scheduledDateTime: snoozeTime,
        title: 'Time to drink water 💧 (Snoozed)',
        body: 'Stay hydrated! Log your water intake now.',
        payload: 'snooze_$reminderId',
      );

      debugPrint('✅ Snoozed reminder $reminderId for 10 minutes');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to snooze reminder: $e');
      return false;
    }
  }

  /// Show test notification
  Future<void> showTestNotification() async {
    if (!_isInitialized) return;

    try {
      await _notifications.show(
        999999, // Test ID
        'Test Water Reminder 💧',
        'This is a test notification to verify everything works!',
        _getNotificationDetails(),
        payload: 'test_notification',
      );
      debugPrint('✅ Test notification shown');
    } catch (e) {
      debugPrint('❌ Failed to show test notification: $e');
    }
  }

  /// Get pending notifications count (for debugging)
  Future<int> getPendingNotificationsCount() async {
    try {
      final pending = await _notifications.pendingNotificationRequests();
      return pending.length;
    } catch (e) {
      debugPrint('❌ Failed to get pending notifications: $e');
      return 0;
    }
  }

  /// Reschedule all notifications (useful after reboot)
  Future<void> rescheduleAllNotifications() async {
    if (!_isInitialized) return;
    await _rescheduleAllNotifications();
  }

  // PRIVATE METHODS

  void _setLocalTimeZone() {
    try {
      final String timeZoneName = DateTime.now().timeZoneName;
      final location = tz.getLocation(timeZoneName);
      tz.setLocalLocation(location);
    } catch (e) {
      debugPrint('⚠️ Could not set timezone, using UTC: $e');
      tz.setLocalLocation(tz.UTC);
    }
  }

  Future<void> _initializePlugin() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: _onBackgroundNotificationResponse,
    );
  }

  Future<void> _createNotificationChannels() async {
    if (Platform.isAndroid) {
      final androidChannel = AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.high,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 250, 250, 250]),
        enableLights: true,
        ledColor: const Color.fromARGB(255, 66, 165, 245),
      );

      await _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);
    }
  }

  Future<bool> _requestAndroidPermissions() async {
    final plugin = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (plugin != null) {
      final granted = await plugin.requestNotificationsPermission();
      return granted ?? false;
    }
    return true; // Assume granted for older versions
  }

  Future<bool> _requestIOSPermissions() async {
    final plugin = _notifications.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    if (plugin != null) {
      final granted = await plugin.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }
    return false;
  }

  Future<void> _scheduleNotification(WaterReminder reminder) async {
    if (!reminder.isEnabled) return;

    try {
      final scheduledDateTime = reminder.getNextScheduledTime();
      final tzScheduledDateTime = tz.TZDateTime.from(scheduledDateTime, tz.local);

      await _notifications.zonedSchedule(
        int.parse(reminder.id),
        'Time to drink water 💧',
        'Stay hydrated! Log your water intake now.',
        tzScheduledDateTime,
        _getNotificationDetails(),
        payload: 'reminder_${reminder.id}',
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time, // Repeat daily
      );

      debugPrint('✅ Scheduled notification for ${reminder.formatTime()} at $scheduledDateTime');
    } catch (e) {
      debugPrint('❌ Failed to schedule notification for ${reminder.id}: $e');
    }
  }

  Future<void> _scheduleOneTimeNotification({
    required int id,
    required DateTime scheduledDateTime,
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      final tzScheduledDateTime = tz.TZDateTime.from(scheduledDateTime, tz.local);

      await _notifications.zonedSchedule(
        id,
        title,
        body,
        tzScheduledDateTime,
        _getNotificationDetails(),
        payload: payload,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint('❌ Failed to schedule one-time notification: $e');
    }
  }

  NotificationDetails _getNotificationDetails() {
    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: const Color.fromARGB(255, 66, 165, 245),
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 250, 250, 250]),
      actions: const [
        AndroidNotificationAction(
          'log_drink',
          'Log Drink',
          contextual: true,
        ),
        AndroidNotificationAction(
          'snooze',
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
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    return NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
  }

  Future<void> _cancelNotification(int id) async {
    try {
      await _notifications.cancel(id);
    } catch (e) {
      debugPrint('❌ Failed to cancel notification $id: $e');
    }
  }

  Future<void> _rescheduleAllNotifications() async {
    if (!_notificationsEnabled) return;

    try {
      // Cancel all existing notifications
      await _notifications.cancelAll();

      // Schedule all enabled reminders
      for (final reminder in _reminders) {
        if (reminder.isEnabled) {
          await _scheduleNotification(reminder);
        }
      }

      debugPrint('✅ Rescheduled ${_reminders.where((r) => r.isEnabled).length} notifications');
    } catch (e) {
      debugPrint('❌ Failed to reschedule notifications: $e');
    }
  }

  void _sortReminders() {
    _reminders.sort((a, b) {
      final aMinutes = a.time.hour * 60 + a.time.minute;
      final bMinutes = b.time.hour * 60 + b.time.minute;
      return aMinutes.compareTo(bMinutes);
    });
  }

  Future<void> _loadStoredData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load notifications enabled setting
      _notificationsEnabled = prefs.getBool(_enabledKey) ?? true;

      // Load reminders
      final remindersJson = prefs.getString(_remindersKey);
      if (remindersJson != null) {
        final List<dynamic> remindersList = json.decode(remindersJson);
        _reminders = remindersList
            .map((json) => WaterReminder.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      debugPrint('✅ Loaded ${_reminders.length} reminders from storage');
    } catch (e) {
      debugPrint('❌ Failed to load stored data: $e');
      _reminders = [];
      _notificationsEnabled = true;
    }
  }

  Future<void> _saveReminders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final remindersJson = json.encode(_reminders.map((r) => r.toJson()).toList());
      await prefs.setString(_remindersKey, remindersJson);
      debugPrint('✅ Saved ${_reminders.length} reminders to storage');
    } catch (e) {
      debugPrint('❌ Failed to save reminders: $e');
    }
  }

  // STATIC CALLBACK METHODS

  static void _onNotificationResponse(NotificationResponse response) {
    debugPrint('📱 Notification tapped: ${response.payload}');
    _handleNotificationAction(response);
  }

  @pragma('vm:entry-point')
  static void _onBackgroundNotificationResponse(NotificationResponse response) {
    debugPrint('📱 Background notification tapped: ${response.payload}');
    _handleNotificationAction(response);
  }

  static void _handleNotificationAction(NotificationResponse response) {
    final payload = response.payload;
    final actionId = response.actionId;

    // Extract reminder ID from payload
    String? reminderId;
    if (payload?.startsWith('reminder_') == true) {
      reminderId = payload!.substring('reminder_'.length);
    } else if (payload?.startsWith('snooze_') == true) {
      reminderId = payload!.substring('snooze_'.length);
    }

    // Handle different actions
    String action = 'tap'; // Default action
    if (actionId != null) {
      action = actionId;
    }

    // Handle specific actions
    switch (action) {
      case 'log_drink':
        debugPrint('🥤 Log drink action for reminder: $reminderId');
        break;
      case 'snooze':
        if (reminderId != null) {
          debugPrint('⏰ Snooze action for reminder: $reminderId');
          // Note: Snooze functionality would need external handling
          // since static methods can't access instance methods safely
        }
        break;
      case 'dismiss':
        debugPrint('🚫 Dismiss action for reminder: $reminderId');
        break;
      case 'tap':
        debugPrint('👆 Direct tap on notification: $reminderId');
        break;
    }

    // Call external callback if set
    onNotificationAction?.call(action, reminderId);
  }

}