#!/bin/sh
# Archives Health Push and uploads it to App Store Connect for TestFlight.
# Uses the Apple ID signed into Xcode (Settings → Accounts); the build number is the current UTC time.
set -eu

cd "$(dirname "$0")"
build=$(date -u +%Y%m%d%H%M)
work=${TMPDIR:-/tmp}/healthpush-$build
team=$(sed -n 's/.*DEVELOPMENT_TEAM = \(.*\);/\1/p' HealthPush.xcodeproj/project.pbxproj | head -1)

cat > "$work.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key><string>app-store-connect</string>
	<key>destination</key><string>upload</string>
	<key>teamID</key><string>$team</string>
	<key>signingStyle</key><string>automatic</string>
	<key>manageAppVersionAndBuildNumber</key><false/>
</dict>
</plist>
EOF

xcodebuild -project HealthPush.xcodeproj -scheme HealthPush -configuration Release \
  -destination 'generic/platform=iOS' -archivePath "$work.xcarchive" \
  -allowProvisioningUpdates CURRENT_PROJECT_VERSION="$build" archive

xcodebuild -exportArchive -archivePath "$work.xcarchive" -exportOptionsPlist "$work.plist" \
  -exportPath "$work" -allowProvisioningUpdates

echo "Uploaded build $build. It appears in TestFlight once App Store Connect has processed it."
