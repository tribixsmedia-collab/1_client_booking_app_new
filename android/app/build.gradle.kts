import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// ---------------------------------------------------------------------------
// Release signing -- see android/README-signing.md for how to create the key.
//
// android/key.properties and the .jks it points at are deliberately absent
// from Git. The upload key is what proves to Google Play that an update came
// from us; anyone holding it can publish as us.
//
// A machine without the key can still build and run debug and profile builds.
// Only release builds need it, and they refuse to run without it rather than
// falling back -- see the check below.
// ---------------------------------------------------------------------------
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKey = keystorePropertiesFile.exists()
val keystoreProperties = Properties().apply {
    if (hasReleaseKey) FileInputStream(keystorePropertiesFile).use { load(it) }
}

if (!hasReleaseKey) {
    // Fail only if a release is actually being built. Checking at
    // configuration time instead would break `flutter run` on every machine
    // that has no key, which is every machine that does not publish.
    gradle.taskGraph.whenReady {
        val building = allTasks.any {
            (it.name.startsWith("assemble") || it.name.startsWith("bundle") ||
             it.name.startsWith("package")) && it.name.contains("Release")
        }
        if (building) throw GradleException(
            "\n\nNo release signing key.\n\n" +
            "This build was about to be signed with the DEBUG key, which " +
            "Google Play rejects and which anyone can forge. Rather than " +
            "hand you an artifact that looks fine and is not publishable, " +
            "it stops here.\n\n" +
            "Create android/key.properties and the keystore it points at:\n" +
            "  see android/README-signing.md\n\n" +
            "Debug and profile builds are unaffected and need no key.\n"
        )
    }
}

android {
    namespace = "com.rniservices.customer"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.rniservices.customer"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            // Null rather than the debug config when there is no key: an
            // unsigned artifact cannot be installed or uploaded by mistake,
            // whereas a debug-signed one looks perfectly normal until Play
            // rejects it. The taskGraph check above stops the build first.
            signingConfig = if (hasReleaseKey) signingConfigs.getByName("release") else null

            // Razorpay's classes must survive shrinking or checkout callbacks
            // stop firing in release builds. Listed here so the rules are
            // already in place whenever minification is turned on.
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
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
