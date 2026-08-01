plugins {
    id("com.android.application")
    // Kotlin is provided by the Flutter Gradle Plugin (Built-in Kotlin).
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.fendo.fendo"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.fendo.fendo"
        // Firebase Auth Phone + Play Integrity require 23+.
        minSdk = maxOf(flutter.minSdkVersion, 23)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        debug {
            // Same keystore fingerprints registered in Firebase (SHA-1/256).
            signingConfig = signingConfigs.getByName("debug")
        }
        release {
            // TODO: replace with upload keystore before Play Store production.
            // Debug signing keeps SHA fingerprints matching Firebase for now.
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Helps Play Integrity / Play Services path for Phone Auth (reduces reCAPTCHA).
    implementation("com.google.android.gms:play-services-base:18.5.0")
    implementation("com.google.android.gms:play-services-auth:21.3.0")
}
