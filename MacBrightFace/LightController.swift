import AppKit
import SwiftUI

@MainActor
final class LightController: ObservableObject {
    private enum DefaultsKey {
        static let isOn = "cn.huang.dash.MacBrightFace.isOn"
        static let brightness = "cn.huang.dash.MacBrightFace.brightness"
        static let colorTemperature = "cn.huang.dash.MacBrightFace.colorTemperature"
        static let hdrPreference = "cn.huang.dash.MacBrightFace.hdrPreference"
        static let borderWidth = "cn.huang.dash.MacBrightFace.borderWidth"
        static let effectMode = "cn.huang.dash.MacBrightFace.effectMode"
        static let primaryDirectionalLightAngle = "cn.huang.dash.MacBrightFace.primaryDirectionalLightAngle"
        static let secondaryDirectionalLightAngle = "cn.huang.dash.MacBrightFace.secondaryDirectionalLightAngle"
    }

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
    @Published private(set) var effectMode: LightEffectMode = .normal
    @Published private(set) var primaryDirectionalLightAngle = LightConfiguration.defaultPrimaryDirectionalLightAngle
    @Published private(set) var secondaryDirectionalLightAngle = LightConfiguration.defaultSecondaryDirectionalLightAngle

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
    private let userDefaults = UserDefaults.standard
    private var preferredHDREnabled = true
    private var hasCompletedLaunch = false
    private let lightViewModel = LightViewModel(
        brightness: LightConfiguration.defaultBrightness,
        colorTemperature: LightConfiguration.defaultColorTemperature,
        isHDREnabled: false,
        maxHDRFactor: 1.0,
        borderWidth: LightConfiguration.defaultBorderWidth,
        effectMode: .normal,
        primaryDirectionalLightAngle: LightConfiguration.defaultPrimaryDirectionalLightAngle,
        secondaryDirectionalLightAngle: LightConfiguration.defaultSecondaryDirectionalLightAngle,
        mouseLocation: NSEvent.mouseLocation
    )

    init() {
        restoreSettings()
        refreshDisplayCapabilities()
        isHDREnabled = hasHDRDisplay && preferredHDREnabled
        syncLightViewModel()
        lastScreenLayout = captureScreenLayout()
        rebuildWindows()
        observeScreenChanges()
        observeMouseLocation()
        persistSettings()
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
        showAllWindows()
        persistSettings()
    }

    func turnOff() {
        guard isOn else { return }
        isOn = false
        displayWindows.forEach { $0.window.orderOut(nil) }
        persistSettings()
    }

    func toggleLight() {
        isOn ? turnOff() : turnOn()
    }

    func setBrightness(_ value: Double) {
        let clampedValue = min(LightConfiguration.brightnessRange.upperBound, max(LightConfiguration.brightnessRange.lowerBound, value))
        guard abs(brightness - clampedValue) > 0.01 else { return }

        brightness = clampedValue
        syncLightViewModel()
        persistSettings()
    }

    func setColorTemperature(_ value: Double) {
        let clampedValue = min(LightConfiguration.colorTemperatureRange.upperBound, max(LightConfiguration.colorTemperatureRange.lowerBound, value))
        guard abs(colorTemperature - clampedValue) > 0.01 else { return }

        colorTemperature = clampedValue
        syncLightViewModel()
        persistSettings()
    }

    func setBorderWidth(_ value: CGFloat) {
        let clampedValue = min(LightConfiguration.borderWidthRange.upperBound, max(LightConfiguration.borderWidthRange.lowerBound, value))
        guard abs(borderWidth - clampedValue) > 1.0 else { return }

        borderWidth = clampedValue
        syncLightViewModel()
        persistSettings()
    }

    func setEffectMode(_ mode: LightEffectMode) {
        guard effectMode != mode else { return }

        effectMode = mode
        syncLightViewModel()
        persistSettings()
    }

    func setPrimaryDirectionalLightAngle(_ value: Double) {
        let clampedValue = min(
            LightConfiguration.directionalLightAngleRange.upperBound,
            max(LightConfiguration.directionalLightAngleRange.lowerBound, value)
        )
        guard abs(primaryDirectionalLightAngle - clampedValue) > 0.5 else { return }

        primaryDirectionalLightAngle = clampedValue
        syncLightViewModel()
        persistSettings()
    }

    func setSecondaryDirectionalLightAngle(_ value: Double) {
        let clampedValue = min(
            LightConfiguration.directionalLightAngleRange.upperBound,
            max(LightConfiguration.directionalLightAngleRange.lowerBound, value)
        )
        guard abs(secondaryDirectionalLightAngle - clampedValue) > 0.5 else { return }

        secondaryDirectionalLightAngle = clampedValue
        syncLightViewModel()
        persistSettings()
    }

    func toggleHDRMode() {
        guard hasHDRDisplay else { return }

        preferredHDREnabled.toggle()
        isHDREnabled = hasHDRDisplay && preferredHDREnabled
        refreshEDRState()
        syncLightViewModel()
        persistSettings()
    }

    func supportsHDR() -> Bool {
        hasHDRDisplay
    }

    func getMaxHDRBrightness() -> Double {
        maxHDRBrightness
    }

