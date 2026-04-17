import CoreGraphics

enum LightConfiguration {
    static let brightnessRange: ClosedRange<Double> = 0.0...1.0
    static let defaultBrightness = 0.35

    static let borderWidthRange: ClosedRange<CGFloat> = 60.0...220.0
    static let defaultBorderWidth: CGFloat = 80.0

    static let standardMaxBrightness = 1.35
    static let minimumSideWindowLength: CGFloat = 24.0
}
