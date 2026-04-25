import AppKit
import Combine
import OSLog
import SwiftUI

private final class DisplayControlPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

private final class ControlPanelHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }
}

private struct ControlPanelAnchor {
    let display: LightViewModel
    let offsetFromRight: CGFloat
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private let logger = Logger(subsystem: "cn.huang.dash.DisplayFill", category: "ControlPanels")
    private var statusBarItem: NSStatusItem!
    private let lightController = LightController()
    private let statusPopover = NSPopover()
    private var controlPanels: [String: NSPanel] = [:]
    private var localControlPanelDismissMonitor: Any?
    private var globalControlPanelDismissMonitor: Any?
    private var displayEffectModeCancellables: [String: AnyCancellable] = [:]
    private var cancellables: Set<AnyCancellable> = []
    private var areControlPanelsVisible = false
    private var isRefreshingVisibleControlPanels = false
    private var isClosingControlPanelsProgrammatically = false
    private var lastAutomaticControlPanelCloseEventNumber: Int?
    private var currentPrimaryDisplayID: String?
    private var currentAnchorOffsetFromRight: CGFloat?
    private var pendingSecondaryResizeTasks: [String: DispatchWorkItem] = [:]
    private var visibleControlPanelRefreshGeneration = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureApplicationMenu()
        setupStatusBarItem()
        setupStatusPopover()
        observeControllerState()
        lightController.completeLaunch()
        if ProcessInfo.processInfo.arguments.contains("--debug-show-control-panels") {
            showControlPanels()
        } else {
            presentInitialControlPanelsIfNeeded()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        hideControlPanels()

        if let statusBarItem {
            NSStatusBar.system.removeStatusItem(statusBarItem)
        }
    }

    @objc private func toggleControlPanels(_ sender: Any?) {
        if toggleWasAlreadyHandledByAutomaticPopoverClose() {
            return
        }

        lastAutomaticControlPanelCloseEventNumber = nil

        if areControlPanelsVisible || statusPopover.isShown {
            hideControlPanels()
        } else {
            showControlPanels()
        }
    }

    @objc private func showAboutPanel() {
        hideControlPanels()
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    @objc private func quitApplication() {
        hideControlPanels()
        NSApp.terminate(nil)
    }

    private func configureApplicationMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem(title: "DisplayFill", action: nil, keyEquivalent: "")
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
        statusBarItem.button?.action = #selector(toggleControlPanels(_:))
        statusBarItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        refreshStatusBarButton()
    }

    private func setupStatusPopover() {
        statusPopover.behavior = .applicationDefined
        statusPopover.animates = false
        statusPopover.delegate = self
    }

    private func observeControllerState() {
        lightController.$anyDisplayOn
            .sink { [weak self] _ in
                self?.refreshStatusBarButton()
            }
            .store(in: &cancellables)

        lightController.$displays
            .sink { [weak self] displays in
                self?.refreshEffectModeSubscriptions(displays)
                guard let self, self.areControlPanelsVisible else { return }
                self.scheduleVisibleControlPanelRefresh()
            }
            .store(in: &cancellables)
    }

    private func refreshEffectModeSubscriptions(_ displays: [LightViewModel]) {
        displayEffectModeCancellables.removeAll()

        for display in displays {
            displayEffectModeCancellables[display.persistentID] = display.$effectMode
                .dropFirst()
                .sink { [weak self] _ in
                    DispatchQueue.main.async { [weak self] in
                        guard let self, self.areControlPanelsVisible else { return }
                        self.handleEffectModeChange(for: display.persistentID)
                    }
                }
        }
    }

    private func handleEffectModeChange(for persistentID: String) {
        guard let display = lightController.displays.first(where: { $0.persistentID == persistentID }) else {
            return
        }

        if persistentID == currentPrimaryDisplayID {
            refreshPrimaryPopoverIfNeeded(for: display)
        } else {
            scheduleSecondaryPanelResize(for: display)
        }
    }

    private func refreshStatusBarButton() {
        guard let button = statusBarItem.button else { return }

        button.image = NSImage(
            systemSymbolName: lightController.anyDisplayOn ? "lightbulb.fill" : "lightbulb",
            accessibilityDescription: lightController.anyDisplayOn ? "TOGGLE_LIGHT_OFF".localized : "TOGGLE_LIGHT_ON".localized
        )
    }

    @discardableResult
    private func showControlPanels() -> Bool {
        guard let anchor = controlPanelAnchorForCurrentInteraction() else { return false }
        return presentControlPanels(
            primaryDisplayID: anchor.display.persistentID,
            anchorOffsetFromRight: anchor.offsetFromRight,
            refreshingPrimaryPopover: statusPopover.isShown
        )
    }

