#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_PATH="${PROJECT_PATH:-$ROOT_DIR/DisplayFill.xcodeproj}"
SCHEME="${SCHEME:-DisplayFill}"
CONFIGURATION="${CONFIGURATION:-Release}"
BUILD_DIR="${BUILD_DIR:-$ROOT_DIR/build}"
DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist}"
ARCHIVE_PATH="${ARCHIVE_PATH:-$BUILD_DIR/$SCHEME.xcarchive}"
EXPORT_DIR="${EXPORT_DIR:-$DIST_DIR/export}"
EXPORT_OPTIONS_PLIST="$BUILD_DIR/ExportOptions.plist"
SKIP_NOTARIZATION="${SKIP_NOTARIZATION:-0}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"

fail() {
	echo "error: $*" >&2
	exit 1
}

read_build_setting() {
	local key="$1"
	xcodebuild \
		-project "$PROJECT_PATH" \
		-scheme "$SCHEME" \
		-configuration "$CONFIGURATION" \
		-showBuildSettings \
		2>/dev/null \
	| awk -F ' = ' -v key="$key" '$1 ~ ("^[[:space:]]*" key "$") { print $2; exit }'
}

TEAM_ID="${TEAM_ID:-$(read_build_setting DEVELOPMENT_TEAM)}"
[[ -n "$TEAM_ID" ]] || fail "TEAM_ID is required. Export TEAM_ID or set DEVELOPMENT_TEAM in Xcode."

if [[ "$SKIP_NOTARIZATION" != "1" && -z "$NOTARY_PROFILE" ]]; then
	fail "NOTARY_PROFILE is required for public releases. Set SKIP_NOTARIZATION=1 only for local QA builds."
fi

if ! security find-identity -v -p codesigning | rg -q "Developer ID Application"; then
	fail "No 'Developer ID Application' certificate found in the login keychain."
fi

mkdir -p "$BUILD_DIR" "$DIST_DIR"
rm -rf "$ARCHIVE_PATH" "$EXPORT_DIR"

cat > "$EXPORT_OPTIONS_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key>
	<string>developer-id</string>
	<key>signingStyle</key>
	<string>automatic</string>
	<key>teamID</key>
	<string>$TEAM_ID</string>
</dict>
</plist>
EOF

echo "Archiving $SCHEME ($CONFIGURATION)..."
xcodebuild archive \
	-project "$PROJECT_PATH" \
	-scheme "$SCHEME" \
	-configuration "$CONFIGURATION" \
	-destination "generic/platform=macOS" \
	-archivePath "$ARCHIVE_PATH" \
	DEVELOPMENT_TEAM="$TEAM_ID" \
	CODE_SIGN_STYLE=Automatic \
	-allowProvisioningUpdates

echo "Exporting Developer ID app..."
xcodebuild -exportArchive \
	-archivePath "$ARCHIVE_PATH" \
	-exportPath "$EXPORT_DIR" \
	-exportOptionsPlist "$EXPORT_OPTIONS_PLIST" \
	-allowProvisioningUpdates

APP_PATH="$(find "$EXPORT_DIR" -maxdepth 1 -name '*.app' -print -quit)"
[[ -n "$APP_PATH" ]] || fail "Export finished but no .app bundle was found in $EXPORT_DIR."

echo "Verifying code signature..."
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

VERSION="$(defaults read "$APP_PATH/Contents/Info" CFBundleShortVersionString)"
BUILD_NUMBER="$(defaults read "$APP_PATH/Contents/Info" CFBundleVersion)"
ZIP_BASENAME="${SCHEME}-${VERSION}-${BUILD_NUMBER}-macOS"
ZIP_PATH="$DIST_DIR/${ZIP_BASENAME}.zip"

if [[ "$SKIP_NOTARIZATION" == "1" ]]; then
	echo "Skipping notarization by request."
	rm -f "$ZIP_PATH"
	ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"
	echo "QA artifact: $ZIP_PATH"
	exit 0
fi

NOTARY_LOG="$DIST_DIR/${ZIP_BASENAME}.notary.json"
rm -f "$ZIP_PATH" "$NOTARY_LOG"
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

echo "Submitting for notarization..."
xcrun notarytool submit "$ZIP_PATH" \
	--keychain-profile "$NOTARY_PROFILE" \
	--wait \
	--output-format json \
	> "$NOTARY_LOG"

echo "Stapling notarization ticket..."
xcrun stapler staple "$APP_PATH"
xcrun stapler validate "$APP_PATH"
spctl -a -t exec -vv "$APP_PATH"

rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

echo "Release artifact: $ZIP_PATH"
echo "Notary log: $NOTARY_LOG"
