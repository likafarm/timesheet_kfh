import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Ключ подписи — вне репозитория (как ключ age): %USERPROFILE%\.kfh\android\
// key.properties со storeFile, storePassword, keyAlias, keyPassword; другой
// путь — переменная окружения KFH_ANDROID_KEY_PROPERTIES. Без ключа
// release-сборка не собирается: APK, подписанный отладочным ключом, не
// обновит установленную программу.
val keyPropertiesFile = file(
    System.getenv("KFH_ANDROID_KEY_PROPERTIES")
        ?: "${System.getProperty("user.home")}/.kfh/android/key.properties",
)
val keyProperties = Properties().apply {
    if (keyPropertiesFile.exists()) keyPropertiesFile.inputStream().use { load(it) }
}

android {
    namespace = "ru.korovatech.kfx_time_tracking"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "ru.korovatech.kfh"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["appLabel"] = "Табель КФХ"
    }

    signingConfigs {
        if (keyPropertiesFile.exists()) {
            create("release") {
                storeFile = file(keyProperties.getProperty("storeFile"))
                storePassword = keyProperties.getProperty("storePassword")
                keyAlias = keyProperties.getProperty("keyAlias")
                keyPassword = keyProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        debug {
            // Отладочная сборка ставится рядом с рабочей: своя папка данных,
            // свой вход (как debug-сборка на Windows).
            applicationIdSuffix = ".debug"
            manifestPlaceholders["appLabel"] = "Табель КФХ (debug)"
        }
        release {
            signingConfig = signingConfigs.findByName("release")
        }
    }
}

gradle.taskGraph.whenReady {
    val release = allTasks.any { it.name.contains("Release") && it.project == project }
    if (release && !keyPropertiesFile.exists()) {
        throw GradleException(
            "Нет ключа подписи: ${keyPropertiesFile.path} (см. android/app/build.gradle.kts)",
        )
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
