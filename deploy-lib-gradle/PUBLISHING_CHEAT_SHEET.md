# Quick Publishing Cheat Sheet

## 🚀 Fastest Way: JitPack (5 minutes)

```bash
# 1. Push to GitHub
git tag v1.0.0
git push origin v1.0.0

# 2. Use in your app's build.gradle.kts
repositories {
    maven { url = uri("https://jitpack.io") }
}

dependencies {
    implementation("com.github.YOUR_USERNAME:vibe:v1.0.0")
}

# That's it! JitPack auto-builds your library
```

---

## 📦 Maven Central (Professional)

### Prerequisites
```bash
# 1. Create Sonatype account (free)
# Go to: https://issues.sonatype.org

# 2. Generate GPG key
gpg --gen-key

# 3. Export key
gpg --export-secret-keys -o ~/.gnupg/secring.gpg

# 4. List your key ID
gpg --list-keys
```

### Configuration
```bash
# Add to ~/.gradle/gradle.properties
org.gradle.jvmargs=-Xmx2048m
org.gradle.parallel=true
org.gradle.daemon=true

signing.keyId=YOUR_KEY_ID
signing.password=YOUR_PASSWORD
signing.secretKeyRingFile=/Users/yourname/.gnupg/secring.gpg

ossrhUsername=YOUR_SONATYPE_USERNAME
ossrhPassword=YOUR_SONATYPE_PASSWORD
```

### Update build.gradle.kts
```gradle
plugins {
    id("com.android.library")
    kotlin("android")
    id("maven-publish")
    id("signing")
}

group = "io.github.yourusername"
version = "1.0.0"

android {
    // ... your config ...
    
    publishing {
        singleVariant("release") {
            withSourceJar()
            withJavadocJar()
        }
    }
}

publishing {
    publications {
        register<MavenPublication>("release") {
            from(components["release"])
            groupId = "io.github.yourusername"
            artifactId = "android-network-package"
            version = project.version.toString()
            // ... pom config ...
        }
    }
}

signing {
    useGpgCmd()
    sign(publishing.publications["release"])
}
```

### Publish
```bash
./gradlew clean :android_network_package:build \
    :android_network_package:publishReleasePublicationToSonatypeRepository \
    publishToSonatype \
    closeAndReleaseSonatypeStagingRepository
```

---

## 🔧 Private Repository (Nexus/Artifactory)

```gradle
repositories {
    maven {
        url = uri("https://nexus.mycompany.com/repository/android/")
        credentials {
            username = findProperty("nexusUsername") as String
            password = findProperty("nexusPassword") as String
        }
    }
}

publishing {
    repositories {
        maven {
            url = uri("https://nexus.mycompany.com/repository/android/")
            credentials {
                username = findProperty("nexusUsername") as String
                password = findProperty("nexusPassword") as String
            }
        }
    }
}
```

### Publish
```bash
./gradlew :android_network_package:publish
```

---

## 📋 Build Commands

```bash
# Clean build
./gradlew clean

# Build library only
./gradlew :android_network_package:build

# Run tests
./gradlew :android_network_package:test

# Check for lint errors
./gradlew :android_network_package:lint

# Assemble release
./gradlew :android_network_package:assembleRelease

# Publish to local Maven
./gradlew :android_network_package:publishToMavenLocal
```

---

## 📝 Version Examples

```
1.0.0         - First release
1.1.0         - Add features (backward compatible)
1.1.1         - Bug fix
2.0.0         - Breaking changes
1.0.0-alpha01 - Alpha version
1.0.0-beta01  - Beta version
1.0.0-rc01    - Release candidate
1.0.0-SNAPSHOT - Development (never release)
```

---

## ✅ Pre-Publish Checklist

- [ ] Update version in `build.gradle.kts`
- [ ] Update `README.md` with new features
- [ ] Run all tests: `./gradlew test`
- [ ] Check for lint errors: `./gradlew lint`
- [ ] Update `CHANGELOG.md`
- [ ] Tag in git: `git tag v1.0.0`
- [ ] Create GitHub release (if using JitPack)
- [ ] Verify GPG key setup (if using Maven Central)

---

## 🔍 After Publishing

### Verify on Maven Central
```bash
# Check Maven Central Repository
curl -s "https://repo1.maven.org/maven2/io/github/yourusername/android-network-package/1.0.0/" | grep .jar

# Web UI
# https://central.sonatype.com/artifact/io.github.yourusername/android-network-package
```

### Verify on JitPack
```
https://jitpack.io/#yourusername/vibe
```

### Test in Your App
```gradle
dependencies {
    implementation("io.github.yourusername:android-network-package:1.0.0")
}
```

---

## 🆘 Troubleshooting

| Issue | Solution |
|-------|----------|
| Gradle sync fails | Check syntax, run `./gradlew clean` |
| Signing error | Verify `secring.gpg` exists, check key ID |
| Auth fails | Check credentials in `gradle.properties` |
| Library not on Maven | Wait 10-30 min, check staging repo |
| Can't access Sonatype | Verify account created and approved |
| GPG key not found | Export key: `gpg --export-secret-keys -o ~/.gnupg/secring.gpg` |

---

## 📚 Useful Links

- **JitPack**: https://jitpack.io/
- **Maven Central**: https://central.sonatype.com/
- **Sonatype Portal**: https://s01.oss.sonatype.org/
- **Gradle Publishing Docs**: https://docs.gradle.org/current/userguide/publishing_gradle_module_metadata.html
- **Android Library Docs**: https://developer.android.com/studio/projects/android-library

---

## 💡 Recommended: CI/CD Automation

Use GitHub Actions to automatically publish on tag:

```yaml
name: Publish
on:
  push:
    tags:
      - 'v*.*.*'

jobs:
  publish:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          java-version: '11'
      - run: ./gradlew clean build :android_network_package:publishToSonatype
        env:
          OSSRH_USERNAME: ${{ secrets.OSSRH_USERNAME }}
          OSSRH_PASSWORD: ${{ secrets.OSSRH_PASSWORD }}
```

Just push a tag: `git push origin v1.0.0` and it publishes automatically!

---

## 🎯 Summary

| Method | Ease | Time | Best For |
|--------|------|------|----------|
| **JitPack** | ⭐⭐⭐⭐⭐ | 5 min | Quick start, small projects |
| **Maven Central** | ⭐⭐⭐ | 30 min | Professional, open source |
| **Private Repo** | ⭐⭐⭐⭐ | 20 min | Enterprise, private |

**Recommendation**: Start with JitPack → Move to Maven Central when ready for production
