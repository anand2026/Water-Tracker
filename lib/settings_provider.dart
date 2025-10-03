import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

enum WaterUnit { ml, oz }

class SettingsProvider extends ChangeNotifier {
  int _dailyGoal = 2000; // ml
  WaterUnit _unit = WaterUnit.ml;
  List<int> _cupPresets = [150, 250, 300]; // ml
  bool _isDarkMode = false;

  // Getters
  int get dailyGoal => _dailyGoal;
  WaterUnit get unit => _unit;
  List<int> get cupPresets => _cupPresets;
  bool get isDarkMode => _isDarkMode;

  // Get daily goal in current unit
  int get dailyGoalInCurrentUnit {
    return _unit == WaterUnit.ml ? _dailyGoal : mlToOz(_dailyGoal);
  }

  // Get cup presets in current unit
  List<int> get cupPresetsInCurrentUnit {
    return _unit == WaterUnit.ml
        ? _cupPresets
        : _cupPresets.map((ml) => mlToOz(ml)).toList();
  }

  // Unit conversion helpers
  int mlToOz(int ml) => (ml * 0.033814).round();
  int ozToMl(int oz) => (oz * 29.5735).round();

  String get unitLabel => _unit == WaterUnit.ml ? 'ml' : 'oz';

  Future<void> initialize() async {
    await _loadSettings();
  }

  Future<void> setDailyGoal(int goal) async {
    // Convert to ml if needed
    _dailyGoal = _unit == WaterUnit.ml ? goal : ozToMl(goal);
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setUnit(WaterUnit unit) async {
    _unit = unit;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> updateCupPreset(int index, int value) async {
    // Convert to ml if needed
    final valueInMl = _unit == WaterUnit.ml ? value : ozToMl(value);
    _cupPresets[index] = valueInMl;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> addCupPreset(int value) async {
    // Convert to ml if needed
    final valueInMl = _unit == WaterUnit.ml ? value : ozToMl(value);
    _cupPresets.add(valueInMl);
    _cupPresets.sort();
    await _saveSettings();
    notifyListeners();
  }

  Future<void> removeCupPreset(int index) async {
    if (_cupPresets.length > 1) { // Keep at least one preset
      _cupPresets.removeAt(index);
      await _saveSettings();
      notifyListeners();
    }
  }

  Future<void> setTheme(bool isDark) async {
    _isDarkMode = isDark;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> resetToDefaults() async {
    _dailyGoal = 2000;
    _unit = WaterUnit.ml;
    _cupPresets = [150, 250, 300];
    _isDarkMode = false;
    await _saveSettings();
    notifyListeners();
  }

  // Storage methods
  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('daily_goal', _dailyGoal);
    await prefs.setString('unit', _unit.name);
    await prefs.setString('cup_presets', json.encode(_cupPresets));
    await prefs.setBool('dark_mode', _isDarkMode);
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    _dailyGoal = prefs.getInt('daily_goal') ?? 2000;

    final unitString = prefs.getString('unit') ?? 'ml';
    _unit = WaterUnit.values.firstWhere(
      (e) => e.name == unitString,
      orElse: () => WaterUnit.ml,
    );

    final presetsString = prefs.getString('cup_presets');
    if (presetsString != null) {
      final List<dynamic> presetsList = json.decode(presetsString);
      _cupPresets = presetsList.cast<int>();
    }

    _isDarkMode = prefs.getBool('dark_mode') ?? false;
  }

  // Export settings as JSON
  Map<String, dynamic> exportSettings() {
    return {
      'daily_goal': _dailyGoal,
      'unit': _unit.name,
      'cup_presets': _cupPresets,
      'dark_mode': _isDarkMode,
      'exported_at': DateTime.now().toIso8601String(),
    };
  }

  // Import settings from JSON
  Future<void> importSettings(Map<String, dynamic> settings) async {
    try {
      _dailyGoal = settings['daily_goal'] ?? 2000;

      final unitString = settings['unit'] ?? 'ml';
      _unit = WaterUnit.values.firstWhere(
        (e) => e.name == unitString,
        orElse: () => WaterUnit.ml,
      );

      if (settings['cup_presets'] != null) {
        _cupPresets = List<int>.from(settings['cup_presets']);
      }

      _isDarkMode = settings['dark_mode'] ?? false;

      await _saveSettings();
      notifyListeners();
    } catch (e) {
      throw Exception('Invalid settings format');
    }
  }

  // Get theme data
  ThemeData getThemeData() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF42A5F5), // Water blue color consistent with the app
      brightness: _isDarkMode ? Brightness.dark : Brightness.light,
    );

    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      scaffoldBackgroundColor: _isDarkMode
          ? const Color(0xFF121212)
          : const Color(0xFFF8FCFF),
      appBarTheme: AppBarTheme(
        backgroundColor: _isDarkMode
            ? const Color(0xFF121212)
            : const Color(0xFFF8FCFF),
        elevation: 0,
      ),
    );
  }

  // Helper methods for water tracking integration
  int convertToMl(int value) {
    return _unit == WaterUnit.ml ? value : ozToMl(value);
  }

  int convertFromMl(int ml) {
    return _unit == WaterUnit.ml ? ml : mlToOz(ml);
  }

  String formatWaterAmount(int ml) {
    final amount = convertFromMl(ml);
    return '$amount$unitLabel';
  }
}