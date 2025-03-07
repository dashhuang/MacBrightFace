//
//  LightView.swift
//  MacBrightFace
//
//  Created for MacBrightFace app.
//

import SwiftUI
import Combine
import AppKit

struct LightView: View {
    let brightness: Double
    let isHDREnabled: Bool
    let maxHDRFactor: Double
    
    // 根据亮度值计算有效亮度
    private var effectiveBrightness: Double {
        // 每次启动时打印一次显示器支持的最大HDR系数
        struct MaxHDRLogState {
            static var logged = false
        }
        
        if !MaxHDRLogState.logged {
            print("\n【显示器信息】当前显示器支持的最大HDR系数: \(maxHDRFactor)")
            MaxHDRLogState.logged = true
        }
        
        // 调整亮度
        var result: Double = 0
        
        // 确保亮度值在0.01到3.5之间，与滑动器范围一致
        let constrainedValue = max(0.01, min(3.5, brightness))
        
        if isHDREnabled {
            // HDR模式下使用平滑的亮度曲线
            let actualHDRFactor = maxHDRFactor
            
            // 记录HDR系数（仅首次）
            struct HDRFactorLogState {
                static var logged = false
            }
            
            if !HDRFactorLogState.logged {
                print("【亮度计算】原始最大HDR系数: \(maxHDRFactor)")
                print("【亮度计算】实际使用的HDR系数: \(actualHDRFactor) (不再限制为2.0)")
                HDRFactorLogState.logged = true
            }
            
            // 最大安全亮度
            let safeMaxBrightness = actualHDRFactor
            
            // 使用平滑曲线计算目标亮度
            let normalizedInput = constrainedValue / 3.5  // 归一化输入为0-1范围
            
            // 混合线性和二次曲线获得平滑亮度变化
            let linearComponent = safeMaxBrightness * normalizedInput * 0.4
            let quadraticComponent = safeMaxBrightness * pow(normalizedInput, 2) * 0.6
            
            // 合并所有分量
            result = linearComponent + quadraticComponent
            
            // 确保结果不超过安全最大值
            let finalResult = min(safeMaxBrightness, result)
            
            // 如果结果被限制，记录一下
            if result > safeMaxBrightness {
                // 仅在特定百分比位置记录一次
                struct LimitLogState {
                    static var loggedPercentages = Set<Int>()
                }
                
                let percentInt = Int(normalizedInput * 100)
                if !LimitLogState.loggedPercentages.contains(percentInt) && percentInt % 10 == 0 {
                    print("【亮度限制】在\(percentInt)%位置，计算结果\(result)超过上限\(safeMaxBrightness)，已限制")
                    LimitLogState.loggedPercentages.insert(percentInt)
                }
            }
            
            result = finalResult
            
            // 定期记录详细日志
            struct ExtraLogState {
                static var lastLogTime: Date = Date(timeIntervalSince1970: 0)
            }
            
            let now = Date()
            if now.timeIntervalSince(ExtraLogState.lastLogTime) > 3.0 {
                let sliderPercentage = (constrainedValue / 3.5) * 100
                print("【HDR模式】滑块位置: \(String(format: "%.1f", sliderPercentage))%, 亮度: \(String(format: "%.3f", result)), 线性分量: \(String(format: "%.3f", linearComponent)), 二次分量: \(String(format: "%.3f", quadraticComponent)), 最大值: \(safeMaxBrightness)")
                ExtraLogState.lastLogTime = now
            }
        } else {
            // 标准模式下的亮度计算
            let safeMaxBrightness = 1.5  // 标准模式下最大亮度
            
            // 记录标准模式信息（仅首次）
            struct StandardFactorLogState {
                static var logged = false
            }
            
            if !StandardFactorLogState.logged {
                print("【亮度计算】标准模式下使用固定亮度上限: \(safeMaxBrightness)")
                StandardFactorLogState.logged = true
            }
            
            // 使用与HDR模式相同的平滑曲线策略
            let normalizedInput = constrainedValue / 3.5  // 归一化输入为0-1范围
            
            // 混合线性和二次曲线获得平滑亮度变化
            let linearComponent = safeMaxBrightness * normalizedInput * 0.4
            let quadraticComponent = safeMaxBrightness * pow(normalizedInput, 2) * 0.6
            
            // 合并所有分量
            result = linearComponent + quadraticComponent
            
            // 确保结果不超过安全最大值
            let finalResult = min(safeMaxBrightness, result)
            
            // 如果结果被限制，记录一下
            if result > safeMaxBrightness {
                // 仅在特定百分比位置记录一次
                struct StandardLimitLogState {
                    static var loggedPercentages = Set<Int>()
                }
                
                let percentInt = Int(normalizedInput * 100)
                if !StandardLimitLogState.loggedPercentages.contains(percentInt) && percentInt % 10 == 0 {
                    print("【亮度限制】在\(percentInt)%位置，计算结果\(result)超过上限\(safeMaxBrightness)，已限制")
                    StandardLimitLogState.loggedPercentages.insert(percentInt)
                }
            }
            
            result = finalResult
            
            // 定期记录详细日志
            struct StandardModeLogState {
                static var lastLogTime: Date = Date(timeIntervalSince1970: 0)
            }
            
            let now = Date()
            if now.timeIntervalSince(StandardModeLogState.lastLogTime) > 3.0 {
                let sliderPercentage = (constrainedValue / 3.5) * 100
                print("【标准模式】滑块位置: \(String(format: "%.1f", sliderPercentage))%, 亮度: \(String(format: "%.3f", result)), 线性分量: \(String(format: "%.3f", linearComponent)), 二次分量: \(String(format: "%.3f", quadraticComponent)), 最大值: \(safeMaxBrightness)")
                StandardModeLogState.lastLogTime = now
            }
        }
        
        // 减少日志输出频率
        struct LogState {
            static var lastLoggedBrightness: Double = -1
            static var lastLogTime: Date = Date(timeIntervalSince1970: 0)
        }
        
        // 只在亮度变化明显或间隔较长时记录日志
        let now = Date()
        if abs(LogState.lastLoggedBrightness - brightness) > 0.1 || 
           LogState.lastLoggedBrightness < 0 ||
           now.timeIntervalSince(LogState.lastLogTime) > 5.0 {
            let sliderPercentage = (constrainedValue / 3.5) * 100
            print("【亮度变化】滑块位置: \(String(format: "%.1f", sliderPercentage))%, 亮度值: \(String(format: "%.3f", result)), HDR: \(isHDREnabled ? "开" : "关")")
            LogState.lastLoggedBrightness = brightness
            LogState.lastLogTime = now
        }
        
        return result
    }
    
