# Reglas de R8/ProGuard para el build de release (solo se aplican si la
# minificacion esta activa: `doctorchile.minify=true` en android/gradle.properties).
# NO verificadas en un dispositivo real: probar el release antes de publicar.

# ONNX Runtime accede a estas clases por JNI (nombres fijos): no se deben
# renombrar ni eliminar.
-keep class ai.onnxruntime.** { *; }
-dontwarn ai.onnxruntime.**

# Plugin Flutter que envuelve ONNX Runtime (registrado en GeneratedPluginRegistrant).
-keep class com.masicai.flutteronnxruntime.** { *; }
-dontwarn com.masicai.flutteronnxruntime.**
