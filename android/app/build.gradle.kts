plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.orbipay.test8" 
    compileSdk = 36

    defaultConfig {
        applicationId = "com.orbipay.test8" 
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = 7
        versionName = "1.0.3"
        // ndkVersion = "28.2.13676358"
        multiDexEnabled = true
    }

    signingConfigs {
        create("release") {
            storeFile = file("release-key.jks")
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
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }
    
    sourceSets {
        getByName("main") {
            jniLibs.srcDirs("libs")
        }
    }

    repositories {
        flatDir {
            dirs("libs")
        }
    }
    
    buildFeatures {
        buildConfig = true
    }
}

// dependencies {
//     implementation(platform("com.google.firebase:firebase-bom:32.3.1"))
//     implementation("com.google.firebase:firebase-messaging:24.0.0")
//     implementation("com.google.firebase:firebase-analytics")
    
//     // 3. Keep your desugaring dependency here
//     coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
// }

dependencies {
    implementation(platform("com.google.firebase:firebase-bom:32.3.1"))
    implementation("com.google.firebase:firebase-messaging:24.0.0")
    implementation("com.google.firebase:firebase-analytics")
    
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation(files("libs/PrinterLib_24.aar"))
    
    // Add version overrides for AGP 8.8.0
    configurations.all {
        resolutionStrategy {
            force("androidx.browser:browser:1.8.0")
            force("androidx.activity:activity-ktx:1.10.0")
            force("androidx.activity:activity:1.10.0")
            force("androidx.core:core-ktx:1.16.0")
            force("androidx.core:core:1.16.0")
        }
    }
}

flutter {
    source = "../.."
}