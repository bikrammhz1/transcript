# Bundle Identifier Information

## Current Bundle IDs

### iOS
- **Bundle Identifier:** `com.flutterLlmSummarizer`
- **MethodChannel:** `com.flutterLlmSummarizer/llama`
- **Location:** `ios/Runner.xcodeproj/project.pbxproj`

### Android
- **Package Name:** `com.yourapp.flutter_llm_summarizer`
- **Application ID:** `com.yourapp.flutter_llm_summarizer`
- **MethodChannel:** `com.flutterLlmSummarizer/llama` (updated to match iOS)
- **Location:** `android/app/build.gradle`

### MethodChannel
- **Channel Name:** `com.flutterLlmSummarizer/llama`
- **Used by:** Both iOS and Android native plugins
- **Location:** 
  - iOS: `ios/Runner/LlamaPlugin.swift`
  - Android: `android/app/src/main/kotlin/.../LlamaPlugin.kt`
  - Dart: `lib/services/local_llm_service.dart`

## Notes

- The **MethodChannel** name is separate from bundle IDs and is used for Flutter ↔ Native communication
- iOS and Android use different bundle ID formats (iOS doesn't use dots in the same way)
- The MethodChannel is consistent across platforms for easier maintenance
- Bundle IDs can be changed in Xcode (iOS) or `build.gradle` (Android) if needed

## Verification

To verify the bundle IDs are correct:

### iOS
```bash
# Check in Xcode project file
grep "PRODUCT_BUNDLE_IDENTIFIER" ios/Runner.xcodeproj/project.pbxproj

# Or open in Xcode:
# Runner target → General → Bundle Identifier
```

### Android
```bash
# Check in build.gradle
grep "applicationId" android/app/build.gradle
```

### MethodChannel
```bash
# Check all platform implementations
grep "MethodChannel" lib/services/local_llm_service.dart
grep "MethodChannel" ios/Runner/LlamaPlugin.swift
grep "MethodChannel" android/app/src/main/kotlin/.../LlamaPlugin.kt
```

All should show: `com.flutterLlmSummarizer/llama`

## Changing Bundle IDs

If you need to change bundle IDs:

### iOS
1. Open `ios/Runner.xcworkspace` in Xcode
2. Select Runner target → General tab
3. Change Bundle Identifier
4. Update code signing if needed

### Android
1. Edit `android/app/build.gradle`
2. Change `applicationId` value
3. Update package name in Kotlin files if needed

### MethodChannel (if needed)
Update in all three locations:
- `lib/services/local_llm_service.dart`
- `ios/Runner/LlamaPlugin.swift`
- `android/app/src/main/kotlin/.../LlamaPlugin.kt`


