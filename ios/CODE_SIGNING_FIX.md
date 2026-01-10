# iOS Code Signing Fix

## Quick Solution: Use iOS Simulator

The easiest way to test without dealing with code signing is to use an iOS Simulator instead of a physical device:

```bash
# List available simulators
flutter devices

# Run on a simulator (e.g., iPhone 14)
flutter run -d "iPhone 14"

# Or just run and it will use the first available simulator
flutter run -d ios
```

**iOS Simulator doesn't require code signing**, so it will work immediately!

---

## Option 2: Fix Code Signing for Physical Device

If you need to run on a physical iOS device, you need to fix the code signing:

### Step 1: Update Bundle Identifier

1. Open Xcode: `open ios/Runner.xcworkspace`
2. Select the `Runner` project in the left sidebar
3. Select the `Runner` target
4. Go to the **Signing & Capabilities** tab
5. The **Bundle Identifier** is currently set to `com.flutterLlmSummarizer`. If you need to change it:
   - `com.yourname.flutterLlmSummarizer` (replace `yourname` with your actual name/company)
   - Or use a reverse domain like `com.github.yourusername.flutterLlmSummarizer`

### Step 2: Configure Signing

1. In the same **Signing & Capabilities** tab:
2. Check **"Automatically manage signing"**
3. Select your **Team** from the dropdown (your Apple ID)
   - If you don't see your team, click "Add Account..." and sign in with your Apple ID
   - A free Apple ID works for development (you don't need a paid Apple Developer account for testing)

### Step 3: Build and Run

After configuring signing:

```bash
flutter run -d ios
```

---

## Option 3: Change Bundle Identifier in Project File

You can also change the bundle identifier directly in the project file:

1. Edit `ios/Runner.xcodeproj/project.pbxproj`
2. Find all instances of `com.yourapp.flutterLlmSummarizer`
3. Replace with your desired bundle identifier
4. Open Xcode and configure signing as described in Option 2

**Or use this command:**

```bash
# Replace with your own bundle identifier
cd ios
sed -i '' 's/com.yourapp.flutterLlmSummarizer/com.yourname.flutterLlmSummarizer/g' Runner.xcodeproj/project.pbxproj
```

Then open Xcode and configure signing.

---

## Notes

- **Free Apple ID**: You can use a free Apple ID for development on your own devices
- **Paid Apple Developer Account**: Only needed if you want to:
  - Publish to App Store
  - Test on devices you don't own
  - Use certain capabilities
- **Team ID**: The error mentions `Q8RK48ZYHF` - this might be from a previous project. You'll need to select your own team.
- **Simulator is easier**: For development and testing, iOS Simulator is the quickest option and doesn't require any signing setup.

---

## Recommended Approach

For initial development and testing:
1. **Use iOS Simulator** - no signing needed
2. Once you're ready to test on a physical device, follow Option 2 above

