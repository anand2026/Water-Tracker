import 'package:flutter/material.dart';

/// Navigation service for handling deep links from notifications
class NavigationService {
  static final NavigationService _instance = NavigationService._internal();
  factory NavigationService() => _instance;
  NavigationService._internal();

  GlobalKey<NavigatorState>? _navigatorKey;

  /// Set the navigator key from your app
  void setNavigatorKey(GlobalKey<NavigatorState> key) {
    _navigatorKey = key;
  }

  /// Get current context
  BuildContext? get currentContext => _navigatorKey?.currentContext;

  /// Navigate to water logging screen
  Future<void> navigateToWaterLogging({String? reminderId}) async {
    final context = currentContext;
    if (context == null) {
      debugPrint('❌ Navigation context not available');
      return;
    }

    try {
      // Navigate to water logging screen
      await Navigator.pushNamed(
        context,
        '/water-logging',
        arguments: {
          'fromNotification': true,
          'reminderId': reminderId,
        },
      );
    } catch (e) {
      debugPrint('❌ Navigation failed: $e');
    }
  }

  /// Navigate to home screen
  Future<void> navigateToHome() async {
    final context = currentContext;
    if (context == null) return;

    try {
      await Navigator.pushNamedAndRemoveUntil(
        context,
        '/',
        (route) => false,
      );
    } catch (e) {
      debugPrint('❌ Navigation to home failed: $e');
    }
  }

  /// Show snack bar message
  void showMessage(String message, {Color? backgroundColor}) {
    final context = currentContext;
    if (context == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor ?? const Color(0xFF42A5F5),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Show confirmation dialog
  Future<bool> showConfirmationDialog({
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
  }) async {
    final context = currentContext;
    if (context == null) return false;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelText),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF42A5F5),
              foregroundColor: Colors.white,
            ),
            child: Text(confirmText),
          ),
        ],
      ),
    );

    return result ?? false;
  }
}