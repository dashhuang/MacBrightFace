import AppKit
import Combine
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarItem: NSStatusItem!
    private let lightController = LightController()
    private let statusPopover = NSPopover()
    private var popoverHostingController: NSHostingController<ContentView>?
    private var cancellables: Set<AnyCancellable> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureApplicationMenu()
        setupStatusBarItem()
        setupStatusPopover()
        observeControllerState()
        lightController.turnOn()
    }

    func applicationWillTerminate(_ notification: Notification) {
        statusPopover.performClose(nil)

        if let statusBarItem {
            NSStatusBar.system.removeStatusItem(statusBarItem)
        }
    }

    @objc private func toggleStatusPopover(_ sender: Any?) {
        guard let button = statusBarItem.button else { return }

        if statusPopover.isShown {
            statusPopover.performClose(sender)
            return
        }

        updateStatusPopoverSize()
        statusPopover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    @objc private func showAboutPanel() {
        statusPopover.performClose(nil)
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    @objc private func quitApplication() {
        NSApp.terminate(nil)
    }

    private func configureApplicationMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem(title: "MacBrightFace", action: nil, keyEquivalent: "")
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu

        let aboutItem = NSMenuItem(title: "ABOUT_LIGHT".localized, action: #selector(showAboutPanel), keyEquivalent: "")
        aboutItem.target = self
        appMenu.addItem(aboutItem)
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(NSMenuItem(title: "QUIT".localized, action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        mainMenu.addItem(appMenuItem)
        NSApplication.shared.mainMenu = mainMenu
    }

    private func setupStatusBarItem() {
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusBarItem.button?.imagePosition = .imageOnly
        statusBarItem.button?.target = self
        statusBarItem.button?.action = #selector(toggleStatusPopover(_:))
        statusBarItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        refreshStatusBarButton()
    }

    private func setupStatusPopover() {
        statusPopover.behavior = .transient
        statusPopover.animates = false
        let hostingController = NSHostingController(
            rootView: ContentView(
                lightController: lightController,
                showAbout: { [weak self] in self?.showAboutPanel() },
                quitApp: { [weak self] in self?.quitApplication() }
            )
        )

        popoverHostingController = hostingController
        statusPopover.contentViewController = hostingController
        updateStatusPopoverSize()
    }

    private func observeControllerState() {
        lightController.$isOn
            .sink { [weak self] _ in
                self?.refreshStatusBarButton()
            }
            .store(in: &cancellables)
    }

    private func refreshStatusBarButton() {
        guard let button = statusBarItem.button else { return }

        button.image = NSImage(
            systemSymbolName: lightController.isOn ? "lightbulb.fill" : "lightbulb",
            accessibilityDescription: lightController.isOn ? "TOGGLE_LIGHT_OFF".localized : "TOGGLE_LIGHT_ON".localized
        )
    }

    private func updateStatusPopoverSize() {
        guard let hostingController = popoverHostingController else { return }

        _ = hostingController.view
        hostingController.view.layoutSubtreeIfNeeded()

        let fittingSize = hostingController.view.fittingSize
        let popoverSize = NSSize(
            width: max(320, fittingSize.width),
            height: max(380, fittingSize.height)
        )

        hostingController.preferredContentSize = popoverSize
        statusPopover.contentSize = popoverSize
    }
}

@main
struct MacBrightFaceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
