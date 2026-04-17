#!/bin/zsh

set -euo pipefail

if [[ $# -ne 2 ]]; then
	echo "usage: $(basename "$0") <marketing-version> <build-number>" >&2
	exit 1
fi

VERSION="$1"
BUILD_NUMBER="$2"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_FILE="$ROOT_DIR/MacBrightFace.xcodeproj/project.pbxproj"
INFO_PLIST="$ROOT_DIR/MacBrightFace/Info.plist"

[[ -f "$PROJECT_FILE" ]] || {
	echo "error: missing project file: $PROJECT_FILE" >&2
	exit 1
}

/usr/bin/perl -0pi -e 's/MARKETING_VERSION = [^;]+;/MARKETING_VERSION = '"$VERSION"';/g' "$PROJECT_FILE"
/usr/bin/perl -0pi -e 's/CURRENT_PROJECT_VERSION = [^;]+;/CURRENT_PROJECT_VERSION = '"$BUILD_NUMBER"';/g' "$PROJECT_FILE"

if [[ -f "$INFO_PLIST" ]]; then
	/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$INFO_PLIST"
	/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$INFO_PLIST"
fi

echo "Set marketing version to $VERSION and build number to $BUILD_NUMBER."
