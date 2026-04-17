import SwiftUI

@MainActor
final class LightViewModel: ObservableObject {
    @Published private(set) var brightness: Double
    @Published private(set) var isHDREnabled: Bool
    @Published private(set) var maxHDRFactor: Double

    init(brightness: Double, isHDREnabled: Bool, maxHDRFactor: Double) {
        self.brightness = brightness
        self.isHDREnabled = isHDREnabled
        self.maxHDRFactor = maxHDRFactor
    }

    func update(brightness: Double, isHDREnabled: Bool, maxHDRFactor: Double) {
        self.brightness = brightness
        self.isHDREnabled = isHDREnabled
        self.maxHDRFactor = maxHDRFactor
    }
}

struct LightView: View {
    @ObservedObject var model: LightViewModel

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
        0.20 + (clampedBrightness * (model.isHDREnabled ? 0.42 : 0.35))
    }

    private var highlightOpacity: Double {
        min(1.0, targetIntensity * (model.isHDREnabled ? 0.34 : 0.28))
    }

    private var bloomOpacity: Double {
        0.12 + (clampedBrightness * (model.isHDREnabled ? 0.32 : 0.24))
    }

    private var bloomRadius: CGFloat {
        let baseRadius = model.isHDREnabled ? 18.0 : 14.0
        return max(6.0, baseRadius - (clampedBrightness * 8.0))
    }

    private var brightnessAdjustment: Double {
        targetIntensity * (model.isHDREnabled ? 0.34 : 0.22)
    }

    private var contrastAdjustment: Double {
        1.0 + (targetIntensity * (model.isHDREnabled ? 0.16 : 0.10))
    }

    var body: some View {
        ZStack {
            Color.white
                .opacity(baseOpacity)

            Rectangle()
                .fill(Color.white)
                .opacity(highlightOpacity)

            Rectangle()
                .fill(Color.white)
                .blur(radius: bloomRadius)
                .opacity(bloomOpacity)

            if model.isHDREnabled {
                Rectangle()
                    .fill(Color.white)
                    .blur(radius: max(4.0, bloomRadius * 0.5))
                    .opacity(0.10 + (clampedBrightness * 0.22))
            }
        }
        .ignoresSafeArea()
        .brightness(brightnessAdjustment)
        .contrast(contrastAdjustment)
        .saturation(1.0 + (model.isHDREnabled ? clampedBrightness * 0.03 : 0.0))
    }
}

#Preview {
    LightView(model: LightViewModel(brightness: 0.35, isHDREnabled: false, maxHDRFactor: 2.0))
}
