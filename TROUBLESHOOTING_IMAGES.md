# Troubleshooting: Images Not Found

## Issue
App reports "No images found" even though images exist in `/storage/emulated/0/DCIM/Receipts/`

## Recent Fixes Applied

### 1. Enhanced Debugging ✅
Added comprehensive logging to `scanning_receipts_page.dart`:
- Lists all albums found by PhotoManager
- Shows image count for each album
- Uses 3-tier strategy to find images
- Detailed error messages with emojis for easy identification

### 2. Android Manifest Update ✅
Added `android:requestLegacyExternalStorage="true"` to handle Android 10+ scoped storage.

### 3. Fixed Progress Bar Crash ✅
Fixed division by zero error in `LinearProgressIndicator`.

## Check These Steps

### Step 1: Check Console Logs
When you run the app and reach the scanning page, check the console for output like:

```
✅ Permission granted, fetching albums...
📱 Found 5 total albums
  Album 0: "Recent" - 245 images
  Album 1: "Camera" - 120 images
  Album 2: "Receipts" - 8 images
  Album 3: "Screenshots" - 15 images
  Album 4: "Downloads" - 3 images

🔍 Strategy 1: Looking for Receipts folder...
✓ Found Receipts album: "Receipts"
  Contains 8 images
  Retrieved 8 assets
  ✓ Adding: /storage/emulated/0/DCIM/Receipts/receipt1.jpg
  ✓ Adding: /storage/emulated/0/DCIM/Receipts/receipt2.jpg
✅ Found 8 receipts in Receipts folder
```

### Step 2: Verify Permissions
Make sure the app has been granted storage permissions:
1. Open Android Settings → Apps → SnapSpend → Permissions
2. Verify these are enabled:
   - **Camera** (required)
   - **Photos and videos** or **Storage** (required)
   - **Files and media** (on Android 13+)

### Step 3: Trigger Media Rescan (Android 10+)
Sometimes Android doesn't immediately index new images. Try:

**Method 1: Using ADB**
```bash
adb shell am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE \
  -d file:///storage/emulated/0/DCIM/Receipts/
```

**Method 2: Using a File Manager App**
1. Install "Files by Google" or similar file manager
2. Navigate to `/DCIM/Receipts/`
3. The file manager will trigger a media scan

**Method 3: Reboot Device**
```bash
adb reboot
```

### Step 4: Verify Images Are Valid
Check that your images are:
- Valid JPEG/PNG files (not corrupted)
- Have proper file extensions (.jpg, .jpeg, .png)
- Have correct file permissions (readable)

**Using ADB:**
```bash
# List files in Receipts folder
adb shell ls -la /storage/emulated/0/DCIM/Receipts/

# Check file type
adb shell file /storage/emulated/0/DCIM/Receipts/receipt1.jpg
```

### Step 5: Check PhotoManager Package
Ensure photo_manager is properly configured:

```bash
cd /home/thomas/Projects/snapspend
flutter pub get
flutter clean
flutter pub get
```

### Step 6: Rebuild the App
```bash
cd /home/thomas/Projects/snapspend
flutter clean
flutter build apk --debug
# Or for running directly:
flutter run
```

## Common Issues & Solutions

### Issue 1: Permission Denied
**Symptoms:** Console shows "❌ Permission denied"

**Solution:**
1. Uninstall the app completely
2. Reinstall and grant all permissions when prompted
3. Or grant manually in Settings

### Issue 2: Images Not Indexed
**Symptoms:** 
- Console shows albums but 0 images in Receipts folder
- OR doesn't find Receipts album at all

**Solution:**
```bash
# Force media scan
adb shell am broadcast -a android.intent.action.MEDIA_MOUNTED \
  -d file:///storage/emulated/0
```

### Issue 3: Scoped Storage (Android 11+)
**Symptoms:** App can't access DCIM folders

**Solution:**
- Already added `requestLegacyExternalStorage="true"` in AndroidManifest
- For Android 11+, this is limited. May need to use MediaStore API instead

### Issue 4: Wrong Album Name
**Symptoms:** PhotoManager finds albums but not "Receipts"

**Solution:** Check what album names are actually found in console logs. The folder might be:
- Listed as "Camera" (if it's the default camera folder)
- Listed as "DCIM"
- Part of "Recent" or "All Photos"
- Has a different name like "Receipt" (without 's')

The code now checks for multiple variations:
```dart
if (albumName.contains('receipts') || albumName.contains('receipt'))
```

## Alternative: Use Recent Photos

If the Receipts folder isn't being detected, the app will automatically fall back to:
1. Camera/DCIM folders
2. First available album with images (usually "Recent")

This is handled by the 3-tier strategy in the code.

## Debug Commands

### Check if images exist via ADB
```bash
# List images
adb shell ls -l /storage/emulated/0/DCIM/Receipts/

# Count images
adb shell ls /storage/emulated/0/DCIM/Receipts/ | wc -l

# Check media database
adb shell content query --uri content://media/external/images/media \
  --projection _data | grep -i receipts
```

### Check app permissions via ADB
```bash
adb shell dumpsys package com.example.snapspend | grep permission
```

### View app logs
```bash
adb logcat | grep -E "Found album|Strategy|Adding file|Permission"
```

## Testing Checklist

- [ ] Run the app and navigate to scanning page
- [ ] Check console logs for album list
- [ ] Verify permissions are granted
- [ ] Confirm images exist in the folder
- [ ] Try media rescan if needed
- [ ] Test with images in Camera folder as fallback
- [ ] Rebuild app after manifest changes

## If Still Not Working

### Temporary Workaround: Use Camera/Gallery Picker
Instead of automatic scanning, use the manual Receipt Scanner page:
1. Navigate to "Receipt Scanner" from the main page
2. Use "Camera" button to take new photos
3. Or use "Gallery" button to pick existing images one by one

This bypasses the PhotoManager album detection entirely.

### Ultimate Solution: Direct File Access
If PhotoManager continues to have issues, we can implement a file picker that:
1. Lets user select a folder
2. Directly reads files from that path
3. Bypasses the media store entirely

This requires adding the `file_picker` package:
```yaml
dependencies:
  file_picker: ^8.0.0
```

## Next Steps After Fixing

Once images are found successfully, the app will:
1. ✅ Perform OCR on each receipt
2. ✅ Send OCR text to Qwen 3 AI model
3. ✅ Extract structured JSON data
4. ✅ Save to SQLite database
5. ✅ Display in receipts list

## Contact
If none of these solutions work, please provide:
1. Full console output from the scanning page
2. Output of `adb shell ls -l /storage/emulated/0/DCIM/Receipts/`
3. Android version
4. Device model








