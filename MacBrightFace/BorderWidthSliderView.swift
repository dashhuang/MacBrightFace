import SwiftUI
import AppKit

class BorderWidthSliderView: NSView {
    private var slider: NSSlider!
    private var valueLabel: NSTextField!
    private var onValueChanged: ((CGFloat) -> Void)?
    private var currentValue: CGFloat = 80 // 默认80像素
    
    // 滑块的最小和最大值
    private let minWidth: CGFloat = 20
    private let maxWidth: CGFloat = 200 // 最大宽度设置为200像素，可根据需要调整
    
    // 自定义初始化方法，接受初始值和回调
    init(frame frameRect: NSRect, initialValue: CGFloat, onChange: @escaping (CGFloat) -> Void) {
        super.init(frame: frameRect)
        self.currentValue = initialValue
        self.onValueChanged = onChange
        self.setupViews()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.setupViews()
    }
    
    private func setupViews() {
        // 创建显示当前值的标签
        valueLabel = NSTextField(frame: NSRect(x: 10, y: 40, width: frame.width - 20, height: 20))
        valueLabel.isEditable = false
        valueLabel.isBordered = false
        valueLabel.backgroundColor = .clear
        valueLabel.alignment = .center
        valueLabel.font = NSFont.systemFont(ofSize: 11)
        updateValueLabel()
        addSubview(valueLabel)
        
        // 创建滑动控件
        slider = NSSlider(frame: NSRect(x: 10, y: 10, width: frame.width - 20, height: 20))
        slider.minValue = Double(minWidth)
        slider.maxValue = Double(maxWidth)
        slider.doubleValue = Double(currentValue)
        
        // 添加滑动标记
        slider.allowsTickMarkValuesOnly = false
        slider.numberOfTickMarks = 10
        slider.tickMarkPosition = .below
        
        // 设置回调
        slider.target = self
        slider.action = #selector(sliderValueChanged(_:))
        
        addSubview(slider)
    }
    
    @objc private func sliderValueChanged(_ sender: NSSlider) {
        currentValue = CGFloat(sender.doubleValue)
        updateValueLabel()
        onValueChanged?(currentValue)
    }
    
    private func updateValueLabel() {
        // 计算宽度值与最大值的百分比
        let percentage = Int(((currentValue - minWidth) / (maxWidth - minWidth)) * 100)
        valueLabel.stringValue = "宽度: \(Int(currentValue))像素 (\(percentage)%)"
    }
    
    // 提供更新当前值的公共方法
    func updateValue(_ value: CGFloat) {
        // 确保值在范围内
        let safeValue = min(maxWidth, max(minWidth, value))
        currentValue = safeValue
        slider.doubleValue = Double(safeValue)
        updateValueLabel()
    }
} 