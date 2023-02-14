//
//  CommandLine.swift
//  MyPlugin
//
//  Created by 影孤清 on 2019/11/20.
//  Copyright © 2019 影孤清. All rights reserved.
//

import Cocoa
import XcodeKit

private extension Language {
    var header:String {
        switch self {
            case .UnKnow, .Swift, .ObjectC:
                return "//"
            case .Ruby:
                return "#"
        }
    }
}

//MARK: 使用// 注释代码
class CommandLine : NSObject, XCSourceEditorCommand {
    
    private enum CommandType {
        case Add,Del
    }
    
    func perform(with invocation: XCSourceEditorCommandInvocation, completionHandler: @escaping (Error?) -> Void ) -> Void {
        let selections = invocation.selections
        // 根据文本语言来添加注释头
        let header = invocation.language.header
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
                if !line.hasPrefix(header) {
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
                    stringNew.insert(contentsOf: header, at: index)
                } else if let range = stringNew.range(of: header) {
                    //删除注释
                    stringNew.replaceSubrange(range, with: "")
                } else {
                    continue
                }
                invocation.buffer.lines.replaceObject(at: lineIndex, with: stringNew)
                if startLine == endLine {
                    if type == .Add {
                        range.start = XCSourceTextPosition(line: range.start.line, column: range.start.column + 2)
                        range.end = XCSourceTextPosition(line: range.start.line, column: range.start.column + 2)
                    } else {
                        range.start = XCSourceTextPosition(line: range.start.line, column: range.start.column - 2)
                        range.end = XCSourceTextPosition(line: range.start.line, column: range.start.column - 2)
                    }
                }
            }
        }
        completionHandler(nil)
    }
}
