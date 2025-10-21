# Publishing Guide - Android Network Package

This guide shows how to build and publish the Android Network Package as a library to Maven Central, JitPack, or your private Maven repository.

## Table of Contents

1. [Quick Start with JitPack](#quick-start-with-jitpack)
2. [Maven Central Repository](#maven-central-repository)
3. [Private Maven Repository](#private-maven-repository)
4. [Gradle Plugin Configuration](#gradle-plugin-configuration)

---

## Quick Start with JitPack

JitPack is the easiest way to publish Android libraries from GitHub/GitLab.

### Step 1: Push to GitHub

```bash
# Initialize git (if not already done)
cd /Users/danhphamquoc/bitbucket/vibe
git init
git add .
git commit -m "Initial commit: Add Android Network Package"
git remote add origin https://github.com/YOUR_USERNAME/vibe.git
git push -u origin main
```

### Step 2: Create a GitHub Release

1. Go to https://github.com/YOUR_USERNAME/vibe
2. Click "Releases" → "Create a new release"
3. Tag version: `v1.0.0`
4. Release title: `Android Network Package v1.0.0`
5. Publish release

### Step 3: Use in Your Project

In your app's `build.gradle.kts`:

```gradle
repositories {
    google()
    mavenCentral()
    maven { url = uri("https://jitpack.io") }
}

dependencies {
    implementation("com.github.YOUR_USERNAME:vibe:v1.0.0")
}
```

**That's it!** JitPack will automatically build your library.

---

## Maven Central Repository

For publishing to Maven Central (official Android repository).

### Step 1: Setup Signing Credentials

Create `~/.gradle/gradle.properties`:

```properties
org.gradle.jvmargs=-Xmx2048m
org.gradle.parallel=true
org.gradle.daemon=true

# Signing
signing.keyId=YOUR_KEY_ID
signing.password=YOUR_PASSWORD
signing.secretKeyRingFile=/Users/danhphamquoc/.gnupg/secring.gpg

# Sonatype
ossrhUsername=YOUR_SONATYPE_USERNAME
ossrhPassword=YOUR_SONATYPE_PASSWORD
```

### Step 2: Create GPG Key

```bash
# Generate GPG key
gpg --gen-key

# Export secret key
gpg --export-secret-keys -o ~/.gnupg/secring.gpg

# List keys to get KEY_ID
gpg --list-keys
```

### Step 3: Register with Sonatype

1. Go to https://issues.sonatype.org
2. Create account
3. Create issue for repository access
4. Provide:
   - Project URL: `https://github.com/YOUR_USERNAME/vibe`
   - Group ID: `com.github.yourusername` or `io.github.yourusername`
   - SCM URL: `https://github.com/YOUR_USERNAME/vibe.git`

### Step 4: Update Project build.gradle.kts

Add to the root `build.gradle.kts`:

```gradle
plugins {
    id("io.github.gradle-nexus.publish-plugin") version "1.3.0"
}

nexusPublishing {
    repositories {
        sonatype {
            nexusUrl.set(uri("https://s01.oss.sonatype.org/service/local/"))
            snapshotRepositoryUrl.set(uri("https://s01.oss.sonatype.org/content/repositories/snapshots/"))
            username.set(System.getenv("OSSRH_USERNAME") ?: project.findProperty("ossrhUsername"))
            password.set(System.getenv("OSSRH_PASSWORD") ?: project.findProperty("ossrhPassword"))
        }
    }
}
```

### Step 5: Update android_network_package/build.gradle.kts

```gradle
plugins {
    id("com.android.library")
    kotlin("android")
    kotlin("plugin.serialization")
    id("maven-publish")
    id("signing")
}

android {
    namespace = "com.vibe.network"
    compileSdk = 34

    defaultConfig {
        minSdk = 24
        targetSdk = 34
        
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
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
}

dependencies {
    // ... existing dependencies ...
}

// Publishing configuration
afterEvaluate {
    publishing {
        publications {
            create<MavenPublication>("release") {
                from(components["release"])

                groupId = "io.github.yourusername"
                artifactId = "android-network-package"
                version = "1.0.0"

                pom {
                    name.set("Android Network Package")
                    description.set("A comprehensive Kotlin-based network handling package for Android with Jetpack Compose support")
                    url.set("https://github.com/YOUR_USERNAME/vibe")

                    licenses {
                        license {
                            name.set("MIT License")
                            url.set("https://opensource.org/licenses/MIT")
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
                        connection.set("scm:git:github.com/YOUR_USERNAME/vibe.git")
                        developerConnection.set("scm:git:ssh://github.com/YOUR_USERNAME/vibe.git")
                        url.set("https://github.com/YOUR_USERNAME/vibe/tree/main")
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
        sign(publishing.publications["release"])
    }
}
```

### Step 6: Publish to Maven Central

```bash
cd /Users/danhphamquoc/bitbucket/vibe

# Build and publish
./gradlew clean :android_network_package:build :android_network_package:publishReleasePublicationToSonatypeRepository

# Or if using nexus plugin
./gradlew publishToSonatype closeAndReleaseSonatypeStagingRepository
```

### Step 7: Wait for Release

1. Go to https://s01.oss.sonatype.org
2. Login with your Sonatype credentials
3. Find your staging repository
4. Click "Close" then "Release"
5. Wait 10-30 minutes for sync to Maven Central

---

## Private Maven Repository

For publishing to a private Maven repository (Nexus, Artifactory, etc.).

### Step 1: Update build.gradle.kts

```gradle
plugins {
    id("com.android.library")
    kotlin("android")
    kotlin("plugin.serialization")
    id("maven-publish")
}

android {
    // ... existing configuration ...
}

dependencies {
    // ... existing dependencies ...
}

publishing {
    publications {
        create<MavenPublication>("release") {
            from(components["release"])

            groupId = "com.mycompany"
            artifactId = "android-network-package"
            version = "1.0.0"

            pom {
                name.set("Android Network Package")
                description.set("Network handling library for Android")
            }
        }
    }

    repositories {
        maven {
            name = "nexus"
            url = uri("https://nexus.mycompany.com/repository/android/")

            credentials {
                username = System.getenv("NEXUS_USERNAME") ?: findProperty("nexusUsername").toString()
                password = System.getenv("NEXUS_PASSWORD") ?: findProperty("nexusPassword").toString()
            }
        }
    }
}
```

### Step 2: Add Credentials to gradle.properties

```properties
nexusUsername=your_username
nexusPassword=your_password
```

### Step 3: Publish

```bash
./gradlew :android_network_package:publish
```

---

## Gradle Plugin Configuration

### Complete build.gradle.kts for Publishing

Here's a complete example with all necessary plugins:

```gradle
plugins {
    id("com.android.library") version "8.2.0"
    kotlin("android") version "1.9.23"
    kotlin("plugin.serialization") version "1.9.23"
    id("maven-publish")
    id("signing")
    id("io.github.gradle-nexus.publish-plugin") version "1.3.0"
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
    implementation("org.jetbrains.kotlin:kotlin-stdlib:1.9.23")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.7.3")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")

    implementation("androidx.compose.ui:ui:1.6.8")
    implementation("androidx.compose.runtime:runtime:1.6.8")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.7.0")

    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.6.3")

    implementation("com.squareup.retrofit2:retrofit:2.11.0")
    implementation("com.squareup.retrofit2:converter-kotlinx-serialization:2.11.0")
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
    implementation("com.squareup.okhttp3:logging-interceptor:4.12.0")

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
```

---

## Build & Publish Commands

### Local Build

```bash
cd /Users/danhphamquoc/bitbucket/vibe

# Build the library
./gradlew :android_network_package:assembleRelease

# Run tests
./gradlew :android_network_package:test

# Check for errors
./gradlew :android_network_package:lint
```

### Publish to JitPack

```bash
# Create GitHub release
git tag v1.0.0
git push origin v1.0.0

# Then access: https://jitpack.io/#yourusername/vibe/v1.0.0
```

### Publish to Maven Central

```bash
# Set environment variables
export OSSRH_USERNAME="your_sonatype_username"
export OSSRH_PASSWORD="your_sonatype_password"

# Publish
./gradlew clean :android_network_package:build \
    :android_network_package:publishReleasePublicationToSonatypeRepository \
    publishToSonatype \
    closeAndReleaseSonatypeStagingRepository
```

### Publish to Private Repository

```bash
# Set environment variables
export NEXUS_USERNAME="your_nexus_username"
export NEXUS_PASSWORD="your_nexus_password"

# Publish
./gradlew :android_network_package:publish
```

---

## Verification

### After Publishing to Maven Central

Verify your library is available:

```bash
# Using curl
curl -s "https://repo1.maven.org/maven2/io/github/yourusername/android-network-package/1.0.0/" | grep .jar

# Or check on Maven Central
# https://central.sonatype.com/artifact/io.github.yourusername/android-network-package
```

### Test in Your Project

After publishing, you can use it like:

```gradle
dependencies {
    implementation("io.github.yourusername:android-network-package:1.0.0")
}
```

---

## Versioning Strategy

### Semantic Versioning

Follow [Semantic Versioning](https://semver.org/):

- **MAJOR** (1.0.0): Breaking changes
- **MINOR** (0.1.0): New features, backward compatible
- **PATCH** (0.0.1): Bug fixes only

### Version Examples

```
1.0.0      - First release
1.1.0      - Added new features
1.1.1      - Bug fix
2.0.0      - Breaking changes
1.0.0-SNAPSHOT - Development version
```

---

## Troubleshooting

### Issue: "Gradle sync failed"
- Check `build.gradle.kts` syntax
- Ensure all plugins are compatible
- Run `./gradlew clean`

### Issue: "Publishing fails with authentication error"
- Verify credentials in `gradle.properties`
- Check Sonatype/Nexus account is active
- Ensure GPG key is properly configured

### Issue: "Library not appearing on Maven Central"
- Wait 10-30 minutes for sync
- Check Sonatype staging repository status
- Verify POM metadata is complete

### Issue: "GPG signature verification failed"
- Ensure `secring.gpg` exists
- Verify key ID and password
- Try: `gpg --keyserver hkp://keys.openpgp.org --send-keys YOUR_KEY_ID`

---

## Best Practices

1. ✅ Always use semantic versioning
2. ✅ Keep detailed CHANGELOG
3. ✅ Add proper documentation
4. ✅ Test before publishing
5. ✅ Use consistent group ID (e.g., io.github.username)
6. ✅ Include LICENSE file
7. ✅ Add source code to publications
8. ✅ Document all breaking changes
9. ✅ Update README with dependency snippet
10. ✅ Consider using CI/CD for automated releases

---

## Next Steps

1. Choose publishing method (JitPack is easiest to start)
2. Setup credentials if using Maven Central
3. Run build tests locally
4. Create GitHub release or publish to Maven
5. Update README with dependency instructions
6. Monitor library adoption and feedback
