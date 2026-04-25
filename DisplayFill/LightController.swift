import AppKit
import ColorSync
import OSLog
import SwiftUI

@MainActor
final class LightController: ObservableObject {
    private let logger = Logger(subsystem: "cn.huang.dash.DisplayFill", category: "Overlays")
    private enum DefaultsKey {
        static let displaySettings = "cn.huang.dash.DisplayFill.displaySettings"
        static let initialControlPanelsShown = "cn.huang.dash.DisplayFill.initialControlPanelsShown"
        static let legacyIsOn = "cn.huang.dash.DisplayFill.isOn"
        static let legacyBrightness = "cn.huang.dash.DisplayFill.brightness"
        static let legacyColorTemperature = "cn.huang.dash.DisplayFill.colorTemperature"
        static let legacyHDRPreference = "cn.huang.dash.DisplayFill.hdrPreference"
        static let legacyBorderWidth = "cn.huang.dash.DisplayFill.borderWidth"
        static let legacyEffectMode = "cn.huang.dash.DisplayFill.effectMode"
        static let legacyPrimaryDirectionalLightAngle = "cn.huang.dash.DisplayFill.primaryDirectionalLightAngle"
        static let legacySecondaryDirectionalLightAngle = "cn.huang.dash.DisplayFill.secondaryDirectionalLightAngle"
    }

    private enum OldDefaultsKey {
        static let suiteName = "cn.huang.dash.MacBrightFace"
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
        let currentHDRFactor: Double
        let screen: NSScreen
    }

    private struct HDRHeadroom {
        let maxHDRFactor: Double
        let currentHDRFactor: Double

        var hasHDRDisplay: Bool {
            maxHDRFactor > 1.0
        }
    }

    private struct HDRHeadroomSnapshot: Equatable {
        let displayName: String
        let maxHDRFactor: Double
        let currentHDRFactor: Double
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
    private var edrRefreshTimer: Timer?
    private var pointerRefreshTimer: Timer?
    private var pointerTrackedDisplayID: String?
    private var lastLoggedHDRHeadroom: [String: HDRHeadroomSnapshot] = [:]
    private var lastLoggedHDRHeadroomTimes: [String: TimeInterval] = [:]
    private let userDefaults = UserDefaults.standard
    private let oldUserDefaults = UserDefaults(suiteName: OldDefaultsKey.suiteName)
    private var persistedDisplaySettings: [String: PersistedDisplaySettings] = [:]
    private var hasCompletedLaunch = false
    private var shouldPresentInitialControlPanels = false

    init() {
        shouldPresentInitialControlPanels = shouldShowInitialControlPanelsForFreshConfiguration()
        migrateDefaultsFromPreviousBundleIdentifierIfNeeded()
        persistedDisplaySettings = loadPersistedDisplaySettings()
        lastScreenLayout = captureScreenLayout()
        rebuildDisplayContexts()
        observeScreenChanges()
        observeMouseLocation()
        observeEDRHeadroom()
    }

