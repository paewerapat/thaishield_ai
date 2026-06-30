# google_mlkit_text_recognition ships optional script-specific recognizers
# (Chinese/Devanagari/Japanese/Korean) as separate dependencies. This app
# only includes the base (Latin) recognizer, so R8 can't find those classes
# when shrinking — they're safe to ignore since they're never called.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
