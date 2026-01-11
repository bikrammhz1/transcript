# iOS Project Setup

The iOS project structure requires generation by Flutter. If you see errors about missing `Runner.xcodeproj`, run the following command in your terminal:

```bash
cd /Users/bikrammaharjan/Desktop/Hugging
flutter create . --platforms=ios
```

This will generate the missing iOS project files including:
- `ios/Runner.xcodeproj/` - Xcode project directory
- Additional iOS configuration files

**Note**: You may need to run this command from your terminal (outside of Cursor) if you encounter permission issues.

After running `flutter create`, you can then:
1. Open the project in Xcode: `open ios/Runner.xcworkspace`
2. Or run from Flutter: `flutter run -d ios`



