import 'package:flutter/material.dart';
import '../services/navigation_service.dart';

/// Water logging screen that can be opened from notifications
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
  int _selectedAmount = 250; // Default 250ml
  final List<int> _quickAmounts = [100, 200, 250, 300, 500, 750, 1000];

  @override
  void initState() {
    super.initState();

    // Show message if opened from notification
    if (widget.fromNotification) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        NavigationService().showMessage(
          'Great! Time to log your water intake 💧',
          backgroundColor: const Color(0xFF4CAF50),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log Water Intake'),
        backgroundColor: const Color(0xFF42A5F5),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Notification indicator
            if (widget.fromNotification) _buildNotificationIndicator(),

            const SizedBox(height: 20),

            // Title
            const Text(
              'How much water did you drink?',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1565C0),
              ),
            ),

            const SizedBox(height: 30),

            // Quick amount buttons
            const Text(
              'Quick amounts:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF424242),
              ),
            ),

            const SizedBox(height: 15),

            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _quickAmounts.map((amount) {
                final isSelected = amount == _selectedAmount;
                return GestureDetector(
                  onTap: () => setState(() => _selectedAmount = amount),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF42A5F5)
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF42A5F5)
                            : Colors.grey[300]!,
                        width: 2,
                      ),
                    ),
                    child: Text(
                      '${amount}ml',
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.grey[700],
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 30),

            // Custom amount input
            const Text(
              'Or enter custom amount:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF424242),
              ),
            ),

            const SizedBox(height: 15),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Amount (ml)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFF42A5F5),
                          width: 2,
                        ),
                      ),
                      suffixText: 'ml',
                      prefixIcon: const Icon(
                        Icons.local_drink,
                        color: Color(0xFF42A5F5),
                      ),
                    ),
                    onChanged: (value) {
                      final amount = int.tryParse(value);
                      if (amount != null && amount > 0) {
                        setState(() => _selectedAmount = amount);
                      }
                    },
                  ),
                ),
              ],
            ),

            const Spacer(),

            // Log button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _logWater,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF42A5F5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_circle_outline, size: 24),
                    const SizedBox(width: 10),
                    Text(
                      'Log ${_selectedAmount}ml',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationIndicator() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF4CAF50),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.notifications_active,
            color: Color(0xFF4CAF50),
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Opened from Reminder',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E7D32),
                  ),
                ),
                if (widget.reminderId != null)
                  Text(
                    'Reminder ID: ${widget.reminderId}',
                    style: const TextStyle(
                      color: Color(0xFF388E3C),
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _logWater() {
    // Here you would typically:
    // 1. Save the water intake to your database
    // 2. Update daily progress
    // 3. Show confirmation

    NavigationService().showMessage(
      'Great! Logged ${_selectedAmount}ml of water 🎉',
      backgroundColor: const Color(0xFF4CAF50),
    );

    // Navigate back with delay
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        if (widget.fromNotification) {
          // If from notification, go to home
          Navigator.of(context).popUntil((route) => route.isFirst);
        } else {
          // Otherwise just go back
          Navigator.of(context).pop();
        }
      }
    });
  }
}