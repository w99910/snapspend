#!/bin/bash
# Script to check receipt images via ADB

echo "=== Checking Receipt Images ==="
echo ""

echo "1. Checking if images exist..."
adb shell ls -lh /storage/emulated/0/DCIM/Receipts/ 2>/dev/null || echo "   ❌ Receipts folder not found or no permission"

echo ""
echo "2. Counting images..."
IMAGE_COUNT=$(adb shell ls /storage/emulated/0/DCIM/Receipts/ 2>/dev/null | wc -l)
echo "   Found $IMAGE_COUNT files"

echo ""
echo "3. Checking media database for indexed images..."
adb shell content query --uri content://media/external/images/media --projection _data 2>/dev/null | grep -i receipts | head -5

echo ""
echo "4. Checking app permissions..."
adb shell dumpsys package com.example.snapspend 2>/dev/null | grep -A 5 "READ_EXTERNAL_STORAGE\|READ_MEDIA_IMAGES" | head -10

echo ""
echo "5. All DCIM folders..."
adb shell ls -lh /storage/emulated/0/DCIM/ 2>/dev/null

echo ""
echo "=== To trigger media rescan, run: ==="
echo "adb shell am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE -d file:///storage/emulated/0/DCIM/Receipts/"
