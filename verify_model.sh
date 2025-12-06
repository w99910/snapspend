#!/bin/bash

# Verification script for Qwen3 model setup

MODEL_FILE="Qwen3-0.6B-Q4_K_M.gguf"
TMP_PATH="/data/local/tmp/$MODEL_FILE"

echo "======================================"
echo "Qwen3 Model Verification"
echo "======================================"
echo ""

# Check if adb is available
if ! command -v adb &> /dev/null; then
    echo "❌ adb not found in PATH"
    echo "   Install Android SDK Platform Tools"
    exit 1
fi

echo "✓ adb found"
echo ""

# Check if device is connected
echo "Checking for connected devices..."
DEVICES=$(adb devices | grep -v "List" | grep "device$" | wc -l)

if [ "$DEVICES" -eq 0 ]; then
    echo "❌ No Android device/emulator connected"
    echo ""
    echo "Start an emulator or connect a device first:"
    echo "  flutter devices"
    exit 1
fi

echo "✓ Device connected"
echo ""

# Check if model exists in /data/local/tmp
echo "Checking for model in /data/local/tmp..."
if adb shell "[ -f $TMP_PATH ] && echo exists" | grep -q "exists"; then
    echo "✓ Model found at $TMP_PATH"
    echo ""
    
    # Get file size
    echo "Model details:"
    adb shell ls -lh "$TMP_PATH" | awk '{print "  Size: " $5}'
    
    # Check permissions
    PERMS=$(adb shell ls -l "$TMP_PATH" | awk '{print $1}')
    echo "  Permissions: $PERMS"
    
    # Check if readable
    if adb shell "[ -r $TMP_PATH ] && echo readable" | grep -q "readable"; then
        echo "  ✓ File is readable"
    else
        echo "  ⚠️  File may not be readable by app"
        echo ""
        echo "Fix with:"
        echo "  adb shell chmod 666 $TMP_PATH"
    fi
    
    echo ""
    echo "✅ All checks passed!"
    echo ""
    echo "You can now run:"
    echo "  flutter run"
    echo ""
    echo "The app will copy the model from /data/local/tmp"
    echo "instead of downloading it!"
    
else
    echo "❌ Model not found at $TMP_PATH"
    echo ""
    echo "To place the model, run:"
    echo "  adb push $MODEL_FILE /data/local/tmp/"
    echo "  adb shell chmod 666 $TMP_PATH"
    echo ""
    echo "Or the app will download it automatically from Hugging Face."
    exit 1
fi
