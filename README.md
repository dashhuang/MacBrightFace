# MacBrightFace

## Project Overview | 项目概述
MacBrightFace is a macOS tool that provides adjustable brightness around the screen, making it especially suitable for video conferences and live streaming. This tool has been optimized for various types of displays, ensuring excellent brightness experience across different monitors, particularly delivering outstanding results on high-brightness displays supporting HDR and XDR technologies.

MacBrightFace是一款macOS工具，在屏幕周围提供可调节的亮度，特别适合视频会议和直播场景。该工具针对不同类型显示器进行了优化，确保在各种显示器上都有优秀的亮度体验，尤其是在支持HDR、XDR等高亮度显示器上效果更加出色。

## Core Features | 核心功能
- **Precise Brightness Control**: Uses a smooth brightness curve algorithm to ensure noticeable brightness changes across the entire 0-100% range.  
  **精确亮度控制**：采用平滑亮度曲线计算算法，确保在整个0-100%范围内都有明显的亮度变化

- **HDR Support**: Fully leverages HDR display capabilities, automatically detecting and adapting to displays with different HDR abilities, delivering higher brightness ranges on XDR displays.  
  **HDR支持**：充分利用HDR显示器的能力，自动检测并适应不同HDR能力的显示器，在XDR显示器上可呈现更高的亮度范围

- **Display Adaptability**: Automatically detects HDR coefficients (such as 2.0, 3.0, etc.) and optimizes brightness curves accordingly, with high-coefficient displays offering superior brightness performance.  
  **显示器自适应**：自动检测显示器HDR系数（如2.0、3.0等），并据此优化亮度曲线，高系数显示器提供更出色的亮度表现

- **Low Resource Usage**: Optimized rendering performance ensures smooth operation on various Mac devices.  
  **低资源占用**：优化渲染性能，确保在各种Mac设备上流畅运行

- **High Dynamic Range Optimization**: Specially optimized for displays with high HDR coefficients, ensuring they can fully utilize their brightness capabilities.  
  **高动态范围优化**：专门针对高HDR系数显示器进行了优化，确保在高端显示器上能充分发挥其亮度能力

- **Automatic Startup**: Automatically turns on the light when the application launches.  
  **自动开启补光**：应用启动时自动开启补光灯

- **Menu Bar Status Synchronization**: The menu bar icon correctly reflects the current status of the light.  
  **菜单栏状态同步**：菜单栏图标会正确反映补光灯的当前状态

- **Light Size Adjustment**: Provides small (80 pixels) and large (200 pixels) size options, allowing for quick switching between light sizes.  
  **补光灯尺寸调整**：提供小(80像素)和大(200像素)两种尺寸选择，方便快速切换补光灯大小

- **Seamless Menu Bar Integration**: The top edge of the light directly attaches to the bottom of the menu bar without extra gaps.  
  **无缝贴合菜单栏**：顶部补光灯边缘直接贴合菜单栏底部，无多余间隙

## Project Structure | 项目结构

### Main Files | 主要文件
- **LightApp.swift**: Application entry point, menu management, and status bar control.  
  **LightApp.swift**：应用入口点和菜单管理、状态栏控制

- **LightController.swift**: Core controller for the light, responsible for window management and brightness control.  
  **LightController.swift**：补光灯核心控制器，负责窗口管理和亮度控制

- **LightView.swift**: The actual rendering view, containing brightness calculation and visual effect logic.  
  **LightView.swift**：实际的渲染视图，包含亮度计算和视觉效果逻辑

- **BrightnessSliderView.swift**: Brightness slider control view component.  
  **BrightnessSliderView.swift**：亮度滑动控制视图组件

### Key Classes and Modules | 关键类和模块
- **AppDelegate**: Manages status bar menu, handles notifications and brightness options, responsible for synchronizing menu bar icon status.  
  **AppDelegate**：管理状态栏菜单、处理通知和亮度选项，负责菜单栏图标状态同步

- **LightController**: Manages window creation, updates, and brightness control logic, communicating with AppDelegate through notifications.  
  **LightController**：管理窗口创建、更新和亮度控制逻辑，通过通知与AppDelegate通信

- **LightView**: A brightness rendering component implemented using SwiftUI.  
  **LightView**：使用 SwiftUI 实现的亮度渲染组件

- **BrightnessSliderView**: Custom NSView that implements brightness slider adjustment functionality.  
  **BrightnessSliderView**：自定义NSView，实现亮度滑动调节功能

## Brightness Calculation Design | 亮度计算设计

The application employs an optimized brightness calculation algorithm:

应用采用了优化的亮度计算算法：

1. **HDR Mode Brightness Calculation | HDR模式亮度计算**：
   - Uses the display's actual HDR coefficient (obtained via `getMaxHDRBrightness()`).  
     使用显示器的真实HDR系数（通过`getMaxHDRBrightness()`获取）
   - Combines linear and quadratic curves for smooth brightness transitions.  
     混合线性和二次曲线实现平滑的亮度变化
   - Specially optimized for displays with high HDR coefficients to fully utilize their brightness capabilities.  
     针对高HDR系数显示器进行了特别优化，可充分发挥其高亮度能力
   - Ensures noticeable visual effects across the entire brightness range.  
     确保在整个亮度范围内都有明显的视觉效果

2. **Standard Mode Brightness Calculation | 标准模式亮度计算**：
   - Uses a similar smooth curve strategy as HDR mode, but with a more conservative maximum value (1.5).  
     使用与HDR模式类似的平滑曲线策略，但最大值更保守（1.5）
   - Ensures good brightness change experience even in standard mode.  
     确保即使在标准模式下也能有良好的亮度变化体验

## User Interface | 用户界面

### Menu Options | 菜单选项
- **Turn On/Off Light**: One-click toggle for the light status, with the menu bar icon updating accordingly.  
  **开/关补光灯**：一键切换补光灯状态，菜单栏图标会相应更新

- **Brightness Slider**: Provides continuous slider control, allowing real-time preview of brightness changes.  
  **滑动调节亮度**：提供连续滑动控制，可实时预览亮度变化

- **HDR Mode Toggle**: Provides HDR mode switch on devices that support HDR.  
  **HDR 模式切换**：在支持 HDR 的设备上提供 HDR 模式开关

- **Light Size Adjustment**: Offers small (80 pixels) and large (200 pixels) size options.  
  **补光灯尺寸调整**：提供小(80像素)和大(200像素)两种尺寸选择

## Technologies Used | 使用技术
- **SwiftUI**: For user interface.  
  **SwiftUI**：用户界面

- **AppKit**: For system integration.  
  **AppKit**：系统集成

- **Metal**: For efficient rendering through drawingGroup().  
  **Metal**：通过 drawingGroup() 进行高效渲染

- **NotificationCenter**: For component communication.  
  **NotificationCenter**：组件间通信