# MacBrightFace Direct Release

This project is configured for direct macOS distribution with `Developer ID` signing and notarization. It does not cover the Mac App Store path.

## What Changed

- `Release` builds use `MacBrightFace/LightRelease.entitlements` instead of the sandbox entitlements file.
- `Release` builds enable Hardened Runtime, which Apple requires for notarized macOS apps distributed outside the Mac App Store.
- `scripts/set_version.sh` updates the app version and build number in the Xcode project.
- `scripts/release_direct.sh` archives, exports, verifies, notarizes, staples, and zips the app.

## One-Time Setup

1. Join the Apple Developer Program and install a `Developer ID Application` certificate in your login keychain.
2. Open the target in Xcode and set your signing team, or export `TEAM_ID` when running the release script.
3. Create a notary keychain profile with `notarytool`.

```bash
xcrun notarytool store-credentials "MacBrightFace-Notary" \
  --apple-id "YOUR_APPLE_ID" \
  --team-id "YOUR_TEAM_ID" \
  --password "YOUR_APP_SPECIFIC_PASSWORD"
```

For CI, you can use an App Store Connect API key instead of an Apple ID, but the script in this repo expects a saved keychain profile name.

## Release Flow

Run the commands below from the repository root.

1. Set the version you want to ship.

```bash
./scripts/set_version.sh 2.0 20
```

2. Build, export, notarize, staple, and zip the app.

```bash
TEAM_ID="YOUR_TEAM_ID" \
NOTARY_PROFILE="MacBrightFace-Notary" \
./scripts/release_direct.sh
```

3. Upload the generated zip from `dist/` to GitHub Releases, your website, or any other direct-download channel.

## Local QA Build

If you only need a signed build for local testing and want to skip notarization:

```bash
TEAM_ID="YOUR_TEAM_ID" \
SKIP_NOTARIZATION=1 \
./scripts/release_direct.sh
```

That produces a zip in `dist/`, but it is not suitable for public distribution.

## Output Files

- `build/MacBrightFace.xcarchive`
- `dist/export/MacBrightFace.app`
- `dist/MacBrightFace-<version>-<build>-macOS.zip`
- `dist/MacBrightFace-<version>-<build>-macOS.notary.json`

## Verification

The release script already runs these checks:

- `codesign --verify --deep --strict --verbose=2`
- `xcrun stapler validate`
- `spctl -a -t exec -vv`

If notarization fails, inspect the JSON log saved in `dist/`.

## Notes

- The checked-in `MacBrightFace/Info.plist` is only kept in sync for reference. The app target uses `GENERATE_INFOPLIST_FILE = YES`, so the shipping app version comes from Xcode build settings.
- If you later want in-app auto-updates for direct distribution, add Sparkle on top of this release pipeline rather than replacing it.
