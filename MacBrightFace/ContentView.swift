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

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(lightController.isOn ? Color.yellow.opacity(0.18) : Color.secondary.opacity(0.12))
                        .frame(width: 42, height: 42)

                    Image(systemName: lightController.isOn ? "lightbulb.fill" : "lightbulb")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(lightController.isOn ? .yellow : .secondary)
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
            }

            controlCard(
                title: "BRIGHTNESS_SLIDER".localized,
                value: brightnessValueLabel,
                footer: brightnessLabel
            ) {
                Slider(value: brightnessBinding, in: LightConfiguration.brightnessRange)
            }

            controlCard(
                title: "BORDER_WIDTH_MENU".localized,
                value: sizeValueLabel,
                footer: borderWidthLabel
            ) {
                Slider(
                    value: borderWidthBinding,
                    in: Double(LightConfiguration.borderWidthRange.lowerBound)...Double(LightConfiguration.borderWidthRange.upperBound)
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
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.primary.opacity(0.05))
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
        .frame(width: 320)
    }

    @ViewBuilder
    private func controlCard<Content: View>(
        title: String,
        value: String,
        footer: String,
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
                    .background(Capsule().fill(Color.secondary.opacity(0.12)))
            }

            content()

            Text(footer)
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.primary.opacity(0.05))
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
