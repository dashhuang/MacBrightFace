import AppKit
import Metal
import MetalKit
import SwiftUI

struct MetalLightView: NSViewRepresentable {
    @ObservedObject var model: LightViewModel

    private static let defaultDevice = MTLCreateSystemDefaultDevice()
    private static let pipelineStateLock = NSLock()
    private static var pipelineStateCache: [String: MTLRenderPipelineState] = [:]
    private static var failedPipelineStateKeys: Set<String> = []

    static var isAvailable: Bool {
        guard let defaultDevice else { return false }
        return pipelineState(device: defaultDevice) != nil
    }

    static var shouldRenderOverlays: Bool {
        !ProcessInfo.processInfo.arguments.contains("--debug-use-swiftui-light-renderer") && isAvailable
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero, device: context.coordinator.device)
        view.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        view.colorPixelFormat = .rgba16Float
        view.colorspace = CGColorSpace(name: CGColorSpace.extendedSRGB)
        view.framebufferOnly = true
        view.wantsLayer = true
        view.layer?.isOpaque = false
        view.layer?.backgroundColor = NSColor.clear.cgColor
        view.layer?.wantsExtendedDynamicRangeContent = model.isHDREnabled

        if let metalLayer = view.layer as? CAMetalLayer {
            metalLayer.isOpaque = false
            metalLayer.pixelFormat = .rgba16Float
            metalLayer.colorspace = CGColorSpace(name: CGColorSpace.extendedSRGB)
        }

        context.coordinator.update(model: model)
        configureFrameTiming(for: view, model: model)
        view.delegate = context.coordinator
        view.needsDisplay = true
        return view
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        nsView.layer?.wantsExtendedDynamicRangeContent = model.isHDREnabled
        context.coordinator.update(model: model)
        configureFrameTiming(for: nsView, model: model)
        if nsView.isPaused {
            nsView.setNeedsDisplay(nsView.bounds)
        }
    }

    @MainActor
    private func configureFrameTiming(for view: MTKView, model: LightViewModel) {
        let hasActivePointer = model.mouseLocation.map { model.screenFrame.contains($0) } ?? false
        let needsContinuousRedraw = model.effectMode.usesAnimatedTimeline || hasActivePointer

        view.preferredFramesPerSecond = hasActivePointer ? 60 : (model.effectMode.usesAnimatedTimeline ? 24 : 30)
        view.enableSetNeedsDisplay = !needsContinuousRedraw
        view.isPaused = !needsContinuousRedraw
    }

    final class Coordinator: NSObject, MTKViewDelegate {
        let device: MTLDevice?
        private let commandQueue: MTLCommandQueue?
        private let pipelineState: MTLRenderPipelineState?
        private var state = MetalLightState.empty
        private let stateLock = NSLock()
        private let startTime = CACurrentMediaTime()

        override init() {
            let device = MetalLightView.defaultDevice
            self.device = device
            self.commandQueue = device?.makeCommandQueue()
            self.pipelineState = device.flatMap { MetalLightView.pipelineState(device: $0) }
            super.init()
        }

        @MainActor
        func update(model: LightViewModel) {
            let nextState = MetalLightState(model: model)
            stateLock.lock()
            state = nextState
            stateLock.unlock()
        }

        private func currentState() -> MetalLightState {
            stateLock.lock()
            let currentState = state
            stateLock.unlock()
            return currentState
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

        func draw(in view: MTKView) {
            guard
                let commandQueue,
                let pipelineState,
                let commandBuffer = commandQueue.makeCommandBuffer(),
                let renderPassDescriptor = view.currentRenderPassDescriptor,
                let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
            else {
                return
            }

            var uniforms = currentState().uniforms(
                drawableSize: view.drawableSize,
                elapsedTime: CACurrentMediaTime() - startTime
            )

            renderEncoder.setRenderPipelineState(pipelineState)
            renderEncoder.setFragmentBytes(
                &uniforms,
                length: MemoryLayout<MetalLightUniforms>.stride,
                index: 0
            )
            renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
            renderEncoder.endEncoding()

            if let drawable = view.currentDrawable {
                commandBuffer.present(drawable)
            }

            commandBuffer.commit()
        }

    }

    private static func pipelineState(device: MTLDevice) -> MTLRenderPipelineState? {
        let cacheKey = "\(device.name)-\(MTLPixelFormat.rgba16Float.rawValue)"

        pipelineStateLock.lock()
        if let cachedPipelineState = pipelineStateCache[cacheKey] {
            pipelineStateLock.unlock()
            return cachedPipelineState
        }

        if failedPipelineStateKeys.contains(cacheKey) {
            pipelineStateLock.unlock()
            return nil
        }
        pipelineStateLock.unlock()

        do {
            let library = try device.makeDefaultLibrary(bundle: .main)
            guard
                let vertexFunction = library.makeFunction(name: "displayFillVertex"),
                let fragmentFunction = library.makeFunction(name: "displayFillFragment")
            else {
                return markPipelineStateFailed(
                    cacheKey: cacheKey,
                    message: "DisplayFill Metal renderer failed to find shader functions"
                )
            }

            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = vertexFunction
            descriptor.fragmentFunction = fragmentFunction
            descriptor.colorAttachments[0].pixelFormat = .rgba16Float
            let pipelineState = try device.makeRenderPipelineState(descriptor: descriptor)

            pipelineStateLock.lock()
            pipelineStateCache[cacheKey] = pipelineState
            pipelineStateLock.unlock()

            return pipelineState
        } catch {
            return markPipelineStateFailed(
                cacheKey: cacheKey,
                message: "DisplayFill Metal renderer failed to compile: \(error)"
            )
        }
    }

    private static func markPipelineStateFailed(cacheKey: String, message: String) -> MTLRenderPipelineState? {
        pipelineStateLock.lock()
        let shouldLog = failedPipelineStateKeys.insert(cacheKey).inserted
        pipelineStateLock.unlock()

        if shouldLog {
            NSLog(message)
        }

        return nil
    }
}

