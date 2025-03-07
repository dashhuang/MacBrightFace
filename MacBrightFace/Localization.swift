//
//  Localization.swift
//  Light
//
//  Minimal localization helper using system APIs
//

import Foundation

/// 为String添加简便的本地化方法
extension String {
    /// 使用系统标准API进行本地化
    var localized: String {
        return NSLocalizedString(self, comment: "")
    }
    
    /// 格式化本地化字符串
    func localizedFormat(_ arguments: CVarArg...) -> String {
        let localizedFormat = NSLocalizedString(self, comment: "")
        return String(format: localizedFormat, arguments: arguments)
    }
} 