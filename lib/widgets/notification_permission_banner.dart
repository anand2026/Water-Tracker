import 'package:flutter/material.dart';
import '../notification_service.dart';
import 'notification_permission_dialog.dart';

class NotificationPermissionBanner extends StatefulWidget {
  const NotificationPermissionBanner({super.key});

  @override
  State<NotificationPermissionBanner> createState() => _NotificationPermissionBannerState();
}

class _NotificationPermissionBannerState extends State<NotificationPermissionBanner> {
  bool _isVisible = true;
  bool _isLoading = true;
  bool _permissionsGranted = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final granted = await NotificationService.instance.checkPermissionStatus();
    if (mounted) {
      setState(() {
        _permissionsGranted = granted;
        _isLoading = false;
        _isVisible = !granted; // Only show banner if permissions not granted
      });
    }
  }

  void _dismiss() {
    setState(() {
      _isVisible = false;
    });
  }

  Future<void> _requestPermissions() async {
    setState(() {
      _isLoading = true;
    });

    if (mounted) {
      await NotificationSetupHelper.requestPermissionWithDialog(context);
    }

    // Re-check permissions after dialog
    await _checkPermissions();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || !_isVisible || _permissionsGranted) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(
              Icons.notifications_outlined,
              color: Colors.white,
              size: 32,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Enable Water Reminders',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Get notified to stay hydrated throughout the day',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      TextButton(
                        onPressed: _dismiss,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white70,
                        ),
                        child: const Text('Not Now'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _requestPermissions,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF1976D2),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        child: const Text('Enable'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: _dismiss,
              icon: const Icon(
                Icons.close,
                color: Colors.white70,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Widget to periodically check permissions and show banner
class PersistentNotificationReminder extends StatefulWidget {
  final Widget child;

  const PersistentNotificationReminder({
    super.key,
    required this.child,
  });

  @override
  State<PersistentNotificationReminder> createState() => _PersistentNotificationReminderState();
}

class _PersistentNotificationReminderState extends State<PersistentNotificationReminder> {
  bool _showBanner = false;
  bool _permissionsGranted = false;

  @override
  void initState() {
    super.initState();
    _startPeriodicCheck();
  }

  void _startPeriodicCheck() {
    // Check permissions immediately
    _checkPermissions();

    // Then check every 30 seconds when app is active
    _scheduleNextCheck();
  }

  void _scheduleNextCheck() {
    Future.delayed(const Duration(seconds: 30), () {
      if (mounted) {
        _checkPermissions();
        _scheduleNextCheck();
      }
    });
  }

  Future<void> _checkPermissions() async {
    final granted = await NotificationService.instance.checkPermissionStatus();
    if (mounted) {
      setState(() {
        _permissionsGranted = granted;
        _showBanner = !granted;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_showBanner && !_permissionsGranted)
          const NotificationPermissionBanner(),
        Expanded(child: widget.child),
      ],
    );
  }
}