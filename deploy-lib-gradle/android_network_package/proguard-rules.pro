-keep class com.vibe.network.** { *; }
-keep interface com.vibe.network.** { *; }
-keep enum com.vibe.network.** { *; }

# Keep Retrofit
-keepattributes Signature, InnerClasses, EnclosingMethod
-keep class retrofit2.** { *; }
-keep interface retrofit2.** { *; }
-keepclasseswithmembers class * {
    @retrofit2.http.* <methods>;
}

# Keep OkHttp
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
-keepnames class okhttp3.internal.publicsuffix.PublicSuffixDatabase

# Keep Kotlinx Serialization
-keepattributes RuntimeVisibleAnnotations, AnnotationDefault
-keep class kotlinx.serialization.** { *; }
-keep @kotlinx.serialization.Serializable class * { *; }
-keepclasseswithmembers class * {
    @kotlinx.serialization.* <methods>;
}

# Keep Coroutines
-keep class kotlinx.coroutines.** { *; }
-keep interface kotlinx.coroutines.** { *; }
