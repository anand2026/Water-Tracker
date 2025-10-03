import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../models/reminder_model.dart';

/// Enhanced notification service with comprehensive debugging for iOS
class NotificationDebugService {
  static final NotificationDebugService _instance = NotificationDebugService._internal();
  factory NotificationDebugService() => _instance;
  NotificationDebugService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;
  List<WaterReminder> _reminders = [];
  bool _notificationsEnabled = true;

  static Function(String action, String? reminderId)? onNotificationAction;

  /// Initialize with enhanced debugging
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      debugPrint('🔧 [DEBUG] Initializing NotificationDebugService...');

      // Initialize timezone
      tz.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
      debugPrint('🌍 [DEBUG] Timezone set to: Asia/Kolkata');

      // Initialize plugin with detailed settings
      await _initializePlugin();

      // Create notification channels
      await _createNotificationChannels();

      // Load stored data
      await _loadStoredData();

      _isInitialized = true;
      debugPrint('✅ [DEBUG] NotificationDebugService initialized successfully');
      return true;
    } catch (e) {
      debugPrint('❌ [DEBUG] Failed to initialize: $e');
      return false;
    }
  }

  /// Enhanced iOS permission handling
  Future<bool> requestPermissions() async {
    debugPrint('📱 [DEBUG] Requesting notifications permissions...');

    if (Platform.isIOS) {
      return await _requestIOSPermissions();
    } else if (Platform.isAndroid) {
      return await _requestAndroidPermissions();
    }
    return false;
  }

  Future<bool> _requestIOSPermissions() async {
    try {
      debugPrint('🍎 [DEBUG] Requesting iOS permissions...');

      final plugin = _notifications.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      if (plugin != null) {
        // Request permissions with all features
        final result = await plugin.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
          critical: false, // Don't request critical notifications
        );

        debugPrint('🍎 [DEBUG] iOS permission result: $result');

        // Check what specific permissions we have
        final settings = await plugin.checkPermissions();
        debugPrint('🍎 [DEBUG] iOS permission details:');
        debugPrint('  - Settings object: $settings');

        return result ?? false;
      }
      return false;
    } catch (e) {
      debugPrint('❌ [DEBUG] iOS permission request failed: $e');
      return false;
    }
  }

  Future<bool> _requestAndroidPermissions() async {
    try {
      debugPrint('🤖 [DEBUG] Requesting Android permissions...');

      final plugin = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (plugin != null) {
        final result = await plugin.requestNotificationsPermission();
        debugPrint('🤖 [DEBUG] Android permission result: $result');
        return result ?? false;
      }
      return true; // Assume granted for older versions
    } catch (e) {
      debugPrint('❌ [DEBUG] Android permission request failed: $e');
      return false;
    }
  }

  /// Enhanced permission checking
  Future<bool> arePermissionsGranted() async {
    try {
      if (Platform.isIOS) {
        final plugin = _notifications.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
        if (plugin != null) {
          final settings = await plugin.checkPermissions();
          debugPrint('🍎 [DEBUG] iOS permission settings: $settings');
          // For iOS, we'll use a simpler check
          final granted = settings != null;
          debugPrint('🍎 [DEBUG] iOS permissions granted: $granted');
          return granted;
        }
        return false;
      } else if (Platform.isAndroid) {
        final plugin = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        if (plugin != null) {
          final granted = await plugin.areNotificationsEnabled();
          debugPrint('🤖 [DEBUG] Android permissions granted: $granted');
          return granted ?? false;
        }
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ [DEBUG] Permission check failed: $e');
      return false;
    }
  }

  /// Add reminder with enhanced debugging
  Future<bool> addReminder(WaterReminder reminder) async {
    if (!_isInitialized) {
      throw StateError('NotificationDebugService not initialized');
    }

    try {
      debugPrint('➕ [DEBUG] Adding reminder: ${reminder.formatTime()} (ID: ${reminder.id})');

      // Remove existing reminder with same ID
      _reminders.removeWhere((r) => r.id == reminder.id);
      _reminders.add(reminder);
      _sortReminders();
      await _saveReminders();

      // Enhanced scheduling with debugging
      if (_notificationsEnabled && reminder.isEnabled) {
        final permissionsGranted = await arePermissionsGranted();
        debugPrint('🔐 [DEBUG] Permissions granted: $permissionsGranted');

        if (permissionsGranted) {
          await _scheduleNotificationDebug(reminder);
        } else {
          debugPrint('⚠️ [DEBUG] Permissions denied - notification NOT scheduled');

          // Provide specific guidance for the user
          if (Platform.isIOS) {
            debugPrint('💡 [DEBUG] iOS: Check Settings > Notifications > Your App');
          } else {
            debugPrint('💡 [DEBUG] Android: Check Settings > Apps > Your App > Notifications');
          }
        }
      } else {
        debugPrint('⚠️ [DEBUG] Notifications disabled or reminder disabled');
      }

      debugPrint('✅ [DEBUG] Reminder added successfully');
      return true;
    } catch (e) {
      debugPrint('❌ [DEBUG] Failed to add reminder: $e');
      return false;
    }
  }

  /// Enhanced notification scheduling with comprehensive debugging
  Future<void> _scheduleNotificationDebug(WaterReminder reminder) async {
    if (!reminder.isEnabled) {
      debugPrint('⚠️ [DEBUG] Reminder disabled, not scheduling');
      return;
    }

    try {
      final scheduledDateTime = reminder.getNextScheduledTime();
      final now = DateTime.now();

      debugPrint('⏰ [DEBUG] Scheduling notification:');
      debugPrint('  - Current time: $now');
      debugPrint('  - Scheduled for: $scheduledDateTime');
      debugPrint('  - Time difference: ${scheduledDateTime.difference(now)}');

      final tzScheduledDateTime = tz.TZDateTime.from(scheduledDateTime, tz.local);
      final tzNow = tz.TZDateTime.now(tz.local);

      debugPrint('  - TZ Current time: $tzNow');
      debugPrint('  - TZ Scheduled time: $tzScheduledDateTime');

      if (tzScheduledDateTime.isBefore(tzNow) || tzScheduledDateTime.isAtSameMomentAs(tzNow)) {
        debugPrint('⚠️ [DEBUG] Scheduled time is not in future, adding 24 hours');
        final newScheduled = tzScheduledDateTime.add(const Duration(days: 1));
        debugPrint('  - New scheduled time: $newScheduled');

        await _scheduleNotificationAtTime(reminder, newScheduled);
      } else {
        await _scheduleNotificationAtTime(reminder, tzScheduledDateTime);
      }

      // Verify notification was scheduled
      await _verifyScheduledNotification(reminder);

    } catch (e) {
      debugPrint('❌ [DEBUG] Failed to schedule notification: $e');
    }
  }

  Future<void> _scheduleNotificationAtTime(WaterReminder reminder, tz.TZDateTime scheduledTime) async {
    try {
      final notificationId = int.parse(reminder.id);

      debugPrint('📅 [DEBUG] Scheduling notification #$notificationId for $scheduledTime');

      await _notifications.zonedSchedule(
        notificationId,
        'Time to drink water 💧',
        'Stay hydrated! Log your water intake now.',
        scheduledTime,
        _getNotificationDetails(),
        payload: 'reminder_${reminder.id}',
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );

      debugPrint('✅ [DEBUG] Notification scheduled successfully');
    } catch (e) {
      debugPrint('❌ [DEBUG] Failed to schedule at specific time: $e');
    }
  }

  /// Verify that notification was actually scheduled
  Future<void> _verifyScheduledNotification(WaterReminder reminder) async {
    try {
      final pendingNotifications = await _notifications.pendingNotificationRequests();
      final notificationId = int.parse(reminder.id);

      final found = pendingNotifications.any((notification) => notification.id == notificationId);

      debugPrint('🔍 [DEBUG] Notification verification:');
      debugPrint('  - Total pending: ${pendingNotifications.length}');
      debugPrint('  - Looking for ID: $notificationId');
      debugPrint('  - Found: $found');

      if (found) {
        final notification = pendingNotifications.firstWhere((n) => n.id == notificationId);
        debugPrint('  - Title: ${notification.title}');
        debugPrint('  - Body: ${notification.body}');
        debugPrint('  - Payload: ${notification.payload}');
      } else {
        debugPrint('⚠️ [DEBUG] Notification NOT found in pending list!');
      }

    } catch (e) {
      debugPrint('❌ [DEBUG] Failed to verify notification: $e');
    }
  }

  /// Get pending notifications count
  Future<int> getPendingNotificationsCount() async {
    try {
      final pending = await _notifications.pendingNotificationRequests();
      debugPrint('📊 [DEBUG] Pending notifications: ${pending.length}');
      return pending.length;
    } catch (e) {
      debugPrint('❌ [DEBUG] Failed to get pending count: $e');
      return 0;
    }
  }

  /// Show immediate test notification
  Future<void> showTestNotification() async {
    try {
      debugPrint('🧪 [DEBUG] Showing immediate test notification...');

      await _notifications.show(
        999, // Test ID
        'Water Tracker Test 🧪',
        'This is a test notification. Tap to verify it works!',
        _getNotificationDetails(),
        payload: 'test_notification',
      );

      debugPrint('✅ [DEBUG] Test notification sent');
    } catch (e) {
      debugPrint('❌ [DEBUG] Failed to show test notification: $e');
    }
  }

  Future<void> _initializePlugin() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,  // Request permission during init
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    final initialized = await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: _onBackgroundNotificationResponse,
    );

    debugPrint('🔧 [DEBUG] Plugin initialized: $initialized');

    if (initialized != true) {
      throw Exception('Failed to initialize flutter_local_notifications');
    }
  }

  Future<void> _createNotificationChannels() async {
    if (Platform.isAndroid) {
      final androidChannel = AndroidNotificationChannel(
        'water_reminders',
        'Water Reminders',
        description: 'Daily water intake reminders',
        importance: Importance.high,
        enableVibration: true,
        playSound: true,
      );

      final androidPlugin = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(androidChannel);

      debugPrint('🤖 [DEBUG] Android notification channel created');
    }
  }

  NotificationDetails _getNotificationDetails() {
    const androidDetails = AndroidNotificationDetails(
      'water_reminders',
      'Water Reminders',
      channelDescription: 'Daily water intake reminders',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      actions: [
        AndroidNotificationAction('log_drink', '💧 Log Drink'),
        AndroidNotificationAction('snooze', '⏰ Snooze 10min'),
        AndroidNotificationAction('dismiss', '🚫 Dismiss'),
      ],
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      categoryIdentifier: 'water_reminder',
    );

    return const NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
  }

  static void _onNotificationResponse(NotificationResponse response) {
    debugPrint('📱 [DEBUG] Notification tapped: ${response.payload}');
    _handleNotificationAction(response);
  }

  @pragma('vm:entry-point')
  static void _onBackgroundNotificationResponse(NotificationResponse response) {
    debugPrint('📱 [DEBUG] Background notification tapped: ${response.payload}');
    _handleNotificationAction(response);
  }

  static void _handleNotificationAction(NotificationResponse response) {
    final payload = response.payload;
    final actionId = response.actionId;

    debugPrint('🔔 [DEBUG] Handling notification action: $actionId, payload: $payload');

    String? reminderId;
    if (payload?.startsWith('reminder_') == true) {
      reminderId = payload!.substring('reminder_'.length);
    }

    String action = actionId ?? 'tap';

    switch (action) {
      case 'log_drink':
        debugPrint('🥤 [DEBUG] Log drink action for reminder: $reminderId');
        break;
      case 'snooze':
        debugPrint('⏰ [DEBUG] Snooze action for reminder: $reminderId');
        break;
      case 'dismiss':
        debugPrint('🚫 [DEBUG] Dismiss action for reminder: $reminderId');
        break;
      case 'tap':
        debugPrint('👆 [DEBUG] Direct tap on notification: $reminderId');
        break;
    }

    onNotificationAction?.call(action, reminderId);
  }

  List<WaterReminder> getReminders() => List.unmodifiable(_reminders);
  bool areNotificationsEnabled() => _notificationsEnabled;

  Future<bool> setNotificationsEnabled(bool enabled) async {
    _notificationsEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', enabled);

    if (enabled) {
      await _rescheduleAllNotifications();
    } else {
      await _notifications.cancelAll();
    }

    debugPrint('🔔 [DEBUG] Notifications ${enabled ? "enabled" : "disabled"}');
    return true;
  }

  Future<bool> removeReminder(String id) async {
    try {
      await _notifications.cancel(int.parse(id));
      _reminders.removeWhere((r) => r.id == id);
      await _saveReminders();
      debugPrint('🗑️ [DEBUG] Removed reminder: $id');
      return true;
    } catch (e) {
      debugPrint('❌ [DEBUG] Failed to remove reminder: $e');
      return false;
    }
  }

  void _sortReminders() {
    _reminders.sort((a, b) {
      final aMinutes = a.time.hour * 60 + a.time.minute;
      final bMinutes = b.time.hour * 60 + b.time.minute;
      return aMinutes.compareTo(bMinutes);
    });
  }

  Future<void> _saveReminders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final remindersJson = _reminders.map((r) => r.toJson()).toList();
      await prefs.setString('water_reminders', remindersJson.toString());
    } catch (e) {
      debugPrint('❌ [DEBUG] Failed to save reminders: $e');
    }
  }

  Future<void> _loadStoredData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      // Load reminders logic here if needed
      debugPrint('✅ [DEBUG] Loaded stored data');
    } catch (e) {
      debugPrint('❌ [DEBUG] Failed to load stored data: $e');
    }
  }

  Future<void> _rescheduleAllNotifications() async {
    try {
      await _notifications.cancelAll();
      int rescheduled = 0;

      for (final reminder in _reminders) {
        if (reminder.isEnabled) {
          await _scheduleNotificationDebug(reminder);
          rescheduled++;
        }
      }

      debugPrint('🔄 [DEBUG] Rescheduled $rescheduled notifications');
    } catch (e) {
      debugPrint('❌ [DEBUG] Failed to reschedule: $e');
    }
  }
}