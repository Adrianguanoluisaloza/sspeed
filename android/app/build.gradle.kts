plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.flutter_application_2"

    // Estos valores los expone el plugin de Flutter; están OK en Kotlin DSL
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    // Recomendado hoy: Java/Kotlin 17. Si quieres mantener 11, deja como lo tenías.
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.example.flutter_application_2"
        minSdk = flutter.minSdkVersion       // ✅ Kotlin DSL (no usar minSdkVersion 21)
        targetSdk = flutter.targetSdkVersion // ✅
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Firma de debug para salir del paso. Cambia luego por tu firma de release.
            signingConfig = signingConfigs.getByName("debug")
            // Si agregas ProGuard:
            // isMinifyEnabled = true
            // proguardFiles(
            //     getDefaultProguardFile("proguard-android-optimize.txt"),
            //     "proguard-rules.pro"
            // )
        }
        debug {
            // Ajustes opcionales de debug
        }
    }
}

flutter {
    source = "../.."
}

// ❌ NO pongas NADA más fuera de android{} / flutter{}.
// El bloque que te estaba rompiendo era este (elíminalo por completo):
// defaultConfig {
//     ...
//     minSdkVersion 21
// }
