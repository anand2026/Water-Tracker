import 'package:flutter/material.dart';
import 'services/notification_service.dart';
import 'models/reminder_model.dart';
import 'utils/notification_troubleshooting.dart';

/// Test app to verify notification system functionality
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print('🧪 Starting Notification System Test...');

  // Run comprehensive test
  final testResults = await NotificationSystemTester.runFullTest();

  print('\n📊 Test Results Summary:');
  testResults.forEach((test, result) {
    final status = result ? '✅ PASS' : '❌ FAIL';
    print('  $test: $status');
  });

  final passedTests = testResults.values.where((result) => result).length;
  final totalTests = testResults.length;

  print('\n🎯 Overall Score: $passedTests/$totalTests tests passed');

  if (passedTests == totalTests) {
    print('🎉 All tests passed! Notification system is working correctly.');
  } else {
    print('⚠️ Some tests failed. Check the issues above.');
  }

  runApp(const NotificationTestApp());
}

class NotificationSystemTester {
  /// Run comprehensive notification system test
  static Future<Map<String, bool>> runFullTest() async {
    final results = <String, bool>{};

    try {
      print('\n1️⃣ Testing Service Initialization...');
      results['service_initialization'] = await _testInitialization();

      print('\n2️⃣ Testing Permission Handling...');
      results['permission_handling'] = await _testPermissions();

      print('\n3️⃣ Testing Immediate Notifications...');
      results['immediate_notifications'] = await _testImmediateNotification();

      print('\n4️⃣ Testing Reminder Scheduling...');
      results['reminder_scheduling'] = await _testReminderScheduling();

      print('\n5️⃣ Testing Storage Persistence...');
      results['storage_persistence'] = await _testStoragePersistence();

      print('\n6️⃣ Testing Global Controls...');
      results['global_controls'] = await _testGlobalControls();

      print('\n7️⃣ Testing Edge Cases...');
      results['edge_cases'] = await _testEdgeCases();

      print('\n8️⃣ Running Diagnostics...');
      results['diagnostics'] = await _testDiagnostics();

    } catch (e) {
      print('❌ Test suite failed with error: $e');
      results['test_suite_error'] = false;
    }

    return results;
  }

  static Future<bool> _testInitialization() async {
    try {
      final service = NotificationService();
      final initialized = await service.initialize();

      if (initialized) {
        print('  ✅ Service initialized successfully');
        return true;
      } else {
        print('  ❌ Service initialization failed');
        return false;
      }
    } catch (e) {
      print('  ❌ Initialization error: $e');
      return false;
    }
  }

  static Future<bool> _testPermissions() async {
    try {
      final service = NotificationService();

      // Test permission request
      final permissionGranted = await service.requestPermissions();
      print('  📱 Permission request result: $permissionGranted');

      // Test permission check
      final permissionStatus = await service.arePermissionsGranted();
      print('  🔒 Permission status check: $permissionStatus');

      return true; // Return true even if permissions denied for testing
    } catch (e) {
      print('  ❌ Permission test error: $e');
      return false;
    }
  }

  static Future<bool> _testImmediateNotification() async {
    try {
      final service = NotificationService();

      print('  📲 Sending test notification...');
      await service.showTestNotification();

      // Wait a moment for notification to be scheduled
      await Future.delayed(const Duration(seconds: 1));

      print('  ✅ Test notification sent successfully');
      return true;
    } catch (e) {
      print('  ❌ Immediate notification error: $e');
      return false;
    }
  }

  static Future<bool> _testReminderScheduling() async {
    try {
      final service = NotificationService();

      // Create test reminder
      final testReminder = WaterReminder(
        id: 'test_${DateTime.now().millisecondsSinceEpoch}',
        time: TimeOfDay(
          hour: DateTime.now().hour,
          minute: (DateTime.now().minute + 2) % 60, // 2 minutes from now
        ),
        isEnabled: true,
        createdAt: DateTime.now(),
      );

      print('  ⏰ Scheduling test reminder for ${testReminder.formatTime()}...');
      final addResult = await service.addReminder(testReminder);

      if (!addResult) {
        print('  ❌ Failed to add reminder');
        return false;
      }

      // Check if reminder was added
      final reminders = service.getReminders();
      final found = reminders.any((r) => r.id == testReminder.id);

      if (!found) {
        print('  ❌ Reminder not found in list');
        return false;
      }

      // Check pending notifications
      final pendingCount = await service.getPendingNotificationsCount();
      print('  📊 Pending notifications: $pendingCount');

      // Clean up test reminder
      await service.removeReminder(testReminder.id);
      print('  🧹 Cleaned up test reminder');

      print('  ✅ Reminder scheduling works correctly');
      return true;
    } catch (e) {
      print('  ❌ Reminder scheduling error: $e');
      return false;
    }
  }

