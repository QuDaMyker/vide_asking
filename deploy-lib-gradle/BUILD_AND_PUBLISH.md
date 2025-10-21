# Build and Publish Android Network Package

Complete step-by-step guide to build and publish your Android Network Package as a library.

## Option 1: JitPack (Recommended for Quick Start)

### What is JitPack?
- Easiest way to publish Android libraries
- No account setup needed
- Works directly from GitHub/GitLab
- Automatic builds on tag release

### Steps

#### 1. Prepare Your Repository

```bash
cd /Users/danhphamquoc/bitbucket/vibe

# Initialize git (if not already done)
git init

# Add all files
git add .

# Create initial commit
git commit -m "Initial commit: Add Android Network Package"

# Add remote (replace with your GitHub URL)
git remote add origin https://github.com/YOUR_USERNAME/vibe.git

# Push to GitHub
git push -u origin main
```

#### 2. Create GitHub Release

1. Go to your GitHub repository: `https://github.com/YOUR_USERNAME/vibe`
2. Click on "Releases" → "Create a new release"
3. Fill in:
   - Tag version: `v1.0.0`
   - Release title: `Android Network Package v1.0.0`
   - Description: Add release notes
4. Click "Publish release"

#### 3. Use in Your Project

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

#### 4. Verify

JitPack will build automatically. Check status at:
```
https://jitpack.io/#YOUR_USERNAME/vibe
```

---

## Option 2: Maven Central (Professional Production)

### Prerequisites

#### Step 1: Create Sonatype Account

1. Go to https://issues.sonatype.org
2. Sign up for free account
3. Create JIRA issue requesting repository access
4. Provide:
   - **Project URL**: https://github.com/YOUR_USERNAME/vibe
   - **Group ID**: `io.github.yourusername` or `com.yourdomain`
   - **SCM URL**: https://github.com/YOUR_USERNAME/vibe.git
5. Wait for approval (usually 1-2 business days)

#### Step 2: Generate GPG Key

```bash
# Generate GPG key
gpg --gen-key

# You'll be asked:
# - Real name: Your Name
# - Email: your.email@example.com
# - Comment: Android Network Package
# - Passphrase: Choose strong password

# List keys to find your KEY_ID
gpg --list-keys

# Output example:
# pub   rsa3072 2024-01-15 [SC] [expires: 2026-01-15]
#       1234567890ABCDEF1234567890ABCDEF12345678  <- This is your KEY_ID
# uid           [ultimate] Your Name <your.email@example.com>
# sub   rsa3072 2024-01-15 [E] [expires: 2026-01-15]

# Export secret key for Gradle
gpg --export-secret-keys > ~/.gnupg/secring.gpg

# Export public key to key server
gpg --keyserver hkp://keys.openpgp.org --send-keys YOUR_KEY_ID
```

#### Step 3: Setup Gradle Credentials

Create or edit `~/.gradle/gradle.properties`:

```properties
# JVM settings
org.gradle.jvmargs=-Xmx2048m
org.gradle.parallel=true
org.gradle.daemon=true

# Signing configuration
signing.keyId=YOUR_KEY_ID
signing.password=YOUR_GPG_PASSWORD
signing.secretKeyRingFile=/Users/YOUR_USERNAME/.gnupg/secring.gpg

# Sonatype credentials
ossrhUsername=YOUR_SONATYPE_USERNAME
ossrhPassword=YOUR_SONATYPE_PASSWORD
```

### Configuration

#### Step 1: Update build.gradle.kts

Edit `/Users/danhphamquoc/bitbucket/vibe/android_network_package/build.gradle.kts`:

```gradle
plugins {
    id("com.android.library")
    kotlin("android")
    kotlin("plugin.serialization")
    id("maven-publish")
    id("signing")
}

group = "io.github.yourusername"  // Change this
version = "1.0.0"                  // Update version

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
    // All existing dependencies...
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

#### Step 2: Verify Build Files

Make sure these files exist in `android_network_package/`:

- `build.gradle.kts` (configured above)
- `proguard-rules.pro` (should be created)
- `consumer-rules.pro` (should be created)
- `LICENSE` (MIT license file)

### Build and Publish

#### Step 1: Local Testing

```bash
cd /Users/danhphamquoc/bitbucket/vibe

# Clean build
./gradlew clean

# Build the library
./gradlew :android_network_package:build

# Check for errors
./gradlew :android_network_package:lint

