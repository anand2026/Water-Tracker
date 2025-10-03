import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'water_data_provider.dart';
import 'settings_provider.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<WaterDataProvider, SettingsProvider>(
      builder: (context, waterData, settings, child) {
        final selectedLogs = _selectedDay != null ? waterData.getLogsForDay(_selectedDay!) : <WaterLog>[];
        final totalIntake = _selectedDay != null ? waterData.getTotalIntakeForDay(_selectedDay!) : 0;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Water History',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF1565C0),
          ),
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Color(0xFF1565C0)),
            onPressed: _shareData,
          ),
          IconButton(
            icon: const Icon(Icons.download, color: Color(0xFF1565C0)),
            onPressed: _exportData,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
          // Calendar Section
          Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.1),
                  spreadRadius: 1,
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TableCalendar<WaterLog>(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              calendarFormat: _calendarFormat,
              eventLoader: waterData.getLogsForDay,
              startingDayOfWeek: StartingDayOfWeek.monday,
              selectedDayPredicate: (day) {
                return isSameDay(_selectedDay, day);
              },
              onDaySelected: (selectedDay, focusedDay) {
                if (!isSameDay(_selectedDay, selectedDay)) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                }
              },
              onFormatChanged: (format) {
                if (_calendarFormat != format) {
                  setState(() {
                    _calendarFormat = format;
                  });
                }
              },
              onPageChanged: (focusedDay) {
                _focusedDay = focusedDay;
              },
              calendarStyle: CalendarStyle(
                outsideDaysVisible: false,
                selectedDecoration: const BoxDecoration(
                  color: Color(0xFF42A5F5),
                  shape: BoxShape.circle,
                ),
                todayDecoration: BoxDecoration(
                  color: const Color(0xFF42A5F5).withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                markerDecoration: const BoxDecoration(
                  color: Color(0xFF4CAF50),
                  shape: BoxShape.circle,
                ),
                markersMaxCount: 1,
                canMarkersOverflow: false,
              ),
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: TextStyle(
                  color: Color(0xFF1565C0),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                leftChevronIcon: Icon(
                  Icons.chevron_left,
                  color: Color(0xFF1565C0),
                ),
                rightChevronIcon: Icon(
                  Icons.chevron_right,
                  color: Color(0xFF1565C0),
                ),
              ),
              daysOfWeekStyle: const DaysOfWeekStyle(
                weekdayStyle: TextStyle(
                  color: Color(0xFF1565C0),
                  fontWeight: FontWeight.w600,
                ),
                weekendStyle: TextStyle(
                  color: Color(0xFF1565C0),
                  fontWeight: FontWeight.w600,
                ),
              ),
              calendarBuilders: CalendarBuilders(
                markerBuilder: (context, day, events) {
                  if (events.isNotEmpty) {
                    final totalIntake = waterData.getTotalIntakeForDay(day);
                    if (totalIntake > 0) {
                      String displayText;
                      if (settings.unit == WaterUnit.ml) {
                        final liters = totalIntake / 1000;
                        if (liters >= 1.0) {
                          displayText = '${liters.toStringAsFixed(1)}L';
                        } else {
                          displayText = '${totalIntake}ml';
                        }
                      } else {
                        final oz = settings.mlToOz(totalIntake);
                        displayText = '${oz}oz';
                      }

                      return Positioned(
                        bottom: 1,
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Color(0xFF4CAF50),
                            borderRadius: BorderRadius.all(Radius.circular(8)),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          constraints: const BoxConstraints(minWidth: 20, minHeight: 16),
                          child: Center(
                            child: Text(
                              displayText,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      );
                    }
                  }
                  return null;
                },
              ),
            ),
          ),

          // Daily Summary
          if (_selectedDay != null) ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('EEEE, MMM d').format(_selectedDay!),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1565C0),
                        ),
                      ),
                      Text(
                        '${selectedLogs.length} entries',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF42A5F5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      settings.formatWaterAmount(totalIntake),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Daily Logs
          Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.1),
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
                      'Daily Log',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1565C0),
                      ),
                    ),
                  ),
                  selectedLogs.isEmpty
                      ? SizedBox(
                          height: 200,
                          child: Center(
                            child: Text(
                              'No water logged for this day',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 16,
                              ),
                            ),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: selectedLogs.length,
                          itemBuilder: (context, index) {
                              final log = selectedLogs[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE3F2FD),
                                        borderRadius: BorderRadius.circular(24),
                                      ),
                                      child: const Icon(
                                        Icons.water_drop,
                                        color: Color(0xFF42A5F5),
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            DateFormat('h:mm a').format(log.time),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 16,
                                              color: Color(0xFF1565C0),
                                            ),
                                          ),
                                          Text(
                                            settings.formatWaterAmount(log.amount),
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE8F5E8),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        _getGlassSize(log.amount, settings),
                                        style: const TextStyle(
                                          color: Color(0xFF2E7D32),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  const SizedBox(height: 20),
                ],
              ),
          ),
          const SizedBox(height: 16),
          ],
        ),
      ),
    );
      }, // Close Consumer builder
    ); // Close Consumer
  }

  String _getGlassSize(int amount, SettingsProvider settings) {
    // Convert to current unit for comparison
    final amountInCurrentUnit = settings.convertFromMl(amount);

    if (settings.unit == WaterUnit.ml) {
      if (amount <= 250) return 'Small';
      if (amount <= 350) return 'Medium';
      if (amount <= 500) return 'Large';
      return 'Bottle';
    } else {
      // For oz
      if (amountInCurrentUnit <= 8) return 'Small';
      if (amountInCurrentUnit <= 12) return 'Medium';
      if (amountInCurrentUnit <= 17) return 'Large';
      return 'Bottle';
    }
  }

  void _shareData() async {
    if (_selectedDay == null) return;

    try {
      final waterData = context.read<WaterDataProvider>();
      final logs = waterData.getLogsForDay(_selectedDay!);
      final total = waterData.getTotalIntakeForDay(_selectedDay!);
      final date = DateFormat('MMM d, yyyy').format(_selectedDay!);
      final settings = context.read<SettingsProvider>();

      String shareText = '🌊 Water Intake Report for $date\n\n';
      shareText += '📊 Total: ${settings.formatWaterAmount(total)}\n';
      shareText += '🎯 Goal: ${settings.formatWaterAmount(settings.dailyGoal)}\n';

      final percentage = (total / settings.dailyGoal * 100).round();
      shareText += '📈 Progress: $percentage%\n\n';

      if (logs.isNotEmpty) {
        shareText += '📝 Daily Log (${logs.length} entries):\n';
        for (final log in logs) {
          shareText += '• ${DateFormat('h:mm a').format(log.time)} - ${settings.formatWaterAmount(log.amount)}\n';
        }
      } else {
        shareText += '📝 No water logged for this day\n';
      }

      shareText += '\n💧 Tracked with Water Tracker App';

      await Share.share(
        shareText,
        subject: 'Water Intake Report - $date',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Water intake data shared successfully!'),
            backgroundColor: Color(0xFF42A5F5),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _exportData() async {
    try {
      final waterData = context.read<WaterDataProvider>();
      final settings = context.read<SettingsProvider>();

      // Show loading indicator
      if (mounted) {
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
                Text('Exporting data...'),
              ],
            ),
            backgroundColor: Color(0xFF42A5F5),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Prepare CSV data
      List<List<dynamic>> csvData = [
        ['Date', 'Time', 'Amount (${settings.unitLabel})', 'Total Daily (${settings.unitLabel})', 'Goal Achievement (%)']
      ];

      // Get all water logs from the provider
      final allLogs = waterData.waterLogs;

      // Sort dates in descending order (newest first)
      final sortedDates = allLogs.keys.toList()
        ..sort((a, b) => b.compareTo(a));

      for (final date in sortedDates) {
        final logs = allLogs[date]!;
        final dailyTotal = waterData.getTotalIntakeForDay(date);
        final goalPercentage = (dailyTotal / settings.dailyGoal * 100).round();
        final dateString = DateFormat('yyyy-MM-dd').format(date);

        if (logs.isEmpty) {
          // Add a row for days with no logs
          csvData.add([
            dateString,
            'No logs',
            '0',
            settings.convertFromMl(dailyTotal).toString(),
            '$goalPercentage%'
          ]);
        } else {
          // Sort logs by time for each day
          final sortedLogs = List<WaterLog>.from(logs)
            ..sort((a, b) => a.time.compareTo(b.time));

          for (int i = 0; i < sortedLogs.length; i++) {
            final log = sortedLogs[i];
            csvData.add([
              i == 0 ? dateString : '', // Only show date for first entry of each day
              DateFormat('HH:mm').format(log.time),
              settings.convertFromMl(log.amount).toString(),
              i == 0 ? settings.convertFromMl(dailyTotal).toString() : '', // Only show total for first entry
              i == 0 ? '$goalPercentage%' : '', // Only show percentage for first entry
            ]);
          }
        }
      }

      // Convert to CSV string
      String csvString = const ListToCsvConverter().convert(csvData);

      // Get the downloads directory
      Directory? directory;
      if (Platform.isAndroid) {
        directory = await getExternalStorageDirectory();
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      if (directory != null) {
        final fileName = 'water_tracker_export_${DateFormat('yyyy_MM_dd_HH_mm').format(DateTime.now())}.csv';
        final file = File('${directory.path}/$fileName');
        await file.writeAsString(csvString);

        // Share the file
        await Share.shareXFiles(
          [XFile(file.path)],
          subject: 'Water Tracker Data Export',
          text: 'Your complete water intake data from Water Tracker app.',
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Data exported successfully! File: $fileName'),
              backgroundColor: const Color(0xFF4CAF50),
              duration: const Duration(seconds: 3),
              action: SnackBarAction(
                label: 'Share',
                textColor: Colors.white,
                onPressed: () async {
                  await Share.shareXFiles([XFile(file.path)]);
                },
              ),
            ),
          );
        }
      } else {
        throw Exception('Could not access storage directory');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting data: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}

