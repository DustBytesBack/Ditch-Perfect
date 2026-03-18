## Flutter Local Notifications — keep scheduled-notification receivers & Gson
-keep class com.dexterous.** { *; }
-keep class com.google.gson.** { *; }
-dontwarn com.google.gson.**

## Keep Flutter plugin registrant
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugin.** { *; }

## Keep AndroidX core (used for notification channels)
-keep class androidx.core.app.NotificationCompat** { *; }

## Keep file_picker
-keep class com.mr.flutter.plugin.filepicker.** { *; }
