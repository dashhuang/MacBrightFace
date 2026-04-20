import CoreGraphics

enum LightConfiguration {
    static let brightnessRange: ClosedRange<Double> = 0.0...1.0
    static let defaultBrightness = 0.35
    static let colorTemperatureRange: ClosedRange<Double> = 0.0...1.0
    static let defaultColorTemperature = 0.5

    static let borderWidthRange: ClosedRange<CGFloat> = 60.0...220.0
    static let defaultBorderWidth: CGFloat = 80.0

    static let standardMaxBrightness = 1.35
    static let minimumCornerRadius: CGFloat = 44.0
    static let pointerCutoutRadius: CGFloat = 162.0
    static let pointerCutoutFeather: CGFloat = 72.0
    static let pointerVisualCenterOffsetX: CGFloat = 10.0
    static let pointerVisualCenterOffsetY: CGFloat = 14.0
}
