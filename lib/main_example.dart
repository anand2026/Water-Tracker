import 'package:flutter/material.dart';
import 'services/notification_service.dart';
import 'services/navigation_service.dart';
import 'screens/water_logging_screen.dart';
import 'models/reminder_model.dart';

/// Complete main.dart example showing how to integrate the notification system
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize notification service
  final notificationService = NotificationService();
  final initialized = await notificationService.initialize();

  if (initialized) {
    debugPrint('✅ Notification service initialized successfully');
  } else {
    debugPrint('❌ Failed to initialize notification service');
  }

  runApp(const WaterTrackerApp());
}

class WaterTrackerApp extends StatefulWidget {
  const WaterTrackerApp({super.key});

  @override
  State<WaterTrackerApp> createState() => _WaterTrackerAppState();
}

class _WaterTrackerAppState extends State<WaterTrackerApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    _setupNotifications();
  }

  Future<void> _setupNotifications() async {
    // Set up navigation service
    NavigationService().setNavigatorKey(_navigatorKey);

    // Set up notification action handler
    NotificationService.onNotificationAction = _handleNotificationAction;

    // Request permissions
    final permissionsGranted = await _notificationService.requestPermissions();

    if (permissionsGranted) {
      debugPrint('✅ Notification permissions granted');

      // Set up default reminders if none exist
      final existingReminders = _notificationService.getReminders();
      if (existingReminders.isEmpty) {
        await _notificationService.scheduleDefaultReminders();
        debugPrint('✅ Default reminders scheduled');
      }
    } else {
      debugPrint('⚠️ Notification permissions not granted');
    }
  }

  void _handleNotificationAction(String action, String? reminderId) {
    debugPrint('🔔 Notification action: $action, reminderId: $reminderId');

    switch (action) {
      case 'log_drink':
      case 'tap':
        // Navigate to water logging screen
        NavigationService().navigateToWaterLogging(reminderId: reminderId);
        break;

      case 'snooze':
        // Snooze is already handled in the notification service
        NavigationService().showMessage('Reminder snoozed for 10 minutes ⏰');
        break;

      case 'dismiss':
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
        useMaterial3: true,
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

/// Home screen with notification management
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final NotificationService _notificationService = NotificationService();
  List<WaterReminder> _reminders = [];
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    setState(() {
      _reminders = _notificationService.getReminders();
      _notificationsEnabled = _notificationService.areNotificationsEnabled();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Water Tracker'),
        backgroundColor: const Color(0xFF42A5F5),
        foregroundColor: Colors.white,
        centerTitle: true,
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
            _buildNotificationToggle(),

            const SizedBox(height: 24),

            // Reminders section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Water Reminders',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1565C0),
                  ),
                ),
                TextButton.icon(
                  onPressed: _addReminder,
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF42A5F5),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Reminders list
            Expanded(
              child: _reminders.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      itemCount: _reminders.length,
                      itemBuilder: (context, index) {
                        final reminder = _reminders[index];
                        return _buildReminderItem(reminder, index);
                      },
                    ),
            ),

            // Status info
            _buildStatusInfo(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addReminder,
        backgroundColor: const Color(0xFF42A5F5),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildNotificationToggle() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              _notificationsEnabled ? Icons.notifications_active : Icons.notifications_off,
              color: _notificationsEnabled ? const Color(0xFF42A5F5) : Colors.grey,
              size: 32,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Water Reminders',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _notificationsEnabled
                        ? 'Get reminded to stay hydrated'
                        : 'Notifications are disabled',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
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
    );
  }

  Widget _buildReminderItem(WaterReminder reminder, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: reminder.isEnabled
              ? const Color(0xFF42A5F5)
              : Colors.grey[400],
          child: Icon(
            Icons.access_time,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          reminder.formatTime(),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          reminder.isEnabled ? 'Active' : 'Disabled',
          style: TextStyle(
            color: reminder.isEnabled ? Colors.green : Colors.grey,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: reminder.isEnabled,
              onChanged: (enabled) => _toggleReminder(reminder, enabled),
              activeThumbColor: const Color(0xFF42A5F5),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _deleteReminder(reminder),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.water_drop_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No reminders set',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the + button to add your first reminder',
            style: TextStyle(
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _setupDefaultReminders,
            icon: const Icon(Icons.auto_fix_high),
            label: const Text('Set up default reminders'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF42A5F5),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusInfo() {
    return FutureBuilder<int>(
      future: _notificationService.getPendingNotificationsCount(),
      builder: (context, snapshot) {
        final pendingCount = snapshot.data ?? 0;
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Active reminders: ${_reminders.where((r) => r.isEnabled).length}',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              Text(
                'Pending: $pendingCount',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _toggleNotifications(bool enabled) async {
    final success = await _notificationService.setNotificationsEnabled(enabled);
    if (success) {
      setState(() {
        _notificationsEnabled = enabled;
      });

      NavigationService().showMessage(
        enabled ? 'Notifications enabled' : 'Notifications disabled'
      );
    }
  }

  Future<void> _toggleReminder(WaterReminder reminder, bool enabled) async {
    final updatedReminder = reminder.copyWith(isEnabled: enabled);
    final success = await _notificationService.updateReminder(reminder.id, updatedReminder);

    if (success) {
      _loadData();
      NavigationService().showMessage(
        enabled ? 'Reminder enabled' : 'Reminder disabled'
      );
    }
  }

  Future<void> _deleteReminder(WaterReminder reminder) async {
    final confirmed = await NavigationService().showConfirmationDialog(
      title: 'Delete Reminder',
      message: 'Are you sure you want to delete the ${reminder.formatTime()} reminder?',
      confirmText: 'Delete',
    );

    if (confirmed) {
      final success = await _notificationService.removeReminder(reminder.id);
      if (success) {
        _loadData();
        NavigationService().showMessage('Reminder deleted');
      }
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
        createdAt: DateTime.now(),
      );

      final success = await _notificationService.addReminder(reminder);
      if (success) {
        _loadData();
        NavigationService().showMessage('Reminder added for ${reminder.formatTime()}');
      }
    }
  }

  Future<void> _setupDefaultReminders() async {
    final success = await _notificationService.scheduleDefaultReminders();
    if (success) {
      _loadData();
      NavigationService().showMessage('Default reminders set up!');
    }
  }

  Future<void> _showTestNotification() async {
    await _notificationService.showTestNotification();
    NavigationService().showMessage('Test notification sent!');
  }
}