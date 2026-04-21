import AppKit
import ColorSync
import OSLog
import SwiftUI

@MainActor
final class LightController: ObservableObject {
    private let logger = Logger(subsystem: "cn.huang.dash.MacBrightFace", category: "Overlays")
    private enum DefaultsKey {
        static let displaySettings = "cn.huang.dash.MacBrightFace.displaySettings"
        static let legacyIsOn = "cn.huang.dash.MacBrightFace.isOn"
        static let legacyBrightness = "cn.huang.dash.MacBrightFace.brightness"
        static let legacyColorTemperature = "cn.huang.dash.MacBrightFace.colorTemperature"
        static let legacyHDRPreference = "cn.huang.dash.MacBrightFace.hdrPreference"
        static let legacyBorderWidth = "cn.huang.dash.MacBrightFace.borderWidth"
        static let legacyEffectMode = "cn.huang.dash.MacBrightFace.effectMode"
        static let legacyPrimaryDirectionalLightAngle = "cn.huang.dash.MacBrightFace.primaryDirectionalLightAngle"
        static let legacySecondaryDirectionalLightAngle = "cn.huang.dash.MacBrightFace.secondaryDirectionalLightAngle"
    }

    private struct PersistedDisplaySettings {
        var isOn: Bool
        var brightness: Double
        var colorTemperature: Double
        var hdrPreference: Bool
        var borderWidth: CGFloat
        var effectMode: LightEffectMode
        var primaryDirectionalLightAngle: Double
        var secondaryDirectionalLightAngle: Double

        init(
            isOn: Bool,
            brightness: Double,
            colorTemperature: Double,
            hdrPreference: Bool,
            borderWidth: CGFloat,
            effectMode: LightEffectMode,
            primaryDirectionalLightAngle: Double,
            secondaryDirectionalLightAngle: Double
        ) {
            self.isOn = isOn
            self.brightness = brightness
            self.colorTemperature = colorTemperature
            self.hdrPreference = hdrPreference
            self.borderWidth = borderWidth
            self.effectMode = effectMode
            self.primaryDirectionalLightAngle = primaryDirectionalLightAngle
            self.secondaryDirectionalLightAngle = secondaryDirectionalLightAngle
        }

        @MainActor
        init(model: LightViewModel) {
            self.init(
                isOn: model.isOn,
                brightness: model.brightness,
                colorTemperature: model.colorTemperature,
                hdrPreference: model.preferredHDREnabled,
                borderWidth: model.borderWidth,
                effectMode: model.effectMode,
                primaryDirectionalLightAngle: model.primaryDirectionalLightAngle,
                secondaryDirectionalLightAngle: model.secondaryDirectionalLightAngle
            )
        }

        init?(dictionary: [String: Any]) {
            let rawEffectMode = dictionary["effectMode"] as? String ?? LightEffectMode.normal.rawValue
            guard let effectMode = LightEffectMode(rawValue: rawEffectMode) else {
                return nil
            }

            self.init(
                isOn: dictionary["isOn"] as? Bool ?? true,
                brightness: min(
                    LightConfiguration.brightnessRange.upperBound,
                    max(
                        LightConfiguration.brightnessRange.lowerBound,
                        dictionary["brightness"] as? Double ?? LightConfiguration.defaultBrightness
                    )
                ),
                colorTemperature: min(
                    LightConfiguration.colorTemperatureRange.upperBound,
                    max(
                        LightConfiguration.colorTemperatureRange.lowerBound,
                        dictionary["colorTemperature"] as? Double ?? LightConfiguration.defaultColorTemperature
                    )
                ),
                hdrPreference: dictionary["hdrPreference"] as? Bool ?? true,
                borderWidth: CGFloat(
                    min(
                        LightConfiguration.borderWidthRange.upperBound,
                        max(
                            LightConfiguration.borderWidthRange.lowerBound,
                            CGFloat(dictionary["borderWidth"] as? Double ?? Double(LightConfiguration.defaultBorderWidth))
                        )
                    )
                ),
                effectMode: effectMode,
                primaryDirectionalLightAngle: min(
                    LightConfiguration.directionalLightAngleRange.upperBound,
                    max(
                        LightConfiguration.directionalLightAngleRange.lowerBound,
                        dictionary["primaryDirectionalLightAngle"] as? Double
                            ?? LightConfiguration.defaultPrimaryDirectionalLightAngle
                    )
                ),
                secondaryDirectionalLightAngle: min(
                    LightConfiguration.directionalLightAngleRange.upperBound,
                    max(
                        LightConfiguration.directionalLightAngleRange.lowerBound,
                        dictionary["secondaryDirectionalLightAngle"] as? Double
                            ?? LightConfiguration.defaultSecondaryDirectionalLightAngle
                    )
                )
            )
        }

