# Permission Fix Applied

## What I Changed

Updated `scanning_receipts_page.dart` to handle permissions better:

### Before
```dart
final PermissionState ps = await PhotoManager.requestPermissionExtend();
if (!ps.isAuth) {
  print('❌ Permission denied');
  return [];
}
```

### After
```dart
// Tries multiple permission request approaches
// Checks both isAuth and hasAccess flags
// Provides detailed logging of permission state
// Accepts either full access or limited access
```

## How to Apply the Fix

### In Your Running Terminal:

1. **Press `R` (capital R)** for Hot Restart
   - This will reload the app with new code

2. **Or Press `r`** (lowercase r) for Hot Reload  
   - Faster but may not update everything

3. **Navigate to the scanning page again**

4. **Look for new console output:**
   ```
   🔐 Requesting photo access permission...
   📋 Permission state: ...
      isAuth: true/false
      hasAccess: true/false
   ✅ Full permission granted, fetching albums...
   ```

## If Permission Dialog Appears

If a permission dialog pops up on your device:
1. **Select "Allow" or "While using the app"**
2. If given choice between "Select photos" or "All photos":
   - Choose **"All photos"** for automatic scanning
   - Or choose **"Select photos"** and pick specific receipts

## If Still Permission Denied

### Option 1: Grant Permission Manually
```bash
# Force grant permission via ADB
adb shell pm grant com.example.snapspend android.permission.READ_MEDIA_IMAGES
adb shell pm grant com.example.snapspend android.permission.READ_EXTERNAL_STORAGE

# Restart the app
adb shell am force-stop com.example.snapspend
```

Then run the app again.

### Option 2: Reinstall with Permissions
```bash
# Uninstall
flutter clean
adb uninstall com.example.snapspend

# Reinstall
flutter run

# Grant permission when prompted
```

### Option 3: Manual Settings
1. On your device: **Settings → Apps → SnapSpend**
2. Tap **Permissions**
3. Find **Photos and videos** or **Files and media**
4. Select **Allow** or **Allow all**
5. Go back to the app and try again

## Expected Output After Fix

```
🔐 Requesting photo access permission...
📋 Permission state: PermissionState(isAuth: true, hasAccess: true)
   isAuth: true
   hasAccess: true
✅ Full permission granted, fetching albums...
📱 Found 3 total albums
  Album 0: "Recent" - 100 images
  Album 1: "Receipts" - 10 images
  Album 2: "Camera" - 50 images

🔍 Strategy 1: Checking Camera/DCIM folders...
✓ Checking: "Camera"
  Contains 50 images
  Retrieved 10 assets
  ✓ Adding: /storage/emulated/0/DCIM/Camera/IMG_001.jpg
✅ Found 10 images in Camera
```

## Debug: Check Current Permission State

```bash
# Check what permissions are granted
adb shell dumpsys package com.example.snapspend | grep -A 5 "granted=true"
```

Should show:
```
android.permission.READ_MEDIA_IMAGES: granted=true
```

## Why This Fixes It

1. **More Robust**: Checks both `isAuth` and `hasAccess` flags
2. **Two Attempts**: Tries requesting permission twice if first fails
3. **Detailed Logging**: Shows exact permission state for debugging
4. **Accepts Limited Access**: Works with "Select photos" permission mode (Android 14+)

## What Happens Next

Once permission is granted:
1. App will list all albums (Recent, Camera, Receipts, etc.)
2. Find images using 3-tier strategy
3. Scan each with OCR
4. Process with Qwen 3 AI
5. Extract structured data
6. Save to SQLite database
7. Show list of processed receipts
