plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.ventourkids.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Required by flutter_local_notifications (java.time APIs on older Android).
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    signingConfigs {
        getByName("debug") {
            storeFile = file("debug.keystore")
            storePassword = "android"
            keyAlias = "ventourkiddebugkey"
            keyPassword = "android"
        }
    }

    defaultConfig {
        applicationId = "com.ventourkids.app"
        minSdk = maxOf(flutter.minSdkVersion, 21)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Map4D SDK đọc key từ AndroidManifest meta-data (không dùng AppConfig Dart).
        // Override bằng -PMAP4D_ACCESS_KEY=... hoặc env MAP4D_ACCESS_KEY khi cần.
        manifestPlaceholders["map4dAccessKey"] =
            project.findProperty("MAP4D_ACCESS_KEY")?.toString()
                ?: System.getenv("MAP4D_ACCESS_KEY")
                ?: "28a1b483b5489fa57f38459d36a358db"
    }

    buildTypes {
        release {
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