    // 计算基础透明度，与亮度成正比但有上下限
    private var baseOpacity: Double {
        // 使用指数函数使透明度随亮度非线性变化，确保更明显的阶梯变化
        let opacityExponent = isHDREnabled ? 0.65 : 0.55
        let multiplier = isHDREnabled ? 0.25 : 0.3
        
        // 为防止溢出和黑屏问题，限制effectiveBrightness的影响范围
        let safeEffectiveBrightness = min(30.0, effectiveBrightness)
        
        // 基于亮度值使用不同的基础透明度计算，确保高亮度区域有明显差异
        if brightness < 0.5 {
            return min(0.95, max(0.15, pow(safeEffectiveBrightness * multiplier, opacityExponent)))
        } else if brightness < 1.0 {
            return min(0.95, max(0.2, pow(safeEffectiveBrightness * multiplier, opacityExponent) + 0.05))
        } else if brightness < 3.0 {
            // 增加60%以上亮度的基础透明度
            return min(0.95, max(0.3, pow(safeEffectiveBrightness * multiplier, opacityExponent) + 0.15))
        } else if brightness < 5.0 {
            // 80%区域透明度明显区分
            return min(0.95, max(0.4, pow(safeEffectiveBrightness * multiplier, opacityExponent) + 0.25))
        } else if brightness < 7.0 {
            // 90%区域透明度进一步提高，确保与80%有明显区别
            return min(0.95, max(0.5, pow(safeEffectiveBrightness * multiplier, opacityExponent) + 0.35))
        } else {
            // 最高亮度区域透明度达到最大
            return min(0.95, max(0.6, pow(safeEffectiveBrightness * multiplier, opacityExponent) + 0.45))
        }
    }
    
