import AppKit
import SwiftUI

@MainActor
final class LightViewModel: ObservableObject {
    @Published private(set) var brightness: Double
    @Published private(set) var colorTemperature: Double
    @Published private(set) var isHDREnabled: Bool
    @Published private(set) var maxHDRFactor: Double
    @Published private(set) var borderWidth: CGFloat
    @Published private(set) var effectMode: LightEffectMode
    @Published private(set) var mouseLocation: CGPoint?

    init(
        brightness: Double,
        colorTemperature: Double,
        isHDREnabled: Bool,
        maxHDRFactor: Double,
        borderWidth: CGFloat,
        effectMode: LightEffectMode,
        mouseLocation: CGPoint? = nil
    ) {
        self.brightness = brightness
        self.colorTemperature = colorTemperature
        self.isHDREnabled = isHDREnabled
        self.maxHDRFactor = maxHDRFactor
        self.borderWidth = borderWidth
        self.effectMode = effectMode
        self.mouseLocation = mouseLocation
    }

    func update(
        brightness: Double,
        colorTemperature: Double,
        isHDREnabled: Bool,
        maxHDRFactor: Double,
        borderWidth: CGFloat,
        effectMode: LightEffectMode,
        mouseLocation: CGPoint? = nil
    ) {
        self.brightness = brightness
        self.colorTemperature = colorTemperature
        self.isHDREnabled = isHDREnabled
        self.maxHDRFactor = maxHDRFactor
        self.borderWidth = borderWidth
        self.effectMode = effectMode
        if let mouseLocation {
            self.mouseLocation = mouseLocation
        }
    }

    func updateMouseLocation(_ mouseLocation: CGPoint?) {
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

struct LightView: View {
    @ObservedObject var model: LightViewModel
    let screenFrame: CGRect

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
        return maxIntensity * baseCurve
    }

    private var baseOpacity: Double {
        if model.isHDREnabled {
            return min(1.0, 0.20 + (curvedBrightness * 0.24) + (temperatureStrength * 0.06))
        }

        return min(1.0, 0.24 + (curvedBrightness * 0.76))
    }

    private var highlightOpacity: Double {
        if model.isHDREnabled {
            return min(1.0, 0.10 + (curvedBrightness * 0.14) + (temperatureStrength * 0.04))
        }

        return min(1.0, 0.08 + (curvedBrightness * 0.28) + (targetIntensity * 0.10))
    }

    private var bloomOpacity: Double {
        if model.isHDREnabled {
            return min(1.0, 0.10 + (curvedBrightness * 0.18) + (temperatureStrength * 0.05))
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
        guard let mouseLocation = model.mouseLocation, screenFrame.contains(mouseLocation) else {
            return nil
        }

        return CGPoint(
            x: (mouseLocation.x - screenFrame.minX) + LightConfiguration.pointerVisualCenterOffsetX,
            y: (size.height - (mouseLocation.y - screenFrame.minY)) + LightConfiguration.pointerVisualCenterOffsetY
        )
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
        outerBloomRadius: CGFloat
    ) -> some View {
        let hdrBloomOpacity = min(1.0, 0.10 + (curvedBrightness * 0.16) + (temperatureStrength * 0.06))

        ZStack {
            LightRingShape(thickness: ringThickness * 1.06, cornerRadius: cornerRadius)
                .fill(
                    lightColor(
                        red: baseLightColorComponents.red,
                        green: baseLightColorComponents.green,
                        blue: baseLightColorComponents.blue,
                        opacity: bloomOpacity,
                        intensity: model.isHDREnabled ? hdrColorIntensity * 0.88 : 1.0
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
                        opacity: baseOpacity,
                        intensity: model.isHDREnabled ? hdrColorIntensity : 1.0
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
                    opacity: highlightOpacity,
                    intensity: model.isHDREnabled ? hdrColorIntensity * 1.04 : 1.0
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
                            intensity: hdrColorIntensity * 1.18
                        ),
                        style: FillStyle(eoFill: true)
                    )
                    .blur(radius: outerBloomRadius * 1.2)
            }
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
            let cutoutCenter = localMouseLocation(in: geometry.size)
            let cutoutDiameter = LightConfiguration.pointerCutoutRadius * 2
            let cutoutBlur = LightConfiguration.pointerCutoutFeather

            ZStack {
                if model.effectMode == .normal || time == nil {
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
            if model.effectMode == .normal {
                renderBody(at: nil)
            } else {
                TimelineView(.periodic(from: .now, by: 1.0 / 24.0)) { context in
                    renderBody(at: context.date.timeIntervalSinceReferenceDate)
                }
            }
        }
    }
}

#Preview {
    LightView(
        model: LightViewModel(
            brightness: 0.35,
            colorTemperature: LightConfiguration.defaultColorTemperature,
            isHDREnabled: false,
            maxHDRFactor: 2.0,
            borderWidth: 80.0,
            effectMode: .normal,
            mouseLocation: CGPoint(x: 260, y: 260)
        ),
        screenFrame: CGRect(x: 0, y: 0, width: 600, height: 400)
    )
}
