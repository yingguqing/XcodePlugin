//
//  AddImport.swift
//  XcodePlugin
//
//  Created by 影孤清 on 2019/11/21.
//  Copyright © 2019 影孤清. All rights reserved.
//

import Cocoa
import XcodeKit

// MARK: 导入头文件
class AddImport: NSObject, XCSourceEditorCommand {
    func perform(with invocation: XCSourceEditorCommandInvocation, completionHandler: @escaping (Error?) -> Void) {
        do {
            try invocation.addImport()
            completionHandler(nil)
        } catch {
            completionHandler(error)
        }
    }
}

private enum AddImportOperationConstants {
    /// Import matchers
    static let objcImport = "#\\s*(import|include).*[\",<].*[\",>]"
    static let objcModuleImport = "@(import).*."
    static let swiftModuleImport = "(import) +.*."
    static let objcClassForwardDeclaration = "@(class).*."
    
    /// Double import strings
    /// Note: For the `doubleImportWarningString` string, we're using a non-breaking space (\u00A0), not a normal space
    static let doubleImportWarningString = "🚨 这个头文件已被导入 🚨"
    
    static let cancelRemoveImportButtonString = "完成"
    
    static let importRegex = try! NSRegularExpression(pattern: AddImportOperationConstants.objcImport, options: [])
    static let moduleImportRegex = try! NSRegularExpression(pattern: AddImportOperationConstants.objcModuleImport, options: [])
    static let swiftModuleImportRegex = try! NSRegularExpression(pattern: AddImportOperationConstants.swiftModuleImport, options: [])
    static let objcClassForwardDeclarationRegex = try! NSRegularExpression(pattern: AddImportOperationConstants.objcClassForwardDeclaration, options: [])
}

private extension XCSourceEditorCommandInvocation {
    func addImport() throws {
        guard let selection = self.selections.first else { throw CommandError.noSelection }
        let selectionLine = selection.start.line
        let importString = self.lines[selectionLine].trimmingCharacters(in: .whitespaces)
        if !isValid(importString: importString) {
            var start = 0
            var selectString = "<#header#>"
            if selection.start.line == selection.end.line, selection.start.column != selection.end.column {
                // 有选中内容
                let string = self.lines[selectionLine]
                selectString = string[selection.start.column ..< selection.end.column]
            }
            if language == .Swift {
                self.buffer.lines.insert("import \(selectString)", at: selectionLine)
                start = 7
            } else {
                self.buffer.lines.insert("#import \"\(selectString).h\"", at: selectionLine)
                start = 9
            }
            let selectionPosition = XCSourceTextRange(start: XCSourceTextPosition(line: selectionLine, column: start), end: XCSourceTextPosition(line: selectionLine, column: start + 6))
            self.buffer.selections.removeAllObjects()
            self.buffer.selections.add(selectionPosition)
            return
        }
        let line = appropriateLine(ignoringLine: selectionLine)
        guard line != NSNotFound else { return }
        var lineToRemove: Int = NSNotFound
        guard self.buffer.canIncludeImportString(importString, atLine: line) else {
            // we need to run this on the main thread since we're getting called on a seconday thread
            OperationQueue.main.addOperation({
                lineToRemove = selectionLine
                let doubleImportAlert = NSAlert()
                doubleImportAlert.icon = #imageLiteral(resourceName: "ImportIcon")
                doubleImportAlert.messageText = AddImportOperationConstants.doubleImportWarningString
                doubleImportAlert.addButton(withTitle: AddImportOperationConstants.cancelRemoveImportButtonString)
                // We're creating a "fake" view so that the text doesn't wrap on two lines
                let fakeRect: NSRect = .init(x: 0, y: 0, width: 307, height: 0)
                let fakeView = NSView(frame: fakeRect)
                doubleImportAlert.accessoryView = fakeView
                NSSound.beep()
                let frontmostApplication = NSWorkspace.shared.frontmostApplication
                let appWindow = doubleImportAlert.window
                appWindow.makeKeyAndOrderFront(appWindow)
                NSApp.activate(ignoringOtherApps: true)
                let response = doubleImportAlert.runModal()
                if response == NSApplication.ModalResponse.alertFirstButtonReturn {
                    let currentPosition = XCSourceTextPosition(line: selectionLine, column: 0)
                    let updatedSelection = XCSourceTextRange(start: currentPosition, end: currentPosition)
                    self.buffer.lines.removeObject(at: lineToRemove)
                    self.buffer.selections.setArray([updatedSelection])
                }
                NSApp.deactivate()
                frontmostApplication?.activate(options: [])
            })
            return
        }
        
        self.buffer.lines.removeObject(at: selectionLine)
        self.buffer.lines.insert(importString, at: line)
        
        // add a new selection. Bug fix for #7
        let currentPosition = XCSourceTextPosition(line: selectionLine, column: 0)
        let updatedSelection = XCSourceTextRange(start: currentPosition, end: currentPosition)
        self.buffer.selections.setArray([updatedSelection])
    }
    
    func isValid(importString: String) -> Bool {
        var numberOfMatches = 0
        let matchingOptions: NSRegularExpression.MatchingOptions = []
        let range = NSMakeRange(0, importString.count)
        
        if language == .Swift {
            numberOfMatches = AddImportOperationConstants.swiftModuleImportRegex.numberOfMatches(in: importString, options: matchingOptions, range: range)
        } else {
            numberOfMatches = AddImportOperationConstants.importRegex.numberOfMatches(in: importString, options: matchingOptions, range: range)
            numberOfMatches = numberOfMatches > 0 ? numberOfMatches : AddImportOperationConstants.moduleImportRegex.numberOfMatches(in: importString, options: matchingOptions, range: range)
            numberOfMatches = numberOfMatches > 0 ? numberOfMatches : AddImportOperationConstants.objcClassForwardDeclarationRegex.numberOfMatches(in: importString, options: matchingOptions, range: range)
        }
        
        return numberOfMatches > 0
    }
        
    func appropriateLine(ignoringLine: Int) -> Int {
        var lineNumber = NSNotFound
        let lines = buffer.lines as NSArray as! [String]
        
        // Find the line that is first after all the imports
        for (index, line) in lines.enumerated() {
            if index == ignoringLine {
                continue
            }
            
            if isValid(importString: line) {
                lineNumber = index
            }
        }
        
        guard lineNumber == NSNotFound else {
            return lineNumber + 1
        }
        
        // if a line is not found, find first free line after comments
        for (index, line) in lines.enumerated() {
            if index == ignoringLine {
                continue
            }
            
            lineNumber = index
            if line.isWhitespaceOrNewline() {
                break
            }
        }
        
        return lineNumber + 1
    }
}

private extension XCSourceTextBuffer {
    /// Checks if the import string isn't already contained in the import list
    ///
    /// - Parameters:
    ///   - importString: The import statement to include
    ///   - atLine: The line where the import should be done. This is to check from lines 0 to atLine
    /// - Returns: true if the statement isn't already included, false if it is
    func canIncludeImportString(_ importString: String, atLine: Int) -> Bool {
        let importBufferArray = self.lines.subarray(with: NSMakeRange(0, atLine)) as NSArray as! [String]
        
        return importBufferArray.contains(importString) == false
    }
}

private extension String {
    func isWhitespaceOrNewline() -> Bool {
        let string = self.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        return string.count == 0
    }
}
