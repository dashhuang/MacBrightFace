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
    @Published private(set) var isHDREnabled = false
    @Published private(set) var hasHDRDisplay = false
    @Published private(set) var borderWidth = LightConfiguration.defaultBorderWidth

    private struct EdgeWindow {
        let displayID: CGDirectDisplayID
        let edge: ScreenEdge
        let window: NSWindow
        let hostingView: NSHostingView<LightView>
    }

    private enum ScreenEdge: CaseIterable {
        case top
        case bottom
        case left
        case right
    }

    private var edgeWindows: [EdgeWindow] = []
    private var maxHDRBrightness = 1.0
    private var lastScreenLayout: [ScreenLayoutSignature] = []
    private let lightViewModel = LightViewModel(
        brightness: LightConfiguration.defaultBrightness,
        isHDREnabled: false,
        maxHDRFactor: 1.0
    )

    init() {
        refreshDisplayCapabilities()
        syncLightViewModel()
        lastScreenLayout = captureScreenLayout()
        rebuildWindows()
        observeScreenChanges()
    }

    func turnOn() {
        guard !isOn else { return }
        isOn = true
        edgeWindows.forEach { $0.window.orderFront(nil) }
    }

    func turnOff() {
        guard isOn else { return }
        isOn = false
        edgeWindows.forEach { $0.window.orderOut(nil) }
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

    func setBorderWidth(_ value: CGFloat) {
        let clampedValue = min(LightConfiguration.borderWidthRange.upperBound, max(LightConfiguration.borderWidthRange.lowerBound, value))
        guard abs(borderWidth - clampedValue) > 1.0 else { return }

        borderWidth = clampedValue
        updateWindowFrames()
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

    @objc private func handleScreenParametersDidChange(_ notification: Notification) {
        let previousLayout = lastScreenLayout
        let wasHDREnabled = isHDREnabled

        refreshDisplayCapabilities()
        let currentLayout = captureScreenLayout()
        lastScreenLayout = currentLayout

        if !hasHDRDisplay {
            isHDREnabled = false
        } else if wasHDREnabled {
            isHDREnabled = true
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
            for edge in ScreenEdge.allCases {
                if let edgeWindow = makeEdgeWindow(for: screen, edge: edge) {
                    edgeWindows.append(edgeWindow)
                }
            }
        }

        if shouldRemainVisible {
            edgeWindows.forEach { $0.window.orderFront(nil) }
        }
    }

    private func closeAllWindows() {
        edgeWindows.forEach { edgeWindow in
            edgeWindow.window.orderOut(nil)
            edgeWindow.window.contentView = nil
            edgeWindow.window.close()
        }
        edgeWindows.removeAll()
    }

    private func makeEdgeWindow(for screen: NSScreen, edge: ScreenEdge) -> EdgeWindow? {
        let frame = frame(for: screen, edge: edge)
        guard frame.width >= 1, frame.height >= 1 else {
            return nil
        }

        let lightView = makeLightView()
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

        return EdgeWindow(
            displayID: displayID(for: screen),
            edge: edge,
            window: window,
            hostingView: hostingView
        )
    }

    private func frame(for screen: NSScreen, edge: ScreenEdge) -> NSRect {
        let availableFrame = screen.visibleFrame
        let width = min(borderWidth, availableFrame.width / 2)
        let height = min(borderWidth, availableFrame.height / 2)
        let verticalSpan = max(LightConfiguration.minimumSideWindowLength, availableFrame.height - (height * 2))

        switch edge {
        case .top:
            return NSRect(
                x: availableFrame.minX,
                y: availableFrame.maxY - height,
                width: availableFrame.width,
                height: height
            )

        case .bottom:
            return NSRect(
                x: availableFrame.minX,
                y: availableFrame.minY,
                width: availableFrame.width,
                height: height
            )

        case .left:
            return NSRect(
                x: availableFrame.minX,
                y: availableFrame.minY + height,
                width: width,
                height: verticalSpan
            )

        case .right:
            return NSRect(
                x: availableFrame.maxX - width,
                y: availableFrame.minY + height,
                width: width,
                height: verticalSpan
            )
        }
    }

    private func updateWindowFrames() {
        let screensByID = Dictionary(uniqueKeysWithValues: NSScreen.screens.map { (displayID(for: $0), $0) })

        for edgeWindow in edgeWindows {
            guard let screen = screensByID[edgeWindow.displayID] else { continue }

            edgeWindow.window.setFrame(frame(for: screen, edge: edgeWindow.edge), display: true)
        }
    }

    private func refreshEDRState() {
        for edgeWindow in edgeWindows {
            applyEDRState(to: edgeWindow.hostingView)
        }
    }

    private func makeLightView() -> LightView {
        LightView(model: lightViewModel)
    }

    private func applyEDRState(to hostingView: NSHostingView<LightView>) {
        guard #available(macOS 10.15, *) else { return }

        hostingView.layer?.wantsExtendedDynamicRangeContent = isHDREnabled
    }

    private func syncLightViewModel() {
        lightViewModel.update(
            brightness: brightness,
            isHDREnabled: isHDREnabled,
            maxHDRFactor: maxHDRBrightness
        )
    }

    private func displayID(for screen: NSScreen) -> CGDirectDisplayID {
        screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID ?? 0
    }
}
