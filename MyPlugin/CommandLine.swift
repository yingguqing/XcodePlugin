//
//  CommandLine.swift
//  MyPlugin
//
//  Created by 影孤清 on 2019/11/20.
//  Copyright © 2019 影孤清. All rights reserved.
//

import Cocoa
import XcodeKit

//MARK: 使用// 注释代码
class CommandLine : NSObject, XCSourceEditorCommand {
    
    private enum CommandType {
        case Add,Del
    }
    
    func perform(with invocation: XCSourceEditorCommandInvocation, completionHandler: @escaping (Error?) -> Void ) -> Void {
        let selections = invocation.selections
        guard !selections.isEmpty else {
            completionHandler(CommandError.noSelection)
            return
        }
        for range in selections {
            let startLine = range.start.line
            let endLine = range.end.line
            var type = CommandType.Del
            
            for index in startLine...endLine {
                let string = invocation.lines[index]
                guard !string.isEmpty else { continue }
                let line = string.deleteFirstSpace
                
                // 去掉了顶头的所有空格
                if !line.hasPrefix("//") {
                    type = .Add
                    break
                }
            }

            for lineIndex in startLine...endLine {
                let line = invocation.lines[lineIndex]
                guard !line.deleteFirstSpace.isEmpty else { continue }
                var stringNew = line
                if type == .Add {
                    // 添加注释
                    var index = line.startIndex
                    for i in line.indices {
                        if line[i] != " " {
                            index = i
                            break
                        }
                    }
                    stringNew.insert(contentsOf: "//", at: index)
                    range.start = XCSourceTextPosition(line: range.start.line, column: range.start.column + 2)
                    range.end = XCSourceTextPosition(line: range.start.line, column: range.start.column + 2)
                } else {
                    //删除注释
                    if let range = stringNew.range(of: "//") {
                        stringNew.replaceSubrange(range, with: "")
                    }
                }
                invocation.buffer.lines.replaceObject(at: lineIndex, with: stringNew)
            }
        }
        completionHandler(nil)
    }
}
