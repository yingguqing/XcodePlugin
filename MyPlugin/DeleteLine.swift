//
//  DeleteLine.swift
//  MyPlugin
//
//  Created by 影孤清 on 2019/11/20.
//  Copyright © 2019 影孤清. All rights reserved.
//

import Cocoa
import XcodeKit
// xcode自带删除选中行功能
class DeleteLine : NSObject, XCSourceEditorCommand {
    // MARK: 删除选中行代码
    func perform(with invocation: XCSourceEditorCommandInvocation, completionHandler: @escaping (Error?) -> Void ) -> Void {
        var newLine = -1
        
        let selections = invocation.selections
        guard !selections.isEmpty else {
            completionHandler(CommandError.noSelection)
            return
        }
        for range in selections {
            let startLine = range.start.line
            let endLine = range.end.line
            if newLine == -1 {
                newLine = startLine
            }
            let length = endLine + 1 - startLine
            let deleteRange = NSRange(location: startLine, length: length)
            invocation.buffer.lines.removeObjects(in: deleteRange)
        }
        
        newLine = min(newLine, invocation.buffer.lines.count - 1)
        invocation.buffer.selections.removeAllObjects()
        
        let currentPosition = XCSourceTextPosition(line: newLine, column: 0)
        let updatedSelection = XCSourceTextRange(start: currentPosition, end: currentPosition)
        invocation.buffer.selections.setArray([updatedSelection])
        completionHandler(nil)
    }
}