private struct MetalLightState {
    var screenFrame: CGRect
    var mouseLocation: CGPoint?
    var brightness: Float
    var colorTemperature: Float
    var borderWidth: Float
    var maxHDRFactor: Float
    var currentHDRFactor: Float
    var primaryDirectionalLightAngle: Float
    var secondaryDirectionalLightAngle: Float
    var effectMode: UInt32
    var isHDREnabled: UInt32

    static let empty = MetalLightState(
        screenFrame: .zero,
        mouseLocation: nil,
        brightness: Float(LightConfiguration.defaultBrightness),
        colorTemperature: Float(LightConfiguration.defaultColorTemperature),
        borderWidth: Float(LightConfiguration.defaultBorderWidth),
        maxHDRFactor: 1,
        currentHDRFactor: 1,
        primaryDirectionalLightAngle: Float(LightConfiguration.defaultPrimaryDirectionalLightAngle),
        secondaryDirectionalLightAngle: Float(LightConfiguration.defaultSecondaryDirectionalLightAngle),
        effectMode: 0,
        isHDREnabled: 0
    )

    @MainActor
    init(model: LightViewModel) {
        self.screenFrame = model.screenFrame
        self.mouseLocation = model.mouseLocation
        self.brightness = Float(model.brightness)
        self.colorTemperature = Float(model.colorTemperature)
        self.borderWidth = Float(model.borderWidth)
        self.maxHDRFactor = Float(model.maxHDRFactor)
        self.currentHDRFactor = Float(model.currentHDRFactor)
        self.primaryDirectionalLightAngle = Float(model.primaryDirectionalLightAngle)
        self.secondaryDirectionalLightAngle = Float(model.secondaryDirectionalLightAngle)
        self.effectMode = Self.effectModeID(for: model.effectMode)
        self.isHDREnabled = model.isHDREnabled ? 1 : 0
    }