    private func presentInitialControlPanelsIfNeeded() {
        guard lightController.shouldPresentInitialControlPanelsOnLaunch else { return }

        presentInitialControlPanelsIfNeeded(remainingAttempts: 3)
    }

    private func presentInitialControlPanelsIfNeeded(remainingAttempts: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let self else { return }
            guard self.lightController.shouldPresentInitialControlPanelsOnLaunch else { return }

            if self.showInitialControlPanels() {
                self.lightController.markInitialControlPanelPresentationShown()
            } else if remainingAttempts > 0 {
                self.presentInitialControlPanelsIfNeeded(remainingAttempts: remainingAttempts - 1)
            }
        }
    }

    @discardableResult
    private func showInitialControlPanels() -> Bool {
        guard let anchor = statusItemControlPanelAnchor() else { return false }

        return presentControlPanels(
            primaryDisplayID: anchor.display.persistentID,
            anchorOffsetFromRight: anchor.offsetFromRight,
            refreshingPrimaryPopover: statusPopover.isShown
        )
    }

    private func refreshVisibleControlPanels() {
        let fallbackAnchor = controlPanelAnchorForCurrentInteraction()
        let primaryDisplayID = currentPrimaryDisplayID ?? fallbackAnchor?.display.persistentID
        _ = presentControlPanels(
            primaryDisplayID: primaryDisplayID,
            anchorOffsetFromRight: currentAnchorOffsetFromRight ?? fallbackAnchor?.offsetFromRight,
            refreshingPrimaryPopover: statusPopover.isShown
        )
    }

    @discardableResult
    private func presentControlPanels(
        primaryDisplayID: String?,
        anchorOffsetFromRight: CGFloat?,
        refreshingPrimaryPopover: Bool
    ) -> Bool {
        guard !isRefreshingVisibleControlPanels else { return false }
        guard !lightController.displays.isEmpty else { return false }

        guard let resolvedPrimaryDisplay = resolvedPrimaryDisplay(for: primaryDisplayID) else { return false }
        let resolvedAnchorOffset = anchorOffsetFromRight
            ?? (resolvedPrimaryDisplay.visibleFrame.maxX - NSEvent.mouseLocation.x)

        NSApp.activate(ignoringOtherApps: true)

        if refreshingPrimaryPopover {
            closeControlPanels()
            isRefreshingVisibleControlPanels = true
            statusPopover.performClose(nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) { [weak self] in
                guard let self else { return }
                self.isRefreshingVisibleControlPanels = false
                guard self.areControlPanelsVisible else { return }
                let didPresent = self.presentControlPanels(
                    primaryDisplayID: resolvedPrimaryDisplay.persistentID,
                    anchorOffsetFromRight: resolvedAnchorOffset,
                    refreshingPrimaryPopover: false
                )
                if !didPresent {
                    self.removeControlPanelDismissMonitors()
                    self.resetControlPanelPresentationState()
                }
            }
            return false
        }

        closeControlPanels()
        guard showPrimaryPopover(for: resolvedPrimaryDisplay) else {
            removeControlPanelDismissMonitors()
            resetControlPanelPresentationState()
            return false
        }

        currentPrimaryDisplayID = resolvedPrimaryDisplay.persistentID
        currentAnchorOffsetFromRight = resolvedAnchorOffset
        areControlPanelsVisible = true
        installControlPanelDismissMonitors()
        logger.info(
            "Primary display=\(resolvedPrimaryDisplay.displayName, privacy: .public) mouse=\(NSStringFromPoint(NSEvent.mouseLocation), privacy: .public) offsetFromRight=\(resolvedAnchorOffset)"
        )

        for display in lightController.displays {
            guard display.persistentID != resolvedPrimaryDisplay.persistentID else { continue }
            let panel = makeControlPanel(for: display)
            let frame = controlPanelFrame(
                for: display,
                contentSize: fittedControlPanelContentSize(for: display),
                anchorOffsetFromRight: resolvedAnchorOffset
            )
            panel.setFrame(frame, display: false)
            controlPanels[display.persistentID] = panel
            logger.info("Will show panel display=\(display.displayName, privacy: .public) persistentID=\(display.persistentID, privacy: .public) targetFrame=\(NSStringFromRect(panel.frame), privacy: .public) visibleFrame=\(NSStringFromRect(display.visibleFrame), privacy: .public)")
            panel.orderFrontRegardless()
            DispatchQueue.main.async { [weak self, weak panel] in
                guard let self, let panel else { return }
                let actualScreenName = panel.screen?.localizedName ?? "nil"
                self.logger.info("Did show panel display=\(display.displayName, privacy: .public) actualScreen=\(actualScreenName, privacy: .public) actualFrame=\(NSStringFromRect(panel.frame), privacy: .public)")
            }
        }

        return true
    }

    private func hideControlPanels() {
        cancelVisibleControlPanelRefresh()
        removeControlPanelDismissMonitors()
        closeControlPanels()
        closePrimaryPopoverProgrammatically()
        resetControlPanelPresentationState()
    }

    private func resetControlPanelPresentationState() {
        areControlPanelsVisible = false
        currentPrimaryDisplayID = nil
        currentAnchorOffsetFromRight = nil
    }

    private func closeControlPanels() {
        for workItem in pendingSecondaryResizeTasks.values {
            workItem.cancel()
        }
        pendingSecondaryResizeTasks.removeAll()

        for panel in controlPanels.values {
            panel.orderOut(nil)
            panel.contentView = nil
            panel.close()
        }

        controlPanels.removeAll()
    }

    private func scheduleVisibleControlPanelRefresh() {
        visibleControlPanelRefreshGeneration += 1
        let generation = visibleControlPanelRefreshGeneration

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            guard let self else { return }
            guard generation == self.visibleControlPanelRefreshGeneration else { return }
            guard self.areControlPanelsVisible else { return }
            self.refreshVisibleControlPanels()
        }
    }

    private func cancelVisibleControlPanelRefresh() {
        visibleControlPanelRefreshGeneration += 1
    }

    private func closePrimaryPopoverProgrammatically() {
        isClosingControlPanelsProgrammatically = true
        statusPopover.performClose(nil)
        DispatchQueue.main.async { [weak self] in
            self?.isClosingControlPanelsProgrammatically = false
        }
    }

    private func toggleWasAlreadyHandledByAutomaticPopoverClose() -> Bool {
        guard let event = NSApp.currentEvent else { return false }
        guard lastAutomaticControlPanelCloseEventNumber == event.eventNumber else { return false }
        guard !areControlPanelsVisible, !statusPopover.isShown else { return false }

        lastAutomaticControlPanelCloseEventNumber = nil
        logger.info("Ignored status item toggle because the same click already dismissed the control panels")
        return true
    }

    private func clickedStatusBarButton(at screenPoint: CGPoint) -> Bool {
        guard let button = statusBarItem.button, let window = button.window else {
            return false
        }

        let buttonFrame = window.convertToScreen(button.bounds).insetBy(dx: -4, dy: -4)
        return buttonFrame.contains(screenPoint)
    }

    private func installControlPanelDismissMonitors() {
        guard localControlPanelDismissMonitor == nil, globalControlPanelDismissMonitor == nil else { return }

        let mouseDownEvents: NSEvent.EventTypeMask = [
            .leftMouseDown,
            .rightMouseDown,
            .otherMouseDown
        ]

        localControlPanelDismissMonitor = NSEvent.addLocalMonitorForEvents(matching: mouseDownEvents) { [weak self] event in
            guard let self else { return event }
            dismissControlPanelsIfNeeded(forMouseDownAt: screenPoint(for: event))
            return event
        }

        globalControlPanelDismissMonitor = NSEvent.addGlobalMonitorForEvents(matching: mouseDownEvents) { [weak self] _ in
            DispatchQueue.main.async { [weak self] in
                self?.dismissControlPanelsIfNeeded(forMouseDownAt: NSEvent.mouseLocation)
            }
        }
    }

    private func removeControlPanelDismissMonitors() {
        if let localControlPanelDismissMonitor {
            NSEvent.removeMonitor(localControlPanelDismissMonitor)
            self.localControlPanelDismissMonitor = nil
        }

        if let globalControlPanelDismissMonitor {
            NSEvent.removeMonitor(globalControlPanelDismissMonitor)
            self.globalControlPanelDismissMonitor = nil
        }
    }

    private func screenPoint(for event: NSEvent) -> CGPoint {
        guard let window = event.window else {
            return NSEvent.mouseLocation
        }

        return window.convertToScreen(NSRect(origin: event.locationInWindow, size: .zero)).origin
    }

    private func dismissControlPanelsIfNeeded(forMouseDownAt screenPoint: CGPoint) {
        guard areControlPanelsVisible || statusPopover.isShown else {
            removeControlPanelDismissMonitors()
            return
        }

        guard !controlPanelUIContains(screenPoint) else { return }
        hideControlPanels()
    }

    private func controlPanelUIContains(_ screenPoint: CGPoint) -> Bool {
        if clickedStatusBarButton(at: screenPoint) {
            return true
        }

        if
            let popoverWindow = statusPopover.contentViewController?.view.window,
            popoverWindow.frame.contains(screenPoint)
        {
            return true
        }

        return controlPanels.values.contains { panel in
            panel.frame.contains(screenPoint)
        }
    }

    private func makeControlPanel(for display: LightViewModel) -> NSPanel {
        let contentSize = fittedControlPanelContentSize(for: display)
        let frame = controlPanelFrame(for: display, contentSize: contentSize, anchorOffsetFromRight: nil)
        let panel = DisplayControlPanel(
            contentRect: frame,
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: false,
            screen: NSScreen.screens.first(where: { $0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID == display.displayID })
        )

        panel.isReleasedWhenClosed = false
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true

        let hostingView = ControlPanelHostingView(rootView: makeContentView(for: display))
        panel.contentView = hostingView
        panel.setFrame(frame, display: false)
        return panel
    }

    private func controlPanelFrame(for display: LightViewModel, contentSize: CGSize, anchorOffsetFromRight: CGFloat?) -> NSRect {
        let margin: CGFloat = 12
        let width = max(320, contentSize.width)
        let height = max(280, contentSize.height)
        let minX = display.visibleFrame.minX + margin
        let maxX = display.visibleFrame.maxX - width - margin
        let x: CGFloat

        if let anchorOffsetFromRight {
            let anchorCenterX = display.visibleFrame.maxX - anchorOffsetFromRight
            x = min(max(anchorCenterX - (width / 2), minX), maxX)
        } else {
            x = maxX
        }

        return NSRect(
            x: x,
            y: display.visibleFrame.maxY - height - margin,
            width: width,
            height: height
        )
    }

    private func controlPanelAnchorForCurrentInteraction() -> ControlPanelAnchor? {
        let mouseLocation = NSEvent.mouseLocation
        if let display = lightController.displays.first(where: {
            $0.visibleFrame.contains(mouseLocation) || $0.screenFrame.contains(mouseLocation)
        }) {
            return ControlPanelAnchor(
                display: display,
                offsetFromRight: display.visibleFrame.maxX - mouseLocation.x
            )
        }

        if let statusItemAnchor = statusItemControlPanelAnchor() {
            return statusItemAnchor
        }

        let display = lightController.displays.first
        guard let display else { return nil }

        return ControlPanelAnchor(
            display: display,
            offsetFromRight: display.visibleFrame.width / 2
        )
    }

    private func statusItemControlPanelAnchor() -> ControlPanelAnchor? {
        guard let button = statusBarItem.button, let window = button.window else {
            return nil
        }

        let buttonFrame = window.convertToScreen(button.bounds)
        guard let display = displayForStatusItemWindow(window, buttonFrame: buttonFrame) else {
            return nil
        }

        return ControlPanelAnchor(
            display: display,
            offsetFromRight: display.visibleFrame.maxX - buttonFrame.midX
        )
    }

    private func displayForStatusItemWindow(_ window: NSWindow, buttonFrame: NSRect) -> LightViewModel? {
        if
            let displayID = window.screen?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID,
            let display = lightController.displays.first(where: { $0.displayID == displayID })
        {
            return display
        }

        let buttonCenter = CGPoint(x: buttonFrame.midX, y: buttonFrame.midY)
        return lightController.displays.first {
            $0.visibleFrame.contains(buttonCenter) || $0.screenFrame.contains(buttonCenter)
        } ?? lightController.displays.first
    }

    private func resolvedPrimaryDisplay(for persistentID: String?) -> LightViewModel? {
        if let persistentID, let display = lightController.displays.first(where: { $0.persistentID == persistentID }) {
            return display
        }

        return controlPanelAnchorForCurrentInteraction()?.display
    }

    @discardableResult
    private func showPrimaryPopover(for display: LightViewModel) -> Bool {
        guard let button = statusBarItem.button else { return false }

        let hostingView = ControlPanelHostingView(rootView: makeContentView(for: display))
        let hostingController = NSViewController()
        hostingController.view = hostingView
        statusPopover.contentViewController = hostingController
        statusPopover.contentSize = fittedControlPanelContentSize(for: display)
        logger.info("Showing primary popover for display=\(display.displayName, privacy: .public)")
        statusPopover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        return statusPopover.isShown
    }

    private func refreshPrimaryPopoverIfNeeded(for display: LightViewModel) {
        guard statusPopover.isShown else { return }

        let targetSize = fittedControlPanelContentSize(for: display)
        guard contentSizeNeedsUpdate(current: statusPopover.contentSize, target: targetSize) else {
            return
        }

        isRefreshingVisibleControlPanels = true
        statusPopover.performClose(nil)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isRefreshingVisibleControlPanels = false
            if self.showPrimaryPopover(for: display) {
                self.areControlPanelsVisible = true
            } else {
                self.removeControlPanelDismissMonitors()
                self.closeControlPanels()
                self.resetControlPanelPresentationState()
            }
        }
    }

    private func resizeSecondaryPanelIfNeeded(for display: LightViewModel) {
        guard let panel = controlPanels[display.persistentID] else { return }

        panel.contentView?.invalidateIntrinsicContentSize()
        panel.contentView?.needsLayout = true
        panel.contentView?.layoutSubtreeIfNeeded()

        let targetContentSize = fittedControlPanelContentSize(for: display)
        let targetFrame = controlPanelFrame(
            for: display,
            contentSize: targetContentSize,
            anchorOffsetFromRight: currentAnchorOffsetFromRight
        )

        guard frameNeedsUpdate(current: panel.frame, target: targetFrame) else {
            return
        }

        panel.setFrame(targetFrame, display: true, animate: false)
        logger.info(
            "Resized secondary panel display=\(display.displayName, privacy: .public) targetFrame=\(NSStringFromRect(targetFrame), privacy: .public)"
        )
    }

    private func scheduleSecondaryPanelResize(for display: LightViewModel) {
        pendingSecondaryResizeTasks[display.persistentID]?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.pendingSecondaryResizeTasks[display.persistentID] = nil
            self.resizeSecondaryPanelIfNeeded(for: display)
        }

        pendingSecondaryResizeTasks[display.persistentID] = workItem
        DispatchQueue.main.async(execute: workItem)
    }

    private func fittedControlPanelContentSize(for display: LightViewModel) -> CGSize {
        let measuredSize = measuredContentSize(for: display)
        return CGSize(
            width: max(320, measuredSize.width),
            height: max(280, measuredSize.height)
        )
    }

    private func measuredContentSize(for display: LightViewModel) -> CGSize {
        let measuringView = ControlPanelHostingView(rootView: makeContentView(for: display))
        measuringView.frame = NSRect(x: 0, y: 0, width: 336, height: 10)
        measuringView.layoutSubtreeIfNeeded()
        return measuringView.fittingSize
    }

    private func contentSizeNeedsUpdate(current: CGSize, target: CGSize) -> Bool {
        abs(current.width - target.width) > 0.5 || abs(current.height - target.height) > 0.5
    }

    private func frameNeedsUpdate(current: CGRect, target: CGRect) -> Bool {
        abs(current.origin.x - target.origin.x) > 0.5
            || abs(current.origin.y - target.origin.y) > 0.5
            || abs(current.size.width - target.size.width) > 0.5
            || abs(current.size.height - target.size.height) > 0.5
    }

    private func makeContentView(for display: LightViewModel) -> ContentView {
        ContentView(
            display: display,
            lightController: lightController,
            showAbout: { [weak self] in self?.showAboutPanel() },
            quitApp: { [weak self] in self?.quitApplication() }
        )
    }

    func popoverDidClose(_ notification: Notification) {
        if isRefreshingVisibleControlPanels || isClosingControlPanelsProgrammatically {
            return
        }

        lastAutomaticControlPanelCloseEventNumber = NSApp.currentEvent?.eventNumber
        cancelVisibleControlPanelRefresh()
        removeControlPanelDismissMonitors()
        closeControlPanels()
        resetControlPanelPresentationState()
    }

    func popoverShouldClose(_ popover: NSPopover) -> Bool {
        guard let event = NSApp.currentEvent else {
            return true
        }

        guard
            event.type == .leftMouseDown
                || event.type == .rightMouseDown
                || event.type == .otherMouseDown
        else {
            return true
        }

        let screenPoint: CGPoint
        if let window = event.window {
            screenPoint = window.convertToScreen(NSRect(origin: event.locationInWindow, size: .zero)).origin
        } else {
            screenPoint = NSEvent.mouseLocation
        }

        if clickedStatusBarButton(at: screenPoint) {
            logger.info("Prevented primary popover close because click landed on the status item at \(NSStringFromPoint(screenPoint), privacy: .public)")
            return false
        }

        let clickedInsideControlPanel = controlPanels.values.contains { panel in
            panel.frame.contains(screenPoint)
        }

        if clickedInsideControlPanel {
            logger.info("Prevented primary popover close because click landed inside a secondary control panel at \(NSStringFromPoint(screenPoint), privacy: .public)")
            return false
        }

        return true
    }
}

@main
struct DisplayFillApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
