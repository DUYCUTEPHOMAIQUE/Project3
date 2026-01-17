#!/bin/bash

# Script để chạy 2 instances của Flutter app trên macOS
# Usage: ./run_two_instances.sh [method]
#   method: "macos" (default) - 2 macOS apps, "simulator" - macOS + iOS Simulator

METHOD=${1:-macos}

if [ "$METHOD" = "simulator" ]; then
    echo "🚀 Starting macOS + iOS Simulator instances..."
    echo ""
    echo "📱 Step 1: Opening iOS Simulator..."
    open -a Simulator
    
    sleep 3
    
    echo "📱 Step 2: Starting macOS app..."
    cd "$(dirname "$0")"
    flutter run -d macos &
    
    sleep 3
    
    echo "📱 Step 3: Starting iOS Simulator app..."
    flutter run -d "iPhone 15 Pro" &
    
    echo ""
    echo "✅ Both instances are running!"
    echo "💡 Instance 1: macOS (Bundle ID = com.e2ee.demoApp)"
    echo "💡 Instance 2: iOS Simulator (isolated data)"
    echo ""
    echo "💡 Tip: Login with different accounts in each instance to test chat"
    exit 0
fi

# Method: 2 macOS apps
echo "🚀 Starting 2 macOS app instances..."
echo "⚠️  Note: macOS may not allow 2 instances of the same app."
echo "💡 For better reliability, use: ./run_two_instances.sh simulator"
echo ""

# Build app trước
echo "📦 Building app..."
cd "$(dirname "$0")"
flutter build macos --debug

# Path tới app đã build
APP_PATH="build/macos/Build/Products/Debug/demo_app.app"

if [ ! -d "$APP_PATH" ]; then
    echo "❌ App not found at $APP_PATH"
    echo "Please build the app first: flutter build macos"
    exit 1
fi

# Copy app để tạo instance thứ 2
APP_PATH_2="build/macos/Build/Products/Debug/demo_app_2.app"
if [ -d "$APP_PATH_2" ]; then
    rm -rf "$APP_PATH_2"
fi
cp -r "$APP_PATH" "$APP_PATH_2"

# Sửa Bundle ID cho instance thứ 2 để isolate data
echo "🔧 Changing Bundle ID for instance 2..."
INFO_PLIST="$APP_PATH_2/Contents/Info.plist"
if [ -f "$INFO_PLIST" ]; then
    # Sửa Bundle ID từ com.e2ee.demoApp thành com.e2ee.demoApp2
    /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.e2ee.demoApp2" "$INFO_PLIST"
    echo "✅ Changed Bundle ID to com.e2ee.demoApp2"
    
    # Remove quarantine attributes để macOS cho phép chạy
    xattr -cr "$APP_PATH_2" 2>/dev/null || true
    echo "✅ Removed quarantine attributes"
else
    echo "⚠️  Warning: Info.plist not found at $INFO_PLIST, instances may share data"
fi

echo "✅ Built 2 app instances"
echo ""
echo "📱 Opening first instance..."
open "$APP_PATH"

sleep 3

echo "📱 Opening second instance..."
# Mở app thứ 2 với environment variable để đảm bảo chạy được
open "$APP_PATH_2" || {
    echo "⚠️  open command failed, trying alternative method..."
    # Thử chạy trực tiếp với nohup
    nohup "$APP_PATH_2/Contents/MacOS/demo_app" > /tmp/demo_app_2.log 2>&1 &
    sleep 2
    if ps aux | grep -i "demo_app" | grep -v grep | wc -l | grep -q "2"; then
        echo "✅ Second instance started successfully"
    else
        echo "❌ Failed to start second instance"
        echo "💡 Check logs: tail -f /tmp/demo_app_2.log"
        echo "💡 Or try manually: open '$APP_PATH_2'"
    fi
}

echo ""
sleep 2

# Kiểm tra xem có 2 instances đang chạy không
INSTANCE_COUNT=$(ps aux | grep -i "demo_app" | grep -v grep | wc -l | tr -d ' ')
if [ "$INSTANCE_COUNT" -ge 2 ]; then
    echo "✅ Both instances are running! ($INSTANCE_COUNT processes found)"
else
    echo "⚠️  Warning: Only $INSTANCE_COUNT instance(s) running"
    echo "💡 macOS may not allow 2 instances of the same app"
    echo "💡 Recommended: Use iOS Simulator instead:"
    echo "   ./run_two_instances.sh simulator"
fi

echo ""
echo "💡 Tip: Login with different accounts in each instance to test chat"
echo "💡 Instance 1: Bundle ID = com.e2ee.demoApp"
echo "💡 Instance 2: Bundle ID = com.e2ee.demoApp2 (isolated data)"
echo ""
echo "💡 If app 2 doesn't open, try:"
echo "   1. ./run_two_instances.sh simulator  (macOS + iOS Simulator)"
echo "   2. Or manually: open '$APP_PATH_2'"