import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'reminders_provider.dart';

class RemindersScreen extends StatelessWidget {
  const RemindersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<RemindersProvider>(
      builder: (context, remindersProvider, child) {
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            title: const Text(
              'Reminders',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF1565C0),
              ),
            ),
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            elevation: 0,
            automaticallyImplyLeading: false,
            actions: [
              // Test notification button (debug mode only)
              if (true) // Set to true for testing
                IconButton(
                  icon: const Icon(Icons.bug_report, color: Color(0xFF1565C0)),
                  onPressed: () async {
                    await remindersProvider.testNotification();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Test notification sent!'),
                          backgroundColor: Color(0xFF42A5F5),
                        ),
                      );
                    }
                  },
                ),
            ],
          ),
          body: Column(
            children: [
              // Master Toggle Section
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).shadowColor.withValues(alpha: 0.1),
                      spreadRadius: 1,
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Water Reminders',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1565C0),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            remindersProvider.permissionsGranted
                                ? 'Get notified to stay hydrated'
                                : 'Notification permissions required',
                            style: TextStyle(
                              color: remindersProvider.permissionsGranted
                                  ? Colors.grey[600]
                                  : Colors.red,
                              fontSize: 14,
                            ),
                          ),
                          if (!remindersProvider.permissionsGranted)
                            TextButton(
                              onPressed: () {
                                remindersProvider.initialize();
                              },
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 30),
                              ),
                              child: const Text(
                                'Grant permissions',
                                style: TextStyle(
                                  color: Color(0xFF42A5F5),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Switch(
                      value: remindersProvider.remindersEnabled,
                      onChanged: remindersProvider.permissionsGranted
                          ? (value) async {
                              await remindersProvider.setRemindersEnabled(value);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      value
                                          ? 'Water reminders enabled'
                                          : 'Water reminders disabled',
                                    ),
                                    backgroundColor: const Color(0xFF42A5F5),
                                  ),
                                );
                              }
                            }
                          : null,
                      activeThumbColor: const Color(0xFF42A5F5),
                      activeTrackColor: const Color(0xFF42A5F5).withValues(alpha: 0.3),
                    ),
                  ],
                ),
              ),

              // Reminders List
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).shadowColor.withValues(alpha: 0.1),
                        spreadRadius: 1,
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          'Daily Reminders',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1565C0),
                          ),
                        ),
                      ),
                      Expanded(
                        child: remindersProvider.reminders.isEmpty
                            ? Center(
                                child: Text(
                                  'No reminders set',
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 16,
                                  ),
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                itemCount: remindersProvider.reminders.length,
                                itemBuilder: (context, index) {
                                  final reminder = remindersProvider.reminders[index];
                                  return _buildReminderItem(context, reminder, index, remindersProvider);
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),

              // Add Reminder Button
              Container(
                margin: const EdgeInsets.all(16),
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _showAddReminderDialog(context, remindersProvider),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF42A5F5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Add Reminder',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReminderItem(BuildContext context, WaterReminder reminder, int index, RemindersProvider provider) {
    final timeString = _formatTime(reminder.time);
    final isEnabled = provider.remindersEnabled && reminder.isEnabled;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isEnabled
            ? const Color(0xFFE3F2FD)
            : const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isEnabled
              ? const Color(0xFF42A5F5).withValues(alpha: 0.3)
              : Colors.grey.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Time and Notification Icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isEnabled
                  ? const Color(0xFF42A5F5)
                  : Colors.grey[400],
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              Icons.notifications,
              color: isEnabled
                  ? Colors.white
                  : Colors.white,
              size: 24,
            ),
          ),

          const SizedBox(width: 16),

          // Time and Frequency Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  timeString,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isEnabled
                        ? const Color(0xFF42A5F5)
                        : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  reminder.frequency,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),

          // Status and Actions
          Column(
            children: [
              // Individual reminder toggle
              Transform.scale(
                scale: 0.8,
                child: Switch(
                  value: reminder.isEnabled,
                  onChanged: provider.remindersEnabled ? (value) async {
                    provider.toggleReminder(index, value);
                  } : null,
                  activeThumbColor: const Color(0xFF42A5F5),
                  activeTrackColor: const Color(0xFF42A5F5).withValues(alpha: 0.3),
                ),
              ),

              // Action buttons
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: isEnabled ? () => _editReminder(context, index, provider) : null,
                    icon: Icon(
                      Icons.edit,
                      size: 20,
                      color: isEnabled
                          ? const Color(0xFF42A5F5)
                          : Colors.grey[500],
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                  IconButton(
                    onPressed: () => _deleteReminder(context, index, provider),
                    icon: const Icon(
                      Icons.delete,
                      size: 20,
                      color: Colors.red,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTime(TimeOfDay time) {
    final now = DateTime.now();
    final dateTime = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return DateFormat('h:mm a').format(dateTime);
  }

  void _editReminder(BuildContext context, int index, RemindersProvider provider) {
    _showEditReminderDialog(context, provider.reminders[index], index, provider);
  }

  void _deleteReminder(BuildContext context, int index, RemindersProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Reminder'),
        content: const Text('Are you sure you want to delete this reminder?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              // Delete immediately without waiting
              provider.deleteReminder(index);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Reminder deleted'),
                  backgroundColor: Color(0xFF42A5F5),
                ),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showAddReminderDialog(BuildContext context, RemindersProvider provider) {
    _showEditReminderDialog(context, null, -1, provider);
  }

  void _showEditReminderDialog(BuildContext context, WaterReminder? reminder, int index, RemindersProvider provider) {
    TimeOfDay selectedTime = reminder?.time ?? const TimeOfDay(hour: 9, minute: 0);
    String selectedFrequency = reminder?.frequency ?? 'Every day';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(reminder == null ? 'Add Reminder' : 'Edit Reminder'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Time Picker
              ListTile(
                leading: const Icon(Icons.access_time, color: Color(0xFF42A5F5)),
                title: const Text('Time'),
                subtitle: Text(_formatTime(selectedTime)),
                onTap: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: selectedTime,
                  );
                  if (time != null) {
                    setDialogState(() {
                      selectedTime = time;
                    });
                  }
                },
              ),

              const SizedBox(height: 16),

              // Frequency Selector
              DropdownButtonFormField<String>(
                initialValue: selectedFrequency,
                decoration: const InputDecoration(
                  labelText: 'Frequency',
                  prefixIcon: Icon(Icons.repeat, color: Color(0xFF42A5F5)),
                  border: OutlineInputBorder(),
                ),
                items: [
                  'Every day',
                  'Weekdays only',
                  'Weekends only',
                  'Monday, Wednesday, Friday',
                  'Tuesday, Thursday',
                ].map((freq) => DropdownMenuItem(
                  value: freq,
                  child: Text(freq),
                )).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() {
                      selectedFrequency = value;
                    });
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final newReminder = WaterReminder(
                  id: reminder?.id ?? WaterReminder.generateSafeId(),
                  time: selectedTime,
                  frequency: selectedFrequency,
                  isEnabled: true,
                );

                if (index >= 0) {
                  await provider.updateReminder(index, newReminder);
                } else {
                  await provider.addReminder(newReminder);
                }

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        reminder == null
                            ? 'Reminder added and scheduled'
                            : 'Reminder updated',
                      ),
                      backgroundColor: const Color(0xFF42A5F5),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF42A5F5),
                foregroundColor: Colors.white,
              ),
              child: Text(reminder == null ? 'Add' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }
}