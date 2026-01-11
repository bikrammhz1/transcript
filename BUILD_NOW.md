# 🚀 Build llama.cpp NOW - Step by Step

Your code is ready! You just need to build the llama.cpp library and configure Xcode. This will take **15-30 minutes**.

## Step 1: Build llama.cpp Library (10-20 min)

Run the build script:

```bash
cd /Users/bikrammaharjan/Desktop/Hugging
./ios/build_llama.sh
```

**What this does:**
- Clones llama.cpp to `~/Documents/llama.cpp` (if needed)
- Builds `libllama.a` for iOS with Metal support
- Copies files to `ios/llama.cpp/`

**Expected output:**
```
✅ Build successful!
   Library location: .../libllama.a
✅ Headers copied to: ios/llama.cpp/
✅ Library copied to: ios/llama.cpp/libllama.a
```

**If it fails:**
- Make sure you have Xcode Command Line Tools: `xcode-select --install`
- Make sure CMake is installed: `brew install cmake`

## Step 2: Configure Xcode (10 min)

### 2.1 Open Xcode Workspace

```bash
open ios/Runner.xcworkspace
```

⚠️ **Important:** Use `.xcworkspace`, NOT `.xcodeproj`

### 2.2 Add llama.cpp to Project

1. In Xcode Project Navigator (left sidebar):
   - Right-click on **`Runner`** (top folder)
   - Select **"Add Files to Runner..."**

2. Navigate to `ios/llama.cpp` folder and **select the folder itself**

3. In the dialog:
   - ✅ **"Create groups"** (selected)
   - ✅ **"Copy items if needed"** (checked)
   - ✅ **"Add to targets: Runner"** (checked)
   - Click **"Add"**

4. Verify:
   - You should see `llama.cpp` group in Project Navigator
   - It contains `llama.h` and `libllama.a`

### 2.3 Link the Library

1. Select **`Runner`** target (in Project Navigator, top)
2. Go to **"Build Phases"** tab
3. Expand **"Link Binary With Libraries"**
4. Click **"+"** button
5. Click **"Add Other..."** → **"Add Files..."**
6. Navigate to `ios/llama.cpp/libllama.a` and add it
7. Verify `libllama.a` appears in the list

### 2.4 Set Header Search Paths

1. Stay in **"Build Settings"** tab (next to "Build Phases")
2. Search for **"Header Search Paths"**
3. Double-click the value
4. Click **"+"** to add new path
5. Add: **`$(PROJECT_DIR)/llama.cpp`**
6. Make sure it's marked as **"recursive"** (folder icon with "r")
7. Click **"Done"**

### 2.5 Add Metal Framework

1. Go back to **"Build Phases"** tab
2. Expand **"Link Binary With Libraries"**
3. Click **"+"**
4. Search for **"Metal.framework"**
5. Add it

### 2.6 Verify C++ Settings

1. In **"Build Settings"** tab
2. Search for **"C++ Language Dialect"**
3. Should be **"C++17"** or **"C++20"** (if not, set it)

## Step 3: Build and Test (2 min)

### 3.1 Clean Build

In Xcode:
- **Product → Clean Build Folder** (Shift+Cmd+K)

Or from terminal:
```bash
cd /Users/bikrammaharjan/Desktop/Hugging
flutter clean
```

### 3.2 Build

In Xcode:
- **Product → Build** (Cmd+B)

Or from terminal:
```bash
flutter run -d ios
```

### 3.3 Check for Errors

**If you see "llama.h not found":**
- Header Search Paths is wrong
- Check it's set to `$(PROJECT_DIR)/llama.cpp` (recursive)

**If you see "Undefined symbols":**
- Library not linked
- Check `libllama.a` is in "Link Binary With Libraries"

**If build succeeds:**
- ✅ You're done! Try running the app

## Step 4: Verify It Works

Run the app:
```bash
flutter run -d ios
```

**Look for these logs:**
```
✅ [llama_ios.cpp] SUCCESS: Model initialized
✅ [LlamaPlugin] SUCCESS: Model initialized
```

**If you see:**
```
❌ [llama_ios.cpp] FAILED: llama.cpp not integrated yet!
```
→ Go back to Step 2 and verify all Xcode settings

## Quick Checklist

- [ ] Build script ran successfully
- [ ] `ios/llama.cpp/libllama.a` exists
- [ ] `ios/llama.cpp/llama.h` exists
- [ ] llama.cpp folder added to Xcode project
- [ ] `libllama.a` linked in Build Phases
- [ ] Header Search Paths set to `$(PROJECT_DIR)/llama.cpp` (recursive)
- [ ] Metal.framework added
- [ ] Build succeeds
- [ ] App runs and model initializes

## Need Help?

- **Detailed guide:** `ios/INTEGRATION_STEPS.md`
- **Quick reference:** `ios/QUICK_INTEGRATION.md`
- **Architecture:** See `ios/COMPLETE_INTEGRATION.md`

---

**Time estimate:** 15-30 minutes total
**Difficulty:** Medium (mostly following steps)

Once you complete these steps, your app will be able to run on-device LLM inference! 🎉



