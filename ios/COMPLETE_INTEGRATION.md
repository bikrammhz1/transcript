# Complete llama.cpp Integration Guide for iOS

This guide will walk you through completing the native llama.cpp integration step by step.

## Prerequisites

- Xcode installed (latest version recommended)
- CMake installed (`brew install cmake` or via Xcode Command Line Tools)
- Git installed
- Terminal access

## Step 1: Build llama.cpp for iOS

### 1.1 Clone llama.cpp Repository

```bash
# Navigate to your desired location (e.g., Documents or Desktop)
cd ~/Documents

# Clone llama.cpp
git clone https://github.com/ggerganov/llama.cpp.git
cd llama.cpp

# Checkout a stable version (optional, recommended)
git checkout master
```

### 1.2 Build for iOS (ARM64)

```bash
# Create build directory
mkdir build-ios && cd build-ios

# Configure CMake for iOS
cmake -G Xcode \
      -DCMAKE_SYSTEM_NAME=iOS \
      -DCMAKE_OSX_ARCHITECTURES=arm64 \
      -DCMAKE_OSX_DEPLOYMENT_TARGET=13.0 \
      -DCMAKE_BUILD_TYPE=Release \
      -DBUILD_SHARED_LIBS=ON \
      -DGGML_METAL=ON \
      ..

# Build the library
xcodebuild -project llama.cpp.xcodeproj \
           -scheme llama \
           -configuration Release \
           -sdk iphoneos \
           ARCHS=arm64 \
           ONLY_ACTIVE_ARCH=NO \
           -derivedDataPath ./build
```

**Note:** The build will take 5-15 minutes depending on your machine.

### 1.3 Verify Build Output

After building, you should find:
- `build/Build/Products/Release-iphoneos/libllama.a` (static library)
- Or `build/Build/Products/Release-iphoneos/libllama.dylib` (dynamic library)

## Step 2: Add llama.cpp to Xcode Project

### 2.1 Copy llama.cpp Files

```bash
# Create a llama.cpp directory in your Flutter project
mkdir -p /Users/bikrammaharjan/Desktop/Hugging/ios/llama.cpp

# Copy the header files you'll need
cp ~/Documents/llama.cpp/llama.h /Users/bikrammaharjan/Desktop/Hugging/ios/llama.cpp/
cp ~/Documents/llama.cpp/common.h /Users/bikrammaharjan/Desktop/Hugging/ios/llama.cpp/
```

### 2.2 Add llama.cpp to Xcode Project

1. **Open Xcode:**
   ```bash
   open /Users/bikrammaharjan/Desktop/Hugging/ios/Runner.xcworkspace
   ```

2. **Add llama.cpp Files:**
   - Right-click on the `Runner` folder in Project Navigator
   - Select "Add Files to Runner..."
   - Navigate to and select the `llama.cpp` directory you created
   - **IMPORTANT:** Make sure:
     - "Copy items if needed" is **CHECKED** ✅
     - "Create groups" is selected
     - "Add to targets: Runner" is **CHECKED** ✅
   - Click "Add"

3. **Link the Compiled Library:**
   - Select the `Runner` target in the project navigator
   - Go to **Build Phases** tab
   - Expand **Link Binary With Libraries**
   - Click the **+** button
   - Click "Add Other..." → "Add Files..."
   - Navigate to `~/Documents/llama.cpp/build-ios/build/Build/Products/Release-iphoneos/`
   - Select `libllama.a` or `libllama.dylib`
   - Click "Add"

### 2.3 Configure Build Settings

1. **Select Runner Target** → **Build Settings** tab
2. **Set Header Search Paths:**
   - Search for "Header Search Paths"
   - Add: `$(PROJECT_DIR)/llama.cpp` (recursive)
   - Or: `$(SRCROOT)/llama.cpp` (recursive)

3. **Set Library Search Paths:**
   - Search for "Library Search Paths"
   - Add the path to your compiled library:
     - `$(HOME)/Documents/llama.cpp/build-ios/build/Build/Products/Release-iphoneos`
   - Or copy the library to your project and reference it relatively

4. **Enable C++17:**
   - Search for "C++ Language Dialect"
   - Set to: **C++17** or **C++20**

5. **Enable Objective-C++:**
   - Search for "Objective-C++ Compiler - Language"
   - Set to: **Objective-C++**

## Step 3: Update llama_ios.cpp

Now update the implementation file with actual llama.cpp API calls.

### 3.1 Update Includes

Edit `ios/Runner/llama_ios.cpp` and replace the placeholder includes:

```cpp
#include "llama.h"
#include "common.h"
#include <string>
#include <vector>
#include <Foundation/Foundation.h>
```

### 3.2 Update initLlama() Function

Replace the placeholder `initLlama()` implementation with:

```cpp
void* initLlama(const char* modelPath, int threads, int contextSize) {
    if (!modelPath) {
        NSLog(@"ERROR: Model path is null");
        return nullptr;
    }
    
    NSLog(@"Initializing llama model: %s", modelPath);
    NSLog(@"Threads: %d, Context size: %d", threads, contextSize);
    
    // Load model
    llama_model_params model_params = llama_model_default_params();
    llama_model *model = llama_load_model_from_file(modelPath, model_params);
    
    if (!model) {
        NSLog(@"ERROR: Failed to load model from %s", modelPath);
        return nullptr;
    }
    
    // Create context
    llama_context_params ctx_params = llama_context_default_params();
    ctx_params.n_ctx = contextSize;
    ctx_params.n_threads = threads;
    ctx_params.n_threads_batch = threads;
    
    llama_context *ctx = llama_new_context_with_model(model, ctx_params);
    
    if (!ctx) {
        NSLog(@"ERROR: Failed to create context");
        llama_free_model(model);
        return nullptr;
    }
    
    // Store state
    llama_state_t *state = new llama_state_t();
    state->model = model;
    state->context = ctx;
    
    NSLog(@"Model initialized successfully");
    return state;
}
```

