# Flutter Local Notifications proguard rules
# Keep all classes from the flutter_local_notifications plugin
-keep class com.dexterous.** { *; }

# Keep all notification related classes
-keep class * extends android.app.Service
-keep class * extends android.content.BroadcastReceiver

# Preserve all notification sound and icon files
-keep class androidx.core.app.NotificationCompat** { *; }
-keep class androidx.core.app.NotificationManagerCompat** { *; }

# Keep Flutter plugin registration classes
-keep class io.flutter.plugin.common.** { *; }
-keep class io.flutter.embedding.engine.plugins.** { *; }

# Keep all classes that have native methods
-keepclasseswithmembers class * {
    native <methods>;
}

# Keep Parcelable implementations
-keep class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}