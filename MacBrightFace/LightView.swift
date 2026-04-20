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
            let innerHighlightThickness = max(6.0, ringThickness * 0.72)
            let hdrBloomOpacity = min(1.0, 0.10 + (curvedBrightness * 0.16) + (temperatureStrength * 0.06))
            let cutoutCenter = localMouseLocation(in: geometry.size)
            let cutoutDiameter = LightConfiguration.pointerCutoutRadius * 2
            let cutoutBlur = LightConfiguration.pointerCutoutFeather

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
