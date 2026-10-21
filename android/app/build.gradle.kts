import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.octaviokonzen.lifelink"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Exigido pelo ota_update (atualização do app pelo próprio app).
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.octaviokonzen.lifelink"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Assinatura fixa das versões publicadas: o Android só instala uma
    // atualização por cima se ela vier assinada com a MESMA chave. A chave
    // vem de android/key.properties (no PC) ou das variáveis ANDROID_* (no
    // GitHub Actions, que decifra android/app/lifelink.jks.enc). Sem ela, usa
    // a chave de debug.
    val keyProps = Properties().apply {
        val file = rootProject.file("key.properties")
        if (file.exists()) file.inputStream().use { load(it) }
    }
    fun key(name: String, env: String): String? = keyProps.getProperty(name) ?: System.getenv(env)
    val storeFilePath = key("storeFile", "ANDROID_KEYSTORE_PATH")

    signingConfigs {
        if (storeFilePath != null) {
            create("release") {
                storeFile = file(storeFilePath)
                storePassword = key("storePassword", "ANDROID_KEYSTORE_PASSWORD")
                keyAlias = key("keyAlias", "ANDROID_KEY_ALIAS")
                keyPassword = key("keyPassword", "ANDROID_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("release") ?: signingConfigs.getByName("debug")
            // Sem o R8 encolher/renomear o código: o shared_preferences (e
            // outros plugins) chamam o código Java/Kotlin pelo NOME, via JNI.
            // Renomeado (ex.: kotlin.coroutines.Continuation → "lh"), o app
            // fechava ao abrir com NoSuchMethodError (versões 1.0.1 e 1.0.2).
            isMinifyEnabled = false
            isShrinkResources = false
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

// Firebase (login e dados da conta): o arquivo google-services.json vem do
// Console do Firebase (app Android com.octaviokonzen.lifelink). Sem ele o app
// compila e funciona sem login.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