        var dictionaryValue: [String: Any] {
            [
                "isOn": isOn,
                "brightness": brightness,
                "colorTemperature": colorTemperature,
                "hdrPreference": hdrPreference,
                "borderWidth": Double(borderWidth),
                "effectMode": effectMode.rawValue,
                "primaryDirectionalLightAngle": primaryDirectionalLightAngle,
                "secondaryDirectionalLightAngle": secondaryDirectionalLightAngle
            ]
        }
    }

    private struct ScreenLayoutSignature: Equatable {
        let persistentID: String
        let frame: CGRect
        let visibleFrame: CGRect
    }

    private struct ScreenDescriptor {
        let persistentID: String
        let displayID: CGDirectDisplayID
        let displayName: String
        let frame: CGRect
        let visibleFrame: CGRect
        let hasHDRDisplay: Bool
        let maxHDRFactor: Double
        let screen: NSScreen
    }

    private final class DisplayContext {
        let model: LightViewModel
        var overlayWindow: NSWindow?
        var hostingView: NSHostingView<LightView>?

        init(model: LightViewModel) {
            self.model = model
        }
    }

    @Published private(set) var displays: [LightViewModel] = []
    @Published private(set) var anyDisplayOn = false

    private var displayContexts: [String: DisplayContext] = [:]
    private var lastScreenLayout: [ScreenLayoutSignature] = []
    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?
    private let userDefaults = UserDefaults.standard
    private var persistedDisplaySettings: [String: PersistedDisplaySettings] = [:]
    private var hasCompletedLaunch = false

