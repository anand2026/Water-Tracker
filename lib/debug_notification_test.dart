import 'package:flutter/material.dart';
import 'services/notification_debug_service.dart';
import 'models/reminder_model.dart';

/// Debug test app to identify notification issues
void main() {
  runApp(const DebugNotificationApp());
}

class DebugNotificationApp extends StatelessWidget {
  const DebugNotificationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Notification Debug Test',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const DebugNotificationScreen(),
    );
  }
}

class DebugNotificationScreen extends StatefulWidget {
  const DebugNotificationScreen({super.key});

  @override
  State<DebugNotificationScreen> createState() => _DebugNotificationScreenState();
}

class _DebugNotificationScreenState extends State<DebugNotificationScreen> {
  final NotificationDebugService _service = NotificationDebugService();
  bool _isInitialized = false;
  bool _permissionsGranted = false;
  int _pendingCount = 0;
  String _statusMessage = 'Not initialized';

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  Future<void> _initializeService() async {
    try {
      setState(() => _statusMessage = 'Initializing...');

      final initialized = await _service.initialize();
      setState(() {
        _isInitialized = initialized;
        _statusMessage = initialized ? 'Initialized ✅' : 'Failed to initialize ❌';
      });

      if (initialized) {
        await _checkPermissions();
      }
    } catch (e) {
      setState(() => _statusMessage = 'Error: $e');
    }
  }

  Future<void> _checkPermissions() async {
    try {
      final granted = await _service.arePermissionsGranted();
      final pending = await _service.getPendingNotificationsCount();

      setState(() {
        _permissionsGranted = granted;
        _pendingCount = pending;
        _statusMessage = granted ? 'Permissions granted ✅' : 'Permissions denied ❌';
      });
    } catch (e) {
      setState(() => _statusMessage = 'Permission check error: $e');
    }
  }

  Future<void> _requestPermissions() async {
    try {
      setState(() => _statusMessage = 'Requesting permissions...');

      final granted = await _service.requestPermissions();
      await _checkPermissions();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(granted ? 'Permissions granted!' : 'Permissions denied'),
            backgroundColor: granted ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() => _statusMessage = 'Permission request error: $e');
    }
  }

  Future<void> _showTestNotification() async {
    try {
      await _service.showTestNotification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Test notification sent! Check your notification panel.'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Test notification failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _scheduleTestReminder() async {
    try {
      final now = DateTime.now();
      final testTime = TimeOfDay(
        hour: now.hour,
        minute: (now.minute + 1) % 60, // 1 minute from now
      );

      final reminder = WaterReminder(
        id: 'debug_${now.millisecondsSinceEpoch}',
        time: testTime,
        isEnabled: true,
        createdAt: now,
      );

      setState(() => _statusMessage = 'Scheduling reminder...');

      final success = await _service.addReminder(reminder);
      await _checkPermissions(); // Refresh pending count

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? 'Reminder scheduled for ${reminder.formatTime()}!\nCheck debug console for details.'
                : 'Failed to schedule reminder'),
            backgroundColor: success ? Colors.green : Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }

      setState(() => _statusMessage = success
          ? 'Reminder scheduled for ${reminder.formatTime()}'
          : 'Failed to schedule reminder');

    } catch (e) {
      setState(() => _statusMessage = 'Schedule error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Debug Test'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card
            Card(
              color: _isInitialized
                  ? (_permissionsGranted ? Colors.green.shade50 : Colors.orange.shade50)
                  : Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Service Status',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text('Status: $_statusMessage'),
                    Text('Initialized: ${_isInitialized ? "✅" : "❌"}'),
                    Text('Permissions: ${_permissionsGranted ? "✅" : "❌"}'),
                    Text('Pending Notifications: $_pendingCount'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Action Buttons
            ElevatedButton.icon(
              onPressed: _isInitialized ? null : _initializeService,
              icon: const Icon(Icons.settings),
              label: const Text('Initialize Service'),
            ),

            const SizedBox(height: 8),

            ElevatedButton.icon(
              onPressed: _isInitialized ? _requestPermissions : null,
              icon: const Icon(Icons.security),
              label: const Text('Request Permissions'),
            ),

            const SizedBox(height: 8),

            ElevatedButton.icon(
              onPressed: _isInitialized && _permissionsGranted ? _showTestNotification : null,
              icon: const Icon(Icons.notifications),
              label: const Text('Test Immediate Notification'),
            ),

            const SizedBox(height: 8),

            ElevatedButton.icon(
              onPressed: _isInitialized && _permissionsGranted ? _scheduleTestReminder : null,
              icon: const Icon(Icons.schedule),
              label: const Text('Schedule Test Reminder (1 min)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),

            const SizedBox(height: 16),

            // Instructions
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Debug Instructions:',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    const Text('1. Tap "Initialize Service"'),
                    const Text('2. Tap "Request Permissions" (say YES)'),
                    const Text('3. Tap "Test Immediate Notification"'),
                    const Text('4. Tap "Schedule Test Reminder"'),
                    const Text('5. Wait 1 minute for scheduled notification'),
                    const SizedBox(height: 8),
                    const Text(
                      'Check the debug console (flutter logs) for detailed information about what\'s happening.',
                      style: TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
            ),

            const Spacer(),

            // Current Time
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      'Current Time',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    StreamBuilder(
                      stream: Stream.periodic(const Duration(seconds: 1)),
                      builder: (context, snapshot) {
                        final now = DateTime.now();
                        return Text(
                          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}',
                          style: Theme.of(context).textTheme.headlineMedium,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}