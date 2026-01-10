# Setup Guide for llama.cpp Integration

This guide will help you complete the native llama.cpp integration for both Android and iOS.

## Prerequisites

1. **llama.cpp source code**: Clone the repository
   ```bash
   git clone https://github.com/ggerganov/llama.cpp.git
   cd llama.cpp
   ```

2. **Android NDK**: Install via Android Studio SDK Manager (r25c recommended)
3. **CMake**: Install via Android Studio SDK Manager (3.18+)
4. **Xcode**: Latest version for iOS development

## Android Setup

### Step 1: Build llama.cpp for Android

```bash
# Navigate to llama.cpp directory
cd llama.cpp

# Set NDK path (adjust to your installation)
export ANDROID_NDK=/path/to/android-ndk

# Create build directory
mkdir build-android && cd build-android

# Configure CMake
cmake -DCMAKE_TOOLCHAIN_FILE=$ANDROID_NDK/build/cmake/android.toolchain.cmake \
      -DANDROID_ABI=arm64-v8a \
      -DANDROID_PLATFORM=android-24 \
      -DCMAKE_BUILD_TYPE=Release \
      -DBUILD_SHARED_LIBS=ON \
      ..

# Build
make -j$(nproc)

# Verify library was created
ls -lh libllama.so
```

### Step 2: Copy Library to Flutter Project

```bash
# Create jniLibs directory if it doesn't exist
mkdir -p flutter_llm_summarizer/android/app/src/main/jniLibs/arm64-v8a

# Copy library
cp libllama.so flutter_llm_summarizer/android/app/src/main/jniLibs/arm64-v8a/
```

### Step 3: Update CMakeLists.txt

Edit `android/app/src/main/cpp/CMakeLists.txt`:

```cmake
# Add path to llama.cpp
set(LLAMA_CPP_DIR "/path/to/llama.cpp")
set(LLAMA_BUILD_DIR "${LLAMA_CPP_DIR}/build-android")

# Include llama.cpp headers
include_directories(${LLAMA_CPP_DIR})
include_directories(${LLAMA_BUILD_DIR})

# Link against compiled library
target_link_libraries(llama
    ${log-lib}
    ${android-lib}
    ${LLAMA_BUILD_DIR}/libllama.so
)
```

### Step 4: Update llama_android.cpp

Replace the placeholder code with actual llama.cpp API calls:

1. **Include headers**:
   ```cpp
   #include "llama.h"
   #include "common.h"
   ```

2. **Implement `initLlama`**:
   ```cpp
   llama_model_params model_params = llama_model_default_params();
   llama_model *model = llama_load_model_from_file(path, model_params);
   
   llama_context_params ctx_params = llama_context_default_params();
   ctx_params.n_ctx = contextSize;
   ctx_params.n_threads = threads;
   ctx_params.n_threads_batch = threads;
   
   llama_context *ctx = llama_new_context_with_model(model, ctx_params);
   ```

3. **Implement `generate`**:
   ```cpp
   // Tokenize prompt
   std::vector<llama_token> tokens = llama_tokenize(model, promptStr, true);
   
   // Decode tokens
   llama_decode(ctx, llama_batch_get_one(tokens.data(), tokens.size(), n_past, 0));
   
   // Generate loop
   for (int i = 0; i < maxTokens; i++) {
       llama_token new_token = llama_sample_token(...);
       // Decode and append to generated string
   }
   ```

4. **Implement `releaseLlama`**:
   ```cpp
   llama_free(ctx);
   llama_free_model(model);
   ```

### Step 5: Verify Build

```bash
cd flutter_llm_summarizer
flutter clean
flutter pub get
flutter build apk --debug
```

## iOS Setup

### Step 1: Build llama.cpp for iOS