    private init(
        screenFrame: CGRect,
        mouseLocation: CGPoint?,
        brightness: Float,
        colorTemperature: Float,
        borderWidth: Float,
        maxHDRFactor: Float,
        currentHDRFactor: Float,
        primaryDirectionalLightAngle: Float,
        secondaryDirectionalLightAngle: Float,
        effectMode: UInt32,
        isHDREnabled: UInt32
    ) {
        self.screenFrame = screenFrame
        self.mouseLocation = mouseLocation
        self.brightness = brightness
        self.colorTemperature = colorTemperature
        self.borderWidth = borderWidth
        self.maxHDRFactor = maxHDRFactor
        self.currentHDRFactor = currentHDRFactor
        self.primaryDirectionalLightAngle = primaryDirectionalLightAngle
        self.secondaryDirectionalLightAngle = secondaryDirectionalLightAngle
        self.effectMode = effectMode
        self.isHDREnabled = isHDREnabled
    }

    func uniforms(drawableSize: CGSize, elapsedTime: TimeInterval) -> MetalLightUniforms {
        let width = max(1, Float(drawableSize.width))
        let height = max(1, Float(drawableSize.height))
        let pointWidth = max(1, Float(screenFrame.width))
        let pointHeight = max(1, Float(screenFrame.height))
        let scaleX = width / pointWidth
        let scaleY = height / pointHeight
        let scale = min(scaleX, scaleY)
        let localMouse: SIMD2<Float>
        let hasMouse: UInt32

        if let mouseLocation, screenFrame.contains(mouseLocation) {
            localMouse = SIMD2<Float>(
                Float(mouseLocation.x - screenFrame.minX + LightConfiguration.pointerVisualCenterOffsetX) * scaleX,
                Float(screenFrame.height - (mouseLocation.y - screenFrame.minY) + LightConfiguration.pointerVisualCenterOffsetY) * scaleY
            )
            hasMouse = 1
        } else {
            localMouse = SIMD2<Float>(-10_000, -10_000)
            hasMouse = 0
        }

        return MetalLightUniforms(
            viewportSize: SIMD2<Float>(width, height),
            mousePosition: localMouse,
            time: Float(elapsedTime),
            brightness: brightness,
            colorTemperature: colorTemperature,
            borderWidth: borderWidth * scale,
            maxHDRFactor: maxHDRFactor,
            currentHDRFactor: currentHDRFactor,
            primaryAngle: primaryDirectionalLightAngle,
            secondaryAngle: secondaryDirectionalLightAngle,
            pointerRadius: Float(LightConfiguration.pointerCutoutRadius) * scale,
            pointerFeather: Float(LightConfiguration.pointerCutoutFeather) * scale,
            screenScale: scale,
            professionalPrimaryEnergy: Float(LightConfiguration.professionalPrimaryLightEnergy),
            professionalSecondaryEnergy: Float(LightConfiguration.professionalSecondaryLightEnergy),
            professionalRingScale: Float(LightConfiguration.professionalRingBrightnessScale),
            professionalKeyHDRIntensityBoost: Float(LightConfiguration.professionalKeyHDRIntensityBoost),
            effectMode: effectMode,
            hasMouse: hasMouse,
            isHDREnabled: isHDREnabled,
            _padding: 0
        )
    }

    private static func effectModeID(for mode: LightEffectMode) -> UInt32 {
        switch mode {
        case .normal:
            return 0
        case .professional:
            return 1
        case .police:
            return 2
        case .fireTruck:
            return 3
        case .campfire:
            return 4
        case .disco:
            return 5
        }
    }
}

private struct MetalLightUniforms {
    var viewportSize: SIMD2<Float>
    var mousePosition: SIMD2<Float>
    var time: Float
    var brightness: Float
    var colorTemperature: Float
    var borderWidth: Float
    var maxHDRFactor: Float
    var currentHDRFactor: Float
    var primaryAngle: Float
    var secondaryAngle: Float
    var pointerRadius: Float
    var pointerFeather: Float
    var screenScale: Float
    var professionalPrimaryEnergy: Float
    var professionalSecondaryEnergy: Float
    var professionalRingScale: Float
    var professionalKeyHDRIntensityBoost: Float
    var effectMode: UInt32
    var hasMouse: UInt32
    var isHDREnabled: UInt32
    var _padding: UInt32
}
