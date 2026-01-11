# Native Plugin Setup - Fix MissingPluginException

## Current Issue

You're seeing `MissingPluginException` because the native `LlamaPlugin` is not registered. This happens because:

1. `LlamaPlugin.swift` exists but is not added to the Xcode project's build target
2. The plugin registration in `AppDelegate.swift` is commented out

## Quick Fix: Add Plugin to Xcode

### Step 1: Open Xcode

```bash
open ios/Runner.xcworkspace
```

### Step 2: Add LlamaPlugin.swift to Target

1. In Xcode's Project Navigator (left sidebar), find `LlamaPlugin.swift` under the `Runner` folder
2. Click on `LlamaPlugin.swift` to select it
3. In the **File Inspector** (right panel, first tab - looks like a document icon)
4. Under **Target Membership**, make sure **Runner** is checked ✅

### Step 3: Uncomment Plugin Registration

1. In Xcode, open `AppDelegate.swift`
2. Find the commented-out plugin registration code:
   ```swift
   // Uncomment this after adding LlamaPlugin.swift to the Xcode target:
   // if let registrar = self.registrar(forPlugin: "LlamaPlugin") {
   //   LlamaPlugin.register(with: registrar)
   // }
   ```
3. Uncomment those 3 lines

### Step 4: Rebuild

```bash
flutter clean
flutter run -d ios
```

## Alternative: Temporary Mock Implementation

If you want to test the UI without native integration, you can create a mock plugin. But note: the LLM features won't actually work until you complete the llama.cpp integration.

## What to Expect

After adding the plugin to Xcode and uncommenting the registration:

- ✅ The app will compile and run
- ✅ `MissingPluginException` will be resolved
- ⚠️ LLM features will still fail because the native llama.cpp implementation is not complete
- ⚠️ You'll need to complete the C++ integration in `llama_ios.cpp` (see `SETUP.md`)

## Current State

- ✅ Flutter UI code: Complete
- ✅ Plugin registration code: Written (needs to be uncommented)
- ✅ Plugin Swift code: Written (needs to be added to Xcode target)
- ⚠️ Native C++ integration: Placeholder code only (needs llama.cpp integration)

The app will now show helpful error messages when the native plugin isn't available, guiding users through the setup process.