### 3.3 Update generate() Function

Replace the placeholder `generate()` implementation with:

```cpp
const char* generate(void* ctx, const char* prompt, int maxTokens, float temperature) {
    if (!ctx || !prompt) {
        NSLog(@"ERROR: Invalid context or prompt");
        return nullptr;
    }
    
    llama_state_t *state = static_cast<llama_state_t*>(ctx);
    llama_context *llama_ctx = static_cast<llama_context*>(state->context);
    llama_model *model = static_cast<llama_model*>(state->model);
    
    NSLog(@"Generating text with maxTokens=%d, temperature=%.2f", maxTokens, temperature);
    
    // Tokenize prompt
    std::vector<llama_token> tokens;
    tokens = llama_tokenize(model, prompt, true);
    
    if (tokens.empty()) {
        NSLog(@"ERROR: Failed to tokenize prompt");
        return nullptr;
    }
    
    // Add tokens to context
    int n_past = 0;
    llama_batch batch = llama_batch_init(512, 1);
    
    for (size_t i = 0; i < tokens.size(); i++) {
        llama_batch_add(batch, tokens[i], n_past, {0}, false);
        n_past++;
    }
    
    if (llama_decode(llama_ctx, batch)) {
        NSLog(@"ERROR: Failed to decode prompt");
        llama_batch_free(batch);
        return nullptr;
    }
    
    llama_batch_free(batch);
    
    // Generate tokens
    std::string generated;
    for (int i = 0; i < maxTokens; i++) {
        // Sample token
        llama_token new_token_id = llama_sample_token(
            llama_ctx,
            nullptr, // grammar (optional)
            {
                .n_ctx = 512,
                .top_k = 40,
                .top_p = 0.9f,
                .temp = temperature,
                .repeat_penalty = 1.1f,
            },
            tokens.data() + tokens.size() - 1,
            1,
            1
        );
        
        if (new_token_id == llama_token_eos(model)) {
            break;
        }
        
        // Decode token to string
        char token_str[32];
        int n = llama_token_to_piece(model, new_token_id, token_str, sizeof(token_str));
        if (n > 0) {
            generated += std::string(token_str, n);
        }
        
        // Add token to context and decode
        batch = llama_batch_init(512, 1);
        llama_batch_add(batch, new_token_id, n_past, {0}, true);
        if (llama_decode(llama_ctx, batch)) {
            llama_batch_free(batch);
            break;
        }
        llama_batch_free(batch);
        n_past++;
    }
    
    // Clean up ChatML tags if present
    std::string result = generated;
    size_t start_pos = result.find("<|im_start|>assistant");
    if (start_pos != std::string::npos) {
        result = result.substr(start_pos);
        start_pos = result.find("\n") + 1;
        if (start_pos < result.length()) {
            result = result.substr(start_pos);
        }
    }
    size_t end_pos = result.find("<|im_end|>");
    if (end_pos != std::string::npos) {
        result = result.substr(0, end_pos);
    }
    
    // Allocate C string (caller must free)
    char* cstr = new char[result.length() + 1];
    strcpy(cstr, result.c_str());
    
    NSLog(@"Generated %zu characters", result.length());
    return cstr;
}
```

### 3.4 Update releaseLlama() Function

Replace the placeholder `releaseLlama()` implementation with:

```cpp
void releaseLlama(void* ctx) {
    if (!ctx) {
        NSLog(@"ERROR: Invalid context pointer for release");
        return;
    }
    
    NSLog(@"Releasing llama model");
    
    llama_state_t *state = static_cast<llama_state_t*>(ctx);
    
    if (state->context) {
        llama_free(static_cast<llama_context*>(state->context));
    }
    if (state->model) {
        llama_free_model(static_cast<llama_model*>(state->model));
    }
    
    delete state;
    NSLog(@"Model released successfully");
}
```

## Step 4: Clean and Rebuild

```bash
cd /Users/bikrammaharjan/Desktop/Hugging
flutter clean
flutter pub get
flutter run -d ios
```

## Troubleshooting

### "llama.h not found"
- Verify header search paths are set correctly in Xcode
- Ensure llama.cpp files were added to the project
- Check that include paths use `$(PROJECT_DIR)` or `$(SRCROOT)`

### "Undefined symbols for architecture arm64"
- Verify the library is built for arm64
- Check library search paths in Xcode
- Ensure the library is linked in Build Phases

### "Failed to load model"
- Verify the model file path is correct
- Check that the model file exists at the specified path
- Ensure the model is in GGUF format

### Build takes too long
- Use Release configuration for faster builds
- Consider building just the library once and reusing it
- Use Metal acceleration if available (already enabled with `-DGGML_METAL=ON`)

## Verification

After completing the integration:

1. **Build succeeds** - No linker errors
2. **App launches** - Runs on device/simulator
3. **Model initializes** - No INIT_FAILED errors
4. **Generation works** - Can generate summaries

## Next Steps

Once integration is complete:
- Test with SmolLM-135M model (smallest, fastest)
- Verify summarization works correctly
- Test different summary types
- Optimize performance if needed

## Resources

- llama.cpp GitHub: https://github.com/ggerganov/llama.cpp
- llama.cpp API Docs: Check `llama.h` header file
- Your setup docs: `SETUP.md` and `README.md`

Good luck with the integration! 🚀



