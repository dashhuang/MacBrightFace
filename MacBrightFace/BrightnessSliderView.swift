//
//  BrightnessSliderView.swift
//  MacBrightFace
//
//  Created for MacBrightFace app.
//

import Foundation
import AppKit

class BrightnessSliderView: NSView {
    private let slider = NSSlider()
    private let valueLabel = NSTextField()
    private var currentValue: Double
    // 最大值设置为3.5，与LightView.swift中使用的constrainedValue范围一致
    // 这确保滑块的0-100%直接映射到亮度计算函数中的0-3.5范围
    private var maxValue: Double = 3.5
    private var onValueChanged: ((Double) -> Void)?
    
    init(frame frameRect: NSRect, initialValue: Double, onChange: @escaping (Double) -> Void) {
        self.currentValue = initialValue
        self.onValueChanged = onChange
        super.init(frame: frameRect)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        self.currentValue = 0.75
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        // 创建显示当前值的标签
        valueLabel.frame = NSRect(x: 10, y: 40, width: frame.width - 20, height: 20)
        valueLabel.isEditable = false
        valueLabel.isBordered = false
        valueLabel.backgroundColor = .clear
        valueLabel.alignment = .center
        valueLabel.font = NSFont.systemFont(ofSize: 11)
        updateValueLabel()
        addSubview(valueLabel)
        
        // 创建滑动控件
        slider.frame = NSRect(x: 10, y: 10, width: frame.width - 20, height: 20)
        slider.minValue = 0.01
        slider.maxValue = maxValue
        slider.doubleValue = currentValue
        
        // 添加滑动标记，均匀分布以便选择合适亮度
        slider.allowsTickMarkValuesOnly = false
        slider.numberOfTickMarks = 10
        slider.tickMarkPosition = .below
        
        // 设置回调
        slider.target = self
        slider.action = #selector(sliderValueChanged(_:))
        slider.isContinuous = true
        
        addSubview(slider)
    }
    
    @objc private func sliderValueChanged(_ sender: NSSlider) {
        currentValue = sender.doubleValue
        updateValueLabel()
        onValueChanged?(currentValue)
    }
    
    private func updateValueLabel() {
        // 将亮度值映射到0-100的百分比范围
        let percentage = Int((currentValue / maxValue) * 100)
        valueLabel.stringValue = "BRIGHTNESS_LABEL".localizedFormat(String(percentage))
    }
    
    func updateValue(_ value: Double) {
        // 确保值在新的范围内
        let safeValue = min(maxValue, max(0.01, value))
        currentValue = safeValue
        slider.doubleValue = safeValue
        updateValueLabel()
    }
} 