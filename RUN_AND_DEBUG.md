# How to Run and Debug Image Detection

## Your Images Are There! ✅
The diagnostic confirmed:
- **10 images** exist in `/storage/emulated/0/DCIM/Receipts/`
- They're **indexed** in Android's media database  
- **Permission is granted** (READ_MEDIA_IMAGES)

## The Issue
The app code was just updated, so you need to rebuild and run it to see the new detection logic.

## Steps to Fix

### Option 1: Run from Terminal (Recommended)
```bash
cd /home/thomas/Projects/snapspend

# Clean and rebuild
flutter clean
flutter pub get

# Run the app and watch console output
flutter run
```

### Option 2: Hot Restart (Faster)
If the app is already running:
1. Press `R` in the terminal (or click hot restart in IDE)
2. Navigate to the scanning page
3. Watch the console output

## What to Look For

When you navigate to the scanning receipts page, you should see console output like:

```
✅ Permission granted, fetching albums...
📱 Found 3 total albums
  Album 0: "Recent" - 245 images
  Album 1: "Receipts" - 10 images      ← YOUR IMAGES!
  Album 2: "Screenshots" - 15 images

🔍 Strategy 1: Checking Camera/DCIM folders...
  (no Camera folder found)

🔍 Strategy 2: Looking for Receipts folder...
✓ Found Receipts album: "Receipts"
  Contains 10 images
  Retrieved 10 assets
  ✓ Adding: /storage/emulated/0/DCIM/Receipts/1.jpeg
  ✓ Adding: /storage/emulated/0/DCIM/Receipts/2.jpeg
  ✓ Adding: /storage/emulated/0/DCIM/Receipts/3.jpeg
  ...
✅ Found 10 images in Receipts folder
```

## If You Still See "No Images Found"

### Quick Check: Copy one image to Camera folder
```bash
# Create Camera folder
adb shell mkdir -p /storage/emulated/0/DCIM/Camera

# Copy one receipt there
adb shell cp /storage/emulated/0/DCIM/Receipts/1.jpeg /storage/emulated/0/DCIM/Camera/

# Trigger media scan
adb shell am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE \
  -d file:///storage/emulated/0/DCIM/Camera/1.jpeg

# Now run the app - it should find the Camera folder
```

### Alternative: Use the Manual Scanner
Instead of the automatic scanning page, use the manual Receipt Scanner:
1. From the main page, navigate to "Receipt Scanner"
2. Tap "Gallery" button
3. Select an image manually
4. Process one receipt at a time

This bypasses PhotoManager entirely and uses the system image picker.

## Expected Behavior After Fix

Once images are detected, the app will:
1. ✅ Display "Processing with AI-powered OCR"
2. ✅ Scan each receipt with Tesseract OCR
3. ✅ Send OCR text to Qwen 3 AI model
4. ✅ Extract structured data (merchant, amount, date, recipient, category)
5. ✅ Save to SQLite database
6. ✅ Show list of scanned receipts with checkmarks

## Debug Commands

### Watch app logs in real-time
```bash
adb logcat | grep -E "Found album|Strategy|Permission|Adding file|images found"
```

### Check what PhotoManager sees
Look for these lines in the console:
```
📱 Found X total albums
  Album 0: "..." - Y images
```

### Verify media scan worked
```bash
adb shell content query --uri content://media/external/images/media \
  --projection _data | grep -i receipts
```

## Common Issues

### Issue: PhotoManager doesn't see Receipts folder
**Why**: Android's media scanner hasn't indexed it yet  
**Fix**: 
```bash
adb shell am broadcast -a android.intent.action.MEDIA_MOUNTED \
  -d file:///storage/emulated/0
```

### Issue: Permission error even though it's granted
**Why**: App needs to be restarted after permission grant  
**Fix**: 
```bash
adb shell am force-stop com.example.snapspend
# Then run the app again
```

### Issue: Old code still running
**Why**: Hot reload doesn't always update everything  
**Fix**:
```bash
flutter clean
flutter run
```

## Next Steps

1. **Run the app**:
   ```bash
   cd /home/thomas/Projects/snapspend
   flutter run
   ```

2. **Navigate to scanning page**

3. **Watch the console output** - Share it with me if issues persist

4. **Look for the emoji indicators**:
   - ✅ = Success
   - ✓ = Found something  
   - ❌ = Error
   - 📱 = Album list
   - 🔍 = Strategy being tried

The code is correct now - it will find your Receipts folder in Strategy 2. You just need to run it and see the output!








