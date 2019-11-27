//
//  Capitalization.swift
//  MyPlugin
//
//  Created by 影孤清 on 2019/11/20.
//  Copyright © 2019 影孤清. All rights reserved.
//

import Cocoa
import XcodeKit

// MARK: 选中内容变成大写或小写
class Capitalization : NSObject, XCSourceEditorCommand {
    
    private enum UppercaseLowercase {
        case Uppercase,Lowercase
    }
    
    func perform(with invocation: XCSourceEditorCommandInvocation, completionHandler: @escaping (Error?) -> Void ) -> Void {
        let identifier = invocation.commandIdentifier
        guard !identifier.isEmpty else {
            completionHandler(nil)
            return
        }
        var type:UppercaseLowercase = .Uppercase
        if identifier == "yingguqing.UppercaseString" {
            //选中代码大写
            type = .Uppercase
        } else if identifier == "yingguqing.lowercaseString" {
            //选中代码小写
            type = .Lowercase
        }
        let selections = invocation.selections
        guard !selections.isEmpty else {
            completionHandler(CommandError.noSelection)
            return
        }
        for range in selections {
            let startLine = range.start.line
            let endLine = range.end.line
            let startColumn = range.start.column
            let endColumn = range.end.column
            guard startLine != endLine || startColumn != endColumn else { continue }
            
            for i in startLine...endLine {
                var string = invocation.lines[i]
                guard !string.isEmpty else { continue }
                //选中文字
                let selectString = string[startColumn..<endColumn - startColumn]
                let resultString:String
                // 对选中文字进行大小写
                switch type {
                case .Uppercase:
                    resultString = selectString.uppercased()
                case .Lowercase:
                    resultString = selectString.lowercased()
                }
                let selectRange = Range(NSRange(location: startColumn, length: endColumn - startColumn), in: string)
                string = string.replacingOccurrences(of: selectString, with: resultString, options: .literal, range: selectRange)
                invocation.buffer.lines.replaceObject(at: i, with: string)
            }
        }
        completionHandler(nil)
    }
}
