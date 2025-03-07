//
//  LightController.swift
//  MacBrightFace
//
//  Created for MacBrightFace app.
//

import Foundation
import AppKit
import SwiftUI

class LightController: ObservableObject {
    private var lightWindows: [NSWindow] = []
    private var isOn: Bool = false
    @Published private(set) var brightness: Double = 0.75
    @Published var isHDREnabled: Bool = false
    @Published private(set) var hasHDRDisplay: Bool = false
    @Published private(set) var borderWidth: CGFloat = 80
    
    // 添加定时器用于定期刷新
    private var refreshTimer: Timer?
    
    init() {
        // 应用初始化信息
        print("\n\n===== MacBrightFace应用 v2.0 启动 =====")
        print("开始初始化窗口...")
        
        // 检测是否有HDR显示器
        checkForHDRDisplays()
        
        // 强制启用HDR模式用于测试 - 设置为true可以在任何显示器上强制开启HDR
        let forceHDR = false
        
        // 如果支持HDR或强制启用，自动启用HDR模式
        if hasHDRDisplay || forceHDR {
            isHDREnabled = true
            brightness = 0.3 // 设置为略低的默认值，以便能显示出亮度变化效果
            
            if hasHDRDisplay {
                print("检测到支持HDR的显示器，自动启用HDR模式")
                print("显示器最大HDR亮度值: \(getMaxHDRBrightness())")
            } else {
                print("强制启用HDR模式进行测试")
            }
        } else {
            print("未检测到支持HDR的显示器，使用标准模式")
            brightness = 0.3 // 同样设置为略低的默认值
        }
        
        // 确保在主线程上创建窗口
        if Thread.isMainThread {
            setupWindows()
        } else {
            DispatchQueue.main.sync {
                setupWindows()
            }
        }
        
        print("===== 初始化完成 =====\n")
        
        // 默认自动开启补光灯
        print("应用启动时自动开启补光灯...")
        // 延迟一小段时间再开启补光灯，确保初始化完全完成
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // 使用通知中心发送通知，让AppDelegate处理开关灯逻辑
            NotificationCenter.default.post(name: NSNotification.Name("ToggleLightNotification"), object: nil)
        }
    }
    
    // 检测系统中是否有支持HDR的显示器
    private func checkForHDRDisplays() {
        // 使用静态变量记录已检测的显示器
        struct HDRDisplayCheckState {
            static var loggedDisplayIDs = Set<CGDirectDisplayID>()
        }
        
        let screens = NSScreen.screens
        var foundHDRDisplay = false
        
        for screen in screens {
            if #available(macOS 11.0, *) {
                // 获取显示器ID
                let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID ?? 0
                let isNewDisplay = !HDRDisplayCheckState.loggedDisplayIDs.contains(displayID)
                
                let hdrValue = screen.maximumPotentialExtendedDynamicRangeColorComponentValue
                
                // 仅对新显示器或主显示器输出日志
                if isNewDisplay {
                    print("检测到显示器: \(screen) HDR值: \(hdrValue)")
                    // 记录已处理的显示器
                    HDRDisplayCheckState.loggedDisplayIDs.insert(displayID)
                }
                
                if hdrValue > 1.0 {
                    hasHDRDisplay = true
                    foundHDRDisplay = true
                    
                    // 仅对新发现的HDR显示器输出确认信息
                    if isNewDisplay {
                        print("确认此显示器支持HDR")
                    }
                }
            } else {
                print("当前系统版本不支持HDR检测 (需要macOS 11.0或更高)")
            }
        }
        
        // 如果没有检测到支持HDR的显示器，但用户可能希望强制启用
        if !foundHDRDisplay {
            // 在某些情况下，我们可能希望强制启用HDR模式进行测试
            // 以下代码默认注释掉，取消注释可强制启用HDR
            // hasHDRDisplay = true 
            // print("强制启用HDR支持进行测试")
        }
    }
    
    private enum ScreenEdge {
        case top, bottom, left, right
    }
    
    private func setupWindows() {
        // 清除现有窗口
        for window in lightWindows {
            window.close()
        }
        lightWindows.removeAll()
        
        // 获取所有屏幕
        let screens = NSScreen.screens
        
        // 正常边框模式
        for screen in screens {
            // 创建四个边缘窗口
            createEdgeWindow(screen: screen, edge: .top)
            createEdgeWindow(screen: screen, edge: .bottom)
            createEdgeWindow(screen: screen, edge: .left)
            createEdgeWindow(screen: screen, edge: .right)
        }
        
        // 初始时隐藏所有窗口
        for window in lightWindows {
            window.orderOut(nil)
        }
    }
    
    private func createEdgeWindow(screen: NSScreen, edge: ScreenEdge) {
        // 使用静态变量记录窗口创建日志
        struct EdgeWindowLogState {
            static var windowCount = 0
            static var lastCreateTime = Date(timeIntervalSince1970: 0)
        }
        
        // 更新窗口计数
        EdgeWindowLogState.windowCount += 1
        
        let screenFrame = screen.frame
        var windowFrame: NSRect
        
        // 获取菜单栏高度以避开菜单栏
        let menuBarHeight: CGFloat = NSApplication.shared.mainMenu?.menuBarHeight ?? 25
        let additionalMenubarPadding: CGFloat = 0 // 移除额外间距，让补光灯直接贴到菜单栏底部
        
        // 菜单栏顶部安全区
        let topSafeArea = menuBarHeight + additionalMenubarPadding
        
        // ===== 关键修改：确保窗口不重叠 =====
        
        // 新的窗口布局计算
        switch edge {
        case .top:
            // 顶部窗口 - 全宽
            windowFrame = NSRect(
                x: screenFrame.minX, 
                y: screenFrame.maxY - borderWidth - topSafeArea, 
                width: screenFrame.width, 
                height: borderWidth
            )
            print("【重要】顶部窗口设置为全宽，高度=\(borderWidth)")
            
        case .bottom:
            // 底部窗口 - 全宽
            windowFrame = NSRect(
                x: screenFrame.minX, 
                y: screenFrame.minY, 
                width: screenFrame.width, 
                height: borderWidth
            )
            print("【重要】底部窗口设置为全宽，高度=\(borderWidth)")
            
        case .left:
            // 关键：确保左窗口不与上下窗口重叠
            windowFrame = NSRect(
                x: screenFrame.minX, 
                y: screenFrame.minY + borderWidth, // 从下窗口上边界开始
                width: borderWidth, 
                height: screenFrame.height - (2 * borderWidth) - topSafeArea // 减去上下窗口高度和菜单栏
            )
            print("【重要】左窗口高度调整，避开上下窗口，实际高度=\(windowFrame.height)")
            
        case .right:
            // 关键：确保右窗口不与上下窗口重叠
            windowFrame = NSRect(
                x: screenFrame.maxX - borderWidth, 
                y: screenFrame.minY + borderWidth, // 从下窗口上边界开始
                width: borderWidth, 
                height: screenFrame.height - (2 * borderWidth) - topSafeArea // 减去上下窗口高度和菜单栏
            )
            print("【重要】右窗口高度调整，避开上下窗口，实际高度=\(windowFrame.height)")
        }
        
        // 输出完整调试信息 - 记录每个窗口的位置和尺寸
        print("创建\(edge)窗口: x=\(Int(windowFrame.minX)), y=\(Int(windowFrame.minY)), 宽=\(Int(windowFrame.width)), 高=\(Int(windowFrame.height)), 屏幕宽=\(Int(screenFrame.width)), 屏幕高=\(Int(screenFrame.height))")
        
        // 创建没有标题栏的窗口
        let window = NSWindow(
            contentRect: windowFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
        )
        
        // 禁用调试模式
        let debugMode = false
        
        if debugMode {
            // 为不同边缘设置不同颜色，帮助识别重叠区域
            switch edge {
            case .top:
                window.backgroundColor = NSColor.red.withAlphaComponent(0.5)
            case .bottom:
                window.backgroundColor = NSColor.green.withAlphaComponent(0.5)
            case .left:
                window.backgroundColor = NSColor.blue.withAlphaComponent(0.5)
            case .right:
                window.backgroundColor = NSColor.yellow.withAlphaComponent(0.5)
            }
            
            // 在调试模式下允许鼠标事件，方便拖动观察
            window.ignoresMouseEvents = false
            window.isMovableByWindowBackground = true
            print("调试模式: \(edge)窗口已设置彩色背景和鼠标交互")
        } else {
            // 正常模式下，使窗口完全透明并忽略鼠标事件
            window.backgroundColor = NSColor.clear
            window.ignoresMouseEvents = true
            window.isMovableByWindowBackground = false
        }
        
        window.hasShadow = false
        window.level = .statusBar // 使用statusBar级别，确保显示在大多数普通窗口上方
        
        // 设置窗口以保持在前面
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        
        // 将窗口设置为全透明(正常模式)或半透明(调试模式)
        window.alphaValue = debugMode ? 0.7 : 1.0
        
        // 为HDR显示开启EDR支持
        if #available(macOS 10.15, *), isHDREnabled {
            if let contentView = window.contentView {
                contentView.wantsLayer = true
                if let layer = contentView.layer {
                    // 使用正确的方式设置HDR支持
                    layer.wantsExtendedDynamicRangeContent = true
                }
            }
        }
        
        // 创建LightView
        let lightView = LightView(brightness: brightness, isHDREnabled: isHDREnabled, maxHDRFactor: getMaxHDRBrightness())
        let hostingView = NSHostingView(rootView: lightView)
        window.contentView = hostingView
        
        lightWindows.append(window)
    }
    
    // 打开或关闭补光灯
    func toggleLight() {
        isOn.toggle()
        
        print("\n===== 补光灯状态切换为: \(isOn ? "开启" : "关闭") =====")
        
        if isOn {
            // 确保所有窗口都有正确的内容和调试模式设置
            print("正在显示所有\(lightWindows.count)个窗口，调试模式已启用...")
            for (index, window) in lightWindows.enumerated() {
                // 确保窗口层级正确
                window.level = .statusBar
                // 强制刷新窗口内容
                window.contentView?.needsDisplay = true
                window.displayIfNeeded()
                // 显示窗口
                window.orderFront(nil)
                print("窗口[\(index)]已显示 - 坐标: x=\(Int(window.frame.minX)), y=\(Int(window.frame.minY)), 宽度=\(Int(window.frame.width)), 高度=\(Int(window.frame.height))")
            }
            // 启动定时刷新
            startRefreshTimer()
        } else {
            print("正在隐藏所有\(lightWindows.count)个窗口...")
            for window in lightWindows {
                window.orderOut(nil)
            }
            // 停止定时刷新
            stopRefreshTimer()
        }
    }
    
    // 启动定时刷新
    private func startRefreshTimer() {
        // 先停止已有定时器
        stopRefreshTimer()
        
        // 创建新的定时器，每5秒刷新一次窗口，减少刷新频率
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self = self, self.isOn else { return }
            
            print("定时刷新补光灯窗口")
            DispatchQueue.main.async {
                // 强制更新所有窗口
                self.refreshAllWindows()
            }
        }
    }
    
    // 停止定时刷新
    private func stopRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    // 刷新所有窗口，确保它们保持正确的亮度和层级
    private func refreshAllWindows() {
        // 减少日志输出频率
        struct RefreshLogState {
            static var lastRefreshTime: Date = Date(timeIntervalSince1970: 0)
            static var refreshCount: Int = 0
        }
        
        let now = Date()
        let timeSinceLastLog = now.timeIntervalSince(RefreshLogState.lastRefreshTime)
        
        // 每30秒最多只记录一次窗口刷新日志，或者刷新超过10次后记录一次
        if timeSinceLastLog > 30 || RefreshLogState.refreshCount >= 10 {
            print("【窗口刷新】强制刷新所有窗口，当前亮度: \(brightness)")
            RefreshLogState.lastRefreshTime = now
            RefreshLogState.refreshCount = 0
        } else {
            RefreshLogState.refreshCount += 1
        }
        
        // 如果没有窗口，记录警告并返回
        if lightWindows.isEmpty {
            print("【警告】没有窗口可供刷新")
            return
        }
        
        // 直接调用更新窗口亮度的方法，避免代码重复
        updateWindowsWithNewBrightness()
    }
    
    // 设置亮度
    func setBrightness(_ value: Double) {
        // 减少日志输出频率
        struct SetBrightnessLogState {
            static var lastLogTime: Date = Date(timeIntervalSince1970: 0)
            static var lastBrightnessValue: Double = -1
        }
        
        let now = Date()
        let timeSinceLastLog = now.timeIntervalSince(SetBrightnessLogState.lastLogTime)
        
        // 确保值在合理范围内
        let newValue = max(0.01, min(10.0, value))
        
        // 检查是否有明显变化，即使微小变化我们也接受
        if abs(brightness - newValue) < 0.001 {
            // 只有在日志间隔超过5秒时才记录忽略微小变化的信息
            if timeSinceLastLog > 5 && abs(SetBrightnessLogState.lastBrightnessValue - newValue) > 0.001 {
                print("【亮度控制】忽略微小变化，当前亮度: \(brightness), 请求值: \(newValue)")
                SetBrightnessLogState.lastLogTime = now
                SetBrightnessLogState.lastBrightnessValue = newValue
            }
            return
        }
        
        // 更新亮度属性并记录变化
        let oldValue = brightness
        brightness = newValue
        
        // 只有在亮度变化明显(>0.05)或者间隔超过3秒时才记录日志
        if abs(oldValue - newValue) > 0.05 || timeSinceLastLog > 3 {
            print("【亮度控制】亮度从 \(oldValue) 变更为 \(brightness), 变化量: \(brightness - oldValue)")
            SetBrightnessLogState.lastLogTime = now
            SetBrightnessLogState.lastBrightnessValue = newValue
        }
        
        // 立即发出变更通知
        objectWillChange.send()
        
        // 强制在主线程上更新窗口内容和亮度
        if Thread.isMainThread {
            self.updateWindowsWithNewBrightness()
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.updateWindowsWithNewBrightness()
            }
        }
        
        // 确保系统级别的刷新但不要重复刷新
        NSApp.setWindowsNeedUpdate(true)
    }
    
    // 专门用于更新亮度的方法
    private func updateWindowsWithNewBrightness() {
        // 减少日志输出频率
        struct UpdateLogState {
            static var lastUpdateLogTime: Date = Date(timeIntervalSince1970: 0)
            static var updateCount: Int = 0
            static var lastRecordedBrightness: Double = -1
        }
        
        let now = Date()
        let timeSinceLastLog = now.timeIntervalSince(UpdateLogState.lastUpdateLogTime)
        let brightnessChanged = abs(UpdateLogState.lastRecordedBrightness - brightness) > 0.05
        
        // 只有在亮度显著变化或者间隔超过10秒时才输出日志
        if brightnessChanged || timeSinceLastLog > 10 || UpdateLogState.updateCount >= 20 {
            print("【亮度更新】开始为所有窗口应用新亮度: \(brightness), HDR模式: \(isHDREnabled ? "开启" : "关闭")")
            UpdateLogState.lastUpdateLogTime = now
            UpdateLogState.lastRecordedBrightness = brightness
            UpdateLogState.updateCount = 0
        } else {
            UpdateLogState.updateCount += 1
        }
        
        // 如果没有窗口，记录警告
        if lightWindows.isEmpty {
            print("【警告】没有窗口可供更新亮度")
            return
        }
        
        // 优化: 不对每个窗口都输出日志，仅记录更新的总数
        var updatedCount = 0
        
        // 更新所有窗口内容
        for (index, window) in lightWindows.enumerated() {
            // 创建新的LightView实例，明确传递当前亮度
            let newView = LightView(brightness: brightness, isHDREnabled: isHDREnabled, maxHDRFactor: getMaxHDRBrightness())
            
            // 创建新的HostingView包装视图
            let hostingView = NSHostingView(rootView: newView)
            
            // 保存窗口的当前level，确保窗口层级不变
            let currentLevel = window.level
            
            // 更换窗口内容
            window.contentView = hostingView
            
            // 确保窗口级别保持不变
            window.level = currentLevel
            
            // 仅对第一个窗口输出详细日志，且仅在亮度变化明显或定期记录时
            if index == 0 && (brightnessChanged || timeSinceLastLog > 10) {
                print("【亮度更新】窗口[\(index)]视图已更新，亮度: \(brightness)")
            }
            
            updatedCount += 1
            
            // 设置HDR标志(如需要)
            if #available(macOS 10.15, *), isHDREnabled, let layer = window.contentView?.layer {
                layer.wantsExtendedDynamicRangeContent = true
            }
            
            // 强制重绘，确保显示最新的内容
            window.contentView?.needsDisplay = true
            
            // 确保窗口显示在前面
            if isOn {
                window.orderFront(nil)
            }
        }
        
        // 只有在亮度变化明显或者间隔超过10秒时才输出完成更新日志
        if brightnessChanged || timeSinceLastLog > 10 {
            print("【亮度更新】所有\(updatedCount)个窗口亮度已更新为: \(brightness)")
        }
    }
    
    // 设置HDR模式
    func toggleHDRMode() {
        isHDREnabled.toggle()
        
        print("HDR模式状态已切换为: \(isHDREnabled ? "开启" : "关闭")")
        
        // 当切换HDR模式时，如果开启HDR，自动设置较高的亮度
        if isHDREnabled {
            // 默认设置为较高亮度
            let newBrightness = 0.9
            print("HDR模式已开启，设置亮度为: \(newBrightness)")
            brightness = newBrightness
        } else {
            // 返回到标准亮度
            let standardBrightness = 0.7
            print("HDR模式已关闭，恢复标准亮度: \(standardBrightness)")
            brightness = standardBrightness
        }
        
        // 不再重建窗口，只更新窗口内容
        updateWindowsForHDRMode()
        
        // 如果灯已开启，确保窗口仍然可见
        if isOn {
            for window in lightWindows {
                if !window.isVisible {
                    window.makeKeyAndOrderFront(nil)
                }
            }
        }
    }
    
    // 更新窗口以适应HDR模式变化，而不是重建窗口
    private func updateWindowsForHDRMode() {
        print("正在更新所有窗口以适应HDR模式变化: \(isHDREnabled ? "启用" : "禁用")")
        
        var updatedCount = 0
        
        for (_, window) in lightWindows.enumerated() {
            // 更新窗口的HDR内容标志
            if #available(macOS 10.15, *) {
                if let contentView = window.contentView {
                    contentView.wantsLayer = true
                    if let layer = contentView.layer {
                        layer.wantsExtendedDynamicRangeContent = isHDREnabled
                        // 减少日志输出，仅对第一个窗口记录详情
                        if updatedCount == 0 {
                            print("设置窗口HDR内容标志: \(isHDREnabled)")
                        }
                    }
                }
            }
            
            // 更新LightView
            if let hostingView = window.contentView as? NSHostingView<LightView> {
                let updatedView = LightView(brightness: brightness, isHDREnabled: isHDREnabled, maxHDRFactor: getMaxHDRBrightness())
                hostingView.rootView = updatedView
                
                // 强制更新视图
                hostingView.needsDisplay = true
                hostingView.setNeedsDisplay(hostingView.bounds)
                updatedCount += 1
            }
            
            // 强制窗口刷新
            window.displayIfNeeded()
            
            // 确保窗口显示在前面
            if isOn {
                window.orderFront(nil)
            }
        }
        
        print("已更新\(updatedCount)个窗口以适应HDR模式变化")
    }
    
    // 检查是否支持HDR模式
    func supportsHDR() -> Bool {
        return hasHDRDisplay
    }
    
    // 获取最大HDR亮度值
    func getMaxHDRBrightness() -> Double {
        // 使用静态变量记录是否已经输出过详细日志
        struct HDRBrightnessLogState {
            static var hasLogged = false
            static var cachedMaxBrightness: Double = 1.0
            // 记录最后一次调用时间，确保不会频繁重复计算
            static var lastCallTime = Date(timeIntervalSince1970: 0)
            // 缓存已检测的显示器信息，避免重复输出
            static var loggedDisplayIDs = Set<CGDirectDisplayID>()
        }
        
        // 如果上次调用在2秒内，直接返回缓存的结果
        let now = Date()
        if now.timeIntervalSince(HDRBrightnessLogState.lastCallTime) < 2.0 && HDRBrightnessLogState.hasLogged {
            return HDRBrightnessLogState.cachedMaxBrightness
        }
        
        // 更新调用时间
        HDRBrightnessLogState.lastCallTime = now
        
        var maxBrightness: Double = 1.0
        
        for screen in NSScreen.screens {
            if #available(macOS 11.0, *) {
                // 获取显示器信息
                let screenDescription = screen.deviceDescription
                let screenNumber = screenDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID ?? 0
                
                // 检查是否已经记录过这个显示器
                let isNewDisplay = !HDRBrightnessLogState.loggedDisplayIDs.contains(screenNumber)
                
                // 仅对新显示器输出详细信息
                if isNewDisplay {
                    // 获取显示器本地化名称和模式
                    let localizedName = screen.localizedName
                    
                    // 获取显示器尺寸信息
                    let displaySize = screenDescription[NSDeviceDescriptionKey.size] as? CGSize
                    let displayWidthCM = displaySize?.width ?? 0
                    let displayHeightCM = displaySize?.height ?? 0
                    
                    // 获取显示器分辨率信息
                    let displayRect = screen.frame
                    let resolution = "\(Int(displayRect.width))x\(Int(displayRect.height))"
                    
                    // 获取HDR亮度值
                    let hdrValue = screen.maximumPotentialExtendedDynamicRangeColorComponentValue
                    print("【显示器信息】名称: \(localizedName), 分辨率: \(resolution), 屏幕尺寸: \(displayWidthCM) x \(displayHeightCM)")
                    print("检测到显示器: \(screen) HDR值: \(hdrValue), 型号: \(localizedName)")
                    
                    if hdrValue > maxBrightness {
                        maxBrightness = hdrValue
                        print("确认此显示器支持HDR")
                    }
                    
                    // 记录已处理的显示器ID
                    HDRBrightnessLogState.loggedDisplayIDs.insert(screenNumber)
                } else {
                    // 对于已记录过的显示器，直接使用其HDR值但不输出日志
                    let hdrValue = screen.maximumPotentialExtendedDynamicRangeColorComponentValue
                    if hdrValue > maxBrightness {
                        maxBrightness = hdrValue
                    }
                }
            }
        }
        
        // 仅在首次或显示器变化时输出最终HDR亮度值
        if !HDRBrightnessLogState.hasLogged {
            print("显示器最大HDR亮度值: \(maxBrightness)")
            HDRBrightnessLogState.hasLogged = true
        }
        
        // 缓存计算结果
        HDRBrightnessLogState.cachedMaxBrightness = maxBrightness
        
        return maxBrightness
    }
    
    // 更新所有窗口中的LightView
    private func updateLightViews() {
        // 这个方法现在直接调用updateWindowsWithNewBrightness
        // 避免重复代码和多次刷新
        updateWindowsWithNewBrightness()
    }
    
    // 析构函数，确保所有窗口都被正确关闭
    deinit {
        // 确保停止定时器
        stopRefreshTimer()
        
        // 在主线程上关闭所有窗口
        if Thread.isMainThread {
            closeAllWindows()
        } else {
            DispatchQueue.main.sync {
                self.closeAllWindows()
            }
        }
    }
    
    // 关闭所有窗口
    private func closeAllWindows() {
        for window in lightWindows {
            window.close()
        }
        lightWindows.removeAll()
    }
    
    // 设置边框宽度
    func setBorderWidth(_ width: CGFloat) {
        // 确保值在合理范围内 (20-200 像素)
        let newWidth = max(20, min(200, width))
        
        // 如果没有变化，直接返回
        if abs(borderWidth - newWidth) < 0.1 {
            return
        }
        
        // 记录旧值和新值
        print("【补光灯尺寸】从 \(borderWidth) 更改为 \(newWidth)")
        
        // 更新宽度
        borderWidth = newWidth
        
        // 发送变更通知
        objectWillChange.send()
        
        // 如果补光灯已开启，需要重建所有窗口以应用新宽度
        if isOn {
            // 先关闭灯，然后重新开启
            print("重建窗口以应用新的补光灯尺寸...")
            
            // 记住当前状态
            let wasOn = isOn
            
            // 在主线程上操作UI
            if Thread.isMainThread {
                rebuildWindowsForNewBorderWidth(wasOn: wasOn)
            } else {
                DispatchQueue.main.async { [weak self] in
                    self?.rebuildWindowsForNewBorderWidth(wasOn: wasOn)
                }
            }
        } else {
            // 如果补光灯处于关闭状态，仅重建窗口
            // 确保在主线程上重建
            if Thread.isMainThread {
                setupWindows()
            } else {
                DispatchQueue.main.async { [weak self] in
                    self?.setupWindows()
                }
            }
        }
        
        // 输出调试信息
        print("窗口更新完成，新的补光灯尺寸为 \(self.borderWidth)")
    }
    
    // 重建窗口以应用新的边框宽度
    private func rebuildWindowsForNewBorderWidth(wasOn: Bool) {
        // 首先隐藏所有窗口
        for window in lightWindows {
            window.orderOut(nil) // 隐藏窗口
        }
        
        // 短暂延迟以确保UI操作完成
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            
            // 获取所有屏幕
            let screens = NSScreen.screens
            
            // 更新每个窗口的位置和大小，而不是关闭并重建窗口
            var windowIndex = 0
            for screen in screens {
                // 创建四个方向的窗口尺寸和位置
                let screenFrame = screen.frame
                
                // 获取菜单栏高度
                let menuBarHeight: CGFloat = NSApplication.shared.mainMenu?.menuBarHeight ?? 25
                let additionalMenubarPadding: CGFloat = 0
                let topSafeArea = menuBarHeight + additionalMenubarPadding
                
                // 定义四个方向的窗口frame
                var frames: [NSRect] = []
                
                // 顶部窗口 - 全宽
                frames.append(NSRect(
                    x: screenFrame.minX, 
                    y: screenFrame.maxY - self.borderWidth - topSafeArea, 
                    width: screenFrame.width, 
                    height: self.borderWidth
                ))
                
                // 底部窗口 - 全宽
                frames.append(NSRect(
                    x: screenFrame.minX, 
                    y: screenFrame.minY, 
                    width: screenFrame.width, 
                    height: self.borderWidth
                ))
                
                // 左侧窗口 - 避开上下窗口
                frames.append(NSRect(
                    x: screenFrame.minX, 
                    y: screenFrame.minY + self.borderWidth, 
                    width: self.borderWidth, 
                    height: screenFrame.height - (2 * self.borderWidth) - topSafeArea
                ))
                
                // 右侧窗口 - 避开上下窗口
                frames.append(NSRect(
                    x: screenFrame.maxX - self.borderWidth, 
                    y: screenFrame.minY + self.borderWidth, 
                    width: self.borderWidth, 
                    height: screenFrame.height - (2 * self.borderWidth) - topSafeArea
                ))
                
                // 应用新的窗口位置和尺寸
                for frame in frames {
                    // 确保我们有足够的窗口
                    if windowIndex < self.lightWindows.count {
                        // 获取对应窗口
                        let window = self.lightWindows[windowIndex]
                        
                        // 更新窗口位置和尺寸
                        window.setFrame(frame, display: true)
                        
                        // 创建新的LightView
                        let lightView = LightView(brightness: self.brightness, 
                                                 isHDREnabled: self.isHDREnabled, 
                                                 maxHDRFactor: self.getMaxHDRBrightness())
                        let hostingView = NSHostingView(rootView: lightView)
                        
                        // 更新窗口内容
                        window.contentView = hostingView
                        
                        // 为HDR显示开启EDR支持
                        if #available(macOS 10.15, *), self.isHDREnabled {
                            if let contentView = window.contentView {
                                contentView.wantsLayer = true
                                if let layer = contentView.layer {
                                    layer.wantsExtendedDynamicRangeContent = true
                                }
                            }
                        }
                        
                        // 如果需要显示窗口
                        if wasOn {
                            window.orderFront(nil)
                        }
                        
                        windowIndex += 1
                    }
                }
            }
            
            print("窗口更新完成，新的补光灯尺寸为 \(self.borderWidth)")
        }
    }
} 