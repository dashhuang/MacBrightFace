import SwiftUI

struct ContentView: View {
    @ObservedObject var lightController: LightController
    let showAbout: () -> Void
    let quitApp: () -> Void

    private var brightnessBinding: Binding<Double> {
        Binding(
            get: { lightController.brightness },
            set: { lightController.setBrightness($0) }
        )
    }

    private var colorTemperatureBinding: Binding<Double> {
        Binding(
            get: { lightController.colorTemperature },
            set: { lightController.setColorTemperature($0) }
        )
    }

    private var borderWidthBinding: Binding<Double> {
        Binding(
            get: { Double(lightController.borderWidth) },
            set: { lightController.setBorderWidth(CGFloat($0)) }
        )
    }

    private var brightnessLabel: String {
        let percentage = Int((lightController.brightness * 100).rounded())
        return "BRIGHTNESS_LABEL".localizedFormat(String(percentage))
    }

    private var borderWidthLabel: String {
        let width = Int(lightController.borderWidth.rounded())
        return "BORDER_WIDTH_LABEL".localizedFormat(String(width))
    }

    private var colorTemperatureLabel: String {
        "COLOR_TEMPERATURE_LABEL".localizedFormat(colorTemperatureValueLabel)
    }

    private var hdrLabel: String {
        if !lightController.supportsHDR() {
            return "HDR_MODE_UNAVAILABLE".localized
        }

        return (lightController.isHDREnabled ? "HDR_MODE_ON" : "HDR_MODE_OFF").localized
    }

    private var hdrButtonLabel: String {
        guard lightController.supportsHDR() else {
            return "HDR_BUTTON_UNAVAILABLE".localized
        }

        return lightController.isHDREnabled ? "关闭" : "开启"
    }

    private var lightStatusLabel: String {
        lightController.isOn ? "TOGGLE_LIGHT_OFF".localized : "TOGGLE_LIGHT_ON".localized
    }

    private var brightnessValueLabel: String {
        "\(Int((lightController.brightness * 100).rounded()))%"
    }

    private var sizeValueLabel: String {
        "\(Int(lightController.borderWidth.rounded())) px"
    }

    private var colorTemperatureValueLabel: String {
        switch lightController.colorTemperature {
        case ..<0.35:
            return "LIGHT_TEMPERATURE_WARM".localized
        case 0.65...:
            return "LIGHT_TEMPERATURE_COOL".localized
        default:
            return "LIGHT_TEMPERATURE_NEUTRAL".localized
        }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.90, green: 0.91, blue: 0.94),
                            Color(red: 0.83, green: 0.84, blue: 0.88)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(lightController.isOn ? Color.yellow.opacity(0.20) : Color.black.opacity(0.06))
                            .frame(width: 42, height: 42)

