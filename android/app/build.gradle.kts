plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.orbipay.test6" 
    compileSdk = 36

    defaultConfig {
        applicationId = "com.orbipay.test6" 
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = 5
        versionName = "1.0.1"
        
        // 1. Enable multiDex for desugaring support
        multiDexEnabled = true
    }

    signingConfigs {
        create("release") {
            storeFile = file("C:/Users/PARDEEP/.android/release-key.jks")
            storePassword = "Ganesh@1234" 
            keyAlias = "release_key"      
            keyPassword = "Ganesh@1234"  
        }
    }

    buildTypes {
        getByName("release") {
            isMinifyEnabled = true
            isShrinkResources = true
            signingConfig = signingConfigs.getByName("release")
        }

        getByName("debug") {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

    compileOptions {
        // 2. Enable core library desugaring here
        isCoreLibraryDesugaringEnabled = true
        
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }
}

dependencies {
    implementation(platform("com.google.firebase:firebase-bom:32.3.1"))
    implementation("com.google.firebase:firebase-messaging:24.0.0")
    implementation("com.google.firebase:firebase-analytics")
    
    // 3. Keep your desugaring dependency here
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}