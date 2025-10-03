import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

/// Minimal test to isolate the initialization issue
void main() async {
  print('🧪 Starting Minimal Test...');

  try {
    // Test 1: Basic timezone initialization
    print('1️⃣ Testing timezone initialization...');
    tz.initializeTimeZones();

    final String timeZoneName = DateTime.now().timeZoneName;
    print('   System timezone: $timeZoneName');

    tz.Location? location;
    if (timeZoneName == 'IST') {
      location = tz.getLocation('Asia/Kolkata');
    } else {
      location = tz.UTC;
    }

    tz.setLocalLocation(location);
    print('   ✅ Timezone set to: ${location.name}');

    // Test 2: Current time in timezone
    final now = tz.TZDateTime.now(location);
    print('   Current time: $now');

    print('🎉 Minimal test completed successfully!');

  } catch (e) {
    print('❌ Minimal test failed: $e');
  }
}