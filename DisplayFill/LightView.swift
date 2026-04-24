import AppKit
import SwiftUI

@MainActor
final class LightViewModel: ObservableObject {
    let persistentID: String
    @Published var displayID: CGDirectDisplayID
    @Published var displayName: String
    @Published var screenFrame: CGRect
    @Published var visibleFrame: CGRect
    @Published var isOn: Bool
    @Published var brightness: Double
    @Published var colorTemperature: Double
    @Published var isHDREnabled: Bool
    @Published var hasHDRDisplay: Bool
    @Published var maxHDRFactor: Double
    @Published var borderWidth: CGFloat
    @Published var effectMode: LightEffectMode
    @Published var primaryDirectionalLightAngle: Double
    @Published var secondaryDirectionalLightAngle: Double
    @Published var mouseLocation: CGPoint?
    var preferredHDREnabled: Bool

    init(
        persistentID: String,
        displayID: CGDirectDisplayID,
        displayName: String,
        screenFrame: CGRect,
        visibleFrame: CGRect,
        isOn: Bool,
        brightness: Double,
        colorTemperature: Double,
        isHDREnabled: Bool,
        hasHDRDisplay: Bool,
        preferredHDREnabled: Bool,
        maxHDRFactor: Double,
        borderWidth: CGFloat,
        effectMode: LightEffectMode,
        primaryDirectionalLightAngle: Double,
        secondaryDirectionalLightAngle: Double,
        mouseLocation: CGPoint? = nil
    ) {
        self.persistentID = persistentID
        self.displayID = displayID
        self.displayName = displayName
        self.screenFrame = screenFrame
        self.visibleFrame = visibleFrame
        self.isOn = isOn
        self.brightness = brightness
        self.colorTemperature = colorTemperature
        self.isHDREnabled = isHDREnabled
        self.hasHDRDisplay = hasHDRDisplay
        self.preferredHDREnabled = preferredHDREnabled
        self.maxHDRFactor = maxHDRFactor
        self.borderWidth = borderWidth
        self.effectMode = effectMode
        self.primaryDirectionalLightAngle = primaryDirectionalLightAngle
        self.secondaryDirectionalLightAngle = secondaryDirectionalLightAngle
        self.mouseLocation = mouseLocation
    }

    func updateMouseLocation(_ mouseLocation: CGPoint?) {
        guard self.mouseLocation != mouseLocation else { return }
        self.mouseLocation = mouseLocation
    }
}

private struct LightRingShape: Shape {
    let thickness: CGFloat
    let cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let clampedThickness = max(1, min(thickness, min(rect.width, rect.height) / 2 - 1))
        let clampedCornerRadius = max(0, min(cornerRadius, min(rect.width, rect.height) / 2))
        let innerRect = rect.insetBy(dx: clampedThickness, dy: clampedThickness)
        let innerCornerRadius = max(0, clampedCornerRadius - clampedThickness)

        var path = Path()
        path.addRoundedRect(
            in: rect,
            cornerSize: CGSize(width: clampedCornerRadius, height: clampedCornerRadius),
            style: .continuous
        )

        if innerRect.width > 0, innerRect.height > 0 {
            path.addRoundedRect(
                in: innerRect,
                cornerSize: CGSize(width: innerCornerRadius, height: innerCornerRadius),
                style: .continuous
            )
        }

        return path
    }
}

private struct EffectFrameState {
    let leadingColor: (red: Double, green: Double, blue: Double)
    let trailingColor: (red: Double, green: Double, blue: Double)
    let leadingPower: Double
    let trailingPower: Double
    let ambientPower: Double
}

private enum EffectEdge {
    case leading
    case trailing
}

private enum DirectionalLightRole {
    case key
    case fill
}

struct LightView: View {
    @ObservedObject var model: LightViewModel

    private var clampedBrightness: Double {
        min(LightConfiguration.brightnessRange.upperBound, max(LightConfiguration.brightnessRange.lowerBound, model.brightness))
    }

    private var curvedBrightness: Double {
        pow(clampedBrightness, model.isHDREnabled ? 1.35 : 1.5)
    }

    private var clampedColorTemperature: Double {
        min(
            LightConfiguration.colorTemperatureRange.upperBound,
            max(LightConfiguration.colorTemperatureRange.lowerBound, model.colorTemperature)
        )
    }

    private var temperatureStrength: Double {
        abs(clampedColorTemperature - 0.5) * 2.0
    }

    private var warmLightColorComponents: (red: Double, green: Double, blue: Double) {
        (red: 1.0, green: 0.74, blue: 0.42)
    }

    private var neutralLightColorComponents: (red: Double, green: Double, blue: Double) {
        (red: 1.0, green: 0.985, blue: 0.965)
    }

    private var coolLightColorComponents: (red: Double, green: Double, blue: Double) {
        (red: 0.58, green: 0.79, blue: 1.0)
    }

    private func lightColor(
        red: Double,
        green: Double,
        blue: Double,
        opacity: Double,
        intensity: Double = 1.0
    ) -> Color {
        if model.isHDREnabled {
            let extendedRed = red * intensity
            let extendedGreen = green * intensity
            let extendedBlue = blue * intensity

            if
                let colorSpace = CGColorSpace(name: CGColorSpace.extendedSRGB),
                let cgColor = CGColor(
                    colorSpace: colorSpace,
                    components: [extendedRed, extendedGreen, extendedBlue, opacity]
                )
            {
                return Color(cgColor: cgColor)
            }
        }

        return Color(red: red, green: green, blue: blue, opacity: opacity)
    }

