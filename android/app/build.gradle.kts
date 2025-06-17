// android/app/build.gradle

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services") version "4.3.15" apply false
}

android {
    // Un seul bloc 'android' est autorisé. Toutes les configurations sont combinées ici.
    namespace "com.example.lead" // IMPORTANT : Remplacez par VOTRE nom de package réel (celui de Firebase)
    compileSdk flutter.compileSdkVersion // Ou une version stable comme 34 si vous préférez

    // MISE À JOUR : Ciblez Java 17, plus compatible avec les dernières versions de Gradle
    compileOptions {
        sourceCompatibility JavaVersion.VERSION_17 // CHANGEMENT : Passez à Java 17
        targetCompatibility JavaVersion.VERSION_17 // CHANGEMENT : Passez à Java 17
    }
    kotlinOptions {
        jvmTarget = '17' // CHANGEMENT : Doit correspondre à compileOptions
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.lead"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode.toInteger()
        versionName = flutter.versionName
        minSdkVersion(23)
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Import the Firebase BoM
    implementation(platform("com.google.firebase:firebase-bom:33.12.0"))
    implementation("com.google.firebase:firebase-auth-ktx")
    implementation("com.google.android.gms:play-services-auth:21.1.1") 


    // TODO: Add the dependencies for Firebase products you want to use
    // When using the BoM, don't specify versions in Firebase dependencies
    // https://firebase.google.com/docs/android/setup#available-libraries
}
apply(plugin = "com.google.gms.google-services")
