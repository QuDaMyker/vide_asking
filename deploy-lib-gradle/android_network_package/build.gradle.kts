plugins {
    id("com.android.library")
    kotlin("android")
    kotlin("plugin.serialization")
    id("maven-publish")
    id("signing")
}

group = "io.github.yourusername"
version = "1.0.0"

android {
    namespace = "com.vibe.network"
    compileSdk = 34

    defaultConfig {
        minSdk = 24
        targetSdk = 34
        
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        consumerProguardFiles("consumer-rules.pro")
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = "11"
    }

    buildFeatures {
        compose = true
    }

    composeOptions {
        kotlinCompilerExtensionVersion = "1.5.14"
    }

    publishing {
        singleVariant("release") {
            withSourceJar()
            withJavadocJar()
        }
    }
}

dependencies {
    // Kotlin
    implementation("org.jetbrains.kotlin:kotlin-stdlib:1.9.23")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.7.3")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")

    // Jetpack Compose
    implementation("androidx.compose.ui:ui:1.6.8")
    implementation("androidx.compose.runtime:runtime:1.6.8")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.7.0")

    // Serialization
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.6.3")

    // Networking
    implementation("com.squareup.retrofit2:retrofit:2.11.0")
    implementation("com.squareup.retrofit2:converter-kotlinx-serialization:2.11.0")
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
    implementation("com.squareup.okhttp3:logging-interceptor:4.12.0")

    // Dependency Injection (Hilt)
    implementation("com.google.dagger:hilt-android:2.50")

    // Testing
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.7.3")
}

publishing {
    publications {
        register<MavenPublication>("release") {
            from(components["release"])

            groupId = "io.github.yourusername"
            artifactId = "android-network-package"
            version = project.version.toString()

            pom {
                name.set("Android Network Package")
                description.set("A comprehensive Kotlin-based network handling package for Android with Jetpack Compose support")
                url.set("https://github.com/yourusername/vibe")

                licenses {
                    license {
                        name.set("MIT License")
                        url.set("https://opensource.org/licenses/MIT")
                        distribution.set("repo")
                    }
                }

                developers {
                    developer {
                        id.set("yourusername")
                        name.set("Your Name")
                        email.set("your.email@example.com")
                    }
                }

                scm {
                    url.set("https://github.com/yourusername/vibe")
                    connection.set("scm:git:github.com/yourusername/vibe.git")
                    developerConnection.set("scm:git:ssh://github.com/yourusername/vibe.git")
                }
            }
        }
    }

    repositories {
        maven {
            name = "sonatype"
            url = if (version.toString().endsWith("SNAPSHOT")) {
                uri("https://s01.oss.sonatype.org/content/repositories/snapshots/")
            } else {
                uri("https://s01.oss.sonatype.org/service/local/staging/deploy/maven2/")
            }
            credentials {
                username = System.getenv("OSSRH_USERNAME") ?: findProperty("ossrhUsername").toString()
                password = System.getenv("OSSRH_PASSWORD") ?: findProperty("ossrhPassword").toString()
            }
        }
    }
}

signing {
    useGpgCmd()
    sign(publishing.publications["release"])
}
