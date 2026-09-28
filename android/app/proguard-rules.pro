# Zachowaj klasy platformowe Fluttera i powiązane pakiety
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugin.editing.** { *; }

# Reguły dla bazy danych SQLite i odtwarzacza
-keepattributes *Annotation*,Signature
-dontwarn sun.misc.**
-keepclassmembers class * extends android.app.Activity {
    public void *(android.view.View);
}

# Ignorowanie opcjonalnych bibliotek Google Play Core
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }