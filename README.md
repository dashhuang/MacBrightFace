# MacBrightFace应用

## 项目概述
MacBrightFace是一款macOS工具，在屏幕周围提供可调节的亮度，特别适合视频会议和直播场景。该工具最近进行了重要优化，显著改善了在不同类型显示器上的亮度体验，尤其是Studio Display等HDR系数较低的显示器。

## 核心功能
- **精确亮度控制**：新版本采用分段式亮度计算算法，确保在整个0-100%范围内都有明显的亮度变化
- **HDR支持**：充分利用HDR显示器的能力，自动检测并适应不同HDR能力的显示器
- **显示器自适应**：自动检测显示器HDR系数（如2.0、3.0等），并据此优化亮度曲线
- **低资源占用**：优化渲染性能，确保在各种Mac设备上流畅运行
- **Studio Display优化**：专门针对HDR系数为2.0的显示器（如Studio Display）进行了优化，确保即使在HDR模式下也有明显的亮度变化
- **自动开启补光**：应用启动时自动开启补光灯
- **菜单栏状态同步**：菜单栏图标会正确反映补光灯的当前状态
- **补光灯尺寸调整**：提供小(80像素)和大(200像素)两种尺寸选择，方便快速切换补光灯大小
- **全屏补光模式**：提供全屏补光模式，让整个屏幕都成为补光灯
- **无缝贴合菜单栏**：顶部补光灯边缘直接贴合菜单栏底部，无多余间隙

## 更新指南
> **重要提示：** 每次更新代码前，请先阅读此README.md文件，了解项目架构和已有功能。每次更新代码后，务必同步更新此README.md文件，记录新增功能、修复的问题和架构变更。这将有助于维护代码质量和方便后续开发。

## 项目结构

### 主要文件
- **LIghtApp.swift**：应用入口点和菜单管理、状态栏控制
- **LightController.swift**：补光灯核心控制器，负责窗口管理和亮度控制
- **LightView.swift**：实际的渲染视图，包含亮度计算和视觉效果逻辑
- **BrightnessSliderView.swift**：亮度滑动控制视图组件

### 关键类和模块
- **AppDelegate**：管理状态栏菜单、处理通知和亮度选项，负责菜单栏图标状态同步
- **LightController**：管理窗口创建、更新和亮度控制逻辑，通过通知与AppDelegate通信
- **LightView**：使用 SwiftUI 实现的亮度渲染组件
- **BrightnessSliderView**：自定义NSView，实现亮度滑动调节功能

### 关键交互流程
1. 应用启动时，`AppDelegate`初始化`LightController`
2. `LightController`初始化完成后，发送`ToggleLightNotification`通知
3. `AppDelegate`接收通知，调用`toggleLight()`方法开启补光灯
4. `toggleLight()`方法更新菜单栏图标状态，并调用`LightController`的相应方法

## 亮度计算核心设计

应用采用了多级亮度计算算法，针对不同亮度范围使用不同的计算方式：

1. **HDR模式亮度计算**：
   - 使用显示器的真实HDR系数（通过`getMaxHDRBrightness()`获取）
   - 对于HDR系数为2.0的显示器（如Studio Display），将最大亮度安全限制在2.0-2.5之间
   - 使用平滑的S形曲线确保亮度变化更加均匀
   - 将0-100%的滑块范围映射到更合理的亮度值范围

2. **标准模式亮度计算**：
   - 采用与HDR模式类似的分段策略，但最大值更保守（1.8）
   - 确保即使在标准模式下也能有良好的亮度变化体验

3. **自适应亮度限制**：
   - 会自动检测显示器的HDR能力
   - 对于高HDR系数显示器（3.0以上）使用更宽的亮度范围
   - 对于低HDR系数显示器（如2.0）使用更窄的亮度范围，确保所有值都有视觉差异

## 已知问题与解决方案

### 已解决问题
1. **高亮度同质化问题**：HDR模式下亮度看起来都一样，通过自适应亮度上限和优化分段曲线解决
2. **日志重复问题**：通过时间间隔和变化阈值限制，减少重复日志
3. **不同显示器支持**：增加显示器亮度自适应功能，解决Studio Display等低亮度显示器上的差异问题
4. **菜单简化**：移除预设亮度选项，专注于滑动控制，提供更精确的亮度调节
5. **菜单栏图标状态不同步**：修复菜单栏图标状态不同步问题，确保菜单栏图标正确反映补光灯开关状态
6. **窗口层级和菜单栏间隙**：优化窗口层级设置，移除顶部补光灯与菜单栏之间的间隙

### 当前限制
1. 亮度值使用保守上限，确保所有显示器都能正常渲染
2. 在某些多显示器配置下可能需要手动调整窗口位置
3. 在某些特殊情况下可能需要手动重启应用以确保状态同步

## 用户界面

### 菜单选项
- **开/关补光灯**：一键切换补光灯状态，菜单栏图标会相应更新
- **滑动调节亮度**：提供连续滑动控制，可实时预览亮度变化
- **HDR 模式切换**：在支持 HDR 的设备上提供 HDR 模式开关
- **补光灯尺寸调整**：提供小(80像素)、大(200像素)和全屏三种模式选择

## 修改历史

### 版本 1.0
- 初始功能实现

### 版本 1.1
- 优化亮度计算，解决高亮度区域差异不明显问题
- 减少日志重复输出

### 版本 1.2
- 修复 90% 和 100% 亮度导致黑屏问题
- 限制亮度计算最大值
- 增加亮度安全保护机制

### 版本 1.3
- 添加滑动亮度控制功能，提供连续精细调节
- 显著增强60%以上亮度区间的差异
- 增加HDR模式切换菜单选项

### 版本 1.4
- 移除预设亮度选项，专注于滑动控制
- 大幅降低HDR模式亮度上限，确保各亮度级别有明显区别
- 优化亮度曲线，使所有亮度级别变化更加均匀
- 调整滑动器范围，提供更精细的亮度控制
- 针对10%以上亮度区域实现更均匀的亮度分布

### 版本 1.5
- 增加显示器亮度自适应功能，根据实际显示器能力调整亮度曲线
- 为Studio Display等亮度较低的显示器优化亮度计算
- 大幅降低HDR模式亮度上限（从20.0降至8.0）
- 细分低亮度区间（0-20%），确保每5%有明显区别
- 更新亮度曲线分段点，提高各亮度区间的差异度

### 版本 1.6
- 完全重新设计了亮度计算逻辑，特别针对HDR系数为2.0的显示器进行了优化
- 在HDR模式下，将最大安全亮度设为与显示器HDR系数匹配的值，确保所有亮度级别都有明显差异
- 添加了更详细的亮度计算日志，帮助调试和监控
- 优化了标准模式下的亮度计算，使其与HDR模式协调一致

### 版本 1.7
- 增强了显示器信息检测功能，现在可在日志中显示显示器名称和型号
- 添加了显示器分辨率和尺寸信息的检测和记录
- 进一步优化了针对Studio Display的亮度计算
- 改进了日志输出格式，更易于诊断显示器兼容性问题

### 版本 1.8
- 大幅优化了日志输出，减少重复信息，使调试更清晰
- 添加了日志缓存机制，避免短时间内重复输出相同的显示器信息
- 实现了基于显示器ID的日志过滤，每个显示器只输出一次详细信息
- 优化了窗口创建过程的日志，减少冗余信息
- 添加了时间间隔控制，确保关键日志不会被频繁输出

### 版本 1.9
- 修复了边缘窗口在角落处重叠导致的亮度不均匀问题
- 添加了专门的四角窗口，确保屏幕所有边缘都有均匀的光照效果
- 为角落窗口单独调整了亮度，使其与边缘窗口亮度平衡，避免角落过亮
- 优化了窗口更新逻辑，确保亮度调整和HDR模式切换时保持一致的渲染效果

### 版本 2.0
- 大幅简化了窗口布局设计，回归到4个窗口的解决方案
- 优化了窗口尺寸计算，通过巧妙调整左右窗口高度而非上下窗口宽度，完全避免了窗口之间的重叠
- 彻底解决了角落区域亮度不均匀的问题，使整个屏幕边缘光照效果更加一致
- 提高了渲染性能，减少了窗口管理的复杂度和系统资源占用
- 改进了窗口布局逻辑，确保每个边缘只会被一个窗口覆盖，避免任何光照叠加
- 添加了详细的窗口布局调试日志，便于验证窗口位置和尺寸是否正确

### 版本 2.1
- 修复了菜单栏图标状态不同步问题，现在图标状态将正确反映补光灯的开关状态
- 重构了启动时自动开启补光灯的逻辑，使用通知中心进行通信
- 增加了对通知的监听，确保AppDelegate能够正确响应LightController的状态变化
- 将边框宽度从20像素增加到40像素，提供更明显的补光效果
- 移除了顶部补光灯与菜单栏之间的额外间距，使补光灯直接贴合菜单栏底部
- 移除了调试信息显示，使界面更加简洁
- 优化了代码结构，修复了未使用变量导致的警告

### 版本 2.2
- 将默认边框宽度从40像素增加到80像素，提供更加明显的补光效果
- 在菜单中添加边框宽度预设选项，支持快速切换80像素和200像素两种宽度
- 重构了LightController中的边框宽度处理逻辑，使其支持动态修改
- 优化了窗口重建过程，确保切换边框宽度时应用保持稳定运行
- 在菜单项中添加当前选中状态指示，提供更好的用户体验

### 版本 2.3
- 将"边框宽度"选项改名为"补光灯尺寸"，使菜单选项更加直观
- 简化菜单选项为"小"和"大"两种尺寸，替代原来的像素数值表示
- 优化窗口重建逻辑，解决窗口叠加和应用冻结问题
- 通过直接调整现有窗口尺寸和位置，避免重新创建窗口引起的问题

### 版本 2.4
- 增加全屏补光灯模式，支持将整个屏幕变为补光灯
- 优化模式切换逻辑，确保在普通边框模式和全屏模式之间平滑切换
- 改进菜单项，添加全屏选项，使用快捷键"3"快速切换

## 使用技术
- SwiftUI（用户界面）
- AppKit（系统集成）
- Metal（通过 drawingGroup() 进行高效渲染）
- NotificationCenter（组件间通信）

## 调试提示
调试模式会在亮度窗口上显示当前亮度值和计算结果，格式为：
`亮度:[原始值] 实际:[计算值] HDR:[模式]`

此外，应用启动时会在控制台输出显示器HDR能力信息，格式为：
```
应用启动 - 显示器最大HDR亮度值: [值]
【显示器信息】名称: [显示器名称], 分辨率: [分辨率], 屏幕尺寸: [尺寸]
```

显示器相关日志信息很重要，特别是在排查以下问题时：
1. 显示器HDR能力识别正确性（HDR系数是否匹配预期）
2. 亮度计算是否基于正确的显示器参数
3. 多显示器环境下的主显示器识别

如果遇到亮度表现异常，请首先检查日志中显示器的HDR值是否与预期一致。

## 未来计划
- 进一步优化多显示器支持
- 改进亮度计算精确度
- 添加更多自定义选项
- 增加更多特效模式
- 提供显示器亮度配置文件功能，支持手动调整亮度曲线
- 添加键盘快捷键支持，方便快速开关补光灯和调整亮度