    func completeLaunch() {
        guard !hasCompletedLaunch else {
            if isOn {
                showAllWindows()
            }
            return
        }

        hasCompletedLaunch = true
        refreshDisplayCapabilities()
        isHDREnabled = hasHDRDisplay && preferredHDREnabled
        syncLightViewModel()

        let currentLayout = captureScreenLayout()
        let needsWindowRefresh = displayWindows.count != currentLayout.count || currentLayout != lastScreenLayout
        lastScreenLayout = currentLayout

        if needsWindowRefresh {
            rebuildWindows()
        } else {
            updateWindowFrames()
            refreshEDRState()
            if isOn {
                showAllWindows()
            }
        }
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

        refreshDisplayCapabilities()
        let currentLayout = captureScreenLayout()
        lastScreenLayout = currentLayout

        isHDREnabled = hasHDRDisplay && preferredHDREnabled
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
                let hdrValue = screen.maximumPotentialExtendedDynamicRangeColorComponentValue
                detectedMaxHDRBrightness = max(detectedMaxHDRBrightness, hdrValue)
                detectedHDR = detectedHDR || hdrValue > 1.0
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

        if shouldRemainVisible && hasCompletedLaunch {
            showAllWindows()
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

    private func showAllWindows() {
        for displayWindow in displayWindows {
            displayWindow.hostingView.layoutSubtreeIfNeeded()
            displayWindow.hostingView.displayIfNeeded()
            displayWindow.window.contentView?.displayIfNeeded()
            displayWindow.window.orderFront(nil)
            displayWindow.window.displayIfNeeded()
        }
    }

    private func makeLightView(for screen: NSScreen) -> LightView {
        LightView(model: lightViewModel, screenFrame: screen.frame)
    }

    private func applyEDRState(to hostingView: NSHostingView<LightView>) {
        guard #available(macOS 10.15, *) else { return }

        hostingView.layer?.wantsExtendedDynamicRangeContent = isHDREnabled
    }

    private func syncLightViewModel() {
        lightViewModel.update(
            brightness: brightness,
            colorTemperature: colorTemperature,
            isHDREnabled: isHDREnabled,
            maxHDRFactor: maxHDRBrightness,
            borderWidth: borderWidth,
            effectMode: effectMode,
            primaryDirectionalLightAngle: primaryDirectionalLightAngle,
            secondaryDirectionalLightAngle: secondaryDirectionalLightAngle,
            mouseLocation: NSEvent.mouseLocation
        )
    }

    private func updateMouseLocation() {
        lightViewModel.updateMouseLocation(NSEvent.mouseLocation)
    }

    private func displayID(for screen: NSScreen) -> CGDirectDisplayID {
        screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID ?? 0
    }

    private func restoreSettings() {
        isOn = userDefaults.object(forKey: DefaultsKey.isOn) as? Bool ?? true
        brightness = clamped(
            userDefaults.object(forKey: DefaultsKey.brightness) as? Double ?? LightConfiguration.defaultBrightness,
            to: LightConfiguration.brightnessRange
        )
        colorTemperature = clamped(
            userDefaults.object(forKey: DefaultsKey.colorTemperature) as? Double ?? LightConfiguration.defaultColorTemperature,
            to: LightConfiguration.colorTemperatureRange
        )
        preferredHDREnabled = userDefaults.object(forKey: DefaultsKey.hdrPreference) as? Bool ?? true
        borderWidth = CGFloat(
            clamped(
                userDefaults.object(forKey: DefaultsKey.borderWidth) as? Double ?? Double(LightConfiguration.defaultBorderWidth),
                to: Double(LightConfiguration.borderWidthRange.lowerBound)...Double(LightConfiguration.borderWidthRange.upperBound)
            )
        )

        if
            let rawEffectMode = userDefaults.string(forKey: DefaultsKey.effectMode),
            let restoredEffectMode = LightEffectMode(rawValue: rawEffectMode)
        {
            effectMode = restoredEffectMode
        }

        primaryDirectionalLightAngle = clamped(
            userDefaults.object(forKey: DefaultsKey.primaryDirectionalLightAngle) as? Double
                ?? LightConfiguration.defaultPrimaryDirectionalLightAngle,
            to: LightConfiguration.directionalLightAngleRange
        )
        secondaryDirectionalLightAngle = clamped(
            userDefaults.object(forKey: DefaultsKey.secondaryDirectionalLightAngle) as? Double
                ?? LightConfiguration.defaultSecondaryDirectionalLightAngle,
            to: LightConfiguration.directionalLightAngleRange
        )
    }

    private func persistSettings() {
        userDefaults.set(isOn, forKey: DefaultsKey.isOn)
        userDefaults.set(brightness, forKey: DefaultsKey.brightness)
        userDefaults.set(colorTemperature, forKey: DefaultsKey.colorTemperature)
        userDefaults.set(preferredHDREnabled, forKey: DefaultsKey.hdrPreference)
        userDefaults.set(Double(borderWidth), forKey: DefaultsKey.borderWidth)
        userDefaults.set(effectMode.rawValue, forKey: DefaultsKey.effectMode)
        userDefaults.set(primaryDirectionalLightAngle, forKey: DefaultsKey.primaryDirectionalLightAngle)
        userDefaults.set(secondaryDirectionalLightAngle, forKey: DefaultsKey.secondaryDirectionalLightAngle)
    }

    private func clamped<T: Comparable>(_ value: T, to range: ClosedRange<T>) -> T {
        min(range.upperBound, max(range.lowerBound, value))
    }
}
