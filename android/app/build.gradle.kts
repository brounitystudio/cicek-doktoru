import java.util.Properties

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

fun configuredValue(name: String, fallback: String): String {
    return (project.findProperty(name) as String?)
        ?: System.getenv(name)
        ?: fallback
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

val configuredAdmobApplicationId = configuredValue("ADMOB_APP_ID", "").trim()
val allowTestAdmobInRelease = configuredValue(
    "ADMOB_ALLOW_TEST_APP_ID",
    "false",
).toBoolean()
val resolvedAdmobApplicationId = configuredAdmobApplicationId.ifEmpty {
    "ca-app-pub-3940256099942544~3347511713"
}
val releaseBuildRequested = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}
if (releaseBuildRequested && configuredAdmobApplicationId.isEmpty() && !allowTestAdmobInRelease) {
    throw GradleException(
        "Release build blocked: set ADMOB_APP_ID to the production AdMob app id. " +
            "For a local test APK only, set ADMOB_ALLOW_TEST_APP_ID=true and " +
            "build with --dart-define=ADMOB_USE_LIVE_IDS=false.",
    )
}

android {
    namespace = "com.brounitystudio.cicek_doktoru"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.brounitystudio.cicek_doktoru"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["admobApplicationId"] = resolvedAdmobApplicationId
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName(
                if (keystorePropertiesFile.exists()) "release" else "debug",
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
