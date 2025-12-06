#!/bin/bash
# Script to push test receipt images to Android emulator gallery

RECEIPTS_DIR="/home/thomas/Downloads/receipts"
EMULATOR_DIR="/sdcard/DCIM/Receipts"

echo "📱 Pushing test receipts to Android emulator..."

# Check if adb is available
if ! command -v adb &> /dev/null; then
    echo "❌ Error: adb not found. Make sure Android SDK is installed."
    exit 1
fi

# Check if emulator is running
if ! adb devices | grep -q "emulator"; then
    echo "❌ Error: No emulator detected. Please start the emulator first."
    exit 1
fi

# Create directory on emulator
echo "📁 Creating directory on emulator..."
adb shell mkdir -p "$EMULATOR_DIR"

# Push all receipt images
echo "📤 Pushing receipt images..."
count=0
for file in "$RECEIPTS_DIR"/*.jpeg "$RECEIPTS_DIR"/*.jpg "$RECEIPTS_DIR"/*.png; do
    if [ -f "$file" ]; then
        filename=$(basename "$file")
        echo "  → Pushing $filename"
        adb push "$file" "$EMULATOR_DIR/"
        ((count++))
    fi
done

# Trigger media scan for each file
echo "🔄 Triggering media scan..."
for file in "$RECEIPTS_DIR"/*.jpeg "$RECEIPTS_DIR"/*.jpg "$RECEIPTS_DIR"/*.png; do
    if [ -f "$file" ]; then
        filename=$(basename "$file")
        adb shell am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE \
            -d "file://$EMULATOR_DIR/$filename" > /dev/null 2>&1
    fi
done

# Also trigger a full media scan
adb shell am broadcast -a android.intent.action.MEDIA_MOUNTED \
    -d "file:///sdcard" > /dev/null 2>&1

echo "✅ Done! Pushed $count receipt images to emulator."
echo "📸 Check the Gallery app - they should be in the 'Receipts' folder."
echo ""
echo "Location on emulator: $EMULATOR_DIR"
