import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Firma de release: los datos del keystore se leen de `android/key.properties`
// (archivo ignorado por Git; copia `key.properties.example` y llénalo). Ver docs/PUBLICAR.md.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
} else {
    logger.warn(
        "ATENCION: no existe android/key.properties. El build de release se firmara con la " +
            "clave de DEBUG y NO sirve para publicar en Play Store. Ver docs/PUBLICAR.md."
    )
}

// Minificacion (R8) opcional: se activa con `doctorchile.minify=true` en android/gradle.properties.
// Esta desactivada por defecto porque debe probarse en un dispositivo real con el modelo ONNX
// antes de publicar (ver docs/PUBLICAR.md).
val habilitarMinificacion =
    (findProperty("doctorchile.minify") as String?)?.toBoolean() ?: false

android {
    namespace = "com.uaz.doctorchile.doctor_chile_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.uaz.doctorchile.doctor_chile_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    buildTypes {
        release {
            // Con key.properties se firma con la clave propia; sin el, se usa la de debug
            // para que `flutter run --release` siga funcionando en desarrollo.
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }

            isMinifyEnabled = habilitarMinificacion
            isShrinkResources = habilitarMinificacion
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

flutter {
    source = "../.."
}
