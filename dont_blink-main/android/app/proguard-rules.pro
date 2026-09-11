# ============================================================
# Google Maps Flutter – keep the native MapView classes
# ============================================================
-keep class io.flutter.plugins.googlemaps.** { *; }
-keep class com.google.android.gms.maps.** { *; }
-keep class com.google.android.gms.location.** { *; }
-keep class com.google.maps.android.** { *; }

# ============================================================
# Google Play Services – general rules
# ============================================================
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# ============================================================
# Firebase
# ============================================================
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# ============================================================
# Flutter embedding
# ============================================================
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# ============================================================
# Geolocator
# ============================================================
-keep class com.baseflow.geolocator.** { *; }

# ============================================================
# General Android
# ============================================================
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# ============================================================
# Cashfree PG SDK
# ============================================================
-keep class com.cashfree.** { *; }
-dontwarn com.cashfree.**

# ============================================================
# Flutter Local Notifications
# ============================================================
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-dontwarn com.dexterous.flutterlocalnotifications.**

# ============================================================
# AndroidX
# ============================================================
-keep class androidx.** { *; }
-dontwarn androidx.**

# ============================================================
# Play Core / Flutter Deferred Components
# ============================================================
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**

# ============================================================
# Common networking / annotations
# ============================================================
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**
-dontwarn org.checkerframework.**

