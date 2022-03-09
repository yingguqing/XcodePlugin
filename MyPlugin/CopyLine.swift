//
//  CopyLine.swift
//  MyPlugin
//
//  Created by 影孤清 on 2019/11/20.
//  Copyright © 2019 影孤清. All rights reserved.
//

import Cocoa
import XcodeKit

enum LineDirection:Int {
    case UP = 0 // 向上
    case Down = 1 // 向下
}

// MARK: 向上或向下复制代码
class CopyLine: NSObject, XCSourceEditorCommand {
    func perform(with invocation: XCSourceEditorCommandInvocation, completionHandler: @escaping (Error?) -> Void) {
        let identifier = invocation.commandIdentifier
        guard !identifier.isEmpty else {
            completionHandler(nil)
            return
        }
        var direction:LineDirection = .UP
        if identifier == "yingguqing.CopyLineUp" {
            // 向上复制选中代码
            direction = .UP
        } else if identifier == "yingguqing.CopyLineDown" {
            // 向下复制选中代码
            direction = .Down
        }
        var insertLine = -1
        
        guard let range = invocation.selections.first else {
            completionHandler(CommandError.noSelection)
            return
        }
        var stringDuel = ""
        let startLine = range.start.line
        var endLine = range.end.line
        // 当选中多行时，如果最后一行是在第0个位置，则减少一行，防止使用像上下移动代码这种功能，会把下一行也复制
        if startLine != endLine, range.end.column == 0 {
            endLine -= 1
        }
        guard endLine >= startLine else {
            completionHandler(CommandError.noSelection)
            return
        }
        let length = endLine - startLine
        if insertLine < 0 {
            insertLine = direction == .UP ? startLine : endLine + 1
        } else {
            insertLine += endLine - startLine + 1
        }

        for i in startLine ... endLine {
            guard let string = invocation.buffer.lines[i] as? String else { continue }
            stringDuel.append(string)
        }
        invocation.buffer.lines.insert(stringDuel, at: insertLine)
        
        let startPosition = XCSourceTextPosition(line: insertLine, column: range.start.column)
        let endPosition = XCSourceTextPosition(line: insertLine + length, column: range.end.column)
        let updatedSelection = XCSourceTextRange(start: startPosition, end: endPosition)
        invocation.buffer.selections.setArray([updatedSelection])
        completionHandler(nil)
    }
}
