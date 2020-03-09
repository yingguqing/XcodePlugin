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
class ToColor: NSObject , XCSourceEditorCommand {

    func perform(with invocation: XCSourceEditorCommandInvocation, completionHandler: @escaping (Error?) -> Void ) -> Void {
        guard let selection = invocation.selections.first else { return completionHandler(CommandError.noSelection) }
        let startLine = selection.start.line
        let endLine = selection.end.line
        guard startLine == endLine else { return completionHandler(nil) }
        let startColumn = selection.start.column
        let endColumn = selection.end.column
        let selectLine = invocation.lines[startLine]
        let selectString = String(selectLine[startColumn..<endColumn])
        var color = ""
        if selectString.hasPrefix("#"), selectString.count == 7 {
            color = selectString.replacingOccurrences(of: "#", with: "0x")
        } else if selectString.hasPrefix("0x"), selectString.count == 8 {
            color = selectString
        }
        guard !color.isEmpty else { return completionHandler(nil) }
        // OC颜色代码
        let ocColorCode = "UIColorHex(%@);"
        let code = String(format: ocColorCode, color)
        let nowString = selectLine.replacingOccurrences(of: selectString, with: code)
        invocation.buffer.lines[startLine] = nowString
        let startPosition = XCSourceTextPosition(line: startLine, column: startColumn)
        let endPosition = XCSourceTextPosition(line: startLine, column: startColumn)
        let updatedSelection = XCSourceTextRange(start: startPosition, end: endPosition)
        invocation.buffer.selections.setArray([updatedSelection])
        completionHandler(nil)
    }
    
}