    private var hdrColorIntensity: Double {
        model.isHDREnabled ? max(1.0, targetIntensity) : 1.0
    }

    private var hdrLowHeadroomCompensation: Double {
        guard model.isHDREnabled else { return 0.0 }

        let headroom = max(1.0, model.maxHDRFactor)
        return min(1.0, max(0.0, (8.0 - headroom) / 4.0))
    }

    private var usesPointerCutout: Bool {
        !model.isHDREnabled || model.maxHDRFactor >= 8.0
    }

    private var baseLightColorComponents: (red: Double, green: Double, blue: Double) {
        func interpolate(_ start: Double, _ end: Double, progress: Double) -> Double {
            start + ((end - start) * progress)
        }

        if clampedColorTemperature <= 0.5 {
            let progress = clampedColorTemperature / 0.5
            return (
                red: interpolate(warmLightColorComponents.red, neutralLightColorComponents.red, progress: progress),
                green: interpolate(warmLightColorComponents.green, neutralLightColorComponents.green, progress: progress),
                blue: interpolate(warmLightColorComponents.blue, neutralLightColorComponents.blue, progress: progress)
            )
        }

        let progress = (clampedColorTemperature - 0.5) / 0.5
        return (
            red: interpolate(neutralLightColorComponents.red, coolLightColorComponents.red, progress: progress),
            green: interpolate(neutralLightColorComponents.green, coolLightColorComponents.green, progress: progress),
            blue: interpolate(neutralLightColorComponents.blue, coolLightColorComponents.blue, progress: progress)
        )
    }

    private var highlightLightColorComponents: (red: Double, green: Double, blue: Double) {
        if model.isHDREnabled {
            return baseLightColorComponents
        }

        let mixAmount = 0.36
        return (
            red: 1.0 - ((1.0 - baseLightColorComponents.red) * (1.0 - mixAmount)),
            green: 1.0 - ((1.0 - baseLightColorComponents.green) * (1.0 - mixAmount)),
            blue: 1.0 - ((1.0 - baseLightColorComponents.blue) * (1.0 - mixAmount))
        )
    }

    private var targetIntensity: Double {
        let maxIntensity = model.isHDREnabled ? max(1.0, model.maxHDRFactor) : LightConfiguration.standardMaxBrightness
        let baseCurve = 0.18 + (curvedBrightness * 0.82)
        let headroomCompensation = model.isHDREnabled ? 1.0 + (hdrLowHeadroomCompensation * 0.24) : 1.0
        return maxIntensity * baseCurve * headroomCompensation
    }

    private var baseOpacity: Double {
        if model.isHDREnabled {
            return min(
                1.0,
                0.20
                    + (curvedBrightness * (0.24 + (hdrLowHeadroomCompensation * 0.36)))
                    + (temperatureStrength * 0.06)
            )
        }

        return min(1.0, 0.24 + (curvedBrightness * 0.76))
    }

    private var highlightOpacity: Double {
        if model.isHDREnabled {
            return min(
                1.0,
                0.10
                    + (curvedBrightness * (0.14 + (hdrLowHeadroomCompensation * 0.12)))
                    + (temperatureStrength * 0.04)
            )
        }

        return min(1.0, 0.08 + (curvedBrightness * 0.28) + (targetIntensity * 0.10))
    }

    private var bloomOpacity: Double {
        if model.isHDREnabled {
            return min(
                1.0,
                0.10
                    + (curvedBrightness * (0.18 + (hdrLowHeadroomCompensation * 0.14)))
                    + (temperatureStrength * 0.05)
            )
        }

        return min(1.0, 0.06 + (curvedBrightness * 0.22))
    }

    private var coreBloomRadius: CGFloat {
        let baseRadius = model.isHDREnabled ? 26.0 : 20.0
        return max(10.0, baseRadius + (model.borderWidth * 0.10) - (clampedBrightness * 6.0))
    }

    private var outerBloomRadius: CGFloat {
        coreBloomRadius + (model.isHDREnabled ? 24.0 : 16.0)
    }

    private var brightnessAdjustment: Double {
        model.isHDREnabled ? 0.0 : targetIntensity * 0.14
    }

    private var contrastAdjustment: Double {
        model.isHDREnabled ? 1.0 : 1.0 + (targetIntensity * 0.06)
    }

    private var saturationAdjustment: Double {
        model.isHDREnabled ? 1.0 : 1.0 + (temperatureStrength * 0.10)
    }

    private var policeBlueColorComponents: (red: Double, green: Double, blue: Double) {
        (red: 0.12, green: 0.42, blue: 1.0)
    }

    private var policeRedColorComponents: (red: Double, green: Double, blue: Double) {
        (red: 1.0, green: 0.14, blue: 0.12)
    }

    private var fireRedColorComponents: (red: Double, green: Double, blue: Double) {
        (red: 1.0, green: 0.20, blue: 0.12)
    }

    private var fireAmberColorComponents: (red: Double, green: Double, blue: Double) {
        (red: 1.0, green: 0.58, blue: 0.08)
    }

    private var campfireGoldColorComponents: (red: Double, green: Double, blue: Double) {
        (red: 1.0, green: 0.76, blue: 0.18)
    }

    private var campfireOrangeColorComponents: (red: Double, green: Double, blue: Double) {
        (red: 1.0, green: 0.46, blue: 0.08)
    }

    private var campfireEmberColorComponents: (red: Double, green: Double, blue: Double) {
        (red: 0.92, green: 0.20, blue: 0.06)
    }