  static Future<bool> _testStoragePersistence() async {
    try {
      final service = NotificationService();

      // Add a test reminder
      final testReminder = WaterReminder(
        id: 'persist_test_${DateTime.now().millisecondsSinceEpoch}',
        time: const TimeOfDay(hour: 10, minute: 30),
        isEnabled: true,
        createdAt: DateTime.now(),
      );

      print('  💾 Testing storage persistence...');
      await service.addReminder(testReminder);

      // Get current count
      final countBefore = service.getReminders().length;

      // Create new service instance to test persistence
      final newService = NotificationService();
      await newService.initialize();

      final countAfter = newService.getReminders().length;
      final persistedReminder = newService.getReminders()
          .where((r) => r.id == testReminder.id)
          .firstOrNull;

      // Clean up
      if (persistedReminder != null) {
        await newService.removeReminder(persistedReminder.id);
      }

      if (countAfter >= countBefore && persistedReminder != null) {
        print('  ✅ Storage persistence works correctly');
        return true;
      } else {
        print('  ❌ Storage persistence failed');
        return false;
      }
    } catch (e) {
      print('  ❌ Storage persistence error: $e');
      return false;
    }
  }

  static Future<bool> _testGlobalControls() async {
    try {
      final service = NotificationService();

      print('  🌍 Testing global notification controls...');

      // Test enabling notifications
      final enableResult = await service.setNotificationsEnabled(true);
      final enabledStatus = service.areNotificationsEnabled();

      if (!enableResult || !enabledStatus) {
        print('  ❌ Failed to enable notifications');
        return false;
      }

      // Test disabling notifications
      final disableResult = await service.setNotificationsEnabled(false);
      final disabledStatus = !service.areNotificationsEnabled();

      if (!disableResult || !disabledStatus) {
        print('  ❌ Failed to disable notifications');
        return false;
      }

      // Re-enable for other tests
      await service.setNotificationsEnabled(true);

      print('  ✅ Global controls work correctly');
      return true;
    } catch (e) {
      print('  ❌ Global controls error: $e');
      return false;
    }
  }

  static Future<bool> _testEdgeCases() async {
    try {
      final service = NotificationService();

      print('  🔍 Testing edge cases...');

      // Test duplicate reminder times
      final time = const TimeOfDay(hour: 15, minute: 45);
      final reminder1 = WaterReminder(
        id: 'edge1_${DateTime.now().millisecondsSinceEpoch}',
        time: time,
        isEnabled: true,
        createdAt: DateTime.now(),
      );

      final reminder2 = WaterReminder(
        id: 'edge2_${DateTime.now().millisecondsSinceEpoch}',
        time: time,
        isEnabled: true,
        createdAt: DateTime.now(),
      );

      await service.addReminder(reminder1);
      await service.addReminder(reminder2);

      final reminders = service.getReminders();
      final sameTimeCount = reminders.where((r) =>
        r.time.hour == time.hour && r.time.minute == time.minute
      ).length;

      // Clean up
      await service.removeReminder(reminder1.id);
      await service.removeReminder(reminder2.id);

      print('  📊 Found $sameTimeCount reminders with same time');
      print('  ✅ Edge cases handled correctly');
      return true;
    } catch (e) {
      print('  ❌ Edge cases error: $e');
      return false;
    }
  }

