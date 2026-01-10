# Fix: Native LLM Plugin Not Available

This error usually occurs when:
1. The build is cached and doesn't include recent changes
2. The app needs a full rebuild after native code changes

## Solution: Full Rebuild

Run these commands in your terminal:

```bash
cd /Users/bikrammaharjan/Desktop/Hugging

# Clean the build
flutter clean

# Get dependencies
flutter pub get

# Rebuild iOS (pod install is needed after clean)
cd ios
pod install
cd ..

# Run the app
flutter run -d ios
```

## If Still Not Working

### 1. Verify LlamaPlugin.swift is compiled

Open Xcode and check:
```bash
open ios/Runner.xcworkspace
```

1. In Project Navigator, find `LlamaPlugin.swift` under `Runner`
2. Select the file
3. In File Inspector (right panel), verify **Target Membership → Runner** is checked ✅

### 2. Verify MethodChannel names match

All should show: `com.flutterLlmSummarizer/llama`

- **Dart:** `lib/services/local_llm_service.dart` line 11
- **iOS:** `ios/Runner/LlamaPlugin.swift` line 22  
- **Android:** `android/app/src/main/kotlin/.../LlamaPlugin.kt` line 32

### 3. Check AppDelegate.swift

Verify LlamaPlugin registration is uncommented:

```swift
// In AppDelegate.swift
if let registrar = self.registrar(forPlugin: "LlamaPlugin") {
  LlamaPlugin.register(with: registrar)
}
```

### 4. Full Clean and Reinstall

If the above doesn't work:

```bash
cd /Users/bikrammaharjan/Desktop/Hugging

# Deep clean
flutter clean
rm -rf ios/Pods
rm -rf ios/.symlinks
rm -rf ios/Podfile.lock
rm -rf build/

# Reinstall
flutter pub get
cd ios
pod install
cd ..

# Rebuild
flutter run -d ios
```

### 5. Restart Xcode

Sometimes Xcode caches things:
1. Close Xcode completely (Cmd+Q)
2. Open again: `open ios/Runner.xcworkspace`
3. Product → Clean Build Folder (Shift+Cmd+K)
4. Build again

## Why This Happens

When you modify native Swift/Kotlin code:
- Hot reload doesn't apply native changes
- Hot restart doesn't apply native changes
- You need a full rebuild (`flutter clean && flutter run`)

Native code changes require a complete app rebuild because they're compiled separately from Dart code.

## Verification

After rebuild, check the Xcode console for:
```
Initializing llama model: [path]
```

This confirms the native plugin is being called.