                        Image(systemName: lightController.isOn ? "lightbulb.fill" : "lightbulb")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(lightController.isOn ? Color(red: 0.95, green: 0.73, blue: 0.14) : .secondary)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("MacBrightFace")
                            .font(.system(size: 18, weight: .semibold))
                        Text(lightStatusLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button(lightController.isOn ? "关闭" : "开启") {
                        lightController.toggleLight()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(Color(red: 0.10, green: 0.45, blue: 0.95))
                }

                sliderCard(
                    title: "BRIGHTNESS_SLIDER".localized,
                    value: brightnessValueLabel,
                    footer: brightnessLabel,
                    icon: "sun.max.fill",
                    iconTint: Color.black.opacity(0.8)
                ) {
                    PillSlider(
                        value: brightnessBinding,
                        range: LightConfiguration.brightnessRange,
                        trackStyle: AnyShapeStyle(Color.black.opacity(0.11)),
                        progressStyle: AnyShapeStyle(Color(red: 0.08, green: 0.44, blue: 0.96)),
                        knobStyle: AnyShapeStyle(Color.white),
                        knobStroke: Color.white.opacity(0.95),
                        knobShadow: Color.black.opacity(0.12),
                        showsProgress: true
                    )
                }

                sliderCard(
                    title: "COLOR_TEMPERATURE".localized,
                    value: colorTemperatureValueLabel,
                    footer: colorTemperatureLabel,
                    icon: "thermometer.sun.fill",
                    iconTint: Color.black.opacity(0.8)
                ) {
                    PillSlider(
                        value: colorTemperatureBinding,
                        range: LightConfiguration.colorTemperatureRange,
                        trackStyle: AnyShapeStyle(
                            LinearGradient(
                                colors: [
                                    Color(red: 1.00, green: 0.70, blue: 0.28),
                                    Color(red: 1.00, green: 0.89, blue: 0.75),
                                    Color(red: 0.89, green: 0.93, blue: 1.00),
                                    Color(red: 0.73, green: 0.83, blue: 0.98)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        ),
                        progressStyle: nil,
                        knobStyle: AnyShapeStyle(
                            LinearGradient(
                                colors: [
                                    Color(red: 1.00, green: 0.96, blue: 0.90),
                                    Color.white
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        ),
                        knobStroke: Color.white.opacity(0.95),
                        knobShadow: Color.orange.opacity(0.14),
                        showsProgress: false
                    )
                }

                sliderCard(
                    title: "BORDER_WIDTH_MENU".localized,
                    value: sizeValueLabel,
                    footer: borderWidthLabel,
                    icon: "arrow.up.left.and.arrow.down.right",
                    iconTint: Color.black.opacity(0.8)
                ) {
                    PillSlider(
                        value: borderWidthBinding,
                        range: Double(LightConfiguration.borderWidthRange.lowerBound)...Double(LightConfiguration.borderWidthRange.upperBound),
                        trackStyle: AnyShapeStyle(Color.black.opacity(0.11)),
                        progressStyle: AnyShapeStyle(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.39, green: 0.72, blue: 1.00),
                                    Color(red: 0.22, green: 0.56, blue: 0.94)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        ),
                        knobStyle: AnyShapeStyle(Color.white),
                        knobStroke: Color.white.opacity(0.95),
                        knobShadow: Color.black.opacity(0.12),
                        showsProgress: true
                    )
                }

                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("HDR")
                            .font(.system(size: 13, weight: .semibold))
                        Text(hdrLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button(hdrButtonLabel) {
                        lightController.toggleHDRMode()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(!lightController.supportsHDR())
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.42))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.35), lineWidth: 1)
                        )
                )

                Divider()

                HStack {
                    Button("ABOUT_LIGHT".localized, action: showAbout)
                        .buttonStyle(.plain)
                    Spacer()
                    Button("QUIT".localized, action: quitApp)
                        .buttonStyle(.plain)
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            }
            .padding(18)
        }
        .frame(width: 336)
    }

    @ViewBuilder
    private func sliderCard<Content: View>(
        title: String,
        value: String,
        footer: String,
        icon: String,
        iconTint: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text(value)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.white.opacity(0.55)))
            }

            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(iconTint)
                    .frame(width: 22)

                content()
            }

            Text(footer)
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.42))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.35), lineWidth: 1)
                )
        )
    }
}

private struct PillSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let trackStyle: AnyShapeStyle
    let progressStyle: AnyShapeStyle?
    let knobStyle: AnyShapeStyle
    let knobStroke: Color
    let knobShadow: Color
    let showsProgress: Bool

    private let knobDiameter: CGFloat = 32
    private let trackHeight: CGFloat = 20

    private var normalizedValue: Double {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return 0 }
        return min(1, max(0, (value - range.lowerBound) / span))
    }

    var body: some View {
        GeometryReader { geometry in
            let travelWidth = max(0, geometry.size.width - knobDiameter)
            let knobOffset = normalizedValue * travelWidth
            let progressWidth = min(geometry.size.width, knobOffset + (knobDiameter / 2))

            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(trackStyle)
                    .frame(height: trackHeight)

                if showsProgress, let progressStyle {
                    Capsule(style: .continuous)
                        .fill(progressStyle)
                        .frame(width: progressWidth, height: 12)
                        .padding(.leading, 4)
                }

                Circle()
                    .fill(knobStyle)
                    .overlay(
                        Circle()
                            .stroke(knobStroke, lineWidth: 1.5)
                    )
                    .shadow(color: knobShadow, radius: 4, x: 0, y: 1)
                    .frame(width: knobDiameter, height: knobDiameter)
                    .offset(x: knobOffset)
            }
            .frame(height: knobDiameter)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        let clampedX = min(max(gesture.location.x - (knobDiameter / 2), 0), travelWidth)
                        let progress = travelWidth > 0 ? clampedX / travelWidth : 0
                        value = range.lowerBound + ((range.upperBound - range.lowerBound) * progress)
                    }
            )
        }
        .frame(height: knobDiameter)
    }
}

#Preview {
    ContentView(
        lightController: LightController(),
        showAbout: {},
        quitApp: {}
    )
}
