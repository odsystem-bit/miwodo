# ProGuard rules for Flutter
# Keep Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Keep Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep Dart2Js
-keep class dart.** { *; }

# Keep Riverpod
-keep class com.miwodo.miwodo.** { *; }

# Keep models
-keep class **.models.** { *; }

# General rules
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception

# Don't warn
-dontwarn android.**
-dontwarn androidx.**
-dontwarn com.google.**
