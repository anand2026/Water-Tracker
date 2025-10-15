import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:share_plus/share_plus.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'settings_provider.dart';
import 'water_data_provider.dart';
import 'notification_service.dart';
import 'notification_permission_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, child) {
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            title: const Text(
              'Settings',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF1565C0),
              ),
            ),
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            elevation: 0,
            automaticallyImplyLeading: false,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Daily Goal Section
                _buildDailyGoalSection(context, settings),
                const SizedBox(height: 32),

                // Units Section
                _buildUnitsSection(context, settings),
                const SizedBox(height: 32),

                // Cup Presets Section
                _buildCupPresetsSection(context, settings),
                const SizedBox(height: 32),

                // Theme Section
                _buildThemeSection(context, settings),
                const SizedBox(height: 32),

                // Notifications Section
                _buildNotificationsSection(context),
                const SizedBox(height: 32),

                // Battery Optimization Section
                _buildBatteryOptimizationSection(context),
                const SizedBox(height: 32),

                // Privacy Policy Section
                _buildPrivacyPolicySection(context),
                const SizedBox(height: 40),

                // Export Button
                _buildExportButton(context, settings),
                const SizedBox(height: 20),

                // Debug: Reset notification permission tracking
                if (kDebugMode) ...[
                  _buildDebugSection(context),
                  const SizedBox(height: 20),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDailyGoalSection(BuildContext context, SettingsProvider settings) {
    final goal = settings.dailyGoalInCurrentUnit;
    final min = settings.unit == WaterUnit.ml ? 1000 : 34; // ~1000ml = 34oz
    final max = settings.unit == WaterUnit.ml ? 4000 : 135; // ~4000ml = 135oz

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Daily Goal',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1565C0),
          ),
        ),
        const SizedBox(height: 20),

        // Goal display with +/- buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Minus button
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: Color(0xFF42A5F5),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: () {
                  final newGoal = goal - (settings.unit == WaterUnit.ml ? 100 : 3);
                  if (newGoal >= min) {
                    settings.setDailyGoal(newGoal);
                  }
                },
                icon: const Icon(Icons.remove, color: Colors.white),
              ),
            ),

            const SizedBox(width: 24),

            // Goal value
            Text(
              '$goal ${settings.unitLabel}',
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1565C0),
              ),
            ),

            const SizedBox(width: 24),

            // Plus button
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: Color(0xFF42A5F5),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: () {
                  final newGoal = goal + (settings.unit == WaterUnit.ml ? 100 : 3);
                  if (newGoal <= max) {
                    settings.setDailyGoal(newGoal);
                  }
                },
                icon: const Icon(Icons.add, color: Colors.white),
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Slider
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: const Color(0xFF42A5F5),
            inactiveTrackColor: const Color(0xFFE3F2FD),
            thumbColor: const Color(0xFF42A5F5),
            overlayColor: const Color(0xFF42A5F5).withValues(alpha: 0.1),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
            trackHeight: 6,
          ),
          child: Slider(
            value: goal.toDouble(),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: settings.unit == WaterUnit.ml ? 30 : 34,
            onChanged: (value) {
              settings.setDailyGoal(value.round());
            },
          ),
        ),
      ],
    );
  }

  Widget _buildUnitsSection(BuildContext context, SettingsProvider settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Units',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1565C0),
          ),
        ),
        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  _buildUnitToggle(
                    'ml',
                    settings.unit == WaterUnit.ml,
                    () => settings.setUnit(WaterUnit.ml),
                  ),
                  const SizedBox(width: 16),
                  _buildUnitToggle(
                    'oz',
                    settings.unit == WaterUnit.oz,
                    () => settings.setUnit(WaterUnit.oz),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUnitToggle(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF42A5F5) : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF757575),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildCupPresetsSection(BuildContext context, SettingsProvider settings) {
    final presets = settings.cupPresetsInCurrentUnit;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Cup Presets',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1565C0),
              ),
            ),
            IconButton(
              onPressed: () => _showEditPresetsDialog(context, settings),
              icon: const Icon(
                Icons.edit,
                color: Color(0xFF42A5F5),
                size: 20,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: presets.map((preset) => _buildPresetChip(preset, settings)).toList(),
        ),
      ],
    );
  }

  Widget _buildPresetChip(int preset, SettingsProvider settings) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F8FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF42A5F5).withValues(alpha: 0.3)),
      ),
      child: Text(
        '$preset ${settings.unitLabel}',
        style: const TextStyle(
          color: Color(0xFF1565C0),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildThemeSection(BuildContext context, SettingsProvider settings) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Theme',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1565C0),
          ),
        ),
        Row(
          children: [
            Icon(
              Icons.wb_sunny,
              color: settings.isDarkMode ? Colors.grey : const Color(0xFF42A5F5),
              size: 20,
            ),
            const SizedBox(width: 8),
            Switch(
              value: settings.isDarkMode,
              onChanged: (value) => settings.setTheme(value),
              activeThumbColor: const Color(0xFF42A5F5),
              activeTrackColor: const Color(0xFF42A5F5).withValues(alpha: 0.3),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.nightlight_round,
              color: settings.isDarkMode ? const Color(0xFF42A5F5) : Colors.grey,
              size: 20,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPrivacyPolicySection(BuildContext context) {
    return InkWell(
      onTap: () => _showPrivacyPolicyDialog(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.privacy_tip_outlined,
              color: Theme.of(context).colorScheme.primary,
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                'Privacy Policy',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExportButton(BuildContext context, SettingsProvider settings) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => _exportData(context, settings),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF42A5F5),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        child: Text(
          'Export',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _showEditPresetsDialog(BuildContext context, SettingsProvider settings) {
    showDialog(
      context: context,
      builder: (context) => _EditPresetsDialog(settings: settings),
    );
  }

  void _showPrivacyPolicyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Privacy Policy'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Water Tracker Privacy Policy',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Last updated: ${DateTime.now().year}',
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              const Text(
                'Data Collection',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                '• Water intake data is stored locally on your device\n'
                '• Daily goals and preferences are saved locally\n'
                '• Reminder settings are stored on your device\n'
                '• No personal data is transmitted to external servers',
              ),
              const SizedBox(height: 16),
              const Text(
                'Data Usage',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                '• Your data is used solely to provide app functionality\n'
                '• Data helps track your hydration progress\n'
                '• Settings customize your experience\n'
                '• No data is shared with third parties',
              ),
              const SizedBox(height: 16),
              const Text(
                'Data Security',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                '• All data remains on your device\n'
                '• No cloud storage or external transmission\n'
                '• You can export or delete your data anytime\n'
                '• App uses standard device security measures',
              ),
              const SizedBox(height: 16),
              const Text(
                'Your Rights',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                '• Full control over your data\n'
                '• Export data through settings\n'
                '• Clear data by uninstalling the app\n'
                '• No account required, no tracking',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Notifications',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            Consumer<NotificationPermissionProvider>(
              builder: (context, permissionProvider, child) {
                final isGranted = permissionProvider.isGranted;

                return Row(
                  children: [
                    Icon(
                      isGranted ? Icons.notifications_active : Icons.notifications_off,
                      color: isGranted ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Notification Permissions',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          Text(
                            isGranted
                              ? 'Notifications are enabled'
                              : 'Notifications are disabled',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isGranted) ...[
                      ElevatedButton(
                        onPressed: () => _requestNotificationPermissions(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF42A5F5),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Enable'),
                      ),
                    ],
                  ],
                );
              },
            ),

            const SizedBox(height: 12),
            Text(
              'Allow notifications to receive reminders to drink water throughout the day.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),

            // Test buttons - only show in debug builds
            if (kDebugMode) ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _testNotification(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Test Now'),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _testScheduledNotification(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Test 10s'),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _testQuickScheduled(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Test 5s'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],

            // Help button - always show
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _showTroubleshootingGuide(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF42A5F5),
                ),
                child: const Text('Troubleshooting Help'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _getNotificationPermissionStatus() async {
    return await NotificationService.instance.checkPermissionStatus();
  }

  Future<void> _requestNotificationPermissions(BuildContext context) async {
    try {
      if (kDebugMode) {
        print('🔔 Enable button clicked - opening notification settings directly');
      }

      // Directly open notification settings instead of showing popup
      final settingsOpened = await NotificationService.instance.openNotificationSettings();

      if (context.mounted) {
        if (settingsOpened) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('📱 Please enable notifications in the settings that opened, then return to the app'),
              backgroundColor: Colors.blue,
              duration: Duration(seconds: 4),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Could not open settings. Please go to Settings > Apps > Water Tracker > Notifications manually'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }


  void _showNotificationInstructions(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Color(0xFF42A5F5)),
            SizedBox(width: 8),
            Text('Enable Notifications'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'To enable notifications for water reminders:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text('1. Open your device Settings'),
            Text('2. Go to Apps → Water Tracker'),
            Text('3. Tap on Notifications'),
            Text('4. Turn on "Show notifications"'),
            Text('5. Enable all notification categories'),
            Text('6. Return to this app'),
            SizedBox(height: 12),
            Text(
              'Note: On some devices, this setting might be under "App permissions" or "Notification permissions".',
              style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Try requesting permissions again
              _requestNotificationPermissions(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF42A5F5),
              foregroundColor: Colors.white,
            ),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }


  Future<void> _testNotification(BuildContext context) async {
    try {
      // Show loading
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
              ),
              SizedBox(width: 16),
              Text('Testing notifications...'),
            ],
          ),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 3),
        ),
      );

      final result = await NotificationService.instance.testNotificationWithDebug();

      if (context.mounted) {
        // Show detailed debug information
        _showDebugResults(context, result);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to test notification: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _testScheduledNotification(BuildContext context) async {
    try {
      await NotificationService.instance.scheduleTestNotification();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Scheduled notification for 10 seconds from now! Wait and see if it appears.'),
            backgroundColor: Colors.purple,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to schedule test notification: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _testQuickScheduled(BuildContext context) async {
    try {
      final now = DateTime.now();
      final testTime = now.add(const Duration(seconds: 5));

      await NotificationService.instance.scheduleWaterReminder(
        id: 9998,
        title: '🔥 QUICK TEST',
        body: 'This notification was scheduled for 5 seconds ago!',
        scheduledTime: testTime,
        payload: 'quick_test',
        repeating: false,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⏰ Quick test scheduled for 5 seconds! Watch closely...'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to schedule quick test: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDebugResults(BuildContext context, Map<String, dynamic> result) {
    final isSuccessful = result['test_notification_sent'] == true;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              isSuccessful ? Icons.check_circle : Icons.error,
              color: isSuccessful ? Colors.green : Colors.red,
            ),
            const SizedBox(width: 8),
            Text(isSuccessful ? 'Test Successful!' : 'Notification Issue'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isSuccessful) ...[
                const Text(
                  '✅ Test notification was sent successfully!',
                  style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                const Text('Check your notification panel to see if it appeared.'),
              ] else ...[
                const Text(
                  '❌ Notification test failed',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _buildDebugInfo('Status', result['final_state']),
                const SizedBox(height: 12),
                if (result['reason'] != null) ...[
                  Text('Reason: ${result['reason']}'),
                  const SizedBox(height: 12),
                ],
                const Text(
                  'Manual Steps:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text('1. Open Settings on your device'),
                const Text('2. Go to Apps → Water Tracker'),
                const Text('3. Tap Notifications'),
                const Text('4. Enable "Show notifications"'),
                const Text('5. Enable all categories'),
                const Text('6. Return to app and test again'),
              ],
            ],
          ),
        ),
        actions: [
          if (!isSuccessful) ...[
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _requestNotificationPermissions(context);
              },
              child: const Text('Try Permission Request'),
            ),
          ],
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDebugInfo(String title, Map<String, dynamic>? info) {
    if (info == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$title:',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        ...info.entries.map((entry) => Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Text(
            '${entry.key}: ${entry.value}',
            style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
          ),
        )),
      ],
    );
  }

  Widget _buildDebugSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Debug Options',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Reset notification permission tracking (for testing)',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _resetPermissionTracking(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Reset Permission Tracking'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _resetNotificationPermissionsOnly(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Reset Notification Permissions Only'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _resetPermissionTracking(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('has_asked_notification_permissions');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permission tracking reset! App will ask for permissions on next launch.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error resetting: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _resetNotificationPermissionsOnly(BuildContext context) async {
    try {
      final result = await NotificationService.instance.forcePermissionRequest();

      if (context.mounted) {
        if (result) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Notification permissions reset and granted!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Notification permissions reset. Permission request completed.'),
              backgroundColor: Colors.purple,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error resetting notification permissions: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildBatteryOptimizationSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Battery Optimization',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            FutureBuilder<bool>(
              future: NotificationService.instance.isBatteryOptimizationIgnored(),
              builder: (context, snapshot) {
                final isOptimized = snapshot.data ?? false;

                return Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          isOptimized ? Icons.battery_saver_outlined : Icons.battery_alert,
                          color: isOptimized ? Colors.green : Colors.orange,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Battery Optimization Status',
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                              Text(
                                isOptimized
                                  ? 'App is exempt from battery optimization'
                                  : 'App may be limited by battery optimization',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!isOptimized)
                          ElevatedButton(
                            onPressed: () => _requestBatteryOptimization(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Fix'),
                          ),
                      ],
                    ),

                    const SizedBox(height: 12),
                    Text(
                      isOptimized
                        ? '✅ Your notifications should work reliably!'
                        : '⚠️ Battery optimization may prevent scheduled notifications. Tap "Fix" to disable it for this app.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isOptimized ? Colors.green[700] : Colors.orange[700],
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _requestBatteryOptimization(BuildContext context) async {
    try {
      final success = await NotificationService.instance.requestBatteryOptimizationExemption();

      if (context.mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Battery optimization settings opened! Please disable optimization for Water Tracker.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        } else {
          // Try opening battery settings directly
          final altSuccess = await NotificationService.instance.openBatteryOptimizationSettings();
          if (context.mounted) {
            if (altSuccess) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Battery settings opened! Find Water Tracker and disable optimization.'),
                  backgroundColor: Colors.orange,
                  duration: Duration(seconds: 4),
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please manually go to Settings > Battery > Battery Optimization and disable it for Water Tracker.'),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 5),
                ),
              );
            }
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showTroubleshootingGuide(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.help_outline, color: Color(0xFF42A5F5)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Notification Help',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'If notifications are not working, try these steps:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              _buildTroubleshootStep(
                '1. Device Settings Method',
                [
                  'Open your device Settings',
                  'Go to Apps → Water Tracker',
                  'Tap Notifications',
                  'Enable "Show notifications"',
                  'Enable all notification categories',
                ],
              ),

              _buildTroubleshootStep(
                '2. Alternative Settings Path',
                [
                  'Settings → Sound & vibration → Notifications',
                  'Find "Water Tracker" in the list',
                  'Enable all notification options',
                ],
              ),

              _buildTroubleshootStep(
                '3. Battery Optimization',
                [
                  'Settings → Battery → Battery optimization',
                  'Find "Water Tracker"',
                  'Select "Don\'t optimize"',
                ],
              ),

              _buildTroubleshootStep(
                '4. Do Not Disturb',
                [
                  'Check if "Do Not Disturb" is enabled',
                  'Add Water Tracker to exceptions',
                  'Or disable DND temporarily',
                ],
              ),

              const SizedBox(height: 12),
              const Text(
                'Android Version Notes:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('• Android 13+: Must grant POST_NOTIFICATIONS permission'),
              const Text('• Android 12+: May need exact alarm permissions'),
              const Text('• Some manufacturers have custom settings'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildTroubleshootStep(String title, List<String> steps) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF42A5F5)),
        ),
        const SizedBox(height: 4),
        ...steps.map((step) => Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 2),
          child: Text('• $step', style: const TextStyle(fontSize: 13)),
        )),
        const SizedBox(height: 12),
      ],
    );
  }

  void _exportData(BuildContext context, SettingsProvider settings) async {
    // Show export options dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Export Data',
          style: TextStyle(
            color: Color(0xFF1565C0),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'Choose export format:',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _exportAsCSV(context, settings);
            },
            child: const Text('CSV Format'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _exportAsJSON(context, settings);
            },
            child: const Text('JSON Format'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _exportAsCSV(BuildContext context, SettingsProvider settings) async {
    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 16),
              Text('Exporting CSV...'),
            ],
          ),
          backgroundColor: Color(0xFF42A5F5),
          duration: Duration(seconds: 2),
        ),
      );

      final waterData = context.read<WaterDataProvider>();

      // Prepare CSV data with comprehensive information
      List<List<dynamic>> csvData = [
        ['Date', 'Time', 'Amount (${settings.unitLabel})', 'Total Daily (${settings.unitLabel})', 'Goal Achievement (%)', 'Daily Goal (${settings.unitLabel})']
      ];

      // Get all water logs from the provider
      final allLogs = waterData.waterLogs;
      final sortedDates = allLogs.keys.toList()..sort((a, b) => b.compareTo(a));

      for (final date in sortedDates) {
        final logs = allLogs[date]!;
        final dailyTotal = waterData.getTotalIntakeForDay(date);
        final goalPercentage = (dailyTotal / settings.dailyGoal * 100).round();
        final dateString = DateFormat('yyyy-MM-dd').format(date);

        if (logs.isEmpty) {
          csvData.add([
            dateString,
            'No logs',
            '0',
            settings.convertFromMl(dailyTotal).toString(),
            '$goalPercentage%',
            settings.convertFromMl(settings.dailyGoal).toString(),
          ]);
        } else {
          final sortedLogs = List.from(logs)..sort((a, b) => a.time.compareTo(b.time));

          for (int i = 0; i < sortedLogs.length; i++) {
            final log = sortedLogs[i];
            csvData.add([
              i == 0 ? dateString : '',
              DateFormat('HH:mm').format(log.time),
              settings.convertFromMl(log.amount).toString(),
              i == 0 ? settings.convertFromMl(dailyTotal).toString() : '',
              i == 0 ? '$goalPercentage%' : '',
              i == 0 ? settings.convertFromMl(settings.dailyGoal).toString() : '',
            ]);
          }
        }
      }

      // Convert to CSV string
      String csvString = const ListToCsvConverter().convert(csvData);

      // Get directory and save file
      Directory? directory;
      if (Platform.isAndroid) {
        directory = await getExternalStorageDirectory();
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      if (directory != null) {
        final fileName = 'water_tracker_complete_export_${DateFormat('yyyy_MM_dd_HH_mm').format(DateTime.now())}.csv';
        final file = File('${directory.path}/$fileName');
        await file.writeAsString(csvString);

        // Share the file
        await Share.shareXFiles(
          [XFile(file.path)],
          subject: 'Water Tracker Complete Data Export',
          text: 'Complete water intake data export from Water Tracker app.',
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('CSV exported successfully! File: $fileName'),
              backgroundColor: const Color(0xFF4CAF50),
              duration: const Duration(seconds: 3),
              action: SnackBarAction(
                label: 'Share Again',
                textColor: Colors.white,
                onPressed: () async {
                  await Share.shareXFiles([XFile(file.path)]);
                },
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('CSV export failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _exportAsJSON(BuildContext context, SettingsProvider settings) async {
    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 16),
              Text('Exporting JSON...'),
            ],
          ),
          backgroundColor: Color(0xFF42A5F5),
          duration: Duration(seconds: 2),
        ),
      );

      final waterData = context.read<WaterDataProvider>();

      // Create comprehensive export data
      final exportData = {
        'app_info': {
          'name': 'Water Tracker',
          'version': '1.0.0',
          'export_format': 'JSON',
        },
        'export_metadata': {
          'exported_at': DateTime.now().toIso8601String(),
          'total_days_tracked': waterData.waterLogs.keys.length,
          'total_entries': waterData.waterLogs.values.fold(0, (sum, logs) => sum + logs.length),
        },
        'user_settings': settings.exportSettings(),
        'water_tracking_data': {
          'current_intake': waterData.currentIntake,
          'streak': waterData.streak,
          'daily_goal': settings.dailyGoal,
          'water_logs': waterData.waterLogs.map((date, logs) {
            return MapEntry(
              date.toIso8601String(),
              {
                'date': DateFormat('yyyy-MM-dd').format(date),
                'total_intake_ml': waterData.getTotalIntakeForDay(date),
                'goal_percentage': (waterData.getTotalIntakeForDay(date) / settings.dailyGoal * 100).round(),
                'entries': logs.map((log) => {
                  'time': log.time.toIso8601String(),
                  'time_formatted': DateFormat('HH:mm').format(log.time),
                  'amount_ml': log.amount,
                  'amount_user_unit': settings.convertFromMl(log.amount),
                }).toList(),
              },
            );
          }),
        },
      };

      final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);

      // Get directory and save file
      Directory? directory;
      if (Platform.isAndroid) {
        directory = await getExternalStorageDirectory();
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      if (directory != null) {
        final fileName = 'water_tracker_backup_${DateFormat('yyyy_MM_dd_HH_mm').format(DateTime.now())}.json';
        final file = File('${directory.path}/$fileName');
        await file.writeAsString(jsonString);

        // Share the file
        await Share.shareXFiles(
          [XFile(file.path)],
          subject: 'Water Tracker Backup & Settings',
          text: 'Complete backup of your Water Tracker data and settings.',
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('JSON backup exported! File: $fileName'),
              backgroundColor: const Color(0xFF4CAF50),
              duration: const Duration(seconds: 3),
              action: SnackBarAction(
                label: 'Share Again',
                textColor: Colors.white,
                onPressed: () async {
                  await Share.shareXFiles([XFile(file.path)]);
                },
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('JSON export failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}

class _EditPresetsDialog extends StatefulWidget {
  final SettingsProvider settings;

  const _EditPresetsDialog({required this.settings});

  @override
  State<_EditPresetsDialog> createState() => _EditPresetsDialogState();
}

class _EditPresetsDialogState extends State<_EditPresetsDialog> {
  late List<TextEditingController> _controllers;
  late List<int> _tempPresets;

  @override
  void initState() {
    super.initState();
    _tempPresets = List.from(widget.settings.cupPresetsInCurrentUnit);
    _controllers = _tempPresets.map((preset) => TextEditingController(text: preset.toString())).toList();
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Cup Presets'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _controllers.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _controllers[index],
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Preset ${index + 1}',
                              suffixText: widget.settings.unitLabel,
                              border: const OutlineInputBorder(),
                            ),
                            onChanged: (value) {
                              final intValue = int.tryParse(value);
                              if (intValue != null) {
                                _tempPresets[index] = intValue;
                              }
                            },
                          ),
                        ),
                        if (_controllers.length > 1)
                          IconButton(
                            onPressed: () {
                              setState(() {
                                _controllers[index].dispose();
                                _controllers.removeAt(index);
                                _tempPresets.removeAt(index);
                              });
                            },
                            icon: const Icon(Icons.remove_circle, color: Colors.red),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _tempPresets.add(widget.settings.unit == WaterUnit.ml ? 200 : 7);
                  _controllers.add(TextEditingController(text: _tempPresets.last.toString()));
                });
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Preset'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF42A5F5),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            // Update all presets
            for (int i = 0; i < _tempPresets.length; i++) {
              if (i < widget.settings.cupPresets.length) {
                await widget.settings.updateCupPreset(i, _tempPresets[i]);
              } else {
                await widget.settings.addCupPreset(_tempPresets[i]);
              }
            }

            // Remove extra presets if any
            while (widget.settings.cupPresets.length > _tempPresets.length) {
              await widget.settings.removeCupPreset(widget.settings.cupPresets.length - 1);
            }

            if (context.mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Cup presets updated'),
                  backgroundColor: Color(0xFF42A5F5),
                ),
              );
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF42A5F5),
            foregroundColor: Colors.white,
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}