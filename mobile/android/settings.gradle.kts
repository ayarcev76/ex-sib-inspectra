pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        file("local.properties").inputStream().use { properties.load(it) }
        val flutterSdkPath = properties.getProperty("flutter.sdk")
        require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
        flutterSdkPath
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    // AGP 8.11.1 — минимальная рекомендуемая для поддержки 16 КБ и совместимости
    id("com.android.application") version "8.11.1" apply false
    // Kotlin 2.0.20 — совместим с AGP 8.11.1 и поддерживает метаданные 2.2.0
    id("org.jetbrains.kotlin.android") version "2.4.10" apply false
}

include(":app")