```bash
# Navigate to llama.cpp directory
cd llama.cpp

# Create build directory
mkdir build-ios && cd build-ios

# Configure CMake for iOS
cmake -G Xcode \
      -DCMAKE_SYSTEM_NAME=iOS \
      -DCMAKE_OSX_ARCHITECTURES=arm64 \
      -DCMAKE_BUILD_TYPE=Release \
      -DBUILD_SHARED_LIBS=ON \
      ..

# Build with Xcode
xcodebuild -project llama.cpp.xcodeproj \
           -scheme llama \
           -configuration Release \
           -sdk iphoneos \
           ARCHS=arm64 \
           ONLY_ACTIVE_ARCH=NO
```

### Step 2: Add llama.cpp to Xcode Project

1. Open `ios/Runner.xcworkspace` in Xcode
2. Right-click on `Runner` → `Add Files to "Runner"...`
3. Select the `llama.cpp` directory
4. Choose "Create groups" (not folder references)
5. Make sure to add:
   - `llama.cpp/llama.h`
   - `llama.cpp/llama.cpp`
   - All other necessary source files

### Step 3: Configure Xcode Build Settings

1. Select `Runner` target
2. Go to `Build Settings`
3. Search for "C++ Language Dialect"
4. Set to "C++17" or "C++20"
5. Search for "C++ Standard Library"
6. Set to "libc++"

### Step 4: Update Bridging Header

Edit `ios/Runner/llama-bridge.h` to include llama.cpp headers:

```objc
#ifndef llama_bridge_h
#define llama_bridge_h

#import <Foundation/Foundation.h>

// Include llama.cpp headers
#import "llama.h"

#ifdef __cplusplus
extern "C" {
#endif

// Function declarations...
// (keep existing declarations)

#ifdef __cplusplus
}
#endif

#endif
```

### Step 5: Update llama_ios.cpp

Replace placeholder code with actual llama.cpp API calls (similar to Android implementation).

### Step 6: Configure Podfile (if needed)

If you prefer using CocoaPods, add to `ios/Podfile`:

```ruby
target 'Runner' do
  # ... existing code ...
  
  pod 'llama.cpp', :path => '../llama.cpp'
end
```

Then run:
```bash
cd ios
pod install
```

### Step 7: Verify Build

```bash
cd flutter_llm_summarizer
flutter clean
flutter pub get
flutter build ios --debug
```

## Testing Native Integration

### Android Test

1. Run app: `flutter run`
2. Check logs: `adb logcat | grep LlamaAndroid`
3. Look for "Model initialized successfully" message

### iOS Test

1. Run app: `flutter run -d ios`
2. Check Xcode console for initialization logs
3. Look for successful model loading

## Common Issues

### "Undefined symbols" (iOS)

- **Solution**: Ensure all llama.cpp source files are added to Xcode project
- Check that bridging header includes `llama.h`
- Verify C++ standard is set to C++17 or higher

### "Library not found" (Android)

- **Solution**: Verify `libllama.so` is in correct location
- Check CMakeLists.txt has correct library path
- Ensure ABI matches (arm64-v8a)

### "MethodChannel not found"

- **Solution**: Verify plugin registration in MainActivity.kt (Android) or AppDelegate.swift (iOS)
- Check channel name matches: `com.flutterLlmSummarizer/llama`

### Model loading fails

- **Solution**: Verify model file path is correct
- Check file permissions
- Ensure model file is GGUF format
- Verify model file integrity (download again if needed)

## Next Steps

1. Complete the llama.cpp API integration in both platforms
2. Test with a small model first (SmolLM-135M)
3. Optimize thread count for your target devices
4. Add error handling for edge cases
5. Test on physical devices (emulators may have issues)

## Resources

- [llama.cpp GitHub](https://github.com/ggerganov/llama.cpp)
- [llama.cpp API Documentation](https://github.com/ggerganov/llama.cpp/blob/master/llama.h)
- [Android NDK CMake Guide](https://developer.android.com/ndk/guides/cmake)
- [iOS C++ Integration](https://developer.apple.com/documentation/swift/imported_c_and_objective-c_apis)

