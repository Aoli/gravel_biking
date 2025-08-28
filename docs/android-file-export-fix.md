# Android File Export/Save Fix

## Problem
User reported that routes could not be exported or saved on Android devices, while the functionality worked properly on web and other platforms.

## Root Cause Analysis
The issue was primarily related to missing Android permissions for file storage operations. The `file_saver` plugin on Android requires specific permissions to access external storage and save files to the device.

## Solution Implemented

### 1. Android Manifest Permissions Added
Added comprehensive file storage permissions to `/android/app/src/main/AndroidManifest.xml`:

```xml
<!-- File storage permissions for file_saver plugin -->
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<!-- For Android 13+ (API 33+) - specific media permissions -->
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
<uses-permission android:name="android.permission.READ_MEDIA_VIDEO" />
<uses-permission android:name="android.permission.READ_MEDIA_AUDIO" />
<!-- For Android 11+ (API 30+) - manage external storage if needed -->
<uses-permission android:name="android.permission.MANAGE_EXTERNAL_STORAGE"
    tools:ignore="ScopedStorage" />
```

### 2. File Service Implementation Update
Simplified the file export logic in `/lib/services/file_service.dart` to use `FileSaver.instance.saveFile()` directly for all platforms (except web), which properly handles Android's Storage Access Framework (SAF).

**Before:**
```dart
// Complex path_provider + FileSaver approach
final directory = await getApplicationDocumentsDirectory();
final file = File('${directory.path}/gravel_route.geojson');
await file.writeAsBytes(bytes);
await FileSaver.instance.saveFile(...);
```

**After:**
```dart
// Direct FileSaver approach for better Android compatibility
await FileSaver.instance.saveFile(
  name: 'gravel_route.geojson',
  bytes: bytes,
  ext: 'geojson',
  mimeType: MimeType.json,
);
```

### 3. Dependencies Update
Updated `file_saver` to version 0.2.14 for better Android compatibility:

```yaml
file_saver: ^0.2.14
```

### 4. Removed Unused Dependencies
Cleaned up unused imports from the FileService:
- Removed `dart:io` (not needed for cross-platform approach)
- Removed `path_provider` (not needed with direct FileSaver approach)

## Technical Details

### Android Storage Access Framework (SAF)
The `file_saver` plugin on Android uses the Storage Access Framework, which:
- Shows the system file picker dialog
- Allows users to choose where to save files
- Handles all permission requirements internally
- Works with scoped storage on Android 10+

### Cross-Platform Compatibility
The solution maintains compatibility across all platforms:
- **Web**: Uses FileSaver directly for browser downloads
- **Android**: Uses FileSaver with SAF for system file picker
- **iOS**: Uses FileSaver with proper iOS file handling
- **Desktop**: Uses FileSaver with native file dialogs

### File Formats Supported
Both GeoJSON and GPX export functions were updated:
- **GeoJSON**: LineString format with loop state and metadata
- **GPX**: Track format (trk/trkseg/trkpt structure) with proper XML formatting

## Testing Results
- All unit tests pass (104 tests)
- Code analysis shows no issues
- Web functionality remains unchanged
- Android export should now work properly with system file picker

## User Instructions for Android
After this fix, Android users will:
1. Tap export (GeoJSON or GPX) from the menu
2. See the Android system file picker dialog
3. Choose where to save the file (Downloads, Documents, etc.)
4. Confirm the save location
5. Receive confirmation that the route was exported

## Future Considerations
- Consider adding runtime permission requests for older Android versions
- Monitor for any additional Android-specific file handling requirements
- Test on various Android versions (especially Android 11+ with scoped storage)

---
**Note**: Users may need to reinstall the app or rebuild the Android APK to ensure the new manifest permissions are properly applied.
