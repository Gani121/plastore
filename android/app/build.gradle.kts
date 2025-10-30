plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.orbipay.test7"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.orbipay.test7"
        minSdk = 21
        targetSdk = 35
        versionCode =4
        versionName = "1.0"
    }

    signingConfigs {
        create("release") {
            storeFile = file("C:/Users/Acer/.android/release-key.jks")
            storePassword = "Ganesh@1234"
            keyAlias = "release_key"
            keyPassword = "Ganesh@1234"
        }
    }

    buildTypes {
        getByName("release") {
            isMinifyEnabled = false        // Keep false for now
            isShrinkResources = false      // Fixes the unused resources error
            signingConfig = signingConfigs.getByName("release")
        }

        getByName("debug") {
            signingConfig = signingConfigs.getByName("release") // optional: use same key for debug
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }
}

dependencies {
    implementation(platform("com.google.firebase:firebase-bom:32.3.1"))
    implementation("com.google.firebase:firebase-analytics")
}

flutter {
    source = "../.."
}
