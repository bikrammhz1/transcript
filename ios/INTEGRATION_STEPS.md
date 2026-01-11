# Step-by-Step: llama.cpp iOS Integration

This guide walks through adding llama.cpp to your Xcode project after building the library.

## Prerequisites

✅ You've run `ios/build_llama.sh` to build the library
✅ You have `libllama.a` in `ios/llama.cpp/` directory
✅ You have `llama.h` in `ios/llama.cpp/` directory

## Step 1: Build llama.cpp Library

First, build the library using the provided script:

```bash
cd /Users/bikrammaharjan/Desktop/Hugging
./ios/build_llama.sh
```

This will:
- Clone llama.cpp if needed (to `~/Documents/llama.cpp`)
- Build the library for iOS with Metal support
- Copy headers and library to `ios/llama.cpp/`

**Expected output:**
- `ios/llama.cpp/libllama.a` (static library)
- `ios/llama.cpp/llama.h` (header file)

## Step 2: Open Xcode Workspace

```bash
open ios/Runner.xcworkspace
```

**Important:** Use `.xcworkspace`, not `.xcodeproj` (for CocoaPods support)

## Step 3: Add llama.cpp Directory to Xcode

1. **In Xcode Project Navigator:**
   - Right-click on the `Runner` folder (top level)
   - Select **"Add Files to Runner..."**

2. **Navigate and Select:**
   - Navigate to `ios/llama.cpp` directory
   - **IMPORTANT:** Select the `llama.cpp` folder itself, not individual files
   - In the dialog:
     - ✅ **"Create groups"** (not folder references)
     - ✅ **"Copy items if needed"** (checked)
     - ✅ **"Add to targets: Runner"** (checked)
   - Click **"Add"**

3. **Verify:**
   - You should see `llama.cpp` group in Project Navigator
   - It should contain `llama.h` and `libllama.a`

## Step 4: Link the Library

1. **Select `Runner` target** in Project Navigator (left sidebar, top)
2. **Go to "Build Phases" tab** (top of main editor)
3. **Expand "Link Binary With Libraries"**
4. **Click the "+" button**
5. **Add `libllama.a`:**
   - Click "Add Other..." → "Add Files..."
   - Navigate to `ios/llama.cpp/libllama.a`
   - Select it and click "Add"
   - **OR** find it in the list and add it directly

6. **Verify:**
   - `libllama.a` should appear in "Link Binary With Libraries"

## Step 5: Configure Header Search Paths

1. **Still in "Build Settings" tab** (next to "Build Phases")
2. **Search for "Header Search Paths"**
3. **Double-click the value** (should show "Debug" and "Release")
4. **Click "+" to add new path**
5. **Add:** `$(PROJECT_DIR)/llama.cpp`
   - Or: `$(SRCROOT)/llama.cpp`
6. **Make sure it's set to "recursive"** (folder icon with "r")
7. **Click "Done"**

## Step 6: Configure Library Search Paths

1. **In "Build Settings" tab**
2. **Search for "Library Search Paths"**
3. **Add:** `$(PROJECT_DIR)/llama.cpp`
   - Or: `$(SRCROOT)/llama.cpp`
4. **Make sure it's recursive** (folder icon with "r")

## Step 7: Set C++ Language Standard

1. **In "Build Settings" tab**
2. **Search for "C++ Language Dialect"**
3. **Set to:** `C++17` or `C++20`
   - For both Debug and Release

4. **Search for "C++ Standard Library"**
5. **Set to:** `libc++` (should be default)

## Step 8: Enable Objective-C++

1. **In "Build Settings" tab**
2. **Search for "Objective-C++ Compiler - Language"**
3. **Set to:** `Objective-C++` (if not already)

## Step 9: Verify llama_ios.cpp is in Build

1. **Go to "Build Phases" tab**
2. **Expand "Compile Sources"**
3. **Verify `llama_ios.cpp` is in the list**
   - If not, click "+" and add `Runner/llama_ios.cpp`

## Step 10: Verify Bridging Header

1. **In "Build Settings" tab**
2. **Search for "Objective-C Bridging Header"**
3. **Should show:** `Runner/Runner-Bridging-Header.h` or similar
4. **Verify `Runner-Bridging-Header.h` includes:**
   ```objc
   #import "llama-bridge.h"
   ```

## Step 11: Add Metal Framework (for GPU acceleration)

1. **Go to "Build Phases" tab**
2. **Expand "Link Binary With Libraries"**
3. **Click "+"**
4. **Search for "Metal.framework"**
5. **Add it**

## Step 12: Build and Test

1. **Clean build folder:**
   - Product → Clean Build Folder (Shift+Cmd+K)

2. **Try building:**
   - Product → Build (Cmd+B)

3. **Check for errors:**
   - Common issues:
     - **"Undefined symbols"** → Library not linked properly
     - **"llama.h not found"** → Header search path incorrect
     - **"Metal functions not found"** → Metal framework not added

4. **Run from Flutter:**
   ```bash
   flutter clean
   flutter run -d ios
   ```

## Verification Checklist

After configuration, verify:

- [ ] `ios/llama.cpp/libllama.a` exists
- [ ] `ios/llama.cpp/llama.h` exists
- [ ] `llama.cpp` folder is in Xcode project
- [ ] `libllama.a` is in "Link Binary With Libraries"
- [ ] Header Search Paths includes `$(PROJECT_DIR)/llama.cpp` (recursive)
- [ ] Library Search Paths includes `$(PROJECT_DIR)/llama.cpp`
- [ ] C++ Language Dialect is C++17 or C++20
- [ ] `Metal.framework` is linked
- [ ] `llama_ios.cpp` compiles without errors
- [ ] App runs and model initializes successfully

## Troubleshooting

### "Undefined symbols for architecture arm64"

**Cause:** Library not properly linked or wrong architecture.

**Fix:**
1. Verify `libllama.a` is in "Link Binary With Libraries"
2. Verify Library Search Paths is set correctly
3. Rebuild llama.cpp for correct architecture (arm64)

### "llama.h file not found"

**Cause:** Header search path incorrect.

**Fix:**
1. Verify `llama.h` exists in `ios/llama.cpp/`
2. Verify Header Search Paths includes `$(PROJECT_DIR)/llama.cpp` (recursive)
3. Clean build folder and rebuild

### "Metal functions not available"

**Cause:** Metal framework not linked or llama.cpp not built with Metal.

**Fix:**
1. Add `Metal.framework` to "Link Binary With Libraries"
2. Rebuild llama.cpp with `-DGGML_METAL=ON`

### Build succeeds but initModel returns null

**Cause:** Model file path incorrect or model file corrupted.

**Fix:**
1. Verify model file exists at path
2. Check logs for model loading errors
3. Verify model file is valid GGUF format

## Next Steps

Once integration is complete:

1. ✅ Model should initialize successfully
2. ✅ `generate()` should produce text
3. ✅ `releaseModel()` should free memory
4. ✅ Check logs for Metal GPU usage

## Performance Tuning

For SmolLM-135M-Q4 (~105MB):

- **Threads:** 2-4 (more doesn't help small models)
- **Context size:** 2048 tokens (sufficient for summaries)
- **Metal acceleration:** Enabled by default (uses GPU)
- **Expected speed:** 2-10 tokens/second on iPhone
- **Memory:** ~200-400MB total (model + context)

Optimization tips:
- Use Q4_K_M quantization (good balance)
- Keep context size reasonable (2048 is enough)
- Let Metal handle GPU offloading automatically


