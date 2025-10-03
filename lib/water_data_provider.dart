import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class WaterLog {
  final DateTime time;
  final int amount;

  WaterLog({required this.time, required this.amount});

  Map<String, dynamic> toJson() {
    return {
      'time': time.millisecondsSinceEpoch,
      'amount': amount,
    };
  }

  factory WaterLog.fromJson(Map<String, dynamic> json) {
    return WaterLog(
      time: DateTime.fromMillisecondsSinceEpoch(json['time']),
      amount: json['amount'],
    );
  }
}

class WaterDataProvider extends ChangeNotifier {
  int _currentIntake = 0;
  int _dailyGoal = 2000;
  int _streak = 0;

  final Map<DateTime, List<WaterLog>> _waterLogs = {};
  bool _isInitialized = false;

  WaterDataProvider() {
    // Mark as initialized with default values to show UI immediately
    _isInitialized = true;
    // Initialize data in the background
    _initializeAsync();
  }

  void _initializeAsync() {
    // Load data asynchronously without blocking UI
    Future.delayed(Duration.zero, () async {
      try {
        final prefs = await SharedPreferences.getInstance();

        // Load daily goal
        final savedGoal = prefs.getInt('daily_goal');
        if (savedGoal != null) {
          _dailyGoal = savedGoal;
        }

        // Load current intake for today
        final today = DateTime.now();
        final todayKey = DateTime(today.year, today.month, today.day);
        final todayString = _dateToString(todayKey);
        final savedIntake = prefs.getInt('current_intake_$todayString');
        if (savedIntake != null) {
          _currentIntake = savedIntake;
        }

        // Load water logs
        await _loadWaterLogs();

        // Calculate streak
        _streak = _calculateCurrentStreak();

        // Notify listeners to update UI
        notifyListeners();

        if (kDebugMode) {
          print('WaterDataProvider: Background initialization completed');
          print('Daily goal: $_dailyGoal, Current intake: $_currentIntake, Streak: $_streak');
        }
      } catch (e) {
        if (kDebugMode) {
          print('WaterDataProvider: Background initialization error: $e');
        }
      }
    });
  }

  // Getters
  int get currentIntake => _currentIntake;
  int get dailyGoal => _dailyGoal;
  int get streak => _streak;
  Map<DateTime, List<WaterLog>> get waterLogs => _waterLogs;
  bool get isInitialized => _isInitialized;


  // Get today's logs
  List<WaterLog> get todaysLog {
    final today = DateTime.now();
    final todayKey = DateTime(today.year, today.month, today.day);
    return _waterLogs[todayKey] ?? [];
  }

  // Add water
  void addWater(int amount) async {
    final now = DateTime.now();
    final todayKey = DateTime(now.year, now.month, now.day);

    // Add to current intake
    _currentIntake += amount;

    // Add to logs
    if (_waterLogs[todayKey] == null) {
      _waterLogs[todayKey] = [];
    }
    _waterLogs[todayKey]!.insert(0, WaterLog(time: now, amount: amount));

    // Update streak after each water addition (might achieve goal)
    _updateStreak();

    // Save to persistent storage
    await _saveTodaysData();
    await _saveWaterLogs();

    notifyListeners();
  }

  // Get logs for a specific day
  List<WaterLog> getLogsForDay(DateTime day) {
    final dayKey = DateTime(day.year, day.month, day.day);
    return _waterLogs[dayKey] ?? [];
  }

  // Get total intake for a specific day
  int getTotalIntakeForDay(DateTime day) {
    final logs = getLogsForDay(day);
    return logs.fold(0, (sum, log) => sum + log.amount);
  }

  // Check if a day has logs
  bool hasLogsForDay(DateTime day) {
    final dayKey = DateTime(day.year, day.month, day.day);
    return _waterLogs.containsKey(dayKey) && _waterLogs[dayKey]!.isNotEmpty;
  }

  // Update streak calculation
  void _updateStreak() {
    _streak = _calculateCurrentStreak();
  }

  // Calculate current streak based on daily goal achievement
  int _calculateCurrentStreak() {
    int streak = 0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (int i = 0; i < 365; i++) { // Check up to a year back
      final checkDate = today.subtract(Duration(days: i));
      final dayKey = DateTime(checkDate.year, checkDate.month, checkDate.day);

      // Check if daily goal was achieved on this day
      final dailyIntake = getTotalIntakeForDay(dayKey);

      if (dailyIntake >= _dailyGoal) {
        streak++;
      } else {
        // Break the streak if goal wasn't met
        // Special case: if this is today and no water logged yet, don't count today but continue checking previous days
        if (i == 0 && dailyIntake == 0 && checkDate.isAtSameMomentAs(today)) {
          // Today with no water logged yet - skip today but continue with previous days
          continue;
        } else {
          // Goal not met on this day - streak is broken
          break;
        }
      }
    }

    return streak;
  }

  // Reset daily data (for testing or new day)
  void resetDay() async {
    _currentIntake = 0;
    final today = DateTime.now();
    final todayKey = DateTime(today.year, today.month, today.day);
    _waterLogs[todayKey] = [];

    // Recalculate streak after reset
    _updateStreak();

    // Save changes to storage
    await _saveTodaysData();
    await _saveWaterLogs();

    notifyListeners();
  }

  // Set daily goal
  void setDailyGoal(int goal) async {
    _dailyGoal = goal;

    // Recalculate streak since goal changed
    _updateStreak();

    // Save to persistent storage
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('daily_goal', _dailyGoal);

    notifyListeners();
  }

  // Helper method to convert date to string
  String _dateToString(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // Save today's current intake
  Future<void> _saveTodaysData() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayKey = DateTime(today.year, today.month, today.day);
    final todayString = _dateToString(todayKey);
    await prefs.setInt('current_intake_$todayString', _currentIntake);
  }

  // Save water logs to persistent storage
  Future<void> _saveWaterLogs() async {
    final prefs = await SharedPreferences.getInstance();

    // Convert water logs to JSON format
    final Map<String, dynamic> logsJson = {};
    _waterLogs.forEach((date, logs) {
      final dateString = _dateToString(date);
      logsJson[dateString] = logs.map((log) => log.toJson()).toList();
    });

    await prefs.setString('water_logs', jsonEncode(logsJson));
  }

  // Load water logs from persistent storage
  Future<void> _loadWaterLogs() async {
    final prefs = await SharedPreferences.getInstance();
    final logsString = prefs.getString('water_logs');

    if (logsString != null) {
      try {
        final Map<String, dynamic> logsJson = jsonDecode(logsString);

        _waterLogs.clear();
        logsJson.forEach((dateString, logsData) {
          final dateParts = dateString.split('-');
          final date = DateTime(
            int.parse(dateParts[0]),
            int.parse(dateParts[1]),
            int.parse(dateParts[2]),
          );

          final logs = (logsData as List)
              .map((logData) => WaterLog.fromJson(logData))
              .toList();

          _waterLogs[date] = logs;
        });
      } catch (e) {
        // If there's an error loading data, start fresh
        _waterLogs.clear();
      }
    }
  }
}