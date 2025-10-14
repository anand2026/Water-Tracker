import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'main_navigation.dart';
import 'water_data_provider.dart';
import 'reminders_provider.dart';
import 'settings_provider.dart';
import 'notification_service.dart';
import 'notification_permission_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize notification service early
  await NotificationService.instance.initialize();

  // Initialize global notification permission provider
  await NotificationPermissionProvider.instance.initialize();

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
        ChangeNotifierProvider.value(value: NotificationPermissionProvider.instance),
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
    // Show UI immediately, don't block on permission check
    if (mounted) {
      setState(() {
        _hasCheckedPermissions = true;
      });
    }

    // Do permission work in background after UI is shown
    _performPermissionCheckBackground();
  }

  void _performPermissionCheckBackground() async {
    try {
      // Wait a bit for the app to fully load and UI to render
      await Future.delayed(const Duration(milliseconds: 1000));

      if (!mounted) return;

      // Always check current notification permission status
      final permissionsGranted = await NotificationService.instance.checkPermissionStatus();

      // If permissions are not granted, show the permission dialog
      if (!permissionsGranted) {
        if (mounted) {
          await NotificationService.instance.requestNotificationPermissionDirectly();
        }
      }
    } catch (e) {
      // Silently handle errors to prevent crashes
      if (kDebugMode) {
        print('Background permission check error: $e');
      }
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