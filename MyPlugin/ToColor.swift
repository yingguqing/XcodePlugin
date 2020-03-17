//
//  ToColor.swift
//  MyPlugin
//
//  Created by gworld020 on 2020/3/9.
//  Copyright © 2020 影孤清. All rights reserved.
//

import Cocoa
import XcodeKit

/// 颜色字符串转成OC颜色代码
class ToColor: NSObject, XCSourceEditorCommand {
    func perform(with invocation: XCSourceEditorCommandInvocation, completionHandler: @escaping (Error?) -> Void) {
        guard let selection = invocation.selections.first else { return completionHandler(CommandError.noSelection) }
        let startLine = selection.start.line
        let endLine = selection.end.line
        guard startLine == endLine else { return completionHandler(nil) }
        let startColumn = selection.start.column
        let endColumn = selection.end.column
        let selectLine = invocation.lines[startLine]
        var nowString = selectLine
        var colorCode = ""
        let inputStart = "<#"
        let inputEnd = "#>"
        var selectString = String(selectLine[startColumn..<endColumn])
        if startColumn != endColumn, !selectString.hasPrefix(inputStart), !selectString.hasSuffix(inputEnd) {
            // 选中内容
            if selectString.count == 8, startColumn > 11, selectString.hasPrefix("0x") {
                let tag = "UIColorHex("
                let temp = String(selectLine[startColumn - tag.count..<startColumn])
                if temp == tag, let string = NSPasteboard.general.string(forType: .string), !string.isEmpty {
                    let color = string.color
                    if !color.isEmpty {
                        colorCode = "0x\(color)"
                    }
                }
            } else if selectString.count == 6, startColumn > 0 {
                let temp = String(selectLine[startColumn - 1..<startColumn])
                if temp == "#" {
                    selectString = "#\(selectString)"
                }
            }
            if colorCode.isEmpty {
                let color = selectString.color
                guard !color.isEmpty else { return completionHandler(nil) }
                colorCode = color.ocColorCode
            }
            nowString = selectLine.replacingOccurrences(of: selectString, with: colorCode)
        } else {
            // 剪切板有内容
            guard let selectString = NSPasteboard.general.string(forType: .string), !selectString.isEmpty else { return completionHandler(nil) }
            let color = selectString.color
            guard !color.isEmpty else { return completionHandler(nil) }
            colorCode = color.ocColorCode
            if let selectRange = Range(NSRange(location: startColumn, length: endColumn - startColumn), in: nowString) {
                nowString.removeSubrange(selectRange)
            }
            let index = nowString.index(nowString.startIndex, offsetBy: startColumn)
            nowString.insert(contentsOf: colorCode, at: index)
        }
        
        invocation.buffer.lines[startLine] = nowString
        let end = startColumn + colorCode.count
        let position = XCSourceTextPosition(line: startLine, column: end)
        let updatedSelection = XCSourceTextRange(start: position, end: position)
        invocation.buffer.selections.setArray([updatedSelection])
        completionHandler(nil)
    }
    
}

private extension String {
    // OC颜色代码
    var ocColorCode: String {
        return String(format: "UIColorHex(0x%@)", self.color.uppercased())
    }
    
    // 提取16进制颜色字符串
    var color: String {
        var skip = 0
        if self.hasPrefix("#") {
            skip = 1
        } else if self.hasPrefix("0x") {
            skip = 2
        }
        guard self.count - skip >= 6 else { return "" }
        // 取出颜色中间6位
        let hex = String(self[skip..<skip + 6])
        guard hex.hexToInt > -1 else { return "" }
        return hex
    }
    
    /// 16进制转成10进制数值
    var hexToInt:Int {
        guard !self.isEmpty else { return -1 }
        let scan: Scanner = Scanner(string: self)
        var val:UInt64 = 0
        guard scan.scanHexInt64(&val) && scan.isAtEnd else { return -1 }
        return Int(val)
    }
    
    /// 对应的RGBA值
    var colorValue:[Int] {
        var color = self.color
        guard !color.isEmpty else { return [] }
        var alpha = ""
        if color.count > 6 {
            alpha = String(color.suffix(2))
            color = String(color.prefix(6))
        }
        let color_vaule = color.hexToInt
        let redValue = Int((color_vaule & 0xFF0000) >> 16)
        let greenValue = Int((color_vaule & 0xFF00) >> 8)
        let blueValue = Int(color_vaule & 0xFF)
        var alphaValue = 255
        if alpha.hexToInt != -1 {
            alphaValue = alpha.hexToInt
        }
        return [redValue, greenValue, blueValue, alphaValue]
    }
}
