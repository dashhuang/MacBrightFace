//
//  MacBrightFaceApp.swift
//  MacBrightFace
//
//  Created by Dash Huang on 03/03/2025.
//

import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarItem: NSStatusItem!
    var lightController: LightController!
    var isLightOn = false
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 先初始化控制器
        lightController = LightController()
        
        // 打印HDR支持状态
        print("应用启动 - HDR支持状态: \(lightController.supportsHDR() ? "支持" : "不支持")")
        print("应用启动 - HDR模式: \(lightController.isHDREnabled ? "已开启" : "已关闭")")
        if lightController.supportsHDR() {
            print("应用启动 - 显示器最大HDR亮度值: \(String(format: "%.2f", lightController.getMaxHDRBrightness()))")
        }
        
        // 移除所有标准菜单项
        removeStandardMenuItems()
        
        // 监听补光灯自动开启通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleToggleLightNotification(_:)),
            name: NSNotification.Name("ToggleLightNotification"),
            object: nil
        )
        print("已添加补光灯开关通知监听")
        
        // 然后设置状态栏项目和菜单
        setupStatusBarItem()
        
        // 在初始化完成后设置边框宽度菜单状态
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // 设置初始边框宽度菜单状态（基于当前的borderWidth值）
            self.updateBorderWidthMenuState(self.lightController.borderWidth)
        }
    }
    
    // 移除所有标准菜单项
    private func removeStandardMenuItems() {
        // 创建一个空的主菜单
        let emptyMenu = NSMenu()
        
        // 只添加必要的应用菜单项
        let appMenu = NSMenu()
        let appMenuItem = NSMenuItem(title: "MacBrightFace", action: nil, keyEquivalent: "")
        appMenuItem.submenu = appMenu
        
        // 添加关于选项到应用菜单
        appMenu.addItem(NSMenuItem(title: "ABOUT_LIGHT".localized, action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: ""))
        
        // 添加分隔线
        appMenu.addItem(NSMenuItem.separator())
        
        // 添加退出选项到应用菜单
        appMenu.addItem(NSMenuItem(title: "QUIT".localized, action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        // 将应用菜单项添加到主菜单
        emptyMenu.addItem(appMenuItem)
        
        // 设置应用的主菜单
        NSApplication.shared.mainMenu = emptyMenu
        
        print("已设置简化菜单，仅保留关于和退出选项")
    }
    
    func setupStatusBarItem() {
        // 确保先创建状态栏项目
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusBarItem.button {
            button.image = NSImage(systemSymbolName: "lightbulb", accessibilityDescription: "Light")
        }
        
        // 确保lightController已初始化
        guard lightController != nil else {
            // 如果控制器未初始化，设置一个简单的菜单
            let menu = NSMenu()
            menu.addItem(NSMenuItem(title: "初始化中...", action: nil, keyEquivalent: ""))
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "QUIT".localized, action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
            statusBarItem.menu = menu
            return
        }
        
        // 设置完整菜单
        setupMenu()
    }
    
    func setupMenu() {
        let menu = NSMenu()
        
        let toggleMenuItem = NSMenuItem(title: "TOGGLE_LIGHT_ON".localized, action: #selector(toggleLight), keyEquivalent: "t")
        menu.addItem(toggleMenuItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 添加滑动控制亮度选项
        let sliderMenuItem = NSMenuItem(title: "BRIGHTNESS_SLIDER".localized, action: nil, keyEquivalent: "")
        
        // 创建自定义视图容器
        let customView = BrightnessSliderView(
            frame: NSRect(x: 0, y: 0, width: 200, height: 70),
            initialValue: lightController.brightness
        ) { [weak self] newValue in
            guard let self = self else { return }
            
            // 记录亮度调整日志
            struct SliderLogState {
                static var lastLogTime: Date = Date(timeIntervalSince1970: 0)
                static var lastValue: Double = -1
            }
            
            let now = Date()
            let timeSinceLastLog = now.timeIntervalSince(SliderLogState.lastLogTime)
            let valueDifference = abs(SliderLogState.lastValue - newValue)
            
            // 只有在较大变化或间隔超过2秒时才记录日志
            if valueDifference > 0.2 || timeSinceLastLog > 2 || SliderLogState.lastValue < 0 {
                print("【滑动亮度】设置新亮度值: \(newValue)")
                SliderLogState.lastLogTime = now
                SliderLogState.lastValue = newValue
            }
            
            // 设置新亮度
            self.lightController.setBrightness(newValue)
        }
        
        sliderMenuItem.view = customView
        menu.addItem(sliderMenuItem)
        
        // 添加分隔线
        menu.addItem(NSMenuItem.separator())
        
        // 添加补光灯尺寸菜单项
        let borderWidthSubmenu = NSMenu()
        
        // 创建小尺寸选项（80像素）
        let width80MenuItem = NSMenuItem(title: "BORDER_WIDTH_SMALL".localized, action: #selector(setBorderWidth80), keyEquivalent: "1")
        borderWidthSubmenu.addItem(width80MenuItem)
        
        // 创建大尺寸选项（200像素）
        let width200MenuItem = NSMenuItem(title: "BORDER_WIDTH_LARGE".localized, action: #selector(setBorderWidth200), keyEquivalent: "2")
        borderWidthSubmenu.addItem(width200MenuItem)
        
        // 创建补光灯尺寸主菜单项
        let borderWidthMenu = NSMenuItem(title: "BORDER_WIDTH_MENU".localized, action: nil, keyEquivalent: "")
        borderWidthMenu.submenu = borderWidthSubmenu
        menu.addItem(borderWidthMenu)
        
        // 添加HDR模式切换
        if lightController.supportsHDR() {
            let hdrMenuItem = NSMenuItem(
                title: (lightController.isHDREnabled ? "HDR_MODE_ON" : "HDR_MODE_OFF").localized,
                action: #selector(toggleHDRMode),
                keyEquivalent: "h"
            )
            menu.addItem(hdrMenuItem)
        }
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "QUIT".localized, action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusBarItem.menu = menu
    }
    
    @objc func toggleLight() {
        // 添加防御性代码
        guard lightController != nil else { return }
        
        isLightOn.toggle()
        
        // 在主线程上切换灯光状态
        if Thread.isMainThread {
            lightController.toggleLight()
        } else {
            DispatchQueue.main.async {
                self.lightController.toggleLight()
            }
        }
        
        // 在主线程上更新UI
        DispatchQueue.main.async {
            // 更新菜单项
            if let menu = self.statusBarItem.menu,
               let toggleItem = menu.item(at: 0) {
                toggleItem.title = self.isLightOn ? "TOGGLE_LIGHT_OFF".localized : "TOGGLE_LIGHT_ON".localized
            }
            
            // 更新状态栏图标
            if let button = self.statusBarItem.button {
                button.image = NSImage(
                    systemSymbolName: self.isLightOn ? "lightbulb.fill" : "lightbulb",
                    accessibilityDescription: self.isLightOn ? "Turn off Light" : "Turn on Light"
                )
            }
        }
    }
    
    @objc func toggleHDRMode() {
        guard lightController != nil else { return }
        
        // 切换HDR模式
        lightController.toggleHDRMode()
        
        // 更新菜单项
        if let menu = statusBarItem.menu {
            // 找到HDR菜单项
            for (index, item) in menu.items.enumerated() {
                if item.action == #selector(toggleHDRMode) {
                    let newItem = NSMenuItem(
                        title: (lightController.isHDREnabled ? "HDR_MODE_ON" : "HDR_MODE_OFF").localized,
                        action: #selector(toggleHDRMode),
                        keyEquivalent: "h"
                    )
                    menu.removeItem(at: index)
                    menu.insertItem(newItem, at: index)
                    break
                }
            }
            
            // 更新滑动条视图中的亮度值
            for item in menu.items {
                if item.title == "BRIGHTNESS_SLIDER".localized, let sliderView = item.view as? BrightnessSliderView {
                    sliderView.updateValue(lightController.brightness)
                    break
                }
            }
        }
        
        print("HDR模式已切换: \(lightController.isHDREnabled ? "开启" : "关闭")")
    }
    
    // 添加边框宽度设置方法
    @objc func setBorderWidth80() {
        guard lightController != nil else { return }
        
        // 使用安全的方式设置边框宽度
        DispatchQueue.main.async {
            print("设置补光灯尺寸为小（80像素）")
            self.lightController.setBorderWidth(80)
            // 更新菜单UI（如果需要）
            self.updateBorderWidthMenuState(80)
        }
    }
    
    @objc func setBorderWidth200() {
        guard lightController != nil else { return }
        
        // 使用安全的方式设置边框宽度
        DispatchQueue.main.async {
            print("设置补光灯尺寸为大（200像素）")
            self.lightController.setBorderWidth(200)
            // 更新菜单UI（如果需要）
            self.updateBorderWidthMenuState(200)
        }
    }
    
    // 更新边框宽度菜单项的选中状态
    private func updateBorderWidthMenuState(_ selectedWidth: CGFloat) {
        if let menu = statusBarItem.menu {
            // 查找补光灯尺寸菜单项
            for item in menu.items {
                if item.title == "BORDER_WIDTH_MENU".localized, let submenu = item.submenu {
                    // 更新所有子菜单项的状态
                    for subItem in submenu.items {
                        let isSelected: Bool
                        if subItem.action == #selector(setBorderWidth80) {
                            isSelected = selectedWidth == 80
                        } else if subItem.action == #selector(setBorderWidth200) {
                            isSelected = selectedWidth == 200
                        } else {
                            isSelected = false
                        }
                        
                        subItem.state = isSelected ? .on : .off
                    }
                    break
                }
            }
        }
    }
    
    // 处理自动开启补光灯通知
    @objc func handleToggleLightNotification(_ notification: Notification) {
        print("收到补光灯开关通知，正在处理...")
        // 调用已有的toggleLight方法，这样会同时更新菜单和图标
        toggleLight()
    }
    
    // 确保在析构时正确清理资源
    deinit {
        // 清理菜单
        if let menu = statusBarItem.menu {
            menu.removeAllItems()
        }
        
        // 清理状态栏项目
        NSStatusBar.system.removeStatusItem(statusBarItem)
    }
}

@main
struct MacBrightFaceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            EmptyView().frame(width: 0, height: 0)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 0, height: 0)
    }
}
