# Publishing Methods Comparison

## Method Comparison

| Aspect | JitPack | Maven Central | Private (Nexus) |
|--------|---------|---------------|-----------------|
| **Setup Time** | 5 minutes | 30 minutes | 20 minutes |
| **Account Setup** | None (GitHub) | Sonatype account | Your company |
| **Cost** | Free | Free | Varies |
| **Discoverability** | Good | Excellent | Internal only |
| **Best For** | Quick start, learning | Production releases | Enterprise apps |
| **Build System** | Auto-builds | Manual | Manual |
| **Release Speed** | Immediate | 10-30 minutes | Immediate |
| **GPG Signing** | Optional | Required | Often required |
| **Complexity** | Very Low | Medium | Medium |
| **Support** | Community | Official | Team support |

---

## Decision Tree

```
Choose your publishing method:

Do you want immediate publishing?
├─ YES → Use JitPack
│   └─ Just push to GitHub, create tag, done!
│
└─ NO (want professional setup?)
    ├─ Open source project?
    │   └─ Use Maven Central
    │       ├─ Create Sonatype account
    │       ├─ Setup GPG signing
    │       └─ Publish via Gradle
    │
    └─ Enterprise/Private?
        └─ Use Private Repository (Nexus/Artifactory)
            ├─ Configure company Nexus
            ├─ Setup credentials
            └─ Publish to internal server
```

---

## Installation Time Estimates

### JitPack
- Push to GitHub: 2 min
- Create release: 1 min
- Add to project: 2 min
- **Total: 5 minutes**

### Maven Central
- Create Sonatype account: 5 min (approval takes 1-2 days)
- Generate GPG key: 5 min
- Configure Gradle: 10 min
- Publish: 2 min
- Verify: 5 min
- **Total: 30 minutes + 1-2 days for approval**

### Private Repository
- Nexus setup (if needed): varies
- Configure credentials: 5 min
- Configure Gradle: 5 min
- Publish: 2 min
- Verify: 3 min
- **Total: 20 minutes + existing Nexus**

---

## Step-by-Step Workflows

### JitPack Workflow
```
1. git tag v1.0.0
   ↓
2. git push origin v1.0.0
   ↓
3. Create GitHub Release
   ↓
4. Use: implementation("com.github.user:repo:v1.0.0")
   ↓
5. Done! JitPack auto-builds
```

### Maven Central Workflow
```
1. Create Sonatype account
   ↓
2. Generate GPG key
   ↓
3. Configure gradle.properties
   ↓
4. Update build.gradle.kts
   ↓
5. ./gradlew publishReleasePublicationToSonatypeRepository
   ↓
6. Release from staging repository
   ↓
7. Wait 10-30 min for sync
   ↓
8. Use: implementation("io.github.user:package:1.0.0")
```

### Private Repository Workflow
```
1. Configure Nexus URL
   ↓
2. Add credentials
   ↓
3. Update build.gradle.kts
   ↓
4. ./gradlew publish
   ↓
5. Use: implementation("com.company:package:1.0.0")
```

---

## Configuration Templates

### JitPack (Minimal Config)
```gradle
// No special config needed!
// Just push to GitHub and create a release tag
```

### Maven Central (Full Config)
```gradle
plugins {
    id("maven-publish")
    id("signing")
}

group = "io.github.yourusername"
version = "1.0.0"

publishing {
    publications {
        register<MavenPublication>("release") {
            from(components["release"])
            groupId = "io.github.yourusername"
            artifactId = "package-name"
            // ... pom, licenses, developers, scm ...
        }
    }
    repositories {
        maven {
            url = uri("https://s01.oss.sonatype.org/service/local/staging/deploy/maven2/")
            credentials { username = ...; password = ... }
        }
    }
}

signing {
    useGpgCmd()
    sign(publishing.publications["release"])
}
```

### Private Repository (Basic Config)
```gradle
publishing {
    repositories {
        maven {
            url = uri("https://nexus.company.com/repository/android/")
            credentials {
                username = findProperty("nexusUser")
                password = findProperty("nexusPassword")
            }
        }
    }
}
```

---

## Publish Commands Quick Reference

### JitPack
```bash
git tag v1.0.0
git push origin v1.0.0
# Then access: https://jitpack.io/#user/repo
```

