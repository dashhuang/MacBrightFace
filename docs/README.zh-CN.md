# MacBrightFace

MacBrightFace 是一个 macOS 菜单栏补光应用，通过点亮屏幕边缘来提供柔和且可控的人脸补光，适用于视频会议、直播以及低光环境下的工作场景。

虽然较新的 macOS 版本已经开始提供系统自带的 [Edge Light](https://support.apple.com/125934) 视频补光效果，而且 Apple 官方说明它从 `macOS Tahoe 26.2` 开始提供，但 MacBrightFace 依然有明确的使用价值，尤其是在支持 HDR 的显示器上，它可以提供更强、更明显、也更依赖显示器亮度能力的补光效果。

## 为什么还要用 MacBrightFace

系统自带的 Edge Light 很方便，但它更偏向轻量、默认、开箱即用的补光效果。MacBrightFace 面向的是另一类需求：

- 更强的屏幕边缘补光效果
- 可调节的亮度与补光尺寸
- 在支持的显示器上启用 HDR 模式
- 支持多显示器
- 独立的菜单栏控制面板

如果你只需要一个轻量的系统补光效果，macOS 现在已经能满足一部分场景。  
如果你希望屏幕更像一盏真正的补光灯，MacBrightFace 的优势会更明显。

## HDR 优势

MacBrightFace 在支持 HDR 的显示器上表现最好。它不只是提供轻微的人脸提亮，而是可以更充分地利用显示器的亮度空间，做出更强、更厚实的补光效果。

这种差异在以下设备上尤其明显：

- Apple Studio Display
- Pro Display XDR
- 其他支持 HDR 的高亮度显示器

在普通 SDR 显示器上，MacBrightFace 依然可用，但和系统自带效果之间的差距会更小。

## 功能特性

- 菜单栏控制面板
- 可调节亮度
- 可调节补光尺寸
- 支持 HDR 模式
- 支持多显示器
- 不影响正常鼠标交互的屏幕覆盖窗口

## 安装方式

### 下载发行版

预编译版本会在 [GitHub Releases](https://github.com/dashhuang/MacBrightFace/releases) 页面发布。

### 从源码构建

要求：

- macOS 15.2 或更高版本
- Xcode 16.2 或更高版本

```bash
git clone https://github.com/dashhuang/MacBrightFace.git
cd MacBrightFace
open MacBrightFace.xcodeproj
```

然后在 Xcode 中运行 `MacBrightFace` scheme。

命令行构建：

```bash
xcodebuild -project MacBrightFace.xcodeproj -scheme MacBrightFace -configuration Release -destination 'generic/platform=macOS' CODE_SIGNING_ALLOWED=NO build
```

## 发布说明

如果你需要站外分发、Developer ID 签名和 notarization，请查看 [docs/RELEASE.md](./RELEASE.md)。

## 贡献

欢迎提交 Issue 和 Pull Request。开始之前请先阅读 [CONTRIBUTING.md](../CONTRIBUTING.md)。

## 更新记录

最近的项目变更记录见 [CHANGELOG.md](../CHANGELOG.md)。

## 许可证

本项目基于 [MIT License](../LICENSE) 开源。
