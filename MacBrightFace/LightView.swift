import SwiftUI

@MainActor
final class LightViewModel: ObservableObject {
    @Published private(set) var brightness: Double
    @Published private(set) var isHDREnabled: Bool
    @Published private(set) var maxHDRFactor: Double
    @Published private(set) var borderWidth: CGFloat
    @Published private(set) var mouseLocation: CGPoint?

    init(
        brightness: Double,
        isHDREnabled: Bool,
        maxHDRFactor: Double,
        borderWidth: CGFloat,
        mouseLocation: CGPoint? = nil
    ) {
        self.brightness = brightness
        self.isHDREnabled = isHDREnabled
        self.maxHDRFactor = maxHDRFactor
        self.borderWidth = borderWidth
        self.mouseLocation = mouseLocation
    }

    func update(
        brightness: Double,
        isHDREnabled: Bool,
        maxHDRFactor: Double,
        borderWidth: CGFloat,
        mouseLocation: CGPoint? = nil
    ) {
        self.brightness = brightness
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

    private var targetIntensity: Double {
        let maxIntensity = model.isHDREnabled ? max(1.0, model.maxHDRFactor) : LightConfiguration.standardMaxBrightness
        let baseCurve = 0.18 + (curvedBrightness * 0.82)
        return maxIntensity * baseCurve
    }

    private var baseOpacity: Double {
        if model.isHDREnabled {
            return 0.10 + (clampedBrightness * 0.22)
        }

        return 0.32 + (curvedBrightness * 0.36)
    }

    private var highlightOpacity: Double {
        if model.isHDREnabled {
            return min(1.0, 0.16 + (targetIntensity * 0.18))
        }

        return min(1.0, 0.14 + (targetIntensity * 0.10))
    }

    private var bloomOpacity: Double {
        if model.isHDREnabled {
            return 0.08 + (clampedBrightness * 0.22)
        }

        return 0.08 + (curvedBrightness * 0.16)
    }

    private var coreBloomRadius: CGFloat {
        let baseRadius = model.isHDREnabled ? 26.0 : 20.0
        return max(10.0, baseRadius + (model.borderWidth * 0.10) - (clampedBrightness * 6.0))
    }

    private var outerBloomRadius: CGFloat {
        coreBloomRadius + (model.isHDREnabled ? 24.0 : 16.0)
    }

    private var brightnessAdjustment: Double {
        targetIntensity * (model.isHDREnabled ? 0.18 : 0.14)
    }

    private var contrastAdjustment: Double {
        1.0 + (targetIntensity * (model.isHDREnabled ? 0.10 : 0.06))
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
            let hdrBloomOpacity = 0.06 + (clampedBrightness * 0.12)
            let cutoutCenter = localMouseLocation(in: geometry.size)
            let cutoutDiameter = LightConfiguration.pointerCutoutRadius * 2
            let cutoutBlur = LightConfiguration.pointerCutoutFeather

            ZStack {
                LightRingShape(thickness: ringThickness * 1.06, cornerRadius: cornerRadius)
                    .fill(Color.white.opacity(bloomOpacity), style: FillStyle(eoFill: true))
                    .blur(radius: outerBloomRadius)

                LightRingShape(thickness: ringThickness, cornerRadius: cornerRadius)
                    .fill(Color.white.opacity(baseOpacity), style: FillStyle(eoFill: true))

                LightRingShape(
                    thickness: innerHighlightThickness,
                    cornerRadius: max(0, cornerRadius - (ringThickness - innerHighlightThickness) * 0.5)
                )
                .fill(Color.white.opacity(highlightOpacity), style: FillStyle(eoFill: true))
                .blur(radius: coreBloomRadius)

                if model.isHDREnabled {
                    LightRingShape(thickness: ringThickness * 0.88, cornerRadius: cornerRadius)
                        .fill(Color.white.opacity(hdrBloomOpacity), style: FillStyle(eoFill: true))
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
        .saturation(1.0 + (model.isHDREnabled ? clampedBrightness * 0.03 : 0.0))
    }
}

#Preview {
    LightView(
        model: LightViewModel(
            brightness: 0.35,
            isHDREnabled: false,
            maxHDRFactor: 2.0,
            borderWidth: 80.0,
            mouseLocation: CGPoint(x: 260, y: 260)
        ),
        screenFrame: CGRect(x: 0, y: 0, width: 600, height: 400)
    )
}
