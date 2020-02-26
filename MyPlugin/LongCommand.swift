//
//  LongCommand.swift
//  XcodePlugin
//
//  Created by 影孤清 on 2019/11/21.
//  Copyright © 2019 影孤清. All rights reserved.
//

import Cocoa
import XcodeKit

// MARK: /**/注释代码

class LongCommand: NSObject, XCSourceEditorCommand {
    func perform(with invocation: XCSourceEditorCommandInvocation, completionHandler: @escaping (Error?) -> Void) {
        guard let selection = invocation.selections.first, let lines = invocation.buffer.lines as? [String] else {
            completionHandler(CommandError.noSelection)
            return
        }

        var selectStrings = [String]()
        let startLine = selection.start.line
        let startColumn = selection.start.column
        let endLine = selection.end.line
        var endColumn = selection.end.column
        var startString = String(lines[startLine].prefix(startColumn))
        let endLineString = lines[endLine]
        var endString = String(endLineString.suffix(endLineString.count - endColumn))
        if endString.hasSuffix("\n") {
            // 去掉最后一个回车
            endString = String(endString.prefix(endString.count - 1))
        }
        if startLine != endLine { // 跨行选中
            // 第一行从选中位置开始，后面的字符串
            var string = String(lines[startLine].suffix(lines[startLine].count - startColumn))
            selectStrings.append(string)
            // 中间选中
            selectStrings += lines[startLine + 1..<endLine]
            // 选中中的最后一行，到最后选中位置前的字符串
            string = String(lines[endLine].prefix(endColumn))
            selectStrings.append(string)
        } else {
            // 选中代码只在一行
            let string = String(lines[startLine][startColumn..<endColumn])
            selectStrings.append(string)
        }
        var tempString = selectStrings.joined(separator: "")
        let searchString = [("/*\n", "\n*/"), ("/* ", " */"), ("/*", "*/")]
        var isAdd = true
        for value in searchString {
            if let sRange = tempString.range(of: value.0), let eRange = tempString.range(of: value.1, options: .backwards) {
                // 存在/*1*/,先删除后面的*/ 再删除前面的/*
                tempString = tempString.replacingOccurrences(of: value.1, with: "", range: eRange)
                tempString = tempString.replacingOccurrences(of: value.0, with: "", range: sRange)
                if startLine == endLine {
                    endColumn -= 4
                } else {
                    endColumn -= 2
                }
                isAdd = false
                break
            }
        }

        if isAdd { // 添加/**/
            // 同一行或者选中内容在中间（即选中前后有不是空格和回车的字符）
            // 后面这种情况比较少会遇到
            if startLine == endLine || (!startString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !endString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                endColumn += 2
                tempString = "/* \(tempString) */"
            } else {
                // 跨行时，前后新增一个空行来插入/* 和 */
                startString = "/*\n\(startString)"
                endString = "\(endString)\n*/"
            }
        }
        let lineRange = NSRange(location: selection.start.line, length: selection.end.line - selection.start.line + 1)
        // 把第一行的头和最后一行的尾拼接上来
        tempString = startString + tempString + endString
        // 重新切成数据
        let array = tempString.components(separatedBy: "\n")
        // 替换原来的字符串数组
        invocation.buffer.lines.replaceObjects(in: lineRange, withObjectsFrom: array)

        let currentPosition = XCSourceTextPosition(line: endLine, column: endColumn)
        let updatedSelection = XCSourceTextRange(start: currentPosition, end: currentPosition)
        invocation.buffer.selections.setArray([updatedSelection])
        completionHandler(nil)
    }
}