    init() {
        persistedDisplaySettings = loadPersistedDisplaySettings()
        lastScreenLayout = captureScreenLayout()
        rebuildDisplayContexts()
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

    func completeLaunch() {
        guard !hasCompletedLaunch else {
            refreshOverlayVisibility()
            return
        }

        hasCompletedLaunch = true
        rebuildDisplayContexts()
        refreshOverlayVisibility()
    }

    func toggleLight(for display: LightViewModel) {
        display.isOn.toggle()
        persist(display)
        refreshOverlayVisibility(for: display.persistentID)
        updateAnyDisplayOn()
    }

    func setBrightness(_ value: Double, for display: LightViewModel) {
        let clampedValue = clamped(value, to: LightConfiguration.brightnessRange)
        guard abs(display.brightness - clampedValue) > 0.01 else { return }

        display.brightness = clampedValue
        persist(display)
    }

    func setColorTemperature(_ value: Double, for display: LightViewModel) {
        let clampedValue = clamped(value, to: LightConfiguration.colorTemperatureRange)
        guard abs(display.colorTemperature - clampedValue) > 0.01 else { return }

        display.colorTemperature = clampedValue
        persist(display)
    }

    func setBorderWidth(_ value: CGFloat, for display: LightViewModel) {
        let clampedValue = clamped(value, to: LightConfiguration.borderWidthRange)
        guard abs(display.borderWidth - clampedValue) > 1.0 else { return }

        display.borderWidth = clampedValue
        persist(display)
    }

    func setEffectMode(_ mode: LightEffectMode, for display: LightViewModel) {
        guard display.effectMode != mode else { return }

        display.effectMode = mode
        persist(display)
    }

    func setPrimaryDirectionalLightAngle(_ value: Double, for display: LightViewModel) {
        let clampedValue = clamped(value, to: LightConfiguration.directionalLightAngleRange)
        guard abs(display.primaryDirectionalLightAngle - clampedValue) > 0.5 else { return }

        display.primaryDirectionalLightAngle = clampedValue
        persist(display)
    }

    func setSecondaryDirectionalLightAngle(_ value: Double, for display: LightViewModel) {
        let clampedValue = clamped(value, to: LightConfiguration.directionalLightAngleRange)
        guard abs(display.secondaryDirectionalLightAngle - clampedValue) > 0.5 else { return }

        display.secondaryDirectionalLightAngle = clampedValue
        persist(display)
    }

    func toggleHDRMode(for display: LightViewModel) {
        guard display.hasHDRDisplay else { return }

        display.preferredHDREnabled.toggle()
        display.isHDREnabled = display.hasHDRDisplay && display.preferredHDREnabled
        applyEDRState(for: display.persistentID)
        persist(display)
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
        let currentLayout = captureScreenLayout()
        guard currentLayout != lastScreenLayout else { return }

        lastScreenLayout = currentLayout
        rebuildDisplayContexts()
        refreshOverlayVisibility()
    }

    private func rebuildDisplayContexts() {
        let descriptors = screenDescriptors()
        let descriptorIDs = Set(descriptors.map(\.persistentID))

        for (persistentID, context) in displayContexts where !descriptorIDs.contains(persistentID) {
            closeOverlayWindow(for: context)
            displayContexts.removeValue(forKey: persistentID)
        }

        for descriptor in descriptors {
            let context = displayContexts[descriptor.persistentID] ?? makeDisplayContext(for: descriptor)
            update(context.model, with: descriptor)
            configureOverlayWindow(for: context, descriptor: descriptor)
            displayContexts[descriptor.persistentID] = context
        }

        displays = descriptors.compactMap { displayContexts[$0.persistentID]?.model }
        updateAnyDisplayOn()
    }

    private func screenDescriptors() -> [ScreenDescriptor] {
        NSScreen.screens
            .map { screen in
                let displayID = displayID(for: screen)
                let maxHDRFactor: Double
                let hasHDRDisplay: Bool

                if #available(macOS 11.0, *) {
                    maxHDRFactor = max(1.0, screen.maximumPotentialExtendedDynamicRangeColorComponentValue)
                    hasHDRDisplay = maxHDRFactor > 1.0
                } else {
                    maxHDRFactor = 1.0
                    hasHDRDisplay = false
                }

                return ScreenDescriptor(
                    persistentID: persistentDisplayID(for: displayID),
                    displayID: displayID,
                    displayName: screen.localizedName,
                    frame: screen.frame,
                    visibleFrame: screen.visibleFrame,
                    hasHDRDisplay: hasHDRDisplay,
                    maxHDRFactor: maxHDRFactor,
                    screen: screen
                )
            }
            .sorted { lhs, rhs in
                if lhs.frame.minX != rhs.frame.minX {
                    return lhs.frame.minX < rhs.frame.minX
                }

                return lhs.persistentID < rhs.persistentID
            }
    }

    private func captureScreenLayout() -> [ScreenLayoutSignature] {
        screenDescriptors().map { descriptor in
            ScreenLayoutSignature(
                persistentID: descriptor.persistentID,
                frame: descriptor.frame,
                visibleFrame: descriptor.visibleFrame
            )
        }
    }

