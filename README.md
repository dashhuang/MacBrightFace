# DisplayFill

DisplayFill transforms the edges of your display into a clean, adjustable fill light for video calls, streaming, and low-light work setups. Compared with Apple's built-in [Edge Light](https://support.apple.com/125934), DisplayFill supports brighter HDR output, independent per-display switches and settings, adjustable directional edge-light angles, and more playful lighting effects.

[Download DisplayFill 1.0.4 for macOS](https://github.com/dashhuang/DisplayFill/releases/download/v1.0.4/DisplayFill-1.0.4-5-macOS.zip). Older builds are available on the [GitHub Releases](https://github.com/dashhuang/DisplayFill/releases) page.

DisplayFill 是一个在 Mac 上利用屏幕进行补光和打光的 App，通过点亮屏幕边缘来提供柔和且可控的人脸补光，适用于视频会议、直播以及低光环境下的工作场景。相比 macOS 系统自带的 [边缘光](https://support.apple.com/125934)，DisplayFill 支持 HDR 因而光线更亮，支持多显示器分别开关和设置，还支持可调光线角度的边缘光以及更多有趣特效。

[下载 DisplayFill 1.0.4 for macOS](https://github.com/dashhuang/DisplayFill/releases/download/v1.0.4/DisplayFill-1.0.4-5-macOS.zip)。旧版本可在 [GitHub Releases](https://github.com/dashhuang/DisplayFill/releases) 页面查看。

中文完整说明请见：[docs/README.zh-CN.md](./docs/README.zh-CN.md)。

## Why Use DisplayFill

macOS now includes Edge Light on recent releases, starting with macOS Tahoe 26.2, which makes lightweight on-device fill lighting available out of the box. DisplayFill is aimed at a different kind of result.

- Stronger edge-based illumination than the built-in effect
- Adjustable brightness and light size
- HDR mode on compatible displays
- Multi-display overlay windows
- A dedicated menu bar control panel

If you want a subtle system effect, macOS may already be enough. If you want your display to behave more like a real fill light, DisplayFill is where the difference becomes noticeable.

## HDR Advantage

DisplayFill becomes much more compelling on HDR-capable displays. Instead of stopping at a mild video-call effect, it can push the display much harder and produce a brighter, more substantial fill light. The difference is most visible on displays such as Apple Studio Display and Pro Display XDR.

On standard SDR displays, the app still works, but the gap versus the built-in system effect is naturally smaller.

## Features

- Menu bar control panel for fast adjustments
- Adjustable brightness from subtle fill to high-intensity output
- Adjustable light size around the screen edges
- HDR mode on supported displays
- Multi-display support
- Overlay windows that stay out of the way of normal interaction

## Build from source

Requirements:

- macOS 15.2 or later
- Xcode 16.2 or later

```bash
git clone https://github.com/dashhuang/DisplayFill.git
cd DisplayFill
open DisplayFill.xcodeproj
```

Then run the `DisplayFill` scheme in Xcode.

For a command-line build:

```bash
xcodebuild -project DisplayFill.xcodeproj -scheme DisplayFill -configuration Release -destination 'generic/platform=macOS' CODE_SIGNING_ALLOWED=NO build
```

## Release and Distribution

Direct distribution, Developer ID signing, and notarization are documented in [docs/RELEASE.md](./docs/RELEASE.md).

## Contributing

Contributions are welcome. Start with [CONTRIBUTING.md](./CONTRIBUTING.md) for local build steps, issue reporting expectations, and pull request guidelines.

## Changelog

Recent project changes are tracked in [CHANGELOG.md](./CHANGELOG.md).

## License

DisplayFill is released under the [MIT License](./LICENSE).
