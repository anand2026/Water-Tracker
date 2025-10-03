import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main_navigation.dart';
import 'water_data_provider.dart';
import 'reminders_provider.dart';
import 'settings_provider.dart';
import 'notification_service.dart';
import 'widgets/notification_permission_dialog.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize notification service early
  await NotificationService.instance.initialize();

  runApp(const WaterTrackerApp());
}

class WaterTrackerApp extends StatelessWidget {
  const WaterTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => WaterDataProvider()),
        ChangeNotifierProvider(create: (context) => RemindersProvider()..initialize()),
        ChangeNotifierProvider(create: (context) => SettingsProvider()..initialize()),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, child) {
          return MaterialApp(
            title: 'Water Tracker',
            theme: settings.getThemeData(),
            home: const AppWithPermissionCheck(),
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}

class AppWithPermissionCheck extends StatefulWidget {
  const AppWithPermissionCheck({super.key});

  @override
  State<AppWithPermissionCheck> createState() => _AppWithPermissionCheckState();
}

class _AppWithPermissionCheckState extends State<AppWithPermissionCheck> {
  bool _hasCheckedPermissions = false;

  @override
  void initState() {
    super.initState();
    _checkNotificationPermissions();
  }

  Future<void> _checkNotificationPermissions() async {
    // Wait a bit for the app to fully load
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    // Check if we've already asked for permissions before
    final hasAskedBefore = await _hasAskedForPermissionsBefore();

    if (!hasAskedBefore) {
      // Check current notification permission status
      final permissionsGranted = await NotificationService.instance.checkPermissionStatus();

      // If permissions are not granted, show the dialog (first time only)
      if (!permissionsGranted) {
        if (mounted) {
          await NotificationSetupHelper.requestPermissionWithDialog(context);
        }
      }

      // Mark that we've asked for permissions (regardless of outcome)
      await _markPermissionsAsked();
    }

    if (mounted) {
      setState(() {
        _hasCheckedPermissions = true;
      });
    }
  }

  Future<bool> _hasAskedForPermissionsBefore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('has_asked_notification_permissions') ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<void> _markPermissionsAsked() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_asked_notification_permissions', true);
    } catch (e) {
      // Ignore error
    }
  }


  @override
  Widget build(BuildContext context) {
    if (!_hasCheckedPermissions) {
      // Show loading screen while checking permissions
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.water_drop,
                size: 64,
                color: Colors.blue,
              ),
              SizedBox(height: 16),
              Text(
                'Water Tracker',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 32),
              CircularProgressIndicator(),
            ],
          ),
        ),
      );
    }

    return const MainNavigation();
  }
}