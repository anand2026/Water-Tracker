import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'services/notification_manager.dart';
import 'services/app_navigation_service.dart';
import 'models/water_reminder.dart';

/// Example of how to integrate the notification system in your main app
class WaterTrackerApp extends StatefulWidget {
  const WaterTrackerApp({super.key});

  @override
  State<WaterTrackerApp> createState() => _WaterTrackerAppState();
}

class _WaterTrackerAppState extends State<WaterTrackerApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final NotificationManager _notificationManager = NotificationManager();

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    // Set up navigation service
    AppNavigationService().setNavigatorKey(_navigatorKey);

    // Set up notification tap handler
    NotificationManager.onNotificationTap = _handleNotificationTap;

    // Initialize notification manager
    final initialized = await _notificationManager.initialize();

    if (initialized) {
      // Request permissions
      final permissionsGranted = await _notificationManager.requestPermissions();

      if (permissionsGranted) {
        // Set up default reminders if none exist
        await _setupDefaultReminders();

        debugPrint('✅ Notifications initialized and permissions granted');
      } else {
        debugPrint('⚠️ Notification permissions not granted');
      }
    } else {
      debugPrint('❌ Failed to initialize notifications');
    }
  }

  Future<void> _setupDefaultReminders() async {
    final existingReminders = _notificationManager.getReminders();

    // Only set up defaults if no reminders exist
    if (existingReminders.isEmpty) {
      final defaultReminders = [
        WaterReminder(
          id: '1',
          time: const TimeOfDay(hour: 9, minute: 0),
          isEnabled: true,
        ),
        WaterReminder(
          id: '2',
          time: const TimeOfDay(hour: 11, minute: 30),
          isEnabled: true,
        ),
        WaterReminder(
          id: '3',
          time: const TimeOfDay(hour: 14, minute: 0),
          isEnabled: true,
        ),
        WaterReminder(
          id: '4',
          time: const TimeOfDay(hour: 16, minute: 30),
          isEnabled: true,
        ),
        WaterReminder(
          id: '5',
          time: const TimeOfDay(hour: 19, minute: 0),
          isEnabled: true,
        ),
      ];

      for (final reminder in defaultReminders) {
        await _notificationManager.addReminder(reminder);
      }

      debugPrint('✅ Set up ${defaultReminders.length} default reminders');
    }
  }

  void _handleNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    final actionId = response.actionId;

    debugPrint('🔔 Notification tapped - Payload: $payload, Action: $actionId');

    // Extract reminder ID from payload
    String? reminderId;
    if (payload?.startsWith('reminder_') == true) {
      reminderId = payload!.substring('reminder_'.length);
    } else if (payload?.startsWith('snooze_') == true) {
      reminderId = payload!.substring('snooze_'.length);
    }

    // Handle different actions
    switch (actionId) {
      case 'log_drink':
      case null: // Direct tap on notification
        // Navigate to water logging screen
        AppNavigationService().navigateToWaterLogging(reminderId: reminderId);
        break;

      case 'snooze_5':
      case 'snooze_10':
      case 'snooze_15':
        // Snooze handling is already done in NotificationManager
        AppNavigationService().showMessage('Reminder snoozed ⏰');
        break;

      case 'dismiss':
        // Dismiss handling is already done in NotificationManager
        debugPrint('Reminder dismissed');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Water Tracker',
      navigatorKey: _navigatorKey,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const HomeScreen(),
      routes: {
        '/water-logging': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return WaterLoggingScreen(
            fromNotification: args?['fromNotification'] ?? false,
            reminderId: args?['reminderId'],
          );
        },
      },
    );
  }
}

/// Example home screen with notification controls
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final NotificationManager _notificationManager = NotificationManager();
  List<WaterReminder> _reminders = [];
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadReminders();
  }

  void _loadReminders() {
    setState(() {
      _reminders = _notificationManager.getReminders();
      _notificationsEnabled = _notificationManager.isGloballyEnabled();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Water Tracker'),
        backgroundColor: const Color(0xFF42A5F5),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: _showTestNotification,
            tooltip: 'Test Notification',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Global notification toggle
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Notifications',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Switch(
                      value: _notificationsEnabled,
                      onChanged: _toggleNotifications,
                      activeThumbColor: const Color(0xFF42A5F5),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Reminders list
            const Text(
              'Water Reminders',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),

            Expanded(
              child: _reminders.isEmpty
                  ? const Center(
                      child: Text(
                        'No reminders set',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _reminders.length,
                      itemBuilder: (context, index) {
                        final reminder = _reminders[index];
                        return Card(
                          child: ListTile(
                            leading: const Icon(
                              Icons.access_time,
                              color: Color(0xFF42A5F5),
                            ),
                            title: Text(
                              _formatTime(reminder.time),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              reminder.isEnabled ? 'Active' : 'Disabled',
                              style: TextStyle(
                                color: reminder.isEnabled
                                    ? Colors.green
                                    : Colors.grey,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Switch(
                                  value: reminder.isEnabled,
                                  onChanged: (enabled) =>
                                      _toggleReminder(reminder, enabled),
                                  activeThumbColor: const Color(0xFF42A5F5),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete),
                                  color: Colors.red,
                                  onPressed: () => _deleteReminder(reminder),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // Add reminder button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _addReminder,
                icon: const Icon(Icons.add),
                label: const Text('Add Reminder'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF42A5F5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(TimeOfDay time) {
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }

  Future<void> _toggleNotifications(bool enabled) async {
    final success = await _notificationManager.setGloballyEnabled(enabled);
    if (success) {
      setState(() {
        _notificationsEnabled = enabled;
      });

      AppNavigationService().showMessage(
        enabled ? 'Notifications enabled' : 'Notifications disabled'
      );
    }
  }

  Future<void> _toggleReminder(WaterReminder reminder, bool enabled) async {
    final updatedReminder = reminder.copyWith(isEnabled: enabled);
    final success = await _notificationManager.updateReminder(reminder, updatedReminder);

    if (success) {
      _loadReminders();
      AppNavigationService().showMessage(
        enabled ? 'Reminder enabled' : 'Reminder disabled'
      );
    }
  }

  Future<void> _deleteReminder(WaterReminder reminder) async {
    final success = await _notificationManager.removeReminder(reminder.id);

    if (success) {
      _loadReminders();
      AppNavigationService().showMessage('Reminder deleted');
    }
  }

  Future<void> _addReminder() async {
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );

    if (time != null) {
      final reminder = WaterReminder(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        time: time,
        isEnabled: true,
      );

      final success = await _notificationManager.addReminder(reminder);

      if (success) {
        _loadReminders();
        AppNavigationService().showMessage('Reminder added');
      }
    }
  }

  Future<void> _showTestNotification() async {
    await _notificationManager.showTestNotification();
    AppNavigationService().showMessage('Test notification sent!');
  }
}

/// Example main.dart integration
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Handle app launched from terminated state by notification
  await _handleAppLaunchedFromNotification();

  runApp(const WaterTrackerApp());
}

/// Handle when app is launched from terminated state by notification
Future<void> _handleAppLaunchedFromNotification() async {
  final notificationManager = NotificationManager();

  // Initialize to check launch details
  await notificationManager.initialize();

  // Note: flutter_local_notifications doesn't provide launch details
  // For this functionality, you might need to use a different approach
  // such as storing notification data and checking on app start
}