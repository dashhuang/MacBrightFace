import AppKit
import SwiftUI

@MainActor
final class LightController: ObservableObject {
    private struct ScreenLayoutSignature: Equatable {
        let displayID: CGDirectDisplayID
        let frame: CGRect
        let visibleFrame: CGRect
    }

    @Published private(set) var isOn = false
    @Published private(set) var brightness = LightConfiguration.defaultBrightness
    @Published private(set) var colorTemperature = LightConfiguration.defaultColorTemperature
    @Published private(set) var isHDREnabled = false
    @Published private(set) var hasHDRDisplay = false
    @Published private(set) var borderWidth = LightConfiguration.defaultBorderWidth

    private struct DisplayWindow {
        let displayID: CGDirectDisplayID
        let window: NSWindow
        let hostingView: NSHostingView<LightView>
    }

    private var displayWindows: [DisplayWindow] = []
    private var maxHDRBrightness = 1.0
    private var lastScreenLayout: [ScreenLayoutSignature] = []
    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?
    private let lightViewModel = LightViewModel(
        brightness: LightConfiguration.defaultBrightness,
        colorTemperature: LightConfiguration.defaultColorTemperature,
        isHDREnabled: false,
        maxHDRFactor: 1.0,
        borderWidth: LightConfiguration.defaultBorderWidth,
        mouseLocation: NSEvent.mouseLocation
    )

    init() {
        refreshDisplayCapabilities()
        isHDREnabled = hasHDRDisplay
        syncLightViewModel()
        lastScreenLayout = captureScreenLayout()
        rebuildWindows()
        observeScreenChanges()
        observeMouseLocation()
    }

    deinit {
        if let globalMouseMonitor {
            NSEvent.removeMonitor(globalMouseMonitor)
        }

        if let localMouseMonitor {
            NSEvent.removeMonitor(localMouseMonitor)
        }
    }

    func turnOn() {
        guard !isOn else { return }
        isOn = true
        displayWindows.forEach { $0.window.orderFront(nil) }
    }

    func turnOff() {
        guard isOn else { return }
        isOn = false
        displayWindows.forEach { $0.window.orderOut(nil) }
    }

    func toggleLight() {
        isOn ? turnOff() : turnOn()
    }

    func setBrightness(_ value: Double) {
        let clampedValue = min(LightConfiguration.brightnessRange.upperBound, max(LightConfiguration.brightnessRange.lowerBound, value))
        guard abs(brightness - clampedValue) > 0.01 else { return }

        brightness = clampedValue
        syncLightViewModel()
    }

    func setColorTemperature(_ value: Double) {
        let clampedValue = min(LightConfiguration.colorTemperatureRange.upperBound, max(LightConfiguration.colorTemperatureRange.lowerBound, value))
        guard abs(colorTemperature - clampedValue) > 0.01 else { return }

        colorTemperature = clampedValue
        syncLightViewModel()
    }

    func setBorderWidth(_ value: CGFloat) {
        let clampedValue = min(LightConfiguration.borderWidthRange.upperBound, max(LightConfiguration.borderWidthRange.lowerBound, value))
        guard abs(borderWidth - clampedValue) > 1.0 else { return }

        borderWidth = clampedValue
        syncLightViewModel()
    }

    func toggleHDRMode() {
        guard hasHDRDisplay else { return }

        isHDREnabled.toggle()
        refreshEDRState()
        syncLightViewModel()
    }

    func supportsHDR() -> Bool {
        hasHDRDisplay
    }

    func getMaxHDRBrightness() -> Double {
        maxHDRBrightness
    }

