// Top-level build file
buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.android.tools.build:gradle:7.3.0") // Vérifiez la version
        classpath("com.google.gms:google-services:4.4.2") // Version cohérente
        // NOTE: Ne mettez pas d'autres versions ici
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Votre configuration existante pour les répertoires build
val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}