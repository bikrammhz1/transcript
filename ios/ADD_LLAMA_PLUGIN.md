# How to Add LlamaPlugin to Xcode Project

The `LlamaPlugin.swift` file exists but needs to be added to the Xcode project's build target so it gets compiled.

## Steps to Add LlamaPlugin to Xcode

1. **Open Xcode workspace:**
   ```bash
   open ios/Runner.xcworkspace
   ```

2. **Find LlamaPlugin.swift in Xcode:**
   - Look in the left sidebar (Project Navigator)
   - Find `Runner` folder
   - Look for `LlamaPlugin.swift`

3. **If the file is not visible:**
   - Right-click on the `Runner` folder
   - Select "Add Files to Runner..."
   - Navigate to and select `ios/Runner/LlamaPlugin.swift`
   - Make sure "Copy items if needed" is **unchecked** (file already exists)
   - Make sure "Add to targets: Runner" is **checked**
   - Click "Add"

4. **If the file is visible but not compiled:**
   - Select `LlamaPlugin.swift` in the project navigator
   - Open the **File Inspector** (right panel, first tab)
   - Under **Target Membership**, make sure **Runner** is checked ✅

5. **Add other plugin files too:**
   - `ios/Runner/llama_ios.cpp` - Add to project if not already there
   - `ios/Runner/llama-bridge.h` - Add to bridging header

6. **Configure Bridging Header:**
   - In Xcode, select the `Runner` target
   - Go to **Build Settings** tab
   - Search for "Objective-C Bridging Header"
   - Set it to: `Runner/llama-bridge.h`

7. **Update AppDelegate.swift:**
   - Uncomment the LlamaPlugin registration code in `AppDelegate.swift`:
   ```swift
   // Register LlamaPlugin before GeneratedPluginRegistrant
   if let registrar = self.registrar(forPlugin: "LlamaPlugin") {
     LlamaPlugin.register(with: registrar)
   }
   ```

8. **Clean and rebuild:**
   ```bash
   flutter clean
   flutter run -d ios
   ```

## Note

The app will currently work without LlamaPlugin (it's commented out in AppDelegate.swift). The native method calls will fail until you complete the llama.cpp integration. But the Flutter app UI will still work for testing purposes.