    private func makeDisplayContext(for descriptor: ScreenDescriptor) -> DisplayContext {
        let settings = persistedDisplaySettings[descriptor.persistentID] ?? legacyDisplaySettings()
        let model = LightViewModel(
            persistentID: descriptor.persistentID,
            displayID: descriptor.displayID,
            displayName: descriptor.displayName,
            screenFrame: descriptor.frame,
            visibleFrame: descriptor.visibleFrame,
            isOn: settings.isOn,
            brightness: settings.brightness,
            colorTemperature: settings.colorTemperature,
            isHDREnabled: descriptor.hasHDRDisplay && settings.hdrPreference,
            hasHDRDisplay: descriptor.hasHDRDisplay,
            preferredHDREnabled: settings.hdrPreference,
            maxHDRFactor: descriptor.maxHDRFactor,
            borderWidth: settings.borderWidth,
            effectMode: settings.effectMode,
            primaryDirectionalLightAngle: settings.primaryDirectionalLightAngle,
            secondaryDirectionalLightAngle: settings.secondaryDirectionalLightAngle,
            mouseLocation: NSEvent.mouseLocation
        )

        return DisplayContext(model: model)
    }

    private func update(_ model: LightViewModel, with descriptor: ScreenDescriptor) {
        model.displayID = descriptor.displayID
        model.displayName = descriptor.displayName
        model.screenFrame = descriptor.frame
        model.visibleFrame = descriptor.visibleFrame
        model.hasHDRDisplay = descriptor.hasHDRDisplay
        model.maxHDRFactor = descriptor.maxHDRFactor
        model.isHDREnabled = descriptor.hasHDRDisplay && model.preferredHDREnabled
    }

