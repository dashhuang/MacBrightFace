import AppKit
import SwiftUI

@MainActor
final class LightViewModel: ObservableObject {
    @Published private(set) var brightness: Double
    @Published private(set) var colorTemperature: Double
    @Published private(set) var isHDREnabled: Bool
    @Published private(set) var maxHDRFactor: Double
    @Published private(set) var borderWidth: CGFloat
    @Published private(set) var mouseLocation: CGPoint?

    init(
        brightness: Double,
        colorTemperature: Double,
        isHDREnabled: Bool,
        maxHDRFactor: Double,
        borderWidth: CGFloat,
        mouseLocation: CGPoint? = nil
    ) {
        self.brightness = brightness
        self.colorTemperature = colorTemperature
        self.isHDREnabled = isHDREnabled
        self.maxHDRFactor = maxHDRFactor
        self.borderWidth = borderWidth
        self.mouseLocation = mouseLocation
    }

    func update(
        brightness: Double,
        colorTemperature: Double,
        isHDREnabled: Bool,
        maxHDRFactor: Double,
        borderWidth: CGFloat,
        mouseLocation: CGPoint? = nil
    ) {
        self.brightness = brightness
        self.colorTemperature = colorTemperature
        self.isHDREnabled = isHDREnabled
        self.maxHDRFactor = maxHDRFactor
        self.borderWidth = borderWidth
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
            if #available(macOS 26.0, *) {
                let hdrColor = NSColor(
                    red: red,
                    green: green,
                    blue: blue,
                    alpha: opacity,
                    linearExposure: intensity
                )
                return Color(hdrColor)
            }

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

    private var effectiveHDRHeadroom: Double {
        max(
            LightConfiguration.standardMaxBrightness,
            min(model.maxHDRFactor, LightConfiguration.practicalHDRHeadroom)
        )
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
        let mixAmount = model.isHDREnabled ? 0.18 : 0.36
        return (
            red: 1.0 - ((1.0 - baseLightColorComponents.red) * (1.0 - mixAmount)),
            green: 1.0 - ((1.0 - baseLightColorComponents.green) * (1.0 - mixAmount)),
            blue: 1.0 - ((1.0 - baseLightColorComponents.blue) * (1.0 - mixAmount))
        )
    }

    private var targetIntensity: Double {
        if model.isHDREnabled {
            let baseCurve = 0.24 + (curvedBrightness * 0.76)
            return effectiveHDRHeadroom * baseCurve
        }

        let baseCurve = 0.18 + (curvedBrightness * 0.82)
        return LightConfiguration.standardMaxBrightness * baseCurve
    }

    private var baseOpacity: Double {
        if model.isHDREnabled {
            return min(1.0, 0.40 + (curvedBrightness * 0.48) + (temperatureStrength * 0.08))
        }

        return 0.32 + (curvedBrightness * 0.36)
    }

    private var highlightOpacity: Double {
        if model.isHDREnabled {
            return min(1.0, 0.20 + (curvedBrightness * 0.18) + (temperatureStrength * 0.04))
        }

        return min(1.0, 0.14 + (targetIntensity * 0.10))
    }

    private var bloomOpacity: Double {
        if model.isHDREnabled {
            return min(1.0, 0.22 + (curvedBrightness * 0.36) + (temperatureStrength * 0.06))
        }

        return 0.08 + (curvedBrightness * 0.16)
    }

    private var hdrPeakOpacity: Double {
        min(1.0, 0.22 + (curvedBrightness * 0.24) + (temperatureStrength * 0.04))
    }

    private var coreBloomRadius: CGFloat {
        let baseRadius = model.isHDREnabled ? 16.0 : 20.0
        return max(10.0, baseRadius + (model.borderWidth * 0.10) - (clampedBrightness * 6.0))
    }

    private var outerBloomRadius: CGFloat {
        coreBloomRadius + (model.isHDREnabled ? 20.0 : 16.0)
    }

    private var brightnessAdjustment: Double {
        targetIntensity * (model.isHDREnabled ? 0.0 : 0.14)
    }

