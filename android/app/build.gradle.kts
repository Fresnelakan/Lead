// android/app/build.gradle

plugins {
    id "com.android.application"
    id "kotlin-android"
    id "dev.flutter.flutter-gradle-plugin"
    id "com.google.gms.google-services" // IMPORTANT : Ajoutez ou assurez-vous que cette ligne est présente
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
        applicationId "com.example.lead" // IMPORTANT : Doit correspondre à votre nom de package Firebase
        minSdk flutter.minSdkVersion // Généralement 21 pour la plupart des apps Flutter/Firebase
        targetSdk flutter.targetSdkVersion // Ou une version stable comme 34 si vous préférez

        versionCode flutter.versionCode
        versionName flutter.versionName

        multiDexEnabled true // Crucial pour les applications avec beaucoup de dépendances comme Firebase
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
    // Importe la BOM (Bill of Materials) Firebase pour gérer les versions de vos dépendances Firebase.
    // Utilisez la dernière version stable.
    implementation platform('com.google.firebase:firebase-bom:32.7.4') // Vérifiez la dernière version sur firebase.google.com/docs/android/setup

    // Dépendances Firebase que vous utilisez. Assurez-vous que celles-ci sont ici.
    implementation 'com.google.firebase:firebase-analytics'
    implementation 'com.google.firebase:firebase-auth'
    implementation 'com.google.firebase:firebase-firestore'
    implementation 'com.google.firebase:firebase-messaging'

    // Dépendance pour MultiDex
    implementation 'androidx.multidex:multidex:2.0.1'

    // Assurez-vous que ces lignes sont bien à la fin des dépendances si elles existent déjà
    implementation flutter.embeddedInAar ? {
        def jarFile = flutter.findJar('flutter-x.jar')
        if (jarFile == null) {
            jarFile = flutter.findJar('flutter-x.x.x.jar')
        }
        if (jarFile == null) {
            return []
        }
        return files(jarFile)
    } : []
}