    private func configureOverlayWindow(for context: DisplayContext, descriptor: ScreenDescriptor) {
        closeOverlayWindow(for: context)

        let lightView = LightView(model: context.model)
        let hostingView = NSHostingView(rootView: lightView)
        let window = NSWindow(
            contentRect: descriptor.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: descriptor.screen
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
        applyEDRState(to: hostingView, isHDREnabled: context.model.isHDREnabled)
        window.setFrame(descriptor.frame, display: false)
        window.orderOut(nil)
        logger.info("Configured overlay display=\(descriptor.displayName, privacy: .public) targetFrame=\(NSStringFromRect(descriptor.frame), privacy: .public)")

        context.hostingView = hostingView
        context.overlayWindow = window
    }

    private func closeOverlayWindow(for context: DisplayContext) {
        context.overlayWindow?.orderOut(nil)
        context.overlayWindow?.contentView = nil
        context.overlayWindow?.close()
        context.overlayWindow = nil
        context.hostingView = nil
    }

    private func refreshOverlayVisibility() {
        for display in displays {
            refreshOverlayVisibility(for: display.persistentID)
        }
    }

    private func refreshOverlayVisibility(for persistentID: String) {
        guard let context = displayContexts[persistentID] else { return }

        if hasCompletedLaunch && context.model.isOn {
            showOverlayWindow(for: context)
        } else {
            logger.info("Hiding overlay display=\(context.model.displayName, privacy: .public) isOn=\(context.model.isOn)")
            context.overlayWindow?.orderOut(nil)
        }
    }

    private func showOverlayWindow(for context: DisplayContext) {
        context.hostingView?.layoutSubtreeIfNeeded()
        context.hostingView?.displayIfNeeded()
        context.overlayWindow?.contentView?.displayIfNeeded()
        context.overlayWindow?.orderFrontRegardless()
        context.overlayWindow?.displayIfNeeded()
        let actualFrame = context.overlayWindow.map { NSStringFromRect($0.frame) } ?? "nil"
        let actualScreen = context.overlayWindow?.screen?.localizedName ?? "nil"
        let isVisible = context.overlayWindow?.isVisible ?? false
        let occlusionStateRawValue = context.overlayWindow?.occlusionState.rawValue ?? 0
        logger.info(
            "Showed overlay display=\(context.model.displayName, privacy: .public) actualScreen=\(actualScreen, privacy: .public) actualFrame=\(actualFrame, privacy: .public) isOn=\(context.model.isOn) isVisible=\(isVisible) occlusionState=\(occlusionStateRawValue)"
        )
    }

    private func applyEDRState(for persistentID: String) {
        guard let context = displayContexts[persistentID], let hostingView = context.hostingView else { return }
        applyEDRState(to: hostingView, isHDREnabled: context.model.isHDREnabled)
    }

    private func applyEDRState(to hostingView: NSHostingView<LightView>, isHDREnabled: Bool) {
        guard #available(macOS 10.15, *) else { return }
        hostingView.layer?.wantsExtendedDynamicRangeContent = isHDREnabled
    }

    private func updateMouseLocation() {
        let mouseLocation = NSEvent.mouseLocation
        for display in displays {
            display.updateMouseLocation(mouseLocation)
        }
    }

    private func updateAnyDisplayOn() {
        anyDisplayOn = displays.contains(where: \.isOn)
    }

    private func loadPersistedDisplaySettings() -> [String: PersistedDisplaySettings] {
        guard let rawDictionary = userDefaults.dictionary(forKey: DefaultsKey.displaySettings) else {
            return [:]
        }

        var result: [String: PersistedDisplaySettings] = [:]
        for (persistentID, value) in rawDictionary {
            guard let dictionary = value as? [String: Any], let settings = PersistedDisplaySettings(dictionary: dictionary) else {
                continue
            }

            result[persistentID] = settings
        }

        return result
    }

    private func legacyDisplaySettings() -> PersistedDisplaySettings {
        let effectMode: LightEffectMode
        if
            let rawEffectMode = userDefaults.string(forKey: DefaultsKey.legacyEffectMode),
            let restoredEffectMode = LightEffectMode(rawValue: rawEffectMode)
        {
            effectMode = restoredEffectMode
        } else {
            effectMode = .normal
        }

        return PersistedDisplaySettings(
            isOn: userDefaults.object(forKey: DefaultsKey.legacyIsOn) as? Bool ?? true,
            brightness: clamped(
                userDefaults.object(forKey: DefaultsKey.legacyBrightness) as? Double ?? LightConfiguration.defaultBrightness,
                to: LightConfiguration.brightnessRange
            ),
            colorTemperature: clamped(
                userDefaults.object(forKey: DefaultsKey.legacyColorTemperature) as? Double ?? LightConfiguration.defaultColorTemperature,
                to: LightConfiguration.colorTemperatureRange
            ),
            hdrPreference: userDefaults.object(forKey: DefaultsKey.legacyHDRPreference) as? Bool ?? true,
            borderWidth: clamped(
                CGFloat(userDefaults.object(forKey: DefaultsKey.legacyBorderWidth) as? Double ?? Double(LightConfiguration.defaultBorderWidth)),
                to: LightConfiguration.borderWidthRange
            ),
            effectMode: effectMode,
            primaryDirectionalLightAngle: clamped(
                userDefaults.object(forKey: DefaultsKey.legacyPrimaryDirectionalLightAngle) as? Double
                    ?? LightConfiguration.defaultPrimaryDirectionalLightAngle,
                to: LightConfiguration.directionalLightAngleRange
            ),
            secondaryDirectionalLightAngle: clamped(
                userDefaults.object(forKey: DefaultsKey.legacySecondaryDirectionalLightAngle) as? Double
                    ?? LightConfiguration.defaultSecondaryDirectionalLightAngle,
                to: LightConfiguration.directionalLightAngleRange
            )
        )
    }

    private func persist(_ display: LightViewModel) {
        persistedDisplaySettings[display.persistentID] = PersistedDisplaySettings(model: display)

        var rawDictionary: [String: [String: Any]] = [:]
        for (persistentID, settings) in persistedDisplaySettings {
            rawDictionary[persistentID] = settings.dictionaryValue
        }

        userDefaults.set(rawDictionary, forKey: DefaultsKey.displaySettings)
    }

    private func persistentDisplayID(for displayID: CGDirectDisplayID) -> String {
        if let uuid = CGDisplayCreateUUIDFromDisplayID(displayID)?.takeRetainedValue() {
            return CFUUIDCreateString(nil, uuid) as String
        }

        return "display-\(displayID)"
    }

    private func displayID(for screen: NSScreen) -> CGDirectDisplayID {
        screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID ?? 0
    }

    private func clamped<T: Comparable>(_ value: T, to range: ClosedRange<T>) -> T {
        min(range.upperBound, max(range.lowerBound, value))
    }
}