    private var contrastAdjustment: Double {
        1.0 + (targetIntensity * (model.isHDREnabled ? 0.01 : 0.06))
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

    var body: some View {
        GeometryReader { geometry in
            let ringThickness = min(model.borderWidth, min(geometry.size.width, geometry.size.height) / 2 - 2)
            let cornerRadius = max(
                LightConfiguration.minimumCornerRadius,
                min(geometry.size.width, geometry.size.height) * 0.18 + (ringThickness * 0.7)
            )
            let innerHighlightThickness = model.isHDREnabled ? max(5.0, ringThickness * 0.42) : max(6.0, ringThickness * 0.72)
            let hdrPeakThickness = model.isHDREnabled ? max(3.0, ringThickness * 0.18) : 0.0
            let hdrBloomOpacity = min(1.0, 0.22 + (curvedBrightness * 0.34) + (temperatureStrength * 0.08))
            let hdrPeakBlurRadius = max(4.0, coreBloomRadius * 0.45)
            let cutoutCenter = localMouseLocation(in: geometry.size)
            let cutoutDiameter = LightConfiguration.pointerCutoutRadius * 2
            let cutoutBlur = LightConfiguration.pointerCutoutFeather
            let canvasRect = CGRect(origin: .zero, size: geometry.size)
            let outerBloomPath = LightRingShape(thickness: ringThickness * 1.06, cornerRadius: cornerRadius).path(in: canvasRect)
            let baseRingPath = LightRingShape(thickness: ringThickness, cornerRadius: cornerRadius).path(in: canvasRect)
            let highlightPath = LightRingShape(
                thickness: innerHighlightThickness,
                cornerRadius: max(0, cornerRadius - (ringThickness - innerHighlightThickness) * 0.5)
            ).path(in: canvasRect)
            let hdrPeakPath = model.isHDREnabled
                ? LightRingShape(
                    thickness: hdrPeakThickness,
                    cornerRadius: max(0, cornerRadius - (ringThickness - hdrPeakThickness) * 0.5)
                ).path(in: canvasRect)
                : Path()
            let hdrBloomPath = LightRingShape(thickness: ringThickness * 0.88, cornerRadius: cornerRadius).path(in: canvasRect)

            Canvas(opaque: false, colorMode: .linear, rendersAsynchronously: false) { context, _ in
                context.drawLayer { layer in
                    layer.addFilter(.blur(radius: outerBloomRadius))
                    layer.fill(
                        outerBloomPath,
                        with: .color(
                            lightColor(
                                red: baseLightColorComponents.red,
                                green: baseLightColorComponents.green,
                                blue: baseLightColorComponents.blue,
                                opacity: bloomOpacity,
                                intensity: model.isHDREnabled ? hdrColorIntensity * 1.10 : 1.0
                            )
                        ),
                        style: FillStyle(eoFill: true)
                    )
                }

                context.fill(
                    baseRingPath,
                    with: .color(
                        lightColor(
                            red: baseLightColorComponents.red,
                            green: baseLightColorComponents.green,
                            blue: baseLightColorComponents.blue,
                            opacity: baseOpacity,
                            intensity: model.isHDREnabled ? hdrColorIntensity * 1.12 : 1.0
                        )
                    ),
                    style: FillStyle(eoFill: true)
                )

                context.drawLayer { layer in
                    layer.addFilter(.blur(radius: coreBloomRadius))
                    layer.fill(
                        highlightPath,
                        with: .color(
                            lightColor(
                                red: highlightLightColorComponents.red,
                                green: highlightLightColorComponents.green,
                                blue: highlightLightColorComponents.blue,
                                opacity: highlightOpacity,
                                intensity: model.isHDREnabled ? hdrColorIntensity * 1.22 : 1.0
                            )
                        ),
                        style: FillStyle(eoFill: true)
                    )
                }

                if model.isHDREnabled {
                    context.drawLayer { layer in
                        layer.addFilter(.blur(radius: hdrPeakBlurRadius))
                        layer.fill(
                            hdrPeakPath,
                            with: .color(
                                lightColor(
                                    red: highlightLightColorComponents.red,
                                    green: highlightLightColorComponents.green,
                                    blue: highlightLightColorComponents.blue,
                                    opacity: hdrPeakOpacity,
                                    intensity: hdrColorIntensity * 2.15
                                )
                            ),
                            style: FillStyle(eoFill: true)
                        )
                    }

                    context.drawLayer { layer in
                        layer.addFilter(.blur(radius: outerBloomRadius * 1.2))
                        layer.fill(
                            hdrBloomPath,
                            with: .color(
                                lightColor(
                                    red: baseLightColorComponents.red,
                                    green: baseLightColorComponents.green,
                                    blue: baseLightColorComponents.blue,
                                    opacity: hdrBloomOpacity,
                                    intensity: hdrColorIntensity * 1.38
                                )
                            ),
                            style: FillStyle(eoFill: true)
                        )
                    }
                }

                if let cutoutCenter {
                    context.drawLayer { layer in
                        layer.addFilter(.blur(radius: cutoutBlur))
                        layer.blendMode = .destinationOut
                        layer.fill(
                            Path(
                                ellipseIn: CGRect(
                                    x: cutoutCenter.x - (cutoutDiameter / 2),
                                    y: cutoutCenter.y - (cutoutDiameter / 2),
                                    width: cutoutDiameter,
                                    height: cutoutDiameter
                                )
                            ),
                            with: .color(.black)
                        )
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .background(Color.clear)
        .ignoresSafeArea()
        .brightness(brightnessAdjustment)
        .contrast(contrastAdjustment)
        .saturation(
            1.0
            + (model.isHDREnabled ? (temperatureStrength * 0.28) + (clampedBrightness * 0.04) : temperatureStrength * 0.10)
        )
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
            mouseLocation: CGPoint(x: 260, y: 260)
        ),
        screenFrame: CGRect(x: 0, y: 0, width: 600, height: 400)
    )
}
