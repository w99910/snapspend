#!/bin/bash
echo "🚀 Starting SnapSpend App Test"
echo ""
echo "Step 1: Cleaning build..."
cd /home/thomas/Projects/snapspend
flutter clean > /dev/null 2>&1

echo "Step 2: Getting dependencies..."
flutter pub get > /dev/null 2>&1

echo "Step 3: Starting app (this will take a moment)..."
echo ""
echo "⏳ Please wait for the app to launch on your device..."
echo "📱 Then navigate to the scanning receipts page"
echo "👀 Watch this console for output showing:"
echo "   - Album detection"
echo "   - Image found messages"
echo ""
echo "════════════════════════════════════════"
echo "APP OUTPUT:"
echo "════════════════════════════════════════"

flutter run 2>&1 | grep --line-buffered -E "Found album|Strategy|Permission|Adding file|images|Album [0-9]|Checking|Contains"