    private var discoMagentaColorComponents: (red: Double, green: Double, blue: Double) {
        (red: 1.0, green: 0.12, blue: 0.76)
    }

    private var discoCyanColorComponents: (red: Double, green: Double, blue: Double) {
        (red: 0.08, green: 0.95, blue: 1.0)
    }

    private var discoLimeColorComponents: (red: Double, green: Double, blue: Double) {
        (red: 0.55, green: 1.0, blue: 0.18)
    }

    private var discoVioletColorComponents: (red: Double, green: Double, blue: Double) {
        (red: 0.54, green: 0.24, blue: 1.0)
    }

    private func blendedColorComponents(
        _ lhs: (red: Double, green: Double, blue: Double),
        _ rhs: (red: Double, green: Double, blue: Double),
        amount: Double
    ) -> (red: Double, green: Double, blue: Double) {
        let clampedAmount = min(1.0, max(0.0, amount))
        let inverse = 1.0 - clampedAmount
        return (
            red: (lhs.red * inverse) + (rhs.red * clampedAmount),
            green: (lhs.green * inverse) + (rhs.green * clampedAmount),
            blue: (lhs.blue * inverse) + (rhs.blue * clampedAmount)
        )
    }

    private func flashStrength(phase: Double, start: Double, duration: Double) -> Double {
        guard phase >= start, phase <= start + duration else {
            return 0.0
        }

        let progress = (phase - start) / duration
        let triangle = 1.0 - abs((progress * 2.0) - 1.0)
        return triangle * triangle * (3.0 - (2.0 * triangle))
    }

    private func sequenceStrength(phase: Double, starts: [Double], duration: Double) -> Double {
        starts.reduce(0.0) { currentMaximum, start in
            max(currentMaximum, flashStrength(phase: phase, start: start, duration: duration))
        }
    }

    private func paletteColor(
        from palette: [(red: Double, green: Double, blue: Double)],
        progress: Double
    ) -> (red: Double, green: Double, blue: Double) {
        guard !palette.isEmpty else {
            return baseLightColorComponents
        }

        let normalized = progress - floor(progress)
        let scaled = normalized * Double(palette.count)
        let index = Int(floor(scaled)) % palette.count
        let nextIndex = (index + 1) % palette.count
        let blend = scaled - Double(index)

        return blendedColorComponents(palette[index], palette[nextIndex], amount: blend)
    }

    private func effectFrameState(at time: TimeInterval) -> EffectFrameState {
        switch model.effectMode {
        case .normal:
            return EffectFrameState(
                leadingColor: baseLightColorComponents,
                trailingColor: baseLightColorComponents,
                leadingPower: 0.0,
                trailingPower: 0.0,
                ambientPower: 0.0
            )
        case .professional:
            return EffectFrameState(
                leadingColor: baseLightColorComponents,
                trailingColor: baseLightColorComponents,
                leadingPower: 0.0,
                trailingPower: 0.0,
                ambientPower: 0.0
            )
        case .police:
            let cycle = 1.18
            let phase = time.truncatingRemainder(dividingBy: cycle)
            let leadingPower = sequenceStrength(phase: phase, starts: [0.02, 0.16], duration: 0.12)
            let trailingPower = sequenceStrength(phase: phase, starts: [0.62, 0.76], duration: 0.12)
            let ambientPower = 0.08 + (max(leadingPower, trailingPower) * 0.18)

            return EffectFrameState(
                leadingColor: policeBlueColorComponents,
                trailingColor: policeRedColorComponents,
                leadingPower: leadingPower,
                trailingPower: trailingPower,
                ambientPower: ambientPower
            )
        case .fireTruck:
            let cycle = 1.52
            let phase = time.truncatingRemainder(dividingBy: cycle)
            let leadingPower = sequenceStrength(phase: phase, starts: [0.00, 0.18, 0.36], duration: 0.14)
            let trailingBurst = sequenceStrength(phase: phase, starts: [0.90], duration: 0.24)
            let trailingPower = min(1.0, 0.18 + (trailingBurst * 0.82))
            let ambientPower = 0.14 + (max(leadingPower, trailingPower * 0.75) * 0.16)

            return EffectFrameState(
                leadingColor: fireRedColorComponents,
                trailingColor: fireAmberColorComponents,
                leadingPower: leadingPower,
                trailingPower: trailingPower,
                ambientPower: ambientPower
            )
        case .campfire:
            let flameDrift = 0.5 + (sin(time * 1.18) * 0.5)
            let flickerA = 0.5 + (sin((time * 4.6) + 0.8) * 0.5)
            let flickerB = 0.5 + (sin((time * 7.9) + 2.1) * 0.5)
            let emberPulse = 0.5 + (sin((time * 2.7) - 0.6) * 0.5)
            let sparkLick = 0.5 + (sin((time * 11.8) + (sin(time * 1.9) * 0.9)) * 0.5)
            let leadingPower = min(1.0, max(0.0, 0.26 + (flickerA * 0.34) + (sparkLick * 0.24)))
            let trailingPower = min(1.0, max(0.0, 0.22 + (flickerB * 0.30) + (emberPulse * 0.28)))
            let ambientPower = min(1.0, 0.22 + ((flickerA + flickerB) * 0.10) + (emberPulse * 0.14))
            let leadingColor = blendedColorComponents(
                campfireGoldColorComponents,
                campfireOrangeColorComponents,
                amount: (flameDrift * 0.58) + (sparkLick * 0.12)
            )
            let trailingColor = blendedColorComponents(
                campfireOrangeColorComponents,
                campfireEmberColorComponents,
                amount: (emberPulse * 0.62) + ((1.0 - flameDrift) * 0.12)
            )

            return EffectFrameState(
                leadingColor: leadingColor,
                trailingColor: trailingColor,
                leadingPower: leadingPower,
                trailingPower: trailingPower,
                ambientPower: ambientPower
            )
        case .disco:
            let beatCycle = 0.82
            let beatPhase = time.truncatingRemainder(dividingBy: beatCycle)
            let kick = sequenceStrength(phase: beatPhase, starts: [0.00, 0.28, 0.54], duration: 0.16)
            let leadingBurst = sequenceStrength(phase: beatPhase, starts: [0.06, 0.44], duration: 0.16)
            let trailingBurst = sequenceStrength(phase: beatPhase, starts: [0.18, 0.62], duration: 0.16)
            let ambientPower = 0.18 + (kick * 0.22)
            let leadingPower = min(1.0, 0.26 + (leadingBurst * 0.74))
            let trailingPower = min(1.0, 0.24 + (trailingBurst * 0.76))
            let leadingColor = paletteColor(
                from: [
                    discoMagentaColorComponents,
                    discoCyanColorComponents,
                    discoLimeColorComponents,
                    discoVioletColorComponents
                ],
                progress: time * 0.56
            )
            let trailingColor = paletteColor(
                from: [
                    discoCyanColorComponents,
                    discoVioletColorComponents,
                    discoMagentaColorComponents,
                    discoLimeColorComponents
                ],
                progress: (time * 0.62) + 0.23
            )

            return EffectFrameState(
                leadingColor: leadingColor,
                trailingColor: trailingColor,
                leadingPower: leadingPower,
                trailingPower: trailingPower,
                ambientPower: ambientPower
            )
        }
    }