    private func observeScreenChanges() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScreenParametersDidChange(_:)),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    private func observeMouseLocation() {
        let mouseEvents: NSEvent.EventTypeMask = [
            .mouseMoved,
            .leftMouseDragged,
            .rightMouseDragged,
            .otherMouseDragged
        ]

        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: mouseEvents) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateMouseLocation()
            }
        }

        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: mouseEvents) { [weak self] event in
            self?.updateMouseLocation()
            return event
        }

        updateMouseLocation()
    }

    @objc private func handleScreenParametersDidChange(_ notification: Notification) {
        let previousLayout = lastScreenLayout
        let previouslyHadHDRDisplay = hasHDRDisplay
        let wasHDREnabled = isHDREnabled

        refreshDisplayCapabilities()
        let currentLayout = captureScreenLayout()
        lastScreenLayout = currentLayout

        if !hasHDRDisplay {
            isHDREnabled = false
        } else if !previouslyHadHDRDisplay {
            isHDREnabled = true
        } else {
            isHDREnabled = wasHDREnabled
        }

        syncLightViewModel()

        if previousLayout != currentLayout {
            rebuildWindows()
        } else {
            refreshEDRState()
            updateWindowFrames()
        }
    }

    private func refreshDisplayCapabilities() {
        var detectedHDR = false
        var detectedMaxHDRBrightness = 1.0

        if #available(macOS 11.0, *) {
            for screen in NSScreen.screens {
                let potentialHDRValue = screen.maximumPotentialExtendedDynamicRangeColorComponentValue
                let currentHDRValue = screen.maximumExtendedDynamicRangeColorComponentValue
                let effectiveHDRValue = max(currentHDRValue, potentialHDRValue)

                detectedMaxHDRBrightness = max(detectedMaxHDRBrightness, effectiveHDRValue)
                detectedHDR = detectedHDR || potentialHDRValue > 1.0
            }
        }

        hasHDRDisplay = detectedHDR
        maxHDRBrightness = detectedHDR ? detectedMaxHDRBrightness : 1.0
    }

    private func captureScreenLayout() -> [ScreenLayoutSignature] {
        NSScreen.screens
            .map { screen in
                let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID ?? 0
                return ScreenLayoutSignature(
                    displayID: displayID,
                    frame: screen.frame,
                    visibleFrame: screen.visibleFrame
                )
            }
            .sorted { lhs, rhs in
                if lhs.displayID != rhs.displayID {
                    return lhs.displayID < rhs.displayID
                }

                return lhs.frame.minX < rhs.frame.minX
            }
    }

    private func rebuildWindows() {
        let shouldRemainVisible = isOn

        closeAllWindows()

        for screen in NSScreen.screens {
            if let displayWindow = makeDisplayWindow(for: screen) {
                displayWindows.append(displayWindow)
            }
        }

        if shouldRemainVisible {
            displayWindows.forEach { $0.window.orderFront(nil) }
        }
    }

    private func closeAllWindows() {
        displayWindows.forEach { displayWindow in
            displayWindow.window.orderOut(nil)
            displayWindow.window.contentView = nil
            displayWindow.window.close()
        }
        displayWindows.removeAll()
    }

    private func makeDisplayWindow(for screen: NSScreen) -> DisplayWindow? {
        let frame = frame(for: screen)
        guard frame.width >= 1, frame.height >= 1 else {
            return nil
        }

        let lightView = makeLightView(for: screen)
        let hostingView = NSHostingView(rootView: lightView)
        let window = NSWindow(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
        )

        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.isMovableByWindowBackground = false
        window.level = .mainMenu
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        window.contentView = hostingView

        hostingView.wantsLayer = true
        applyEDRState(to: hostingView)
        window.orderOut(nil)

        return DisplayWindow(
            displayID: displayID(for: screen),
            window: window,
            hostingView: hostingView
        )
    }

    private func frame(for screen: NSScreen) -> NSRect {
        screen.frame
    }

    private func updateWindowFrames() {
        let screensByID = Dictionary(uniqueKeysWithValues: NSScreen.screens.map { (displayID(for: $0), $0) })

        for displayWindow in displayWindows {
            guard let screen = screensByID[displayWindow.displayID] else { continue }

            displayWindow.window.setFrame(frame(for: screen), display: true)
        }
    }

    private func refreshEDRState() {
        for displayWindow in displayWindows {
            applyEDRState(to: displayWindow.hostingView)
        }
    }

    private func makeLightView(for screen: NSScreen) -> LightView {
        LightView(model: lightViewModel, screenFrame: screen.frame)
    }

    private func applyEDRState(to hostingView: NSHostingView<LightView>) {
        guard let layer = hostingView.layer else { return }

        if #available(macOS 26.0, *) {
            let shouldEnableHDR = isHDREnabled
                && hasHDRDisplay
                && !NSApp.applicationShouldSuppressHighDynamicRangeContent

            layer.preferredDynamicRange = shouldEnableHDR ? .high : .standard
            layer.contentsHeadroom = shouldEnableHDR
                ? CGFloat(max(1.0, min(maxHDRBrightness, LightConfiguration.practicalHDRHeadroom)))
                : 0.0
            layer.toneMapMode = shouldEnableHDR ? .never : .automatic
            return
        }

        if #available(macOS 10.15, *) {
            layer.wantsExtendedDynamicRangeContent = isHDREnabled
        }
    }

    private func syncLightViewModel() {
        lightViewModel.update(
            brightness: brightness,
            colorTemperature: colorTemperature,
            isHDREnabled: isHDREnabled,
            maxHDRFactor: maxHDRBrightness,
            borderWidth: borderWidth,
            mouseLocation: NSEvent.mouseLocation
        )
    }

    private func updateMouseLocation() {
        lightViewModel.updateMouseLocation(NSEvent.mouseLocation)
    }

    private func displayID(for screen: NSScreen) -> CGDirectDisplayID {
        screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID ?? 0
    }
}
