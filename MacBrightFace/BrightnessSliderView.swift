import AppKit

final class BrightnessSliderView: NSView {
    private let slider = NSSlider()
    private let valueLabel = NSTextField(labelWithString: "")
    private var currentValue: Double
    private let onValueChanged: (Double) -> Void
    private var pendingValue: Double?
    private var isValueDeliveryScheduled = false

    init(frame frameRect: NSRect, initialValue: Double, onChange: @escaping (Double) -> Void) {
        currentValue = initialValue
        onValueChanged = onChange
        super.init(frame: frameRect)
        setupUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()

        valueLabel.frame = NSRect(x: 10, y: bounds.height - 28, width: bounds.width - 20, height: 18)
        slider.frame = NSRect(x: 10, y: 8, width: bounds.width - 20, height: 28)
    }

    func updateValue(_ value: Double) {
        let clampedValue = min(LightConfiguration.brightnessRange.upperBound, max(LightConfiguration.brightnessRange.lowerBound, value))
        currentValue = clampedValue
        slider.doubleValue = clampedValue
        updateValueLabel()
    }

    private func setupUI() {
        valueLabel.alignment = .center
        valueLabel.font = .systemFont(ofSize: 11, weight: .medium)
        addSubview(valueLabel)

        slider.minValue = LightConfiguration.brightnessRange.lowerBound
        slider.maxValue = LightConfiguration.brightnessRange.upperBound
        slider.numberOfTickMarks = 11
        slider.allowsTickMarkValuesOnly = false
        slider.isContinuous = true
        slider.target = self
        slider.action = #selector(handleSliderChange(_:))
        addSubview(slider)

        updateValue(currentValue)
    }

    @objc private func handleSliderChange(_ sender: NSSlider) {
        currentValue = sender.doubleValue
        updateValueLabel()
        scheduleValueDelivery(currentValue)
    }

    private func scheduleValueDelivery(_ value: Double) {
        pendingValue = value
        guard !isValueDeliveryScheduled else { return }

        isValueDeliveryScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            isValueDeliveryScheduled = false
            guard let pendingValue else { return }

            self.pendingValue = nil
            onValueChanged(pendingValue)
        }
    }

    private func updateValueLabel() {
        let percentage = Int((currentValue * 100).rounded())
        valueLabel.stringValue = "BRIGHTNESS_LABEL".localizedFormat(String(percentage))
    }
}