    private func localMouseLocation(in size: CGSize) -> CGPoint? {
        guard let mouseLocation = model.mouseLocation, model.screenFrame.contains(mouseLocation) else {
            return nil
        }

        return CGPoint(
            x: (mouseLocation.x - model.screenFrame.minX) + LightConfiguration.pointerVisualCenterOffsetX,
            y: (size.height - (mouseLocation.y - model.screenFrame.minY)) + LightConfiguration.pointerVisualCenterOffsetY
        )
    }

    private func directionalLightPosition(
        angle: Double,
        in size: CGSize
    ) -> CGPoint {
        let radians = angle * .pi / 180
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let dx = cos(radians)
        let dy = -sin(radians)
        let xReach = (size.width / 2) / max(abs(dx), 0.0001)
        let yReach = (size.height / 2) / max(abs(dy), 0.0001)
        let travel = min(xReach, yReach)

        return CGPoint(
            x: center.x + (dx * travel),
            y: center.y + (dy * travel)
        )
    }

    private func beamRotation(for angle: Double) -> Angle {
        .degrees(-angle)
    }

    private func gradientStops(
        for edge: EffectEdge,
        brightColor: Color,
        softColor: Color,
        transparentColor: Color
    ) -> [Gradient.Stop] {
        switch edge {
        case .leading:
            return [
                .init(color: brightColor, location: 0.00),
                .init(color: brightColor, location: 0.20),
                .init(color: softColor, location: 0.56),
                .init(color: transparentColor, location: 1.00)
            ]
        case .trailing:
            return [
                .init(color: transparentColor, location: 0.00),
                .init(color: softColor, location: 0.44),
                .init(color: brightColor, location: 0.80),
                .init(color: brightColor, location: 1.00)
            ]
        }
    }