    deinit {
        if let globalMouseMonitor {
            NSEvent.removeMonitor(globalMouseMonitor)
        }

        if let localMouseMonitor {
            NSEvent.removeMonitor(localMouseMonitor)
        }

        edrRefreshTimer?.invalidate()
        pointerRefreshTimer?.invalidate()
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

    func consumeInitialControlPanelPresentationIfNeeded() -> Bool {
        guard shouldPresentInitialControlPanels else { return false }

        shouldPresentInitialControlPanels = false
        userDefaults.set(true, forKey: DefaultsKey.initialControlPanelsShown)
        return true
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

        let removedDisplayIDs = displayContexts.keys.filter { !descriptorIDs.contains($0) }
        for persistentID in removedDisplayIDs {
            if let context = displayContexts[persistentID] {
                closeOverlayWindow(for: context)
                displayContexts.removeValue(forKey: persistentID)
            }
        }

        if let pointerTrackedDisplayID, !descriptorIDs.contains(pointerTrackedDisplayID) {
            self.pointerTrackedDisplayID = nil
            updatePointerRefreshTimer(isActive: false)
        }

        for descriptor in descriptors {
            let context = displayContexts[descriptor.persistentID] ?? makeDisplayContext(for: descriptor)
            update(context.model, with: descriptor)
            configureOverlayWindow(for: context, descriptor: descriptor)
            displayContexts[descriptor.persistentID] = context
        }

        displays = descriptors.compactMap { displayContexts[$0.persistentID]?.model }
        logHDRHeadroomIfNeeded(for: descriptors)
        updateAnyDisplayOn()
    }

    private func screenDescriptors() -> [ScreenDescriptor] {
        NSScreen.screens
            .map { screen in
                let displayID = displayID(for: screen)
                let persistentID = persistentDisplayID(for: displayID)
                let hdrHeadroom = hdrHeadroom(for: screen)

                return ScreenDescriptor(
                    persistentID: persistentID,
                    displayID: displayID,
                    displayName: screen.localizedName,
                    frame: screen.frame,
                    visibleFrame: screen.visibleFrame,
                    hasHDRDisplay: hdrHeadroom.hasHDRDisplay,
                    maxHDRFactor: hdrHeadroom.maxHDRFactor,
                    currentHDRFactor: hdrHeadroom.currentHDRFactor,
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

    private func hdrHeadroom(for screen: NSScreen) -> HDRHeadroom {
        guard #available(macOS 11.0, *) else {
            return HDRHeadroom(maxHDRFactor: 1.0, currentHDRFactor: 1.0)
        }

        return HDRHeadroom(
            maxHDRFactor: max(1.0, screen.maximumPotentialExtendedDynamicRangeColorComponentValue),
            currentHDRFactor: max(1.0, screen.maximumExtendedDynamicRangeColorComponentValue)
        )
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
            currentHDRFactor: descriptor.currentHDRFactor,
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
        model.currentHDRFactor = descriptor.currentHDRFactor
        model.isHDREnabled = descriptor.hasHDRDisplay && model.preferredHDREnabled
    }

    private func configureOverlayWindow(for context: DisplayContext, descriptor: ScreenDescriptor) {
        if context.overlayWindow == nil || context.hostingView == nil {
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

            window.contentView = hostingView
            hostingView.wantsLayer = true

            context.hostingView = hostingView
            context.overlayWindow = window
        }

        guard let window = context.overlayWindow, let hostingView = context.hostingView else { return }

        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.isMovableByWindowBackground = false
        window.level = .mainMenu
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        applyEDRState(to: hostingView, isHDREnabled: context.model.isHDREnabled)
        window.setFrame(descriptor.frame, display: false)
        window.orderOut(nil)
        logger.info("Configured overlay display=\(descriptor.displayName, privacy: .public) targetFrame=\(NSStringFromRect(descriptor.frame), privacy: .public)")
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
        let usesMetalRenderer = MetalLightView.shouldRenderOverlays
        let activeDisplay = displays.first { display in
            let shouldTrackMouse = usesMetalRenderer || !display.isHDREnabled || display.maxHDRFactor >= 8.0
            return shouldTrackMouse && display.screenFrame.contains(mouseLocation)
        }
        let activeDisplayID = activeDisplay?.persistentID

        if pointerTrackedDisplayID != activeDisplayID, let previousDisplayID = pointerTrackedDisplayID {
            displayContexts[previousDisplayID]?.model.updateMouseLocation(nil)
        }

        activeDisplay?.updateMouseLocation(mouseLocation)
        pointerTrackedDisplayID = activeDisplayID

        let needsPointerRefresh = activeDisplay?.isOn == true && usesMetalRenderer
        updatePointerRefreshTimer(isActive: needsPointerRefresh)
    }

    private func updatePointerRefreshTimer(isActive: Bool) {
        if isActive {
            guard pointerRefreshTimer == nil else { return }

            let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.updateMouseLocation()
                }
            }
            RunLoop.main.add(timer, forMode: .common)
            pointerRefreshTimer = timer
        } else {
            pointerRefreshTimer?.invalidate()
            pointerRefreshTimer = nil
        }
    }

    private func observeEDRHeadroom() {
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshCurrentHDRFactors()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        edrRefreshTimer = timer
        refreshCurrentHDRFactors()
    }

    private func refreshCurrentHDRFactors() {
        guard !displays.isEmpty else { return }

        let snapshots = currentHDRHeadroomSnapshotsByPersistentID()
        for display in displays {
            guard let snapshot = snapshots[display.persistentID] else { continue }

            let renderHDRFactor = renderHDRFactor(
                currentDisplayFactor: display.currentHDRFactor,
                rawDisplayFactor: snapshot.currentHDRFactor
            )
            if abs(display.currentHDRFactor - renderHDRFactor) > 0.01 {
                display.currentHDRFactor = renderHDRFactor
            }

            guard snapshot.maxHDRFactor > 1.0 else { continue }
            logHDRHeadroomIfNeeded(
                persistentID: display.persistentID,
                displayName: snapshot.displayName,
                maxHDRFactor: snapshot.maxHDRFactor,
                currentHDRFactor: snapshot.currentHDRFactor
            )
        }
    }

    private func renderHDRFactor(currentDisplayFactor: Double, rawDisplayFactor: Double) -> Double {
        let clampedRawFactor = max(1.0, rawDisplayFactor)

        if clampedRawFactor <= 1.01, currentDisplayFactor > 1.01 {
            return currentDisplayFactor
        }

        return clampedRawFactor
    }

    private func currentHDRHeadroomSnapshotsByPersistentID() -> [String: HDRHeadroomSnapshot] {
        var snapshots: [String: HDRHeadroomSnapshot] = [:]
        for screen in NSScreen.screens {
            let displayID = displayID(for: screen)
            let persistentID = persistentDisplayID(for: displayID)
            let headroom = hdrHeadroom(for: screen)
            snapshots[persistentID] = HDRHeadroomSnapshot(
                displayName: screen.localizedName,
                maxHDRFactor: headroom.maxHDRFactor,
                currentHDRFactor: headroom.currentHDRFactor
            )
        }
        return snapshots
    }

    private func logHDRHeadroomIfNeeded(for descriptors: [ScreenDescriptor]) {
        for descriptor in descriptors where descriptor.hasHDRDisplay {
            logHDRHeadroomIfNeeded(
                persistentID: descriptor.persistentID,
                displayName: descriptor.displayName,
                maxHDRFactor: descriptor.maxHDRFactor,
                currentHDRFactor: descriptor.currentHDRFactor
            )
        }
    }

    private func logHDRHeadroomIfNeeded(
        persistentID: String,
        displayName: String,
        maxHDRFactor: Double,
        currentHDRFactor: Double
    ) {
        let snapshot = HDRHeadroomSnapshot(
            displayName: displayName,
            maxHDRFactor: maxHDRFactor,
            currentHDRFactor: currentHDRFactor
        )

        if
            let previousSnapshot = lastLoggedHDRHeadroom[persistentID],
            previousSnapshot.displayName == snapshot.displayName
        {
            let now = Date().timeIntervalSinceReferenceDate
            let lastLoggedAt = lastLoggedHDRHeadroomTimes[persistentID] ?? 0
            let potentialChanged = abs(previousSnapshot.maxHDRFactor - snapshot.maxHDRFactor) > 0.01
            let currentChangedEnough = abs(previousSnapshot.currentHDRFactor - snapshot.currentHDRFactor) > 0.25
            let isThrottled = now - lastLoggedAt < 0.75

            if !potentialChanged && (!currentChangedEnough || isThrottled) {
                return
            }
        }

        lastLoggedHDRHeadroom[persistentID] = snapshot
        lastLoggedHDRHeadroomTimes[persistentID] = Date().timeIntervalSinceReferenceDate
        logger.info(
            "HDR headroom display=\(displayName, privacy: .public) potential=\(maxHDRFactor, privacy: .public) current=\(currentHDRFactor, privacy: .public)"
        )
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

    private func shouldShowInitialControlPanelsForFreshConfiguration() -> Bool {
        guard userDefaults.object(forKey: DefaultsKey.initialControlPanelsShown) == nil else {
            return false
        }

        return !hasAnyStoredLightConfiguration()
    }

    private func hasAnyStoredLightConfiguration() -> Bool {
        let currentKeys = [
            DefaultsKey.displaySettings,
            DefaultsKey.legacyIsOn,
            DefaultsKey.legacyBrightness,
            DefaultsKey.legacyColorTemperature,
            DefaultsKey.legacyHDRPreference,
            DefaultsKey.legacyBorderWidth,
            DefaultsKey.legacyEffectMode,
            DefaultsKey.legacyPrimaryDirectionalLightAngle,
            DefaultsKey.legacySecondaryDirectionalLightAngle
        ]
        if currentKeys.contains(where: { userDefaults.object(forKey: $0) != nil }) {
            return true
        }

        let oldKeys = [
            OldDefaultsKey.displaySettings,
            OldDefaultsKey.legacyIsOn,
            OldDefaultsKey.legacyBrightness,
            OldDefaultsKey.legacyColorTemperature,
            OldDefaultsKey.legacyHDRPreference,
            OldDefaultsKey.legacyBorderWidth,
            OldDefaultsKey.legacyEffectMode,
            OldDefaultsKey.legacyPrimaryDirectionalLightAngle,
            OldDefaultsKey.legacySecondaryDirectionalLightAngle
        ]
        return oldKeys.contains { oldUserDefaults?.object(forKey: $0) != nil }
    }

    private func legacyDisplaySettings() -> PersistedDisplaySettings {
        let effectMode: LightEffectMode
        if
            let rawEffectMode = legacyString(forKey: DefaultsKey.legacyEffectMode, oldKey: OldDefaultsKey.legacyEffectMode),
            let restoredEffectMode = LightEffectMode(rawValue: rawEffectMode)
        {
            effectMode = restoredEffectMode
        } else {
            effectMode = .normal
        }

        return PersistedDisplaySettings(
            isOn: legacyObject(forKey: DefaultsKey.legacyIsOn, oldKey: OldDefaultsKey.legacyIsOn) as? Bool ?? true,
            brightness: clamped(
                legacyObject(forKey: DefaultsKey.legacyBrightness, oldKey: OldDefaultsKey.legacyBrightness) as? Double
                    ?? LightConfiguration.defaultBrightness,
                to: LightConfiguration.brightnessRange
            ),
            colorTemperature: clamped(
                legacyObject(forKey: DefaultsKey.legacyColorTemperature, oldKey: OldDefaultsKey.legacyColorTemperature) as? Double
                    ?? LightConfiguration.defaultColorTemperature,
                to: LightConfiguration.colorTemperatureRange
            ),
            hdrPreference: legacyObject(forKey: DefaultsKey.legacyHDRPreference, oldKey: OldDefaultsKey.legacyHDRPreference) as? Bool ?? true,
            borderWidth: clamped(
                CGFloat(
                    legacyObject(forKey: DefaultsKey.legacyBorderWidth, oldKey: OldDefaultsKey.legacyBorderWidth) as? Double
                        ?? Double(LightConfiguration.defaultBorderWidth)
                ),
                to: LightConfiguration.borderWidthRange
            ),
            effectMode: effectMode,
            primaryDirectionalLightAngle: clamped(
                legacyObject(forKey: DefaultsKey.legacyPrimaryDirectionalLightAngle, oldKey: OldDefaultsKey.legacyPrimaryDirectionalLightAngle) as? Double
                    ?? LightConfiguration.defaultPrimaryDirectionalLightAngle,
                to: LightConfiguration.directionalLightAngleRange
            ),
            secondaryDirectionalLightAngle: clamped(
                legacyObject(forKey: DefaultsKey.legacySecondaryDirectionalLightAngle, oldKey: OldDefaultsKey.legacySecondaryDirectionalLightAngle) as? Double
                    ?? LightConfiguration.defaultSecondaryDirectionalLightAngle,
                to: LightConfiguration.directionalLightAngleRange
            )
        )
    }

    private func migrateDefaultsFromPreviousBundleIdentifierIfNeeded() {
        guard userDefaults.object(forKey: DefaultsKey.displaySettings) == nil else { return }

        if let rawDictionary = oldUserDefaults?.dictionary(forKey: OldDefaultsKey.displaySettings) {
            userDefaults.set(rawDictionary, forKey: DefaultsKey.displaySettings)
        }
    }

    private func legacyObject(forKey key: String, oldKey: String) -> Any? {
        userDefaults.object(forKey: key) ?? oldUserDefaults?.object(forKey: oldKey)
    }

    private func legacyString(forKey key: String, oldKey: String) -> String? {
        userDefaults.string(forKey: key) ?? oldUserDefaults?.string(forKey: oldKey)
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
