import AppKit

final class BorderWidthSliderView: NSView {
    private let slider = NSSlider()
    private let valueLabel = NSTextField(labelWithString: "")
    private var currentValue: CGFloat
    private let onValueChanged: (CGFloat) -> Void
    private var pendingValue: CGFloat?
    private var isValueDeliveryScheduled = false

    init(frame frameRect: NSRect, initialValue: CGFloat, onChange: @escaping (CGFloat) -> Void) {
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

    func updateValue(_ value: CGFloat) {
        let clampedValue = min(LightConfiguration.borderWidthRange.upperBound, max(LightConfiguration.borderWidthRange.lowerBound, value))
        currentValue = clampedValue
        slider.doubleValue = Double(clampedValue)
        updateValueLabel()
    }

    private func setupUI() {
        valueLabel.alignment = .center
        valueLabel.font = .systemFont(ofSize: 11, weight: .medium)
        addSubview(valueLabel)

        slider.minValue = Double(LightConfiguration.borderWidthRange.lowerBound)
        slider.maxValue = Double(LightConfiguration.borderWidthRange.upperBound)
        slider.numberOfTickMarks = 9
        slider.allowsTickMarkValuesOnly = false
        slider.isContinuous = true
        slider.target = self
        slider.action = #selector(handleSliderChange(_:))
        addSubview(slider)

        updateValue(currentValue)
    }

    @objc private func handleSliderChange(_ sender: NSSlider) {
        currentValue = CGFloat(sender.doubleValue)
        updateValueLabel()
        scheduleValueDelivery(currentValue)
    }

    private func scheduleValueDelivery(_ value: CGFloat) {
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
        let value = Int(currentValue.rounded())
        valueLabel.stringValue = "BORDER_WIDTH_LABEL".localizedFormat(String(value))
    }
}
