#!/bin/bash

# Quick start script for running the Llama FFI demo on Android emulator

echo "======================================"
echo "Llama FFI Demo - Android Emulator"
echo "======================================"
echo ""

# Check if Flutter is available
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter not found in PATH"
    exit 1
fi

echo "✓ Flutter found"
echo ""

# Check for running emulators
echo "Checking for Android emulators..."
DEVICES=$(flutter devices 2>&1)

if echo "$DEVICES" | grep -q "emulator"; then
    echo "✓ Android emulator detected"
    echo ""
    echo "Starting app on emulator..."
    flutter run
else
    echo "⚠️  No Android emulator detected"
    echo ""
    echo "Please start an x86_64 Android emulator first:"
    echo "  1. Open Android Studio"
    echo "  2. Go to Device Manager"
    echo "  3. Start an x86_64 emulator (not ARM)"
    echo ""
    echo "Or use command line:"
    echo "  emulator -avd <your_avd_name>"
    echo ""
    echo "Available devices:"
    echo "$DEVICES"
fi
