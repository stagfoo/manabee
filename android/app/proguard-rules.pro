# R8 rules for the release build.
#
# The Flutter Gradle plugin contributes the rules the engine and the embedding
# need, so this file only has to cover what belongs to this app.

# google_mlkit_text_recognition references every script's recogniser options
# (compileOnly), but this app ships only the Latin and Japanese models. R8
# fails the release build on the missing classes unless told they are absent
# on purpose.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.korean.**

# ML Kit loads its recogniser implementations reflectively.
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_text_common.** { *; }