    private func effectSegment(
        size: CGSize,
        edge: EffectEdge,
        color: (red: Double, green: Double, blue: Double),
        opacity: Double,
        intensity: Double
    ) -> some View {
        let brightColor = lightColor(
            red: color.red,
            green: color.green,
            blue: color.blue,
            opacity: opacity,
            intensity: intensity
        )
        let softColor = lightColor(
            red: color.red,
            green: color.green,
            blue: color.blue,
            opacity: opacity * 0.72,
            intensity: intensity
        )
        let transparentColor = lightColor(
            red: color.red,
            green: color.green,
            blue: color.blue,
            opacity: 0.0,
            intensity: intensity
        )

        return Rectangle()
            .fill(LinearGradient(
                gradient: Gradient(stops: gradientStops(
                    for: edge,
                    brightColor: brightColor,
                    softColor: softColor,
                    transparentColor: transparentColor
                )),
                startPoint: .leading,
                endPoint: .trailing
            ))
            .frame(width: size.width * 0.80, height: size.height)
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: edge == .leading ? .leading : .trailing
            )
    }

    private func effectBridge(
        size: CGSize,
        leadingColor: (red: Double, green: Double, blue: Double),
        trailingColor: (red: Double, green: Double, blue: Double),
        leadingOpacity: Double,
        trailingOpacity: Double,
        leadingIntensity: Double,
        trailingIntensity: Double
    ) -> some View {
        let bridgeColor = blendedColorComponents(leadingColor, trailingColor, amount: 0.5)
        let bridgeOpacity = min(1.0, ((leadingOpacity + trailingOpacity) * 0.22))
        let bridgeIntensity = model.isHDREnabled ? max(1.0, max(leadingIntensity, trailingIntensity) * 0.88) : 1.0

        return Rectangle()
            .fill(
                lightColor(
                    red: bridgeColor.red,
                    green: bridgeColor.green,
                    blue: bridgeColor.blue,
                    opacity: bridgeOpacity,
                    intensity: bridgeIntensity
                )
            )
            .frame(width: size.width * 0.24, height: size.height)
            .blur(radius: 18)
    }

    @ViewBuilder
    private func effectRingLayer(
        size: CGSize,
        thickness: CGFloat,
        cornerRadius: CGFloat,
        leadingColor: (red: Double, green: Double, blue: Double),
        trailingColor: (red: Double, green: Double, blue: Double),
        leadingOpacity: Double,
        trailingOpacity: Double,
        leadingIntensity: Double,
        trailingIntensity: Double,
        blurRadius: CGFloat
    ) -> some View {
        ZStack {
            effectSegment(
                size: size,
                edge: .leading,
                color: leadingColor,
                opacity: leadingOpacity,
                intensity: leadingIntensity
            )

            effectBridge(
                size: size,
                leadingColor: leadingColor,
                trailingColor: trailingColor,
                leadingOpacity: leadingOpacity,
                trailingOpacity: trailingOpacity,
                leadingIntensity: leadingIntensity,
                trailingIntensity: trailingIntensity
            )

            effectSegment(
                size: size,
                edge: .trailing,
                color: trailingColor,
                opacity: trailingOpacity,
                intensity: trailingIntensity
            )
        }
        .mask(
            LightRingShape(thickness: thickness, cornerRadius: cornerRadius)
                .fill(Color.white, style: FillStyle(eoFill: true))
        )
        .blur(radius: blurRadius)
    }

    @ViewBuilder
    private func normalLightScene(
        size: CGSize,
        ringThickness: CGFloat,
        cornerRadius: CGFloat,
        innerHighlightThickness: CGFloat,
        coreBloomRadius: CGFloat,
        outerBloomRadius: CGFloat,
        brightnessScale: Double = 1.0
    ) -> some View {
        let clampedBrightnessScale = min(1.0, max(0.0, brightnessScale))
        let hdrBloomOpacity = min(
            1.0,
            (
                0.10
                    + (curvedBrightness * (0.16 + (hdrLowHeadroomCompensation * 0.12)))
                    + (temperatureStrength * 0.06)
            ) * clampedBrightnessScale
        )
        let baseLayerOpacity = baseOpacity * clampedBrightnessScale
        let highlightLayerOpacity = highlightOpacity * clampedBrightnessScale
        let bloomLayerOpacity = bloomOpacity * clampedBrightnessScale
        let ringIntensityScale = model.isHDREnabled ? clampedBrightnessScale : 1.0

        ZStack {
            LightRingShape(thickness: ringThickness * 1.06, cornerRadius: cornerRadius)
                .fill(
                    lightColor(
                        red: baseLightColorComponents.red,
                        green: baseLightColorComponents.green,
                        blue: baseLightColorComponents.blue,
                        opacity: bloomLayerOpacity,
                        intensity: model.isHDREnabled ? hdrColorIntensity * 0.88 * ringIntensityScale : 1.0
                    ),
                    style: FillStyle(eoFill: true)
                )
                .blur(radius: outerBloomRadius)

            LightRingShape(thickness: ringThickness, cornerRadius: cornerRadius)
                .fill(
                    lightColor(
                        red: baseLightColorComponents.red,
                        green: baseLightColorComponents.green,
                        blue: baseLightColorComponents.blue,
                        opacity: baseLayerOpacity,
                        intensity: model.isHDREnabled ? hdrColorIntensity * ringIntensityScale : 1.0
                    ),
                    style: FillStyle(eoFill: true)
                )

            LightRingShape(
                thickness: innerHighlightThickness,
                cornerRadius: max(0, cornerRadius - (ringThickness - innerHighlightThickness) * 0.5)
            )
            .fill(
                lightColor(
                    red: highlightLightColorComponents.red,
                    green: highlightLightColorComponents.green,
                    blue: highlightLightColorComponents.blue,
                    opacity: highlightLayerOpacity,
                    intensity: model.isHDREnabled ? hdrColorIntensity * 1.04 * ringIntensityScale : 1.0
                ),
                style: FillStyle(eoFill: true)
            )
            .blur(radius: coreBloomRadius)

            if model.isHDREnabled {
                LightRingShape(thickness: ringThickness * 0.88, cornerRadius: cornerRadius)
                    .fill(
                        lightColor(
                            red: baseLightColorComponents.red,
                            green: baseLightColorComponents.green,
                            blue: baseLightColorComponents.blue,
                            opacity: hdrBloomOpacity,
                            intensity: hdrColorIntensity * 1.18 * ringIntensityScale
                        ),
                        style: FillStyle(eoFill: true)
                    )
                    .blur(radius: outerBloomRadius * 1.2)
            }
        }
    }

    @ViewBuilder
    private func directionalStudioLight(
        size: CGSize,
        angle: Double,
        energy: Double,
        role: DirectionalLightRole
    ) -> some View {
        let maxDimension = max(size.width, size.height)
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let brightnessScale = min(1.0, max(0.0, energy))
        let isKeyLight = role == .key
        let isSDRKeyLight = isKeyLight && !model.isHDREnabled
        let sourcePoint = directionalLightPosition(angle: angle, in: size)
        // `beamPoint` is measured from screen center toward the source point.
        // Keeping the beam anchor near the edge prevents the professional lights
        // from leaving a visible white patch in the middle of the screen.
        let beamReach = isKeyLight ? 0.82 : 0.74
        let beamPoint = CGPoint(
            x: center.x + ((sourcePoint.x - center.x) * beamReach),
            y: center.y + ((sourcePoint.y - center.y) * beamReach)
        )
        let ambientDiameter = maxDimension * (isKeyLight ? 0.82 : 0.60)
        let coreDiameter = maxDimension * (isKeyLight ? 0.52 : 0.36)
        let haloDiameter = maxDimension * (isKeyLight ? 0.30 : 0.20)
        let hotspotDiameter = maxDimension * (isKeyLight ? 0.22 : 0.14)
        let sourcePlateDiameter = hotspotDiameter * (isSDRKeyLight ? 0.92 : 0.72)
        let beamWidth = maxDimension * (isKeyLight ? 0.74 : 0.50)
        let beamHeight = maxDimension * (isKeyLight ? 0.28 : 0.18)
        let sizeScale = isKeyLight ? 0.5 : 1.0
        let sourceSpreadScale = isSDRKeyLight ? 0.68 : 1.0
        let beamScale = isSDRKeyLight ? 0.32 : (isKeyLight ? 0.44 : 0.40)
        let ambientOpacity = min(
            1.0,
            isSDRKeyLight
                ? 0.34 + (curvedBrightness * 0.30 * brightnessScale)
                : (isKeyLight ? 0.20 : 0.10) + (curvedBrightness * (isKeyLight ? 0.32 : 0.18) * brightnessScale)
        )
        let coreOpacity = min(
            1.0,
            isSDRKeyLight
                ? 0.52 + (curvedBrightness * 0.28 * brightnessScale)
                : (isKeyLight ? 0.28 : 0.12) + (curvedBrightness * (isKeyLight ? 0.36 : 0.20) * brightnessScale)
        )
        let haloOpacity = min(
            1.0,
            isSDRKeyLight
                ? 0.28 + (curvedBrightness * 0.22 * brightnessScale)
                : (isKeyLight ? 0.16 : 0.08) + (curvedBrightness * (isKeyLight ? 0.22 : 0.12) * brightnessScale)
        )
        let hotspotOpacity = min(
            1.0,
            isSDRKeyLight
                ? 0.74 + (curvedBrightness * 0.22 * brightnessScale)
                : (isKeyLight ? 0.30 : 0.12) + (curvedBrightness * (isKeyLight ? 0.28 : 0.10) * brightnessScale)
        )
        let beamOpacity = min(
            1.0,
            isSDRKeyLight
                ? 0.14 + (curvedBrightness * 0.10 * brightnessScale)
                : (isKeyLight ? 0.16 : 0.07) + (curvedBrightness * (isKeyLight ? 0.22 : 0.11) * brightnessScale)
        )
        let sourcePlateOpacity = min(1.0, 0.56 + (curvedBrightness * 0.44 * brightnessScale))
        let hdrIntensityBoost = isKeyLight ? 1.12 : 1.0
        let intensity = model.isHDREnabled ? max(0.0, hdrColorIntensity * brightnessScale * hdrIntensityBoost) : 1.0
        let sourcePlateColor = blendedColorComponents(
            highlightLightColorComponents,
            (red: 1.0, green: 1.0, blue: 1.0),
            amount: isSDRKeyLight ? 0.72 : 0.28
        )

        Circle()
            .fill(
                lightColor(
                    red: baseLightColorComponents.red,
                    green: baseLightColorComponents.green,
                    blue: baseLightColorComponents.blue,
                    opacity: ambientOpacity,
                    intensity: intensity
                )
            )
            .frame(width: ambientDiameter * sizeScale * sourceSpreadScale, height: ambientDiameter * sizeScale * sourceSpreadScale)
            .position(sourcePoint)
            .blur(radius: maxDimension * (isSDRKeyLight ? 0.022 : (isKeyLight ? 0.035 : 0.048)))

        Ellipse()
            .fill(
                LinearGradient(
                    colors: [
                        lightColor(
                            red: baseLightColorComponents.red,
                            green: baseLightColorComponents.green,
                            blue: baseLightColorComponents.blue,
                            opacity: beamOpacity,
                            intensity: intensity
                        ),
                        lightColor(
                            red: baseLightColorComponents.red,
                            green: baseLightColorComponents.green,
                            blue: baseLightColorComponents.blue,
                            opacity: beamOpacity * 0.38,
                            intensity: intensity
                        ),
                        lightColor(
                            red: baseLightColorComponents.red,
                            green: baseLightColorComponents.green,
                            blue: baseLightColorComponents.blue,
                            opacity: 0.0,
                            intensity: intensity
                        )
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: beamWidth * sizeScale * beamScale, height: beamHeight * sizeScale * beamScale)
            .rotationEffect(beamRotation(for: angle))
            .position(beamPoint)
            .blur(radius: maxDimension * (isSDRKeyLight ? 0.010 : (isKeyLight ? 0.021 : 0.026)))

        Circle()
            .fill(
                lightColor(
                    red: highlightLightColorComponents.red,
                    green: highlightLightColorComponents.green,
                    blue: highlightLightColorComponents.blue,
                    opacity: coreOpacity,
                    intensity: model.isHDREnabled ? intensity * 1.06 : 1.0
                )
            )
            .frame(width: coreDiameter * sizeScale * sourceSpreadScale, height: coreDiameter * sizeScale * sourceSpreadScale)
            .position(sourcePoint)
            .blur(radius: maxDimension * (isSDRKeyLight ? 0.012 : (isKeyLight ? 0.021 : 0.026)))

        Circle()
            .fill(
                lightColor(
                    red: highlightLightColorComponents.red,
                    green: highlightLightColorComponents.green,
                    blue: highlightLightColorComponents.blue,
                    opacity: haloOpacity,
                    intensity: model.isHDREnabled ? intensity * 1.10 : 1.0
                )
            )
            .frame(width: haloDiameter * sizeScale * sourceSpreadScale, height: haloDiameter * sizeScale * sourceSpreadScale)
            .position(sourcePoint)
            .blur(radius: maxDimension * (isSDRKeyLight ? 0.008 : (isKeyLight ? 0.013 : 0.016)))

        if isSDRKeyLight {
            Circle()
                .fill(
                    lightColor(
                        red: sourcePlateColor.red,
                        green: sourcePlateColor.green,
                        blue: sourcePlateColor.blue,
                        opacity: sourcePlateOpacity,
                        intensity: 1.0
                    )
                )
                .frame(width: sourcePlateDiameter * sizeScale, height: sourcePlateDiameter * sizeScale)
                .position(sourcePoint)
                .blur(radius: maxDimension * 0.004)
        }

        Circle()
            .fill(
                lightColor(
                    red: highlightLightColorComponents.red,
                    green: highlightLightColorComponents.green,
                    blue: highlightLightColorComponents.blue,
                    opacity: hotspotOpacity,
                    intensity: model.isHDREnabled ? intensity * (isKeyLight ? 1.18 : 1.06) : 1.0
                )
            )
            .frame(width: hotspotDiameter * sizeScale, height: hotspotDiameter * sizeScale)
            .position(sourcePoint)
            .blur(radius: maxDimension * (isKeyLight ? 0.009 : 0.010))
    }

    @ViewBuilder
    private func professionalLightScene(
        size: CGSize,
        ringThickness: CGFloat,
        cornerRadius: CGFloat,
        innerHighlightThickness: CGFloat,
        coreBloomRadius: CGFloat,
        outerBloomRadius: CGFloat
    ) -> some View {
        let primaryEnergy = 1.0
        let secondaryEnergy = 0.6
        let ringBrightnessScale = 0.5 + (hdrLowHeadroomCompensation * 0.16)

        ZStack {
            directionalStudioLight(
                size: size,
                angle: model.secondaryDirectionalLightAngle,
                energy: secondaryEnergy,
                role: .fill
            )

            directionalStudioLight(
                size: size,
                angle: model.primaryDirectionalLightAngle,
                energy: primaryEnergy,
                role: .key
            )

            normalLightScene(
                size: size,
                ringThickness: ringThickness,
                cornerRadius: cornerRadius,
                innerHighlightThickness: innerHighlightThickness,
                coreBloomRadius: coreBloomRadius,
                outerBloomRadius: outerBloomRadius,
                brightnessScale: ringBrightnessScale
            )
        }
    }

    @ViewBuilder
    private func effectLightScene(
        time: TimeInterval,
        size: CGSize,
        ringThickness: CGFloat,
        cornerRadius: CGFloat,
        innerHighlightThickness: CGFloat,
        coreBloomRadius: CGFloat,
        outerBloomRadius: CGFloat
    ) -> some View {
        let state = effectFrameState(at: time)
        let overallBlend = blendedColorComponents(
            state.leadingColor,
            state.trailingColor,
            amount: state.trailingPower / max(0.001, state.leadingPower + state.trailingPower)
        )
        let overallOpacity = min(1.0, (0.06 + (curvedBrightness * 0.14)) + state.ambientPower)
        let leadingBaseOpacity = min(1.0, (0.08 + (curvedBrightness * 0.18)) + (state.leadingPower * 0.60))
        let trailingBaseOpacity = min(1.0, (0.08 + (curvedBrightness * 0.18)) + (state.trailingPower * 0.60))
        let leadingHighlightOpacity = min(1.0, (0.04 + (curvedBrightness * 0.12)) + (state.leadingPower * 0.54))
        let trailingHighlightOpacity = min(1.0, (0.04 + (curvedBrightness * 0.12)) + (state.trailingPower * 0.54))
        let leadingIntensity = model.isHDREnabled ? max(1.0, hdrColorIntensity * (0.52 + (state.leadingPower * 0.92))) : 1.0
        let trailingIntensity = model.isHDREnabled ? max(1.0, hdrColorIntensity * (0.52 + (state.trailingPower * 0.92))) : 1.0
        let overallIntensity = model.isHDREnabled ? max(1.0, hdrColorIntensity * (0.42 + (state.ambientPower * 0.80))) : 1.0

        ZStack {
            LightRingShape(thickness: ringThickness * 1.08, cornerRadius: cornerRadius)
                .fill(
                    lightColor(
                        red: overallBlend.red,
                        green: overallBlend.green,
                        blue: overallBlend.blue,
                        opacity: overallOpacity,
                        intensity: overallIntensity
                    ),
                    style: FillStyle(eoFill: true)
                )
                .blur(radius: outerBloomRadius * 1.22)

            effectRingLayer(
                size: size,
                thickness: ringThickness * 1.02,
                cornerRadius: cornerRadius,
                leadingColor: state.leadingColor,
                trailingColor: state.trailingColor,
                leadingOpacity: min(1.0, leadingBaseOpacity * 0.78),
                trailingOpacity: min(1.0, trailingBaseOpacity * 0.78),
                leadingIntensity: model.isHDREnabled ? max(1.0, leadingIntensity * 0.92) : 1.0,
                trailingIntensity: model.isHDREnabled ? max(1.0, trailingIntensity * 0.92) : 1.0,
                blurRadius: outerBloomRadius
            )

            effectRingLayer(
                size: size,
                thickness: ringThickness,
                cornerRadius: cornerRadius,
                leadingColor: state.leadingColor,
                trailingColor: state.trailingColor,
                leadingOpacity: leadingBaseOpacity,
                trailingOpacity: trailingBaseOpacity,
                leadingIntensity: leadingIntensity,
                trailingIntensity: trailingIntensity,
                blurRadius: 0
            )

            effectRingLayer(
                size: size,
                thickness: innerHighlightThickness,
                cornerRadius: max(0, cornerRadius - (ringThickness - innerHighlightThickness) * 0.5),
                leadingColor: state.leadingColor,
                trailingColor: state.trailingColor,
                leadingOpacity: leadingHighlightOpacity,
                trailingOpacity: trailingHighlightOpacity,
                leadingIntensity: model.isHDREnabled ? max(1.0, leadingIntensity * 1.06) : 1.0,
                trailingIntensity: model.isHDREnabled ? max(1.0, trailingIntensity * 1.06) : 1.0,
                blurRadius: coreBloomRadius
            )

            if model.isHDREnabled {
                effectRingLayer(
                    size: size,
                    thickness: ringThickness * 0.90,
                    cornerRadius: cornerRadius,
                    leadingColor: state.leadingColor,
                    trailingColor: state.trailingColor,
                    leadingOpacity: min(1.0, 0.06 + (state.leadingPower * 0.42)),
                    trailingOpacity: min(1.0, 0.06 + (state.trailingPower * 0.42)),
                    leadingIntensity: max(1.0, leadingIntensity * 1.16),
                    trailingIntensity: max(1.0, trailingIntensity * 1.16),
                    blurRadius: outerBloomRadius * 1.16
                )
            }
        }
    }

    @ViewBuilder
    private func renderBody(at time: TimeInterval?) -> some View {
        GeometryReader { geometry in
            let ringThickness = min(model.borderWidth, min(geometry.size.width, geometry.size.height) / 2 - 2)
            let cornerRadius = max(
                LightConfiguration.minimumCornerRadius,
                min(geometry.size.width, geometry.size.height) * 0.18 + (ringThickness * 0.7)
            )
            let innerHighlightThickness = max(6.0, ringThickness * 0.72)
            let cutoutCenter = usesPointerCutout ? localMouseLocation(in: geometry.size) : nil
            let cutoutDiameter = LightConfiguration.pointerCutoutRadius * 2
            let cutoutBlur = LightConfiguration.pointerCutoutFeather

            ZStack {
                if model.effectMode == .professional {
                    professionalLightScene(
                        size: geometry.size,
                        ringThickness: ringThickness,
                        cornerRadius: cornerRadius,
                        innerHighlightThickness: innerHighlightThickness,
                        coreBloomRadius: coreBloomRadius,
                        outerBloomRadius: outerBloomRadius
                    )
                } else if model.effectMode == .normal || time == nil {
                    normalLightScene(
                        size: geometry.size,
                        ringThickness: ringThickness,
                        cornerRadius: cornerRadius,
                        innerHighlightThickness: innerHighlightThickness,
                        coreBloomRadius: coreBloomRadius,
                        outerBloomRadius: outerBloomRadius
                    )
                } else if let time {
                    effectLightScene(
                        time: time,
                        size: geometry.size,
                        ringThickness: ringThickness,
                        cornerRadius: cornerRadius,
                        innerHighlightThickness: innerHighlightThickness,
                        coreBloomRadius: coreBloomRadius,
                        outerBloomRadius: outerBloomRadius
                    )
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .compositingGroup()
            .overlay {
                if let cutoutCenter {
                    Circle()
                        .fill(Color.black)
                        .frame(width: cutoutDiameter, height: cutoutDiameter)
                        .position(cutoutCenter)
                        .blur(radius: cutoutBlur)
                        .blendMode(.destinationOut)
                }
            }
            .compositingGroup()
        }
        .background(Color.clear)
        .ignoresSafeArea()
        .brightness(brightnessAdjustment)
        .contrast(contrastAdjustment)
        .saturation(saturationAdjustment)
    }

    var body: some View {
        Group {
            if model.effectMode.usesAnimatedTimeline {
                TimelineView(.periodic(from: .now, by: 1.0 / 24.0)) { context in
                    renderBody(at: context.date.timeIntervalSinceReferenceDate)
                }
            } else {
                renderBody(at: nil)
            }
        }
    }
}

#Preview {
    LightView(
        model: LightViewModel(
            persistentID: "preview-display",
            displayID: 1,
            displayName: "Preview Display",
            screenFrame: CGRect(x: 0, y: 0, width: 600, height: 400),
            visibleFrame: CGRect(x: 0, y: 0, width: 600, height: 400),
            isOn: true,
            brightness: 0.35,
            colorTemperature: LightConfiguration.defaultColorTemperature,
            isHDREnabled: false,
            hasHDRDisplay: true,
            preferredHDREnabled: true,
            maxHDRFactor: 2.0,
            borderWidth: 80.0,
            effectMode: .normal,
            primaryDirectionalLightAngle: LightConfiguration.defaultPrimaryDirectionalLightAngle,
            secondaryDirectionalLightAngle: LightConfiguration.defaultSecondaryDirectionalLightAngle,
            mouseLocation: CGPoint(x: 260, y: 260)
        )
    )
}
