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

    private var primaryDirectionalLightAngleBinding: Binding<Double> {
        Binding(
            get: { lightController.primaryDirectionalLightAngle },
            set: { lightController.setPrimaryDirectionalLightAngle($0) }
        )
    }

    private var secondaryDirectionalLightAngleBinding: Binding<Double> {
        Binding(
            get: { lightController.secondaryDirectionalLightAngle },
            set: { lightController.setSecondaryDirectionalLightAngle($0) }
        )
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

    private var effectModeValueLabel: String {
        lightController.effectMode.localizedTitle
    }

    private var showsDirectionalLightCard: Bool {
        lightController.effectMode.supportsDirectionalLights
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

                if lightController.effectMode.supportsColorTemperatureControl {
                    sliderCard(
                        title: "COLOR_TEMPERATURE".localized,
                        value: colorTemperatureValueLabel,
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
                }

                sliderCard(
                    title: "BORDER_WIDTH_MENU".localized,
                    value: sizeValueLabel,
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

                effectMenuCard

                if showsDirectionalLightCard {
                    directionalLightAnglesCard
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

    private var effectMenuCard: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                Text("LIGHT_EFFECT_MENU".localized)
                    .font(.system(size: 13, weight: .semibold))
            }

            Spacer()

            Menu {
                ForEach(LightEffectMode.allCases) { mode in
                    Button {
                        lightController.setEffectMode(mode)
                    } label: {
                        Label(
                            mode.localizedTitle,
                            systemImage: lightController.effectMode == mode ? "checkmark" : mode.symbolName
                        )
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: lightController.effectMode.symbolName)
                        .font(.system(size: 13, weight: .semibold))
                    Text(effectModeValueLabel)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(Color.black.opacity(0.78))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.62))
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(Color.white.opacity(0.70), lineWidth: 1)
                        )
                )
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.42))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.35), lineWidth: 1)
                )
        )
    }

    private var directionalLightAnglesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PRO_DIRECTIONAL_LIGHT_ANGLES".localized)
                .font(.system(size: 13, weight: .semibold))

            HStack(spacing: 10) {
                AngleDial(
                    value: primaryDirectionalLightAngleBinding,
                    label: "PRO_DIRECTIONAL_LIGHT_PRIMARY".localized,
                    accentColor: Color(red: 1.00, green: 0.57, blue: 0.20)
                )

                AngleDial(
                    value: secondaryDirectionalLightAngleBinding,
                    label: "PRO_DIRECTIONAL_LIGHT_SECONDARY".localized,
                    accentColor: Color(red: 1.00, green: 0.73, blue: 0.28)
                )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.42))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.35), lineWidth: 1)
                )
        )
    }

    @ViewBuilder
    private func sliderCard<Content: View>(
        title: String,
        value: String,
        icon: String,
        iconTint: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
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
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
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

private struct AngleDial: View {
    @Binding var value: Double
    let label: String
    let accentColor: Color

    private let dialSize: CGFloat = 118
    private let knobSize: CGFloat = 18

    private var clampedValue: Double {
        min(LightConfiguration.directionalLightAngleRange.upperBound, max(LightConfiguration.directionalLightAngleRange.lowerBound, value))
    }

    private var formattedValue: String {
        "\(Int(clampedValue.rounded()))°"
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.42))
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.78), lineWidth: 1)
                    )

                Circle()
                    .stroke(Color.black.opacity(0.08), lineWidth: 11)

                Circle()
                    .stroke(accentColor.opacity(0.55), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: dialSize * 0.66, height: dialSize * 0.66)

                Capsule(style: .continuous)
                    .fill(accentColor.opacity(0.24))
                    .frame(width: dialSize * 0.42, height: 4)
                    .offset(x: dialVector(length: dialSize * 0.14).width / 2, y: dialVector(length: dialSize * 0.14).height / 2)
                    .rotationEffect(.degrees(-clampedValue))

                Circle()
                    .fill(accentColor)
                    .frame(width: knobSize, height: knobSize)
                    .shadow(color: accentColor.opacity(0.28), radius: 4, x: 0, y: 2)
                    .offset(x: dialVector(length: dialSize * 0.33).width, y: dialVector(length: dialSize * 0.33).height)

                VStack(spacing: 2) {
                    Text(formattedValue)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                    Text(label)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: dialSize, height: dialSize)
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        let center = CGPoint(x: dialSize / 2, y: dialSize / 2)
                        let dx = gesture.location.x - center.x
                        let dy = center.y - gesture.location.y
                        guard abs(dx) > 0.001 || abs(dy) > 0.001 else { return }

                        var angle = atan2(dy, dx) * 180 / .pi
                        if angle < 0 {
                            angle += 360
                        }
                        value = angle
                    }
            )
        }
        .frame(maxWidth: .infinity)
    }

    private func dialVector(length: CGFloat) -> CGSize {
        let radians = clampedValue * .pi / 180
        return CGSize(
            width: cos(radians) * length,
            height: -sin(radians) * length
        )
    }
}

#Preview {
    ContentView(
        lightController: LightController(),
        showAbout: {},
        quitApp: {}
    )
}

private extension LightEffectMode {
    var localizedTitle: String {
        switch self {
        case .normal:
            return "LIGHT_EFFECT_NORMAL".localized
        case .professional:
            return "LIGHT_EFFECT_PROFESSIONAL".localized
        case .police:
            return "LIGHT_EFFECT_POLICE".localized
        case .fireTruck:
            return "LIGHT_EFFECT_FIRE_TRUCK".localized
        case .campfire:
            return "LIGHT_EFFECT_CAMPFIRE".localized
        case .disco:
            return "LIGHT_EFFECT_DISCO".localized
        }
    }

    var symbolName: String {
        switch self {
        case .normal:
            return "light.min"
        case .professional:
            return "light.beacon.max.fill"
        case .police:
            return "lightswitch.on"
        case .fireTruck:
            return "flame.fill"
        case .campfire:
            return "tent.2.fill"
        case .disco:
            return "sparkles"
        }
    }
}
