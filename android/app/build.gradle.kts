plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    
}

android {
    namespace = "com.example.fp_pemrograman"
    // PERBAIKAN 1: Naikkan compileSdk ke 35 (atau lebih tinggi jika diminta nanti)
    compileSdk = 36
    
    // PERBAIKAN 2: Atur ndkVersion sesuai yang diminta
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    defaultConfig {
        applicationId = "com.example.fp_pemrograman"
        // PERBAIKAN 3: Naikkan minSdk ke 23
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode ?: 1
        versionName = flutter.versionName ?: "1.0"
        multiDexEnabled = true // Tambahkan ini untuk berjaga-jaga
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    implementation(platform("com.google.firebase:firebase-bom:33.2.0"))
    implementation("com.google.firebase:firebase-analytics")
    implementation("com.google.firebase:firebase-auth")
    implementation("com.google.firebase:firebase-storage")
    implementation("androidx.multidex:multidex:2.0.1") // Tambahkan ini untuk berjaga-jaga
    
}

flutter {
    source = "../.."
}