# Publish to local Maven (optional test)
./gradlew :android_network_package:publishToMavenLocal
```

#### Step 2: Publish to Maven Central

```bash
# Set environment variables (if not using gradle.properties)
export OSSRH_USERNAME="your_sonatype_username"
export OSSRH_PASSWORD="your_sonatype_password"
export GPG_PASSPHRASE="your_gpg_password"

# Navigate to project
cd /Users/danhphamquoc/bitbucket/vibe

# Publish
./gradlew clean \
    :android_network_package:build \
    :android_network_package:publishReleasePublicationToSonatypeRepository \
    publishToSonatype \
    closeAndReleaseSonatypeStagingRepository
```

#### Step 3: Monitor Release

1. Go to https://s01.oss.sonatype.org
2. Login with your Sonatype credentials
3. Check "Staging Repositories"
4. Find your repository
5. Verify files then click "Release"

#### Step 4: Verify Publication

After 10-30 minutes, verify at:

```bash
# Check Maven Central
curl -s "https://repo1.maven.org/maven2/io/github/yourusername/android-network-package/1.0.0/" | grep .jar
```

Or visit:
```
https://central.sonatype.com/artifact/io.github.yourusername/android-network-package/1.0.0
```

---

## Option 3: Private Maven Repository

For internal/enterprise use (Nexus, Artifactory, etc.)

### Configuration

```gradle
publishing {
    repositories {
        maven {
            name = "company-nexus"
            url = uri("https://nexus.company.com/repository/android/")
            
            credentials {
                username = System.getenv("NEXUS_USERNAME") ?: findProperty("nexusUsername").toString()
                password = System.getenv("NEXUS_PASSWORD") ?: findProperty("nexusPassword").toString()
            }
        }
    }
}
```

### Publish

```bash
export NEXUS_USERNAME="your_username"
export NEXUS_PASSWORD="your_password"

./gradlew :android_network_package:publish
```

---

## Usage in Your Project

After publishing, use in any Android project:

```gradle
// Add repository
repositories {
    // For JitPack
    maven { url = uri("https://jitpack.io") }
    
    // For Maven Central (no repo needed, it's default)
    
    // For private Nexus
    // maven {
    //     url = uri("https://nexus.company.com/repository/android/")
    // }
}

// Add dependency
dependencies {
    // JitPack
    implementation("com.github.YOUR_USERNAME:vibe:v1.0.0")
    
    // Maven Central
    // implementation("io.github.yourusername:android-network-package:1.0.0")
    
    // Private Nexus
    // implementation("com.company:android-network-package:1.0.0")
}
```

---

## Troubleshooting

### Gradle Build Fails

```bash
# Clean everything
./gradlew clean

# Check dependencies
./gradlew :android_network_package:dependencies

# Rebuild
./gradlew :android_network_package:build
```

### Authentication Errors

```bash
# Verify credentials
cat ~/.gradle/gradle.properties

# Verify GPG key
gpg --list-keys

# Re-export GPG key if needed
gpg --export-secret-keys > ~/.gnupg/secring.gpg
```

### GPG Signature Fails

```bash
# Try using system GPG command
gpg --version

# Export public key to servers
gpg --keyserver hkp://keys.openpgp.org --send-keys YOUR_KEY_ID
gpg --keyserver hkp://pgp.mit.edu --send-keys YOUR_KEY_ID
```

### Library Not Appearing

**For Maven Central**: Wait 10-30 minutes and check:
- Staging repository was released
- No files failed verification

**For JitPack**: Check build status at:
```
https://jitpack.io/#YOUR_USERNAME/vibe
```

---

## Version Management

### Semantic Versioning

```
MAJOR.MINOR.PATCH

1.0.0      - First release
1.1.0      - New features
1.1.1      - Bug fixes
2.0.0      - Breaking changes
1.0.0-alpha - Pre-release
1.0.0-SNAPSHOT - Development (never release)
```

### Update Version

Edit `build.gradle.kts`:
```gradle
version = "1.1.0"  // Change version
```

Then republish.

---

## Next Steps

1. Choose publishing method (recommend JitPack for quick start)
2. Complete setup steps for chosen method
3. Build locally and verify
4. Publish
5. Test in another project
6. Update README with usage instructions
7. Monitor and maintain library

---

## Summary Table

| Feature | JitPack | Maven Central | Private |
|---------|---------|---------------|---------|
| Setup Time | 5 min | 30 min | 20 min |
| Account Required | GitHub | Sonatype | Yes |
| Best For | Quick Start | Production | Enterprise |
| Cost | Free | Free | Varies |
| Discoverability | Good | Excellent | Internal |
