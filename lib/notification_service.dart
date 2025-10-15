import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  static NotificationService get instance => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _permissionsGranted = false;
  bool _hasRequestedPermissions = false;

  bool get isInitialized => _initialized;
  bool get permissionsGranted => _permissionsGranted;

  Future<void> initialize() async {
    if (_initialized) return;

    // Skip initialization on web
    if (kIsWeb) {
      _initialized = true;
      _permissionsGranted = false;
      if (kDebugMode) {
        print('Web platform: Skipping notification initialization');
      }
      return;
    }

    try {
      // Initialize timezone data
      tz.initializeTimeZones();

      // Android initialization
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

      // iOS initialization
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      final initialized = await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      if (kDebugMode) {
        print('Notification plugin initialized: $initialized');
      }

      // Create notification channel explicitly for Android
      if (defaultTargetPlatform == TargetPlatform.android) {
        await _createNotificationChannel();
      }

      // Load permission status from storage
      await _loadPermissionStatus();

      _initialized = true;

      // Clear any potentially corrupted notifications on initialization
      try {
        final pending = await getPendingNotifications();
        if (kDebugMode) {
          print('Found ${pending.length} pending notifications on initialization');
        }
        // If we detect issues with pending notifications, clear them
        for (final notification in pending) {
          if (notification.payload == null || notification.payload!.isEmpty) {
            if (kDebugMode) {
              print('Found notification with null/empty payload, clearing: ${notification.id}');
            }
            await cancelNotification(notification.id);
          }
        }
      } catch (pendingError) {
        if (kDebugMode) {
          print('Error checking pending notifications, clearing all: $pendingError');
        }
        await _clearCorruptedNotifications();
      }

      // Don't auto-request permissions - let user trigger it via enable button

      if (kDebugMode) {
        print('NotificationService initialized successfully');
        print('Notification permissions granted: $_permissionsGranted');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing notifications: $e');
      }
      _initialized = false;
      _permissionsGranted = false;

      // Try to clear corrupted notifications even if initialization failed
      try {
        await _clearCorruptedNotifications();
      } catch (clearError) {
        if (kDebugMode) {
          print('Error clearing corrupted notifications during failed init: $clearError');
        }
      }
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    // Handle notification tap - could navigate to add water screen
    if (kDebugMode) {
      print('Notification tapped: ${response.payload}');
    }
  }

  Future<bool> requestPermissions() async {
    if (!_initialized) {
      throw StateError('NotificationService not initialized. Call initialize() first.');
    }

    // Web doesn't support local notifications the same way
    if (kIsWeb) {
      _permissionsGranted = false;
      _hasRequestedPermissions = true;
      await _savePermissionStatus();
      if (kDebugMode) {
        print('Web platform: Notifications not supported');
      }
      return false;
    }

    bool? granted;

    try {
      // Request permissions for different platforms
      if (defaultTargetPlatform == TargetPlatform.android) {
        if (kDebugMode) {
          print('🔔 Requesting Android notification permissions...');
        }

        // For Android 13+ (API 33+)
        final androidImplementation = _notifications
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

        if (androidImplementation != null) {
          if (kDebugMode) {
            print('🔔 Android implementation found - directly requesting permissions');
          }

          // First check current status
          try {
            final currentStatus = await androidImplementation.areNotificationsEnabled();
            if (kDebugMode) {
              print('🔔 Current notification status before request: $currentStatus');
            }
          } catch (e) {
            if (kDebugMode) {
              print('🔔 Could not check current status: $e');
            }
          }

          try {
            // Always request notification permissions directly - this shows the popup
            if (kDebugMode) {
              print('🔔 Calling requestNotificationsPermission() - this should show dialog');
            }
            granted = await androidImplementation.requestNotificationsPermission();

            if (kDebugMode) {
              print('🔔 Permission request completed. Result: $granted');
            }
          } catch (e) {
            if (kDebugMode) {
              print('🔔 Error during permission request: $e');
            }
            granted = false;
          }

          // If still not granted, show explanation
          if (granted == null || !granted) {
            if (kDebugMode) {
              print('❌ Notification permission denied by user.');
              print('📱 User needs to manually enable in device settings:');
              print('   Settings > Apps > Water Tracker > Notifications > Allow notifications');
            }
          } else {
            if (kDebugMode) {
              print('✅ Notification permission granted!');
            }
          }

          // Also request exact alarm permissions for Android 12+
          try {
            if (kDebugMode) {
              print('Requesting exact alarm permissions...');
            }
            final exactAlarmGranted = await androidImplementation.requestExactAlarmsPermission();
            if (kDebugMode) {
              print('Exact alarm permission granted: $exactAlarmGranted');
            }
          } catch (e) {
            if (kDebugMode) {
              print('Error requesting exact alarm permission: $e');
            }
          }
        } else {
          if (kDebugMode) {
            print('❌ Android implementation is null - plugin issue');
          }
          granted = false;
        }
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        if (kDebugMode) {
          print('Requesting iOS notification permissions...');
        }

        granted = await _notifications
            .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            );

        if (kDebugMode) {
          print('iOS permission result: $granted');
        }
      }

      _permissionsGranted = granted ?? false;
      _hasRequestedPermissions = true;

      // Save permission status to storage
      await _savePermissionStatus();

      if (kDebugMode) {
        print('\n🔔 Final notification permission status: $_permissionsGranted');
        if (!_permissionsGranted) {
          print('\n📋 TROUBLESHOOTING STEPS:');
          print('1. Open device Settings');
          print('2. Go to Apps > Water Tracker');
          print('3. Tap Notifications');
          print('4. Enable "Show notifications"');
          print('5. Enable all notification categories');
          print('6. Return to app and try again\n');
        }
      }

    } catch (e) {
      if (kDebugMode) {
        print('❌ Critical error requesting notification permissions: $e');
      }
      _permissionsGranted = false;
    }

    return _permissionsGranted;
  }

  Future<void> scheduleWaterReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
    bool repeating = true,
  }) async {
    if (!_initialized) await initialize();

    if (!_permissionsGranted) {
      if (kDebugMode) {
        print('Cannot schedule notification: permissions not granted');
      }
      return;
    }

    try {
      // Ensure payload is never null to prevent serialization issues
      final safePayload = payload ?? 'water_reminder';

      final tzDateTime = tz.TZDateTime.from(scheduledTime, tz.local);

      if (kDebugMode) {
        print('Scheduling notification:');
        print('  ID: $id');
        print('  Title: $title');
        print('  Scheduled for: $scheduledTime');
        print('  TZ DateTime: $tzDateTime');
        print('  Repeating: $repeating');
        print('  Payload: $safePayload');
      }

      // Create notification details with explicit type safety
      final notificationDetails = NotificationDetails(
        android: AndroidNotificationDetails(
          'water_reminders',
          'Water Reminders',
          channelDescription: 'Notifications to remind you to drink water',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          enableVibration: true,
          playSound: true,
          autoCancel: true,
          ongoing: false,
          showWhen: true,
          // Add additional parameters to ensure proper serialization
          enableLights: true,
          ledColor: const Color(0xFF42A5F5),
          ledOnMs: 1000,
          ledOffMs: 500,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

      if (repeating) {
        // For daily repeating notifications
        await _notifications.zonedSchedule(
          id,
          title,
          body,
          tzDateTime,
          notificationDetails,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time, // Repeat daily at same time
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: safePayload,
        );
      } else {
        // For one-time notifications
        await _notifications.zonedSchedule(
          id,
          title,
          body,
          tzDateTime,
          notificationDetails,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: safePayload,
        );
      }

      if (kDebugMode) {
        print('Notification scheduled successfully!');
        // Show pending notifications for verification
        final pending = await getPendingNotifications();
        print('Total pending notifications: ${pending.length}');
      }

    } catch (e) {
      if (kDebugMode) {
        print('Error scheduling notification: $e');
      }
      // If there's an error, try to clear potentially corrupted notifications
      try {
        await _clearCorruptedNotifications();
      } catch (clearError) {
        if (kDebugMode) {
          print('Error clearing corrupted notifications: $clearError');
        }
      }
    }
  }

  Future<void> scheduleDailyWaterReminder({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    String? payload,
  }) async {
    if (!_initialized) await initialize();

    if (!_permissionsGranted) {
      if (kDebugMode) {
        print('Cannot schedule daily reminder: permissions not granted');
      }
      return;
    }

    final now = DateTime.now();
    var scheduledTime = DateTime(now.year, now.month, now.day, hour, minute);

    // If the time has already passed today, schedule for tomorrow
    if (scheduledTime.isBefore(now)) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
      if (kDebugMode) {
        print('Time has passed today, scheduling for tomorrow: $scheduledTime');
      }
    } else {
      if (kDebugMode) {
        print('Scheduling for today: $scheduledTime');
      }
    }

    await scheduleWaterReminder(
      id: id,
      title: title,
      body: body,
      scheduledTime: scheduledTime,
      payload: payload,
      repeating: true,
    );
  }

  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }

  Future<void> showInstantNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_initialized) await initialize();

    if (!_permissionsGranted) {
      if (kDebugMode) {
        print('Cannot show notification: permissions not granted');
      }
      return;
    }

    try {
      // Ensure payload is never null to prevent serialization issues
      final safePayload = payload ?? 'instant_notification';

      await _notifications.show(
        id,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'water_reminders',
            'Water Reminders',
            channelDescription: 'Notifications to remind you to drink water',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            enableVibration: true,
            playSound: true,
            autoCancel: true,
            ongoing: false,
            showWhen: true,
            // Add additional parameters to ensure proper serialization
            enableLights: true,
            ledColor: const Color(0xFF42A5F5),
            ledOnMs: 1000,
            ledOffMs: 500,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: safePayload,
      );

      if (kDebugMode) {
        print('Instant notification shown: $title');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error showing instant notification: $e');
      }
    }
  }

  // Generate notification messages
  static List<String> get reminderMessages => [
    '💧 Time to drink water!',
    '🚰 Stay hydrated - drink some water',
    '💦 Your body needs water right now',
    '🌊 Hydration time! Drink up',
    '💧 Don\'t forget to drink water',
    '🚰 Keep up your hydration streak',
    '💦 Time for a water break',
    '🌊 Your daily hydration reminder',
  ];

  static String getRandomMessage() {
    return reminderMessages[(DateTime.now().millisecondsSinceEpoch % reminderMessages.length)];
  }

  // Persistence methods for notification permissions
  Future<void> _savePermissionStatus() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notification_permissions_granted', _permissionsGranted);
    await prefs.setBool('notification_permissions_requested', _hasRequestedPermissions);
  }

  Future<void> _loadPermissionStatus() async {
    final prefs = await SharedPreferences.getInstance();
    _permissionsGranted = prefs.getBool('notification_permissions_granted') ?? false;
    _hasRequestedPermissions = prefs.getBool('notification_permissions_requested') ?? false;
  }

  // Method to check current permission status without requesting
  Future<bool> checkPermissionStatus() async {
    if (!_initialized) await initialize();

    // Web doesn't support notifications the same way
    if (kIsWeb) {
      return false;
    }

    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidImplementation = _notifications
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

        if (androidImplementation != null) {
          final granted = await androidImplementation.areNotificationsEnabled();
          _permissionsGranted = granted ?? false;
        }
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        // iOS doesn't have a direct way to check, assume from stored state
        await _loadPermissionStatus();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error checking notification permissions: $e');
      }
      _permissionsGranted = false;
    }

    return _permissionsGranted;
  }

  // Method to re-request permissions (for settings screen)
  Future<bool> retryPermissionRequest() async {
    _hasRequestedPermissions = false;
    return await requestPermissions();
  }

  // Method to force permission request without clearing app data
  Future<bool> forcePermissionRequest() async {
    if (kDebugMode) {
      print('🔔 Force requesting notification permissions...');
    }

    // Reset permission tracking state only
    _hasRequestedPermissions = false;
    _permissionsGranted = false;

    // Clear only notification permission preferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('notification_permissions_granted');
    await prefs.remove('notification_permissions_requested');

    return await requestPermissions();
  }

  // Method to open app settings directly when permission dialog can't be shown
  Future<bool> openNotificationSettings() async {
    if (kDebugMode) {
      print('🔔 Opening notification settings since dialog cannot be shown when already granted');
    }

    try {
      // Try to open app notification settings directly
      bool success = await openAppNotificationSettings();

      if (!success) {
        // Fallback to general app settings
        success = await openAppSettingsAlternative();
      }

      return success;
    } catch (e) {
      if (kDebugMode) {
        print('🔔 Error opening notification settings: $e');
      }
      return false;
    }
  }

  // Direct method to request notification permission popup with smart fallback
  Future<bool> requestNotificationPermissionDirectly() async {
    if (kDebugMode) {
      print('🔔 Direct notification permission request with smart fallback');
    }

    try {
      final androidImplementation = _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      if (androidImplementation != null) {
        // First check if we're already enabled
        final currentStatus = await androidImplementation.areNotificationsEnabled();
        if (currentStatus == true) {
          if (kDebugMode) {
            print('🔔 Notifications already enabled!');
          }
          _permissionsGranted = true;
          _hasRequestedPermissions = true;
          await _savePermissionStatus();
          return true;
        }

        if (kDebugMode) {
          print('🔔 Calling requestNotificationsPermission() - attempting to show popup');
        }

        final granted = await androidImplementation.requestNotificationsPermission();

        if (kDebugMode) {
          print('🔔 Direct permission result: $granted');
        }

        // If permission request returned false, just return false
        // This happens either when user clicks "Don't allow" or Android blocks the popup
        if (granted == false) {
          if (kDebugMode) {
            print('🔔 Permission denied or blocked - dialog dismissed');
          }

          // Don't open settings automatically - just return false
          return false;
        }

        // Update internal state for successful grants
        _permissionsGranted = granted ?? false;
        _hasRequestedPermissions = true;

        // Save permission status to storage
        await _savePermissionStatus();

        if (kDebugMode) {
          print('🔔 Updated internal permission state: $_permissionsGranted');
        }

        return _permissionsGranted;
      }
    } catch (e) {
      if (kDebugMode) {
        print('🔔 Error in direct permission request: $e');
      }
    }

    return false;
  }

  // Create notification channel explicitly (Android 8.0+)
  Future<void> _createNotificationChannel() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidImplementation = _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      if (androidImplementation != null) {
        const androidNotificationChannel = AndroidNotificationChannel(
          'water_reminders',
          'Water Reminders',
          description: 'Notifications to remind you to drink water',
          importance: Importance.high,
          enableVibration: true,
          playSound: true,
        );

        await androidImplementation.createNotificationChannel(androidNotificationChannel);

        if (kDebugMode) {
          print('Notification channel created: water_reminders');
        }
      }
    }
  }

  // Method to show instructions for enabling notifications in device settings
  void showNotificationInstructions() {
    if (kDebugMode) {
      print('\n=== NOTIFICATION SETUP INSTRUCTIONS ===');
      print('If notifications are not working:');
      print('1. Go to device Settings');
      print('2. Find Apps or Application Manager');
      print('3. Search for "Water Tracker"');
      print('4. Tap on Notifications');
      print('5. Enable "Show notifications"');
      print('6. Make sure all notification categories are enabled');
      print('7. Return to the app and try again');
      print('=========================================\n');
    }
  }

  // Comprehensive notification debugging
  Future<Map<String, dynamic>> getNotificationDebugInfo() async {
    final debugInfo = <String, dynamic>{};

    try {
      debugInfo['initialized'] = _initialized;
      debugInfo['permissions_granted'] = _permissionsGranted;
      debugInfo['has_requested_permissions'] = _hasRequestedPermissions;
      debugInfo['platform'] = defaultTargetPlatform.toString();
      debugInfo['is_web'] = kIsWeb;

      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidImplementation = _notifications
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

        if (androidImplementation != null) {
          try {
            final enabled = await androidImplementation.areNotificationsEnabled();
            debugInfo['android_notifications_enabled'] = enabled;

            final exactAlarmEnabled = await androidImplementation.canScheduleExactNotifications();
            debugInfo['android_exact_alarm_enabled'] = exactAlarmEnabled;

            final pendingRequests = await getPendingNotifications();
            debugInfo['pending_notifications_count'] = pendingRequests.length;
            debugInfo['pending_notifications'] = pendingRequests.map((n) => {
              'id': n.id,
              'title': n.title,
              'body': n.body,
            }).toList();
          } catch (e) {
            debugInfo['android_check_error'] = e.toString();
          }
        } else {
          debugInfo['android_implementation'] = 'null';
        }
      }
    } catch (e) {
      debugInfo['debug_error'] = e.toString();
    }

    return debugInfo;
  }

  // Test notification method with detailed debugging
  Future<Map<String, dynamic>> testNotificationWithDebug() async {
    final result = <String, dynamic>{};

    if (kDebugMode) {
      print('\n=== COMPREHENSIVE NOTIFICATION TEST ===');
    }

    // Get initial debug info
    final debugInfo = await getNotificationDebugInfo();
    result['initial_state'] = debugInfo;

    if (kDebugMode) {
      print('Initial state: $debugInfo');
    }

    // Initialize if needed
    if (!_initialized) {
      if (kDebugMode) print('Initializing notification service...');
      await initialize();
      result['initialization_completed'] = true;
    }

    // Request permissions if needed
    if (!_permissionsGranted) {
      if (kDebugMode) print('Requesting permissions...');
      final granted = await requestPermissions();
      result['permission_request_result'] = granted;

      if (kDebugMode) {
        print('Permission request result: $granted');
      }
    }

    // Get updated debug info
    final updatedDebugInfo = await getNotificationDebugInfo();
    result['final_state'] = updatedDebugInfo;

    if (kDebugMode) {
      print('Final state: $updatedDebugInfo');
    }

    // Try to send test notification
    if (_permissionsGranted) {
      try {
        if (kDebugMode) print('Sending test notification...');
        await showInstantNotification(
          id: 999,
          title: '💧 Test Notification',
          body: 'If you see this, notifications are working!',
          payload: 'test',
        );
        result['test_notification_sent'] = true;

        if (kDebugMode) {
          print('Test notification sent successfully!');
        }
      } catch (e) {
        result['test_notification_error'] = e.toString();
        if (kDebugMode) {
          print('Error sending test notification: $e');
        }
      }
    } else {
      result['test_notification_sent'] = false;
      result['reason'] = 'Permissions not granted';

      if (kDebugMode) {
        print('Cannot send test notification: permissions not granted');
        print('Try the following:');
        print('1. Check if the app appears in device Settings > Apps');
        print('2. Look for notification permissions in app settings');
        print('3. Ensure "Show notifications" is enabled');
        print('4. Check if notification categories are enabled');
      }
    }

    if (kDebugMode) {
      print('=== END COMPREHENSIVE TEST ===\n');
      print('Full result: $result');
    }

    return result;
  }

  // Method to schedule a test notification for 10 seconds from now
  Future<void> scheduleTestNotification() async {
    try {
      final now = DateTime.now();
      final testTime = now.add(const Duration(seconds: 10));

      await scheduleWaterReminder(
        id: 9999,
        title: '🧪 Test Scheduled Notification',
        body: 'This notification was scheduled for 10 seconds ago!',
        scheduledTime: testTime,
        payload: 'test_scheduled',
        repeating: false,
      );

      if (kDebugMode) {
        print('Test notification scheduled for $testTime (10 seconds from now)');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error in scheduleTestNotification: $e');
      }
      // In release mode, silently handle the error without crashing
    }
  }

  // Method to open Android app notification settings directly
  Future<bool> openAppNotificationSettings() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      if (kDebugMode) {
        print('Opening notification settings only supported on Android');
      }
      return false;
    }

    try {
      // Use Android method channel to open app notification settings
      const platform = MethodChannel('water_tracker/settings');
      final result = await platform.invokeMethod('openNotificationSettings');

      if (kDebugMode) {
        print('Opened notification settings: $result');
      }

      return result == true;
    } catch (e) {
      if (kDebugMode) {
        print('Error opening notification settings: $e');
      }

      // Fallback: try using android implementation if available
      try {
        final androidImplementation = _notifications
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

        if (androidImplementation != null) {
          // This might not work on all devices, but worth trying
          await androidImplementation.requestNotificationsPermission();
          return true;
        }
      } catch (fallbackError) {
        if (kDebugMode) {
          print('Fallback also failed: $fallbackError');
        }
      }

      return false;
    }
  }

  // Alternative method using package info to get package name
  Future<bool> openAppSettingsAlternative() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }

    try {
      // Try to use the android intent to open app info
      const platform = MethodChannel('water_tracker/settings');
      final result = await platform.invokeMethod('openAppInfo');

      if (kDebugMode) {
        print('Opened app info settings: $result');
      }

      return result == true;
    } catch (e) {
      if (kDebugMode) {
        print('Error opening app settings: $e');
      }
      // In release mode, silently return false instead of crashing
      return false;
    }
  }

  // Check if app is exempt from battery optimization
  Future<bool> isBatteryOptimizationIgnored() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return true; // Not applicable on non-Android
    }

    try {
      const platform = MethodChannel('water_tracker/settings');
      final result = await platform.invokeMethod('checkBatteryOptimization');

      if (kDebugMode) {
        print('Battery optimization ignored: $result');
      }

      return result == true;
    } catch (e) {
      if (kDebugMode) {
        print('Error checking battery optimization: $e');
      }
      // In release mode, assume false and don't crash
      return false;
    }
  }

  // Request battery optimization exemption
  Future<bool> requestBatteryOptimizationExemption() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return true;
    }

    try {
      const platform = MethodChannel('water_tracker/settings');
      final result = await platform.invokeMethod('requestBatteryOptimization');

      if (kDebugMode) {
        print('Battery optimization exemption requested: $result');
      }

      return result == true;
    } catch (e) {
      if (kDebugMode) {
        print('Error requesting battery optimization exemption: $e');
      }
      // In release mode, return false without crashing
      return false;
    }
  }

  // Open battery optimization settings
  Future<bool> openBatteryOptimizationSettings() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return true;
    }

    try {
      const platform = MethodChannel('water_tracker/settings');
      final result = await platform.invokeMethod('openBatterySettings');

      if (kDebugMode) {
        print('Opened battery optimization settings: $result');
      }

      return result == true;
    } catch (e) {
      if (kDebugMode) {
        print('Error opening battery optimization settings: $e');
      }
      // In release mode, return false without crashing
      return false;
    }
  }

  // Method to clear potentially corrupted notifications
  Future<void> _clearCorruptedNotifications() async {
    try {
      if (kDebugMode) {
        print('Clearing potentially corrupted notifications...');
      }

      // Cancel all existing notifications to prevent serialization issues
      await _notifications.cancelAll();

      if (kDebugMode) {
        print('All notifications cleared successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error clearing notifications: $e');
      }
      // If even clearing fails, we'll just continue
    }
  }

  // Method to safely clear all notifications and reset
  Future<void> clearAllNotificationsAndReset() async {
    try {
      await _clearCorruptedNotifications();

      // Clear any stored notification preferences that might be corrupted
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('scheduled_notifications');
      await prefs.remove('notification_ids');

      if (kDebugMode) {
        print('Notification system reset completed');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error during notification reset: $e');
      }
    }
  }
}