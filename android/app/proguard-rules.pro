# SGP-Agent release ProGuard / R8 rules
# Flutter + speech plugins keep reflection entry points.

-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

-keep class com.sgp.sgp_agent.** { *; }

-dontwarn javax.annotation.**
-dontwarn org.bouncycastle.**
-dontwarn com.google.android.gms.**
