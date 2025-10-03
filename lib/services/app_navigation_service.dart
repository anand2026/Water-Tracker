import 'package:flutter/material.dart';

/// Service for handling deep links and navigation from notifications
class AppNavigationService {
  static final AppNavigationService _instance = AppNavigationService._internal();
  factory AppNavigationService() => _instance;
  AppNavigationService._internal();

  GlobalKey<NavigatorState>? _navigatorKey;

  /// Set the navigator key from your app
  void setNavigatorKey(GlobalKey<NavigatorState> key) {
    _navigatorKey = key;
  }

  /// Navigate to water logging screen from notification
  Future<void> navigateToWaterLogging({String? reminderId}) async {
    final context = _navigatorKey?.currentContext;
    if (context == null) return;

    // Example navigation - adjust routes to match your app structure
    try {
      // Option 1: Using named routes
      await Navigator.pushNamed(context, '/water-logging', arguments: {
        'fromNotification': true,
        'reminderId': reminderId,
      });

      // Option 2: Using MaterialPageRoute (uncomment if you prefer this approach)
      /*
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => WaterLoggingScreen(
            fromNotification: true,
            reminderId: reminderId,
          ),
        ),
      );
      */
    } catch (e) {
      debugPrint('❌ Navigation failed: $e');
    }
  }

  /// Navigate to home screen
  Future<void> navigateToHome() async {
    final context = _navigatorKey?.currentContext;
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
  void showMessage(String message) {
    final context = _navigatorKey?.currentContext;
    if (context == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF42A5F5),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

/// Example water logging screen that handles notification deep links
class WaterLoggingScreen extends StatefulWidget {
  final bool fromNotification;
  final String? reminderId;

  const WaterLoggingScreen({
    super.key,
    this.fromNotification = false,
    this.reminderId,
  });

  @override
  State<WaterLoggingScreen> createState() => _WaterLoggingScreenState();
}

class _WaterLoggingScreenState extends State<WaterLoggingScreen> {
  @override
  void initState() {
    super.initState();

    // Handle notification deep link
    if (widget.fromNotification) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleNotificationNavigation();
      });
    }
  }

  void _handleNotificationNavigation() {
    // Show a message that user came from notification
    AppNavigationService().showMessage(
      'Great! Let\'s log your water intake 💧'
    );

    // You can also pre-fill forms or highlight specific actions
    // based on the reminderId or other notification data
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log Water Intake'),
        backgroundColor: const Color(0xFF42A5F5),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Show special message if from notification
            if (widget.fromNotification)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF42A5F5),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.notifications_active,
                      color: Color(0xFF42A5F5),
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'From Notification',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1565C0),
                            ),
                          ),
                          Text(
                            widget.reminderId != null
                                ? 'Reminder ID: ${widget.reminderId}'
                                : 'Time to stay hydrated!',
                            style: const TextStyle(
                              color: Color(0xFF1976D2),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // Water amount selection
            const Text(
              'How much water did you drink?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),

            // Quick amount buttons
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [250, 500, 750, 1000].map((amount) {
                return ElevatedButton(
                  onPressed: () => _logWater(amount),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF42A5F5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text('${amount}ml'),
                );
              }).toList(),
            ),

            const SizedBox(height: 30),

            // Custom amount input
            const Text(
              'Or enter custom amount:',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Amount (ml)',
                      suffixText: 'ml',
                    ),
                    onSubmitted: (value) {
                      final amount = int.tryParse(value);
                      if (amount != null && amount > 0) {
                        _logWater(amount);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () {
                    // Handle custom amount logging
                    _logWater(250); // Default amount for demo
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF42A5F5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                  ),
                  child: const Text('Log'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _logWater(int amount) {
    // Here you would typically:
    // 1. Save the water intake to your database/storage
    // 2. Update the user's daily progress
    // 3. Show confirmation
    // 4. Navigate back or to dashboard

    AppNavigationService().showMessage(
      'Great! Logged ${amount}ml of water 🎉'
    );

    // If came from notification, navigate back to home after a delay
    if (widget.fromNotification) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      });
    } else {
      Navigator.of(context).pop();
    }
  }
}