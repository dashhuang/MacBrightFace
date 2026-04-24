import CoreGraphics

enum LightEffectMode: String, CaseIterable, Identifiable {
    case normal
    case professional
    case police
    case fireTruck
    case campfire
    case disco

    var id: String { rawValue }

    var supportsColorTemperatureControl: Bool {
        switch self {
        case .normal, .professional:
            return true
        case .police, .fireTruck, .campfire, .disco:
            return false
        }
    }

    var supportsDirectionalLights: Bool {
        switch self {
        case .professional:
            return true
        case .normal, .police, .fireTruck, .campfire, .disco:
            return false
        }
    }

    var usesAnimatedTimeline: Bool {
        switch self {
        case .police, .fireTruck, .campfire, .disco:
            return true
        case .normal, .professional:
            return false
        }
    }
}

enum LightConfiguration {
    static let brightnessRange: ClosedRange<Double> = 0.0...1.0
    static let defaultBrightness = 0.35
    static let colorTemperatureRange: ClosedRange<Double> = 0.0...1.0
    static let defaultColorTemperature = 0.5

    static let borderWidthRange: ClosedRange<CGFloat> = 60.0...220.0
    static let defaultBorderWidth: CGFloat = 80.0
    static let directionalLightAngleRange: ClosedRange<Double> = 0.0...360.0
    static let defaultPrimaryDirectionalLightAngle = 130.0
    static let defaultSecondaryDirectionalLightAngle = 68.0
    static let professionalPrimaryLightEnergy = 1.0
    static let professionalSecondaryLightEnergy = 0.6
    static let professionalRingBrightnessScale = professionalPrimaryLightEnergy * 0.3
    static let professionalKeyHDRIntensityBoost = 1.12

    static let standardMaxBrightness = 1.35
    static let minimumCornerRadius: CGFloat = 44.0
    static let pointerCutoutRadius: CGFloat = 162.0
    static let pointerCutoutFeather: CGFloat = 72.0
    static let pointerVisualCenterOffsetX: CGFloat = 10.0
    static let pointerVisualCenterOffsetY: CGFloat = 14.0
}
