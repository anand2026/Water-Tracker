import 'package:flutter/material.dart';

/// Data model for water reminders
class WaterReminder {
  final String id;
  final TimeOfDay time;
  final bool isEnabled;
  final DateTime? lastTriggered;
  final int snoozeCount;
  final List<String> activeDays; // ['mon', 'tue', 'wed', etc.]
  final String frequency; // Add frequency property for compatibility

  const WaterReminder({
    required this.id,
    required this.time,
    this.isEnabled = true,
    this.lastTriggered,
    this.snoozeCount = 0,
    this.activeDays = const ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'],
    this.frequency = 'Every day', // Default frequency
  });

  /// Create a copy with modified properties
  WaterReminder copyWith({
    String? id,
    TimeOfDay? time,
    bool? isEnabled,
    DateTime? lastTriggered,
    int? snoozeCount,
    List<String>? activeDays,
    String? frequency,
  }) {
    return WaterReminder(
      id: id ?? this.id,
      time: time ?? this.time,
      isEnabled: isEnabled ?? this.isEnabled,
      lastTriggered: lastTriggered ?? this.lastTriggered,
      snoozeCount: snoozeCount ?? this.snoozeCount,
      activeDays: activeDays ?? this.activeDays,
      frequency: frequency ?? this.frequency,
    );
  }

  /// Convert to JSON for persistence
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'hour': time.hour,
      'minute': time.minute,
      'isEnabled': isEnabled,
      'lastTriggered': lastTriggered?.millisecondsSinceEpoch,
      'snoozeCount': snoozeCount,
      'activeDays': activeDays,
      'frequency': frequency,
    };
  }

  /// Create from JSON
  factory WaterReminder.fromJson(Map<String, dynamic> json) {
    return WaterReminder(
      id: json['id'] as String,
      time: TimeOfDay(
        hour: json['hour'] as int,
        minute: json['minute'] as int,
      ),
      isEnabled: json['isEnabled'] as bool? ?? true,
      lastTriggered: json['lastTriggered'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['lastTriggered'] as int)
          : null,
      snoozeCount: json['snoozeCount'] as int? ?? 0,
      activeDays: List<String>.from(json['activeDays'] as List? ??
          ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun']),
      frequency: json['frequency'] as String? ?? 'Every day',
    );
  }

  /// Check if reminder should trigger today
  bool shouldTriggerToday() {
    if (!isEnabled) return false;

    final now = DateTime.now();
    final weekdayMap = {
      1: 'mon', 2: 'tue', 3: 'wed', 4: 'thu',
      5: 'fri', 6: 'sat', 7: 'sun'
    };

    final todayKey = weekdayMap[now.weekday];
    return activeDays.contains(todayKey);
  }

  /// Get next scheduled DateTime for this reminder
  DateTime getNextScheduledTime() {
    final now = DateTime.now();
    var scheduledDate = DateTime(
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    // If time has passed today, schedule for tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    // Find next active day
    while (!_isActiveDay(scheduledDate)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return scheduledDate;
  }

  bool _isActiveDay(DateTime date) {
    final weekdayMap = {
      1: 'mon', 2: 'tue', 3: 'wed', 4: 'thu',
      5: 'fri', 6: 'sat', 7: 'sun'
    };
    final dayKey = weekdayMap[date.weekday];
    return activeDays.contains(dayKey);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WaterReminder &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'WaterReminder{id: $id, time: ${time.format}, isEnabled: $isEnabled}';
  }

  /// Generate a safe notification ID that fits within 32-bit integer limits
  /// Uses a simple counter-based approach to ensure safe IDs
  static String generateSafeId() {
    final now = DateTime.now();
    // Use a much smaller, safer approach
    // Generate ID based on time components but keep it very small
    final hour = now.hour;
    final minute = now.minute;
    final second = now.second;
    final millisPart = (now.millisecond ~/ 100); // 0-9

    // Create a safe ID: HHMMSS + single digit (max 7 digits)
    // This ensures we never exceed safe integer limits
    final safeId = (hour * 10000) + (minute * 100) + second + millisPart;

    return safeId.toString();
  }
}

/// Notification action types
enum NotificationAction {
  logDrink,
  snooze5,
  snooze10,
  snooze15,
  dismiss,
}

/// Snooze duration options
class SnoozeDuration {
  static const Duration five = Duration(minutes: 5);
  static const Duration ten = Duration(minutes: 10);
  static const Duration fifteen = Duration(minutes: 15);

  static Duration fromAction(NotificationAction action) {
    switch (action) {
      case NotificationAction.snooze5:
        return five;
      case NotificationAction.snooze10:
        return ten;
      case NotificationAction.snooze15:
        return fifteen;
      default:
        return five;
    }
  }
}