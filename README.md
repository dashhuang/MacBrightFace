# MacBrightFace

MacBrightFace transforms the edges of your display into a clean, adjustable fill light for video calls, streaming, and low-light work setups. Recent versions of macOS now include Apple's built-in [Edge Light](https://support.apple.com/125934) effect for video calls, but MacBrightFace remains the better fit when you want more intensity, more control, and a result that truly benefits from HDR-capable displays.

MacBrightFace 是一个 macOS 菜单栏补光应用，通过点亮屏幕边缘来提供柔和且可控的人脸补光，适用于视频会议、直播以及低光环境下的工作场景。虽然较新的 macOS 版本已经开始提供系统自带的 [Edge Light](https://support.apple.com/125934) 视频补光效果，但如果你需要更强、更明显的补光表现，尤其是在支持 HDR 的显示器上，MacBrightFace 依然是更合适的选择。

中文完整说明请见：[docs/README.zh-CN.md](./docs/README.zh-CN.md)。

## Why Use MacBrightFace

macOS now includes Edge Light on recent releases, starting with macOS Tahoe 26.2, which makes lightweight on-device fill lighting available out of the box. MacBrightFace is aimed at a different kind of result.

- Stronger edge-based illumination than the built-in effect
- Adjustable brightness and light size
- HDR mode on compatible displays
- Multi-display overlay windows
- A dedicated menu bar control panel

If you want a subtle system effect, macOS may already be enough. If you want your display to behave more like a real fill light, MacBrightFace is where the difference becomes noticeable.

## HDR Advantage

MacBrightFace becomes much more compelling on HDR-capable displays. Instead of stopping at a mild video-call effect, it can push the display much harder and produce a brighter, more substantial fill light. The difference is most visible on displays such as Apple Studio Display and Pro Display XDR.

On standard SDR displays, the app still works, but the gap versus the built-in system effect is naturally smaller.

## Features

- Menu bar control panel for fast adjustments
- Adjustable brightness from subtle fill to high-intensity output
- Adjustable light size around the screen edges
- HDR mode on supported displays
- Multi-display support
- Overlay windows that stay out of the way of normal interaction

## Installation

### Download

Prebuilt releases are published on the [GitHub Releases](https://github.com/dashhuang/MacBrightFace/releases) page when available.

### Build from source

Requirements:

- macOS 15.2 or later
- Xcode 16.2 or later

```bash
git clone https://github.com/dashhuang/MacBrightFace.git
cd MacBrightFace
open MacBrightFace.xcodeproj
```

Then run the `MacBrightFace` scheme in Xcode.

For a command-line build:

```bash
xcodebuild -project MacBrightFace.xcodeproj -scheme MacBrightFace -configuration Release -destination 'generic/platform=macOS' CODE_SIGNING_ALLOWED=NO build
```

## Release and Distribution

Direct distribution, Developer ID signing, and notarization are documented in [docs/RELEASE.md](./docs/RELEASE.md).

## Contributing

Contributions are welcome. Start with [CONTRIBUTING.md](./CONTRIBUTING.md) for local build steps, issue reporting expectations, and pull request guidelines.

## Changelog

Recent project changes are tracked in [CHANGELOG.md](./CHANGELOG.md).

## License

MacBrightFace is released under the [MIT License](./LICENSE).
