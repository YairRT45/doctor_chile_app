# Guía de Compilación, Firma y Publicación (`Doctor Chile`)

Este documento detalla el proceso paso a paso para generar compilaciones de producción (`release`) firmadas de **Doctor Chile** para Android, así como la verificación opcional de minificación R8.

---

## 1. Requisitos previos

1. **Flutter SDK** `>= 3.32.0` (Dart `^3.8.0`).
2. **JDK 17+** (incluye la herramienta `keytool`).
3. **Licencias del Android SDK aceptadas:**
   ```bash
   flutter doctor --android-licenses
   ```
4. Verificar que todos los análisis y pruebas pasen antes de empaquetar:
   ```bash
   flutter analyze
   flutter test
   ```

---

## 2. Identificador de aplicación (`applicationId`)

Actualmente `android/app/build.gradle.kts` define:

```kotlin
applicationId = "com.example.doctor_chile_app"
```

> **Importante antes de subir a Google Play Store:** Google Play rechaza paquetes con el prefijo reservado `com.example.*`. Antes de la primera publicación pública, cambia `namespace` y `applicationId` en `android/app/build.gradle.kts` (por ejemplo, `mx.doctorchile.app`) y actualiza el paquete de `MainActivity.kt` si corresponde. Para distribución interna (APK directo en laboratorio o pruebas de campo), puede conservarse temporalmente.

---

## 3. Generación del Keystore de producción

> **Seguridad:** Nunca subas archivos `.jks`, `.keystore` ni `android/key.properties` al repositorio Git (están excluidos en `.gitignore`). Guarda una copia de respaldo del keystore y sus contraseñas en un gestor de secretos seguro; si pierdes la llave, no podrás actualizar la aplicación en dispositivos que ya la tengan instalada.

Ejecuta desde la raíz del proyecto (o en una carpeta segura fuera del repositorio):

```bash
keytool -genkey -v \
  -keystore android/app/upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload
```

---

## 4. Configuración de `android/key.properties`

1. Copia la plantilla incluida en el repositorio:
   ```bash
   cp android/key.properties.example android/key.properties
   ```
2. Edita `android/key.properties` con tus credenciales reales:
   ```properties
   storePassword=TU_PASSWORD_DEL_KEYSTORE
   keyPassword=TU_PASSWORD_DE_LA_LLAVE
   keyAlias=upload
   storeFile=upload-keystore.jks
   ```
   *(Nota: `storeFile` se resuelve de forma relativa a `android/app/`).*

Si `android/key.properties` no existe, `build.gradle.kts` emitirá una advertencia en consola y usará la llave `debug` automáticamente para no bloquear pruebas locales.

---

## 5. Compilación de artefactos de distribución

### Opción A: APKs divididos por arquitectura (recomendado para instalación directa en campo)
Empaqueta únicamente las librerías nativas de `onnxruntime` necesarias para cada arquitectura (`arm64-v8a`, `armeabi-v7a`, `x86_64`), reduciendo el tamaño de descarga en ~55-65%:

```bash
flutter build apk --release --split-per-abi
```

Los archivos generados se ubicarán en:
- `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` *(dispositivos Android modernos)*
- `build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk` *(dispositivos de 32 bits)*
- `build/app/outputs/flutter-apk/app-x86_64-release.apk` *(emuladores PC)*

### Opción B: Android App Bundle (`.aab` para Google Play Store)
```bash
flutter build appbundle --release
```
Salida: `build/app/outputs/bundle/release/app-release.aab`

---

## 6. Minificación de código (R8 / ProGuard)

El proyecto incluye reglas de preservación JNI para ONNX Runtime en `android/app/proguard-rules.pro`. Por seguridad, la minificación está **desactivada por defecto** (`doctorchile.minify=false` en `android/gradle.properties`) hasta validarse en un dispositivo físico.

Para compilar activando R8 y reducción de recursos:

```bash
flutter build apk --release --split-per-abi -Pdoctorchile.minify=true
```

### Lista de verificación obligatoria en dispositivo físico tras activar R8:
1. Instalar el APK `release` en un teléfono Android real.
2. Abrir la app sin conexión a internet (modo avión).
3. Analizar una foto desde **Cámara** y otra desde **Galería**.
4. Confirmar que la inferencia ONNX concluye sin errores y muestra el resultado.
5. Guardar el diagnóstico, cerrar la app por completo, volver a abrirla y verificar el **Historial** y **Detalle**.
6. Si todo funciona correctamente, puedes cambiar `doctorchile.minify=true` de forma permanente en `android/gradle.properties`.

---

## 7. Respaldo automático de Android (`allowBackup`)

En `android/app/src/main/AndroidManifest.xml`, Android permite por defecto respaldar la base de datos SQLite y los documentos de la app en Google Drive del usuario. Gracias a la migración **v3** de la base de datos (`local_database.dart`), las rutas de imágenes se guardan como rutas relativas (`fotos_diagnosticos/<archivo>`), por lo que son resilientes a restauraciones entre dispositivos siempre que el sistema restaure tanto la base de datos como el directorio de documentos.
