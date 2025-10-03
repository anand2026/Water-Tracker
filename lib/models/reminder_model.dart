import 'package:flutter/material.dart';

/// Data model for water reminders
class WaterReminder {
  final String id;
  final TimeOfDay time;
  final bool isEnabled;
  final DateTime createdAt;
  final DateTime? lastTriggered;

  const WaterReminder({
    required this.id,
    required this.time,
    this.isEnabled = true,
    required this.createdAt,
    this.lastTriggered,
  });

  /// Copy with method for updates
  WaterReminder copyWith({
    String? id,
    TimeOfDay? time,
    bool? isEnabled,
    DateTime? createdAt,
    DateTime? lastTriggered,
  }) {
    return WaterReminder(
      id: id ?? this.id,
      time: time ?? this.time,
      isEnabled: isEnabled ?? this.isEnabled,
      createdAt: createdAt ?? this.createdAt,
      lastTriggered: lastTriggered ?? this.lastTriggered,
    );
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'hour': time.hour,
      'minute': time.minute,
      'isEnabled': isEnabled,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'lastTriggered': lastTriggered?.millisecondsSinceEpoch,
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
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int),
      lastTriggered: json['lastTriggered'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['lastTriggered'] as int)
          : null,
    );
  }

  /// Get next scheduled DateTime for this reminder
  DateTime getNextScheduledTime() {
    final now = DateTime.now();
    var scheduledDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    // If time has passed today, schedule for tomorrow
    if (scheduledDateTime.isBefore(now)) {
      scheduledDateTime = scheduledDateTime.add(const Duration(days: 1));
    }

    return scheduledDateTime;
  }

  /// Format time for display
  String formatTime() {
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WaterReminder &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  /// Generate a safe notification ID that fits within 32-bit integer limits
  /// Uses a hash-based approach to ensure uniqueness while staying within bounds
  static String generateSafeId() {
    final now = DateTime.now();
    // Create a unique identifier based on time components
    // Use seconds since epoch (smaller number) + milliseconds for uniqueness
    final baseId = now.millisecondsSinceEpoch ~/ 1000; // Seconds since epoch
    final millis = now.millisecondsSinceEpoch % 1000; // Just the milliseconds part

    // Combine with a simple hash to ensure we stay within 32-bit range
    // Max 32-bit signed int: 2,147,483,647
    final safeId = (baseId % 1000000) * 1000 + millis; // Keep under 1 billion

    return safeId.toString();
  }

  @override
  String toString() {
    return 'WaterReminder{id: $id, time: ${formatTime()}, isEnabled: $isEnabled}';
  }
}