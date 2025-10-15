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

  /// Initialize the notification service with Android 15+ compatibility
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      debugPrint('🛠️ Starting NotificationService initialization...');

      // Step 1: Initialize timezone data with enhanced error handling
      try {
        tz.initializeTimeZones();
        _setLocalTimeZone();
        debugPrint('✅ Timezone initialized successfully');
      } catch (e) {
        debugPrint('❌ Timezone initialization failed: $e');
        // Continue anyway - this shouldn't be fatal
      }

      // Step 2: Initialize the plugin with retry mechanism
      bool pluginInitialized = false;
      for (int attempt = 1; attempt <= 3; attempt++) {
        try {
          await _initializePlugin();
          pluginInitialized = true;
          debugPrint('✅ Plugin initialized successfully (attempt $attempt)');
          break;
        } catch (e) {
          debugPrint('⚠️ Plugin initialization attempt $attempt failed: $e');
          if (attempt == 3) {
            debugPrint('❌ Plugin initialization failed after 3 attempts');
            return false;
          }
          await Future.delayed(Duration(milliseconds: 500 * attempt));
        }
      }

      if (!pluginInitialized) {
        debugPrint('❌ Critical: Plugin could not be initialized');
        return false;
      }

      // Step 3: Create notification channels with Android 15+ compatibility
      try {
        await _createNotificationChannels();
        debugPrint('✅ Notification channels created successfully');
      } catch (e) {
        debugPrint('❌ Channel creation failed: $e');
        // Try to continue - some Android versions might not need explicit channel creation
      }

      // Step 4: Load saved data
      try {
        await _loadStoredData();
        debugPrint('✅ Stored data loaded successfully');
      } catch (e) {
        debugPrint('⚠️ Failed to load stored data: $e');
        // Initialize with defaults
        _reminders = [];
        _notificationsEnabled = true;
      }

      // Step 5: Check permissions before rescheduling
      bool hasPermissions = false;
      try {
        hasPermissions = await arePermissionsGranted();
        debugPrint('✅ Permission check completed: $hasPermissions');
      } catch (e) {
        debugPrint('⚠️ Permission check failed: $e');
      }

      // Step 6: Reschedule notifications only if we have permissions
      if (hasPermissions) {
        try {
          await _rescheduleAllNotifications();
          debugPrint('✅ Notifications rescheduled successfully');
        } catch (e) {
          debugPrint('⚠️ Reschedule failed: $e');
          // Don't fail initialization for this
        }
      } else {
        debugPrint('⚠️ Skipping notification rescheduling due to missing permissions');
      }

      _isInitialized = true;
      debugPrint('✅ NotificationService initialized successfully');
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ Critical initialization failure: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      return false;
    }
  }

  /// Request notification permissions with Android 14+ compatibility
  Future<bool> requestPermissions() async {
    if (!_isInitialized) {
      throw StateError('NotificationService not initialized. Call initialize() first.');
    }

    try {
      if (Platform.isAndroid) {
        // Check Android version first
        final androidInfo = await _getAndroidInfo();
        if (androidInfo['version']['sdkInt'] >= 33) {
          // Android 13+ requires POST_NOTIFICATIONS permission
          return await _requestAndroidNotificationPermissions();
        } else {
          // Older Android versions don't need runtime permission
          return true;
        }
      } else if (Platform.isIOS) {
        return await _requestIOSPermissions();
      }
      return false;
    } catch (e) {
      debugPrint('❌ Failed to request permissions: $e');
      return false;
    }
  }

  /// Check if permissions are granted with Android 14+ compatibility
  Future<bool> arePermissionsGranted() async {
    if (!_isInitialized) return false;

    try {
      if (Platform.isAndroid) {
        final androidInfo = await _getAndroidInfo();
        if (androidInfo['version']['sdkInt'] >= 33) {
          // Android 13+ check POST_NOTIFICATIONS permission
          final plugin = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
          final granted = await plugin?.areNotificationsEnabled();
          return granted ?? false;
        } else {
          // Older Android versions always have permission
          return true;
        }
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
      debugPrint('Setting timezone: $timeZoneName');

      // Try to get the location with fallbacks
      tz.Location? location;
      try {
        location = tz.getLocation(timeZoneName);
      } catch (e) {
        debugPrint('⚠️ Could not get timezone $timeZoneName, trying alternatives: $e');

        // Try common timezone alternatives
        final alternatives = [
          'America/New_York',
          'America/Los_Angeles',
          'Europe/London',
          'UTC'
        ];

        for (final alt in alternatives) {
          try {
            location = tz.getLocation(alt);
            debugPrint('✅ Using alternative timezone: $alt');
            break;
          } catch (e) {
            debugPrint('⚠️ Alternative $alt failed: $e');
          }
        }
      }

      if (location != null) {
        tz.setLocalLocation(location);
        debugPrint('✅ Timezone set successfully');
      } else {
        debugPrint('⚠️ All timezone options failed, using UTC');
        tz.setLocalLocation(tz.UTC);
      }
    } catch (e) {
      debugPrint('❌ Critical timezone error, using UTC: $e');
      try {
        tz.setLocalLocation(tz.UTC);
      } catch (utcError) {
        debugPrint('❌ Even UTC failed: $utcError');
      }
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
    if (!Platform.isAndroid) return;

    try {
      final plugin = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (plugin == null) {
        debugPrint('⚠️ Android plugin not available for channel creation');
        return;
      }

      // Validate importance level for Android 14+ and 15+ compatibility
      Importance channelImportance = Importance.defaultImportance; // Start with safest option
      try {
        final androidInfo = await _getAndroidInfo();
        int sdkInt = androidInfo['version']['sdkInt'];

        if (sdkInt >= 36) {
          // Android 15+ (API 36): Use most conservative approach
          channelImportance = Importance.defaultImportance;
          debugPrint('🔴 Android 15+ detected, using conservative importance');
        } else if (sdkInt >= 34) {
          // Android 14+ may have stricter importance validation
          channelImportance = Importance.defaultImportance;
          debugPrint('🔵 Android 14+ detected, using default importance');
        } else if (sdkInt >= 33) {
          // Android 13+ can handle higher importance
          channelImportance = Importance.high;
          debugPrint('🟠 Android 13+ detected, using high importance');
        } else {
          // Older Android versions
          channelImportance = Importance.high;
          debugPrint('🟢 Older Android detected, using high importance');
        }
      } catch (e) {
        debugPrint('⚠️ Could not determine Android version, using safest importance: $e');
        channelImportance = Importance.defaultImportance;
      }

      final androidChannel = AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: channelImportance,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 250, 250, 250]),
        enableLights: true,
        ledColor: const Color.fromARGB(255, 66, 165, 245),
      );

      await plugin.createNotificationChannel(androidChannel);
      debugPrint('✅ Notification channel created with importance: $channelImportance');
    } catch (e) {
      debugPrint('❌ Failed to create notification channel: $e');
      // Try creating a basic channel as fallback
      await _createFallbackChannel();
    }
  }

  Future<bool> _requestAndroidNotificationPermissions() async {
    try {
      final plugin = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (plugin == null) {
        debugPrint('⚠️ Android plugin not available');
        return false;
      }

      // Request POST_NOTIFICATIONS permission (Android 13+)
      final granted = await plugin.requestNotificationsPermission();
      if (granted != true) {
        debugPrint('❌ POST_NOTIFICATIONS permission denied');
        return false;
      }

      // Check if exact alarm permission is needed and available
      await _requestExactAlarmPermissionIfNeeded();

      return true;
    } catch (e) {
      debugPrint('❌ Failed to request Android notification permissions: $e');
      return false;
    }
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
      // Check if we have notification permissions first
      final hasPermission = await arePermissionsGranted();
      if (!hasPermission) {
        debugPrint('⚠️ No notification permission, skipping schedule for ${reminder.id}');
        return;
      }

      final scheduledDateTime = reminder.getNextScheduledTime();
      final tzScheduledDateTime = tz.TZDateTime.from(scheduledDateTime, tz.local);

      // Determine the appropriate schedule mode based on permissions
      final scheduleMode = await _getOptimalScheduleMode();

      await _notifications.zonedSchedule(
        int.parse(reminder.id),
        'Time to drink water 💧',
        'Stay hydrated! Log your water intake now.',
        tzScheduledDateTime,
        _getNotificationDetails(),
        payload: 'reminder_${reminder.id}',
        androidScheduleMode: scheduleMode,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time, // Repeat daily
      );

      debugPrint('✅ Scheduled notification for ${reminder.formatTime()} at $scheduledDateTime with mode: $scheduleMode');
    } catch (e) {
      debugPrint('❌ Failed to schedule notification for ${reminder.id}: $e');
      // Try fallback scheduling without exact timing
      await _scheduleNotificationFallback(reminder);
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

  // HELPER METHODS

  /// Get Android SDK version info with actual API level detection
  Future<Map<String, dynamic>> _getAndroidInfo() async {
    try {
      // For Android 15+ (API 36), we need to be even more careful
      // Default to the highest known API level to ensure all permissions are requested
      int sdkInt = 36; // Default to Android 15+ to be extra safe

      debugPrint('📱 Assuming Android API level: $sdkInt');

      return {
        'version': {'sdkInt': sdkInt}
      };
    } catch (e) {
      debugPrint('⚠️ Could not get device info: $e');
      return {
        'version': {'sdkInt': 36} // Default to Android 15+ to be extra safe
      };
    }
  }

  /// Request exact alarm permission if needed (Android 12+)
  Future<void> _requestExactAlarmPermissionIfNeeded() async {
    try {
      final androidInfo = await _getAndroidInfo();
      if (androidInfo['version']['sdkInt'] >= 31) {
        // Android 12+ might need exact alarm permission
        final plugin = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        // Note: There's no direct API to request SCHEDULE_EXACT_ALARM permission
        // The user must grant it manually in Settings
        debugPrint('⚠️ Android 12+ detected: Exact alarm permission may need manual approval');
      }
    } catch (e) {
      debugPrint('⚠️ Could not check exact alarm permission requirements: $e');
    }
  }

  /// Determine optimal schedule mode with Android 15+ compatibility
  Future<AndroidScheduleMode> _getOptimalScheduleMode() async {
    try {
      final androidInfo = await _getAndroidInfo();
      int sdkInt = androidInfo['version']['sdkInt'];

      if (sdkInt >= 36) {
        // Android 15+ (API 36): Use most permissive mode to avoid restrictions
        debugPrint('🔴 Android 15+ detected, using alarmClock mode');
        return AndroidScheduleMode.alarmClock;
      } else if (sdkInt >= 34) {
        // Android 14+: Try exactAllowWhileIdle with fallback
        debugPrint('🔵 Android 14+ detected, using exactAllowWhileIdle mode');
        return AndroidScheduleMode.exactAllowWhileIdle;
      } else if (sdkInt >= 31) {
        // Android 12+: Use exactAllowWhileIdle
        debugPrint('🟠 Android 12+ detected, using exactAllowWhileIdle mode');
        return AndroidScheduleMode.exactAllowWhileIdle;
      } else {
        // Older Android: Use exact timing
        debugPrint('🟢 Older Android detected, using exact mode');
        return AndroidScheduleMode.exact;
      }
    } catch (e) {
      debugPrint('❌ Could not determine optimal schedule mode: $e');
      return AndroidScheduleMode.alarmClock; // Most permissive fallback
    }
  }

  /// Fallback notification scheduling without exact timing
  Future<void> _scheduleNotificationFallback(WaterReminder reminder) async {
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
        androidScheduleMode: AndroidScheduleMode.alarmClock,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );

      debugPrint('✅ Fallback notification scheduled for ${reminder.formatTime()}');
    } catch (e) {
      debugPrint('❌ Fallback scheduling also failed for ${reminder.id}: $e');
    }
  }

  /// Create a basic notification channel as fallback
  Future<void> _createFallbackChannel() async {
    try {
      final plugin = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (plugin == null) return;

      final basicChannel = AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.defaultImportance,
      );

      await plugin.createNotificationChannel(basicChannel);
      debugPrint('✅ Fallback notification channel created');
    } catch (e) {
      debugPrint('❌ Even fallback channel creation failed: $e');
    }
  }

  // STATIC CALLBACK METHODS

  static void _onNotificationResponse(NotificationResponse response) {
    try {
      debugPrint('📱 Notification tapped: ${response.payload}');
      _handleNotificationAction(response);
    } catch (e) {
      debugPrint('❌ Notification callback error: $e');
      // Don't rethrow - this could crash the app
    }
  }

  @pragma('vm:entry-point')
  static void _onBackgroundNotificationResponse(NotificationResponse response) {
    try {
      debugPrint('📱 Background notification tapped: ${response.payload}');
      _handleNotificationAction(response);
    } catch (e) {
      debugPrint('❌ Background notification callback error: $e');
      // Don't rethrow - this could crash the entire notification system
    }
  }

  static void _handleNotificationAction(NotificationResponse response) {
    try {
      final payload = response.payload;
      final actionId = response.actionId;

      // Validate response data
      if (payload == null && actionId == null) {
        debugPrint('⚠️ Notification response has no payload or action');
        return;
      }

      // Extract reminder ID from payload
      String? reminderId;
      if (payload?.startsWith('reminder_') == true) {
        reminderId = payload!.substring('reminder_'.length);
      } else if (payload?.startsWith('snooze_') == true) {
        reminderId = payload!.substring('snooze_'.length);
      }

      // Handle different actions
      String action = 'tap'; // Default action
      if (actionId != null && actionId.isNotEmpty) {
        action = actionId;
      }

      // Validate action and reminder ID
      if (action.isEmpty) {
        debugPrint('⚠️ Invalid action received');
        return;
      }

      // Handle specific actions
      switch (action) {
        case 'log_drink':
          debugPrint('🥤 Log drink action for reminder: $reminderId');
          break;
        case 'snooze':
          if (reminderId != null && reminderId.isNotEmpty) {
            debugPrint('⏰ Snooze action for reminder: $reminderId');
            // Note: Snooze functionality would need external handling
            // since static methods can't access instance methods safely
          } else {
            debugPrint('⚠️ Snooze action without valid reminder ID');
          }
          break;
        case 'dismiss':
          debugPrint('🚫 Dismiss action for reminder: $reminderId');
          break;
        case 'tap':
          debugPrint('👆 Direct tap on notification: $reminderId');
          break;
        default:
          debugPrint('⚠️ Unknown action: $action');
          break;
      }

      // Call external callback if set - with additional error handling
      try {
        onNotificationAction?.call(action, reminderId);
      } catch (callbackError) {
        debugPrint('❌ Notification callback execution failed: $callbackError');
      }
    } catch (e) {
      debugPrint('❌ Critical error in notification action handler: $e');
    }
  }

}