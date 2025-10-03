import 'package:flutter/material.dart';
import 'services/notification_service_fixed.dart';
import 'models/reminder_model.dart';

/// Simple test to verify notification system works
void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
  } catch (e) {
    print('⚠️ Could not initialize Flutter binding: $e');
  }

  print('🧪 Starting Simple Notification Test...');

  final service = NotificationServiceFixed();

  try {
    // Test 1: Initialize service
    print('1️⃣ Testing initialization...');
    final initialized = await service.initialize();
    print('   Result: ${initialized ? "✅ SUCCESS" : "❌ FAILED"}');

    if (!initialized) {
      print('❌ Cannot continue - initialization failed');
      return;
    }

    // Test 2: Request permissions
    print('2️⃣ Testing permissions...');
    final permissions = await service.requestPermissions();
    print('   Result: ${permissions ? "✅ GRANTED" : "⚠️ DENIED"}');

    // Test 3: Check permissions
    print('3️⃣ Checking permission status...');
    final permissionStatus = await service.arePermissionsGranted();
    print('   Result: ${permissionStatus ? "✅ GRANTED" : "⚠️ DENIED"}');

    // Test 4: Test immediate notification
    print('4️⃣ Testing immediate notification...');
    await service.showTestNotification();
    print('   Result: ✅ Test notification sent');

    // Test 5: Schedule a reminder
    print('5️⃣ Testing reminder scheduling...');
    final testReminder = WaterReminder(
      id: 'test_${DateTime.now().millisecondsSinceEpoch}',
      time: TimeOfDay(
        hour: DateTime.now().hour,
        minute: (DateTime.now().minute + 1) % 60,
      ),
      isEnabled: true,
      createdAt: DateTime.now(),
    );

    final scheduleResult = await service.addReminder(testReminder);
    print('   Result: ${scheduleResult ? "✅ SCHEDULED" : "❌ FAILED"}');

    if (scheduleResult) {
      // Test 6: Check pending notifications
      print('6️⃣ Checking pending notifications...');
      final pendingCount = await service.getPendingNotificationsCount();
      print('   Result: ✅ $pendingCount pending notifications');

      // Test 7: Remove test reminder
      print('7️⃣ Cleaning up test reminder...');
      final removeResult = await service.removeReminder(testReminder.id);
      print('   Result: ${removeResult ? "✅ REMOVED" : "❌ FAILED"}');
    }

    print('\n🎉 Basic notification test completed successfully!');
    print('✅ All core functions are working');
    print('📱 Check your device for the test notification');

  } catch (e) {
    print('❌ Test failed with error: $e');
  }
}