    // 获取视图亮度增强值，增强高亮度区域的效果
    private var brightnessEnhancement: Double {
        if brightness < 1.0 {
            return isHDREnabled ? effectiveBrightness * 0.4 : effectiveBrightness * 0.25
        } else if brightness < 3.0 {
            // 60%以上亮度区域显著增强
            return isHDREnabled ? effectiveBrightness * 0.5 : effectiveBrightness * 0.35
        } else if brightness < 5.0 {
            // 80%以上亮度区域明显增强
            return isHDREnabled ? min(2.0, effectiveBrightness * 0.6) : min(1.5, effectiveBrightness * 0.45)
        } else if brightness < 7.0 {
            // 90%区域特别明亮
            return isHDREnabled ? min(2.5, effectiveBrightness * 0.7) : min(1.8, effectiveBrightness * 0.5)
        } else {
            // 最高亮度区域明显不同于其他区域
            return isHDREnabled ? min(3.0, effectiveBrightness * 0.8) : min(2.0, effectiveBrightness * 0.6)
        }
    }
    
    // 获取对比度增强值，同样增强高亮度区域
    private var contrastEnhancement: Double {
        if brightness < 1.0 {
            return isHDREnabled ? 1 + (effectiveBrightness * 0.25) : 1 + (effectiveBrightness * 0.15)
        } else if brightness < 3.0 {
            // 60%以上亮度区域增强对比度
            return isHDREnabled ? 1 + (effectiveBrightness * 0.3) : 1 + (effectiveBrightness * 0.2)
        } else if brightness < 5.0 {
            // 80%以上亮度区域增强对比度，确保与60%有明显区别
            return isHDREnabled ? min(2.0, 1 + (effectiveBrightness * 0.35)) : min(1.7, 1 + (effectiveBrightness * 0.25))
        } else if brightness < 7.0 {
            // 90%区域对比度特殊增强
            return isHDREnabled ? min(2.3, 1 + (effectiveBrightness * 0.4)) : min(1.9, 1 + (effectiveBrightness * 0.3))
        } else {
            // 最高亮度区域对比度达到最高
            return isHDREnabled ? min(2.5, 1 + (effectiveBrightness * 0.45)) : min(2.1, 1 + (effectiveBrightness * 0.35))
        }
    }
    
    private var debugInfo: String {
        return "亮度:\(String(format: "%.2f", brightness)) 实际:\(String(format: "%.2f", effectiveBrightness)) HDR:\(isHDREnabled ? "开" : "关")"
    }
    
    // 调试模式开关
    private var isDebugMode: Bool {
        #if DEBUG
        return false  // 更改为false以关闭调试信息显示
        #else
        return false
        #endif
    }
    
