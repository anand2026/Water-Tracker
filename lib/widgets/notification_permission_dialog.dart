import 'package:flutter/material.dart';
import '../notification_service.dart';

class NotificationPermissionDialog extends StatelessWidget {
  const NotificationPermissionDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.notifications_outlined, color: Colors.blue),
          SizedBox(width: 8),
          Text('Enable Notifications'),
        ],
      ),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Stay hydrated with water reminders!',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          SizedBox(height: 12),
          Text('💧 Get reminded to drink water throughout the day'),
          SizedBox(height: 6),
          Text('⏰ Set custom reminder times'),
          SizedBox(height: 6),
          Text('📱 Never miss your hydration goals'),
          SizedBox(height: 16),
          Text(
            'We need notification permission to send you water reminders.',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Not Now'),
        ),
        ElevatedButton(
          onPressed: () async {
            Navigator.of(context).pop(true);
          },
          child: const Text('Enable Notifications'),
        ),
      ],
    );
  }

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const NotificationPermissionDialog();
      },
    );
  }
}

class NotificationSetupHelper {
  static Future<void> requestPermissionWithDialog(BuildContext context) async {
    // Check if notifications are already enabled
    final permissionsGranted = await NotificationService.instance.checkPermissionStatus();

    if (permissionsGranted) {
      return; // Already have permissions
    }

    // Show dialog explaining why we need permission
    final userWantsNotifications = await NotificationPermissionDialog.show(context);

    if (userWantsNotifications == true) {
      // Request permissions
      final granted = await NotificationService.instance.requestPermissions();

      if (!granted) {
        // Show instructions if permission was denied
        if (context.mounted) {
          _showPermissionDeniedDialog(context);
        }
      } else {
        // Show success message
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🎉 Notifications enabled! You can now receive water reminders.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  // Method to manually request permissions (for settings screen)
  static Future<void> manualPermissionRequest(BuildContext context) async {
    final granted = await NotificationService.instance.requestPermissions();

    if (!granted) {
      if (context.mounted) {
        _showPermissionDeniedDialog(context);
      }
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Notifications enabled successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  static void _showPermissionDeniedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.orange),
              SizedBox(width: 8),
              Text('Enable in Settings'),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('To receive water reminders, please:'),
              SizedBox(height: 12),
              Text('1. Go to device Settings'),
              Text('2. Find Apps → Water Tracker'),
              Text('3. Tap Notifications'),
              Text('4. Enable "Show notifications"'),
              SizedBox(height: 12),
              Text(
                'You can enable notifications anytime in the app settings.',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Try to open app settings
                NotificationService.instance.openAppNotificationSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    );
  }
}