#!/bin/bash
# Runs on the macOS build machine after "npx cap add ios":
# adds the native code, background audio, the app name and the icons to the generated Xcode project.
set -euo pipefail
cd "$(dirname "$0")/.."
APP=ios/App/App

# 1. native code: added to AppDelegate.swift, which is already part of the Xcode project
#    (so the project file itself needs no changes); the extra imports go to the top
AD="$APP/AppDelegate.swift"
{ printf 'import AVFoundation\nimport MediaPlayer\n'; cat "$AD"; cat native/VolnaNative.swift; } > "$AD.new"
mv "$AD.new" "$AD"

# 2. the main screen uses our view controller (it registers the plugin)
SB="$APP/Base.lproj/Main.storyboard"
grep -q 'customClass="CAPBridgeViewController"' "$SB" || { echo "Main.storyboard: CAPBridgeViewController not found"; cat "$SB"; exit 1; }
sed -i '' 's/customClass="CAPBridgeViewController" customModule="Capacitor"/customClass="VolnaViewController" customModule="App" customModuleProvider="target"/' "$SB"
grep -q 'VolnaViewController' "$SB" || { echo "Main.storyboard was not patched"; exit 1; }

# 3. Info.plist: background audio and the name under the icon
PL="$APP/Info.plist"
/usr/libexec/PlistBuddy -c "Delete :UIBackgroundModes" "$PL" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :UIBackgroundModes array" "$PL"
/usr/libexec/PlistBuddy -c "Add :UIBackgroundModes:0 string audio" "$PL"
/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName Волна" "$PL" 2>/dev/null || /usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string Волна" "$PL"
# only standard HTTPS: no export-compliance questions in App Store Connect for every build
/usr/libexec/PlistBuddy -c "Delete :ITSAppUsesNonExemptEncryption" "$PL" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :ITSAppUsesNonExemptEncryption bool false" "$PL"

# 3b. project settings: iPhone only; for signed builds the team and a build number that grows every run
PBX=ios/App/App.xcodeproj/project.pbxproj
sed -i '' 's/TARGETED_DEVICE_FAMILY = "1,2";/TARGETED_DEVICE_FAMILY = 1;/' "$PBX"
if [ -n "${BUILD_NUMBER:-}" ]; then
  sed -i '' "s/CURRENT_PROJECT_VERSION = 1;/CURRENT_PROJECT_VERSION = ${BUILD_NUMBER};/" "$PBX"
fi
if [ -n "${TEAM_ID:-}" ]; then
  sed -i '' "s/CODE_SIGN_STYLE = Automatic;/CODE_SIGN_STYLE = Automatic;\\
				DEVELOPMENT_TEAM = ${TEAM_ID};/" "$PBX"
  grep -q "DEVELOPMENT_TEAM = ${TEAM_ID};" "$PBX" || { echo "team was not set"; exit 1; }
fi

# 4. icon and launch screen: every picture in the template is replaced, resized to the size it had
fit() { # fit <source.png> <folder>
  for f in "$2"/*.png; do
    [ -e "$f" ] || continue
    w=$(sips -g pixelWidth "$f" | awk '/pixelWidth/{print $2}')
    h=$(sips -g pixelHeight "$f" | awk '/pixelHeight/{print $2}')
    sips -s format png -z "$h" "$w" "$1" --out "$f" >/dev/null
  done
}
fit native/AppIcon-1024.png "$APP/Assets.xcassets/AppIcon.appiconset"
fit native/Splash-2732.png "$APP/Assets.xcassets/Splash.imageset"

echo "iOS project patched"
