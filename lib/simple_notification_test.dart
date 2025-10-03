import 'package:flutter/material.dart';
import 'notification_service.dart';
import 'models/reminder_model.dart';

/// Simple working notification test - NO INFINITE LOOPS
void main() {
  runApp(const SimpleNotificationTestApp());
}

class SimpleNotificationTestApp extends StatelessWidget {
  const SimpleNotificationTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Simple Notification Test',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const SimpleNotificationTestScreen(),
    );
  }
}

class SimpleNotificationTestScreen extends StatefulWidget {
  const SimpleNotificationTestScreen({super.key});

  @override
  State<SimpleNotificationTestScreen> createState() => _SimpleNotificationTestScreenState();
}

class _SimpleNotificationTestScreenState extends State<SimpleNotificationTestScreen> {
  // Use singleton correctly
  final NotificationService _service = NotificationService.instance;
  bool _isInitialized = false;
  bool _permissionsGranted = false;
  String _statusMessage = 'Not initialized';

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  Future<void> _initializeService() async {
    try {
      setState(() => _statusMessage = 'Initializing...');

      // Initialize only once
      if (!_service.isInitialized) {
        await _service.initialize();
      }

      setState(() {
        _isInitialized = _service.isInitialized;
        _statusMessage = _isInitialized ? 'Initialized ✅' : 'Failed to initialize ❌';
      });

      if (_isInitialized) {
        await _checkPermissions();
      }
    } catch (e) {
      setState(() => _statusMessage = 'Error: $e');
    }
  }

  Future<void> _checkPermissions() async {
    try {
      final granted = _service.permissionsGranted;
      setState(() {
        _permissionsGranted = granted;
        _statusMessage = granted ? 'Ready to test notifications ✅' : 'Need permissions ⚠️';
      });
    } catch (e) {
      setState(() => _statusMessage = 'Permission check error: $e');
    }
  }

  Future<void> _requestPermissions() async {
    try {
      setState(() => _statusMessage = 'Requesting permissions...');

      await _service.requestPermissions();
      await _checkPermissions();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_permissionsGranted ? 'Permissions granted!' : 'Please enable notifications in Settings'),
            backgroundColor: _permissionsGranted ? Colors.green : Colors.orange,
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
        id: 'test_${now.millisecondsSinceEpoch}',
        time: testTime,
        isEnabled: true,
        createdAt: now,
      );

      setState(() => _statusMessage = 'Scheduling reminder...');

      final success = await _service.addReminder(reminder);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? 'Reminder scheduled for ${reminder.formatTime()}!'
                : 'Failed to schedule reminder'),
            backgroundColor: success ? Colors.green : Colors.red,
            duration: const Duration(seconds: 3),
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
        title: const Text('Simple Notification Test'),
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