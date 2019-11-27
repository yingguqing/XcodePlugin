//
//  InsertEnter.swift
//  XcodePlugin
//
//  Created by 影孤清 on 2019/11/21.
//  Copyright © 2019 影孤清. All rights reserved.
//

import Cocoa
import XcodeKit

//MARK: 向上或向下添加一个回车
class InsertEnter : NSObject, XCSourceEditorCommand {
    func perform(with invocation: XCSourceEditorCommandInvocation, completionHandler: @escaping (Error?) -> Void ) -> Void {
        let identifier = invocation.commandIdentifier
        guard !identifier.isEmpty else {
            completionHandler(nil)
            return
        }
        
        var direction:LineDirection = .UP
        if identifier == "yingguqing.UpInsertEnter" {
            // 向上复制选中代码
            direction = .UP
        } else if identifier == "yingguqing.DownInsertEnter" {
            // 向下复制选中代码
            direction = .Down
        }
        guard let selection = invocation.buffer.selections.firstObject as? XCSourceTextRange, let lines = invocation.buffer.lines as? [String] else {
            completionHandler(CommandError.noSelection)
            return
        }
        var index = 0

        let insertIndex = selection.start.line + direction.rawValue
        var string:String
        if ((insertIndex == 0) || direction != .UP) {
            string = lines[selection.start.line]
        } else {
            string = lines[selection.start.line - 1]
        }
        var insertString = string.frontSpace
        
        index = insertString.count
        insertString.append("\n")
        invocation.buffer.lines.insert(insertString, at: insertIndex)
        
        let currentPosition = XCSourceTextPosition(line: insertIndex, column: index)
        let updatedSelection = XCSourceTextRange(start: currentPosition, end: currentPosition)
        invocation.buffer.selections.setArray([updatedSelection])
        completionHandler(nil)
    }
}

