// Local copy of flutter_tesseract_ocr 0.4.31 with a build script for current
// Android Gradle Plugin versions: the original used jcenter() and a bundled
// tesseract4android .aar, neither of which current tooling accepts. The same
// engine (Tesseract4Android) now comes from JitPack.
group = "io.paratoner.flutter_tesseract_ocr"
version = "1.0"

buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.android.tools.build:gradle:8.13.1")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
        maven("https://jitpack.io")
    }
}

plugins {
    id("com.android.library")
}

android {
    namespace = "io.paratoner.flutter_tesseract_ocr"
    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        minSdk = 21
    }
}

dependencies {
    implementation("cz.adaptech.tesseract4android:tesseract4android:4.9.0")
}