    var body: some View {
        ZStack {
            // 基础层 - 亮度最低时也可见
            Color.white
                .opacity(0.3 + baseOpacity * 0.3)
            
            // 中间强度层 - 根据亮度级别调整
            Rectangle()
                .fill(Color.white)
                .opacity(baseOpacity * (brightness < 1.0 ? 0.7 : 0.8))
            
            // 高亮区域 - 随亮度变化明显，根据亮度级别调整系数
            Rectangle()
                .fill(Color.white)
                .opacity(min(1.0, brightness < 1.0 ? effectiveBrightness * 0.4 : effectiveBrightness * 0.5))
            
            // HDR模式下添加额外的高亮效果，对不同亮度级别进行区分处理
            if isHDREnabled {
                // 基础HDR层 - 所有亮度都有
                Rectangle()
                    .fill(Color.white)
                    .blur(radius: 10)
                    .opacity(min(0.95, effectiveBrightness * 0.35))
                
                // 中等亮度HDR层 - 亮度 > 0.5
                if brightness > 0.5 {
                    Rectangle()
                        .fill(Color.white)
                        .blur(radius: 8)
                        .opacity(min(0.9, effectiveBrightness * 0.4))
                }
                
                // 高亮度HDR层 - 亮度 > 1.0 (60%)
                if brightness > 1.0 {
                    Rectangle()
                        .fill(Color.white)
                        .blur(radius: 6)
                        .opacity(min(0.92, effectiveBrightness * 0.45))
                }
                
                // 很高亮度HDR层 - 亮度 > 3.0 (80%)
                if brightness > 3.0 {
                    Rectangle()
                        .fill(Color.white)
                        .blur(radius: 4)
                        .opacity(min(0.95, effectiveBrightness * 0.5 + (brightness - 3.0) * 0.1))
                }
                
                // 最高亮度HDR层 - 亮度 > 5.0 (100%)
                if brightness > 5.0 {
                    Rectangle()
                        .fill(Color.white)
                        .blur(radius: 2)
                        .opacity(min(0.95, effectiveBrightness * 0.4 + min(0.3, (brightness - 5.0) * 0.05)))
                }
            } else {
                // 非HDR模式下也区分不同亮度级别
                
                // 中等亮度层 - 亮度 > 0.5
                if brightness > 0.5 {
                    Rectangle()
                        .fill(Color.white)
                        .blur(radius: 6)
                        .opacity(min(0.85, effectiveBrightness * 0.3))
                }
                
                // 高亮度层 - 亮度 > 1.0 (60%)
                if brightness > 1.0 {
                    Rectangle()
                        .fill(Color.white)
                        .blur(radius: 5)
                        .opacity(min(0.88, effectiveBrightness * 0.35))
                }
                
                // 很高亮度层 - 亮度 > 3.0 (80%)
                if brightness > 3.0 {
                    Rectangle()
                        .fill(Color.white)
                        .blur(radius: 4)
                        .opacity(min(0.9, effectiveBrightness * 0.4 + (brightness - 3.0) * 0.08))
                }
                
                // 最高亮度层 - 亮度 > 5.0 (100%)
                if brightness > 5.0 {
                    Rectangle()
                        .fill(Color.white)
                        .blur(radius: 3)
                        .opacity(min(0.9, effectiveBrightness * 0.35 + min(0.2, (brightness - 5.0) * 0.04)))
                }
            }
            
            // 视觉效果增强区域 - 亮度敏感
            Rectangle()
                .fill(Color.white)
                .blur(radius: brightness < 1.0 ? 8 : brightness < 3.0 ? 6 : 4)
                .opacity(min(0.9, effectiveBrightness * (brightness < 1.0 ? 0.25 : brightness < 3.0 ? 0.3 : 0.35)))
            
            // 调试信息 - 仅在调试模式下显示
            if isDebugMode {
                Text(debugInfo)
                    .font(.system(size: 12))
                    .foregroundColor(.black)
                    .padding(4)
                    .background(Color.white.opacity(0.7))
                    .cornerRadius(4)
                    .position(x: 150, y: 30)
                    .opacity(0.8)
            }
        }
        .edgesIgnoringSafeArea(.all)
        .brightness(brightnessEnhancement)
        .contrast(contrastEnhancement)
        .saturation(1 + (isHDREnabled ? effectiveBrightness * 0.05 : 0)) // 轻微增加饱和度
        .drawingGroup() // 使用Metal渲染，提高性能
        .animation(.easeInOut(duration: 0.2), value: brightness) // 加快动画响应
        .onAppear {
            // 减少onAppear日志输出频率，使用静态计数器
            struct OnAppearLogState {
                static var count: Int = 0
                static var lastLogTime = Date(timeIntervalSince1970: 0)
            }
            
            let now = Date()
            let timeSinceLastLog = now.timeIntervalSince(OnAppearLogState.lastLogTime)
            
            // 只有在间隔超过5秒或者是第一次出现时才记录日志
            if timeSinceLastLog > 5.0 || OnAppearLogState.count == 0 {
                print("【LightView】视图初始化 - 亮度:\(brightness) 效果亮度:\(effectiveBrightness) HDR:\(isHDREnabled ? "开" : "关")")
                OnAppearLogState.lastLogTime = now
            }
            
            OnAppearLogState.count += 1
        }
    }
}

// 不再使用复杂的Metal渲染
// 以下是Preview
#Preview {
    LightView(brightness: 0.75, isHDREnabled: false, maxHDRFactor: 2.0)
} 