### Maven Central
```bash
./gradlew clean \
  :android_network_package:build \
  :android_network_package:publishReleasePublicationToSonatypeRepository \
  publishToSonatype \
  closeAndReleaseSonatypeStagingRepository
```

### Private Repository
```bash
./gradlew :android_network_package:publish
```

### Local Testing (All Methods)
```bash
./gradlew :android_network_package:publishToMavenLocal
```

---

## Verification Steps

### JitPack Verification
```
1. Go to: https://jitpack.io/#user/repo
2. Watch build log
3. Click "Release" version when ready
```

### Maven Central Verification
```
1. Check: https://s01.oss.sonatype.org (Login)
2. Find staging repo
3. Click "Release"
4. After 10-30 min check: https://central.sonatype.com/artifact/...
5. Or use: curl https://repo1.maven.org/maven2/io/github/...
```

### Private Repository Verification
```
1. Log into your Nexus
2. Find artifact in repository
3. Verify can download
```

---

## Common Issues & Solutions

### "No credentials found"
**Solution:** Check `~/.gradle/gradle.properties` or set environment variables
```bash
export OSSRH_USERNAME="username"
export OSSRH_PASSWORD="password"
export GPG_PASSPHRASE="passphrase"
```

### "GPG key not found"
**Solution:** Re-export GPG key
```bash
gpg --export-secret-keys > ~/.gnupg/secring.gpg
```

### "Library not in Maven Central after 1 hour"
**Solution:** 
- Check if staging repo was released
- Check for validation errors in staging repo
- Verify all required POM fields are present

### "JitPack build failing"
**Solution:**
- Check build log at jitpack.io
- Ensure `build.gradle.kts` is valid
- Verify all dependencies are available

### "Can't connect to Sonatype"
**Solution:**
- Verify network connectivity
- Check Sonatype status page
- Use VPN if needed (company firewall)

---

## Publishing Checklist

### Before Publishing
- [ ] Version updated in `build.gradle.kts`
- [ ] README.md updated
- [ ] CHANGELOG.md created/updated
- [ ] Tests pass: `./gradlew test`
- [ ] No lint errors: `./gradlew lint`
- [ ] All files committed to git

### JitPack Specific
- [ ] GitHub repository public
- [ ] License file present
- [ ] build.gradle.kts valid

### Maven Central Specific
- [ ] Sonatype account created and approved
- [ ] GPG key generated and exported
- [ ] `gradle.properties` configured
- [ ] POM metadata complete
- [ ] Source and Javadoc jars configured

### Private Repository Specific
- [ ] Nexus URL configured
- [ ] Credentials verified
- [ ] Repository access granted

---

## Version Numbering Strategy

### Semantic Versioning
```
MAJOR.MINOR.PATCH

Breaking Changes → Increment MAJOR (e.g., 1.0.0 → 2.0.0)
New Features → Increment MINOR (e.g., 1.0.0 → 1.1.0)
Bug Fixes → Increment PATCH (e.g., 1.0.0 → 1.0.1)
```

### Example Progression
```
0.1.0           First alpha
0.5.0           Stable alpha
1.0.0           First release
1.1.0           New feature
1.1.1           Bug fix
1.2.0           More features
2.0.0           Major refactor (breaking changes)
2.0.1           Bug fix
2.1.0           New feature
```

### Special Versions (Don't publish these)
```
1.0.0-SNAPSHOT  Development version
1.0.0-alpha01   Alpha release
1.0.0-beta01    Beta release
1.0.0-rc01      Release candidate
```

---

## File Structure for Publishing

```
android_network_package/
├── build.gradle.kts              ✓ Configured for publishing
├── src/main/
│   └── kotlin/com/vibe/network/  ✓ Your source code
├── LICENSE                       ✓ License file
├── proguard-rules.pro           ✓ ProGuard configuration
├── consumer-rules.pro           ✓ Consumer ProGuard
└── README.md                    ✓ Documentation
```

---

## Summary

**Recommended Flow:**

1. **Start with JitPack** (Learn the process - 5 min)
2. **Verify it works** (Use in test project)
3. **Move to Maven Central** (Professional - 30 min setup + 1-2 days approval)
4. **Maintain versions** (Follow semantic versioning)
5. **Automate with CI/CD** (Use GitHub Actions)

**All tools and files are ready in your workspace!**

See `BUILD_AND_PUBLISH.md` for detailed step-by-step instructions.
