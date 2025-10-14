import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'notification_service.dart';

class NotificationPermissionProvider extends ChangeNotifier with WidgetsBindingObserver {
  static final NotificationPermissionProvider _instance = NotificationPermissionProvider._internal();
  static NotificationPermissionProvider get instance => _instance;

  NotificationPermissionProvider._internal();

  bool _isGranted = false;
  Timer? _permissionCheckTimer;
  bool _isInitialized = false;

  bool get isGranted => _isGranted;
  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    if (_isInitialized) return;

    WidgetsBinding.instance.addObserver(this);
    await _checkPermissionStatus();
    _startPeriodicChecking();
    _isInitialized = true;

    if (kDebugMode) {
      print('🌐 NotificationPermissionProvider initialized with status: $_isGranted');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _permissionCheckTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (kDebugMode) {
        print('🌐 App resumed - checking permission status globally');
      }

      // Single check when app resumes to prevent ANR
      _checkPermissionStatus();
    }
  }

  void _startPeriodicChecking() {
    // Check every 3 seconds - much less aggressive to prevent ANR
    _permissionCheckTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _checkPermissionStatus();
    });
  }

  Future<void> _checkPermissionStatus() async {
    try {
      final newStatus = await NotificationService.instance.checkPermissionStatus();

      if (newStatus != _isGranted) {
        if (kDebugMode) {
          print('🌐 Global permission status changed: $_isGranted → $newStatus');
        }

        _isGranted = newStatus;
        notifyListeners(); // This will update ALL widgets listening to this provider
      }
    } catch (e) {
      if (kDebugMode) {
        print('🌐 Error checking global permission status: $e');
      }
    }
  }

  // Force an immediate check (useful after permission requests)
  Future<void> forceCheck() async {
    await _checkPermissionStatus();

    // Single delayed check to ensure we catch changes without causing ANR
    Future.delayed(const Duration(milliseconds: 500), () => _checkPermissionStatus());
  }

  // Request permissions and update status
  Future<bool> requestPermissions() async {
    try {
      final granted = await NotificationService.instance.requestNotificationPermissionDirectly();

      // Force immediate check after permission request
      await forceCheck();

      return granted;
    } catch (e) {
      if (kDebugMode) {
        print('🌐 Error requesting permissions: $e');
      }
      return false;
    }
  }
}