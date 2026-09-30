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

# ==============================================================================
# OCHRONA DYNAMICZNEJ WYSPY / NAKŁADKI SYSTEMOWEJ (flutter_overlay_window)
# ==============================================================================
# Zapobiega wycinaniu klas wtyczki tworzącej pływające okno systemowe
-keep class flutter.overlay.window.flutter_overlay_window.** { *; }
-dontwarn flutter.overlay.window.flutter_overlay_window.**

# Zachowanie izolowanego punktu wejścia dla procesu nakładki (overlayMain)
-keepclassmembers class * {
    @pragma("vm:entry-point") *;
    @androidx.annotation.Keep *;
}

# ==============================================================================
# OCHRONA SILNIKA AUDIO W TLE I POWIADOMIEŃ MEDIÓW (AudioService & MediaKit)
# ==============================================================================
# Zapobiega usunięciu natywnego serwisu multimedialnego i kontrolera Bluetooth/słuchawek
-keep class com.ryanheise.audioservice.** { *; }
-dontwarn com.ryanheise.audioservice.**

# Ochrona silnika odtwarzania MediaKit (dekodery FFmpeg / natywne biblioteki C++)
-keep class com.alexmercerind.media_kit.** { *; }
-dontwarn com.alexmercerind.media_kit.**

# Ochrona sesji audio systemowej (audio_session)
-keep class com.ryanheise.audio_session.** { *; }
-dontwarn com.ryanheise.audio_session.**

# ==============================================================================
# OCHRONA DOSTAWCY PLIKÓW DLA AKTUALIZACJI APK (FileProvider)
# ==============================================================================
-keep class androidx.core.content.FileProvider { *; }