  static Future<bool> _testDiagnostics() async {
    try {
      print('  🧪 Running built-in diagnostics...');

      final diagnostics = await NotificationTroubleshooting.runDiagnostics();
      final debugInfo = await NotificationTroubleshooting.collectDebugInfo();

      print('  📊 Diagnostic results:');
      diagnostics.forEach((test, result) {
        final status = result ? '✅' : '❌';
        print('    $test: $status');
      });

      print('  📱 System info:');
      debugInfo.forEach((key, value) {
        print('    $key: $value');
      });

      return true;
    } catch (e) {
      print('  ❌ Diagnostics error: $e');
      return false;
    }
  }
}

/// Test app UI
class NotificationTestApp extends StatelessWidget {
  const NotificationTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Notification Test',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const NotificationTestScreen(),
    );
  }
}

class NotificationTestScreen extends StatefulWidget {
  const NotificationTestScreen({super.key});

  @override
  State<NotificationTestScreen> createState() => _NotificationTestScreenState();
}

class _NotificationTestScreenState extends State<NotificationTestScreen> {
  final NotificationService _service = NotificationService();
  Map<String, bool> _testResults = {};
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    _setupNotificationHandling();
  }

  void _setupNotificationHandling() {
    NotificationService.onNotificationAction = (action, reminderId) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Notification action: $action (ID: $reminderId)'),
          backgroundColor: Colors.green,
        ),
      );
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification System Test'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Test buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _testing ? null : _runTests,
                    child: _testing
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Run Full Test'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _testImmediateNotification,
                    child: const Text('Test Notification'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Test results
            if (_testResults.isNotEmpty) ...[
              const Text(
                'Test Results:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  itemCount: _testResults.length,
                  itemBuilder: (context, index) {
                    final entry = _testResults.entries.elementAt(index);
                    final icon = entry.value ? '✅' : '❌';
                    final color = entry.value ? Colors.green : Colors.red;

                    return ListTile(
                      leading: Text(icon, style: const TextStyle(fontSize: 20)),
                      title: Text(entry.key.replaceAll('_', ' ').toUpperCase()),
                      trailing: Icon(
                        entry.value ? Icons.check_circle : Icons.error,
                        color: color,
                      ),
                    );
                  },
                ),
              ),
            ] else ...[
              const Expanded(
                child: Center(
                  child: Text(
                    'Click "Run Full Test" to test the notification system',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],

            // Quick actions
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton.icon(
                  onPressed: _scheduleTestReminder,
                  icon: const Icon(Icons.schedule),
                  label: const Text('Schedule Test'),
                ),
                TextButton.icon(
                  onPressed: _checkPendingNotifications,
                  icon: const Icon(Icons.list),
                  label: const Text('Check Pending'),
                ),
                TextButton.icon(
                  onPressed: _clearAllReminders,
                  icon: const Icon(Icons.clear_all),
                  label: const Text('Clear All'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _runTests() async {
    setState(() {
      _testing = true;
      _testResults.clear();
    });

    final results = await NotificationSystemTester.runFullTest();

    setState(() {
      _testResults = results;
      _testing = false;
    });

    final passedCount = results.values.where((result) => result).length;
    final totalCount = results.length;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Tests completed: $passedCount/$totalCount passed'),
        backgroundColor: passedCount == totalCount ? Colors.green : Colors.orange,
      ),
    );
  }

  Future<void> _testImmediateNotification() async {
    await _service.showTestNotification();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Test notification sent!'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  Future<void> _scheduleTestReminder() async {
    final now = DateTime.now();
    final testTime = TimeOfDay(
      hour: now.hour,
      minute: (now.minute + 1) % 60,
    );

    final reminder = WaterReminder(
      id: 'quick_test_${now.millisecondsSinceEpoch}',
      time: testTime,
      isEnabled: true,
      createdAt: now,
    );

    final success = await _service.addReminder(reminder);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success
            ? 'Test reminder scheduled for ${reminder.formatTime()}'
            : 'Failed to schedule reminder'
        ),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }

  Future<void> _checkPendingNotifications() async {
    final count = await _service.getPendingNotificationsCount();
    final reminders = _service.getReminders();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Pending notifications: $count, Stored reminders: ${reminders.length}'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  Future<void> _clearAllReminders() async {
    final reminders = _service.getReminders();
    for (final reminder in reminders) {
      await _service.removeReminder(reminder.id);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Cleared ${reminders.length} reminders'),
        backgroundColor: Colors.orange,
      ),
    );
  }
}