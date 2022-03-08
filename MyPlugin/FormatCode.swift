//
//  FormatCode.swift
//  MyPlugin
//
//  Created by 影孤清 on 2019/11/20.
//  Copyright © 2019 影孤清. All rights reserved.
//

import Cocoa
import XcodeKit
// MARK: 格式化代码
class FormatCode : NSObject, XCSourceEditorCommand {
    func perform(with invocation: XCSourceEditorCommandInvocation, completionHandler: @escaping (Error?) -> Void ) -> Void {
        do {
            if invocation.buffer.isSwiftSource {
                try formatSwift(invocation)
            } else {
                try formatOC(invocation)
            }
            completionHandler(nil)
        } catch let error {
            print(error.localizedDescription)
            completionHandler(error)
        }
    }
    
    private func formatSwift(_ invocation: XCSourceEditorCommandInvocation) throws {
        guard SupportedContentUTIs.contains(invocation.buffer.contentUTI) else {
            throw FormatCommandError.notSwiftLanguage
        }

        // Grab the file source to format
        let sourceToFormat = invocation.buffer.completeBuffer
        let input = tokenize(sourceToFormat)

        // Get rules
        let rules = FormatRules.named(RulesStore().rules.compactMap { $0.isEnabled ? $0.name : nil })

        // Get options
        let store = OptionsStore()
        var formatOptions = store.inferOptions ? inferFormatOptions(from: input) : store.formatOptions
        formatOptions.indent = invocation.buffer.indentationString
        formatOptions.tabWidth = invocation.buffer.tabWidth
        formatOptions.swiftVersion = store.formatOptions.swiftVersion
        if formatOptions.requiresFileInfo {
            formatOptions.fileHeader = .ignore
        }

        let output: [Token]
        do {
            output = try format(input, rules: rules, options: formatOptions)
        } catch {
            throw error
        }
        if output == input {
            // No changes needed
            return
        }

        // Remove all selections to avoid a crash when changing the contents of the buffer.
        let selections = invocation.buffer.selections.compactMap { $0 as? XCSourceTextRange }
        invocation.buffer.selections.removeAllObjects()

        // Update buffer
        invocation.buffer.completeBuffer = sourceCode(for: output)

        // Restore selections
        for selection in selections {
            invocation.buffer.selections.add(XCSourceTextRange(
                start: invocation.buffer.newPosition(for: selection.start, in: output),
                end: invocation.buffer.newPosition(for: selection.end, in: output)
            ))
        }
    }
    
    //MARK: 格式化OC代码
    private func formatOC(_ invocation: XCSourceEditorCommandInvocation) throws {
        guard let range = invocation.selections.first else { throw CommandError.noSelection }
        let startLine = range.start.line
        let endLine = range.end.line
        var insertIndex = 0
        let newLine = startLine
        
        var selectString = ""
        var removeIndexSet:IndexSet
        // 没有选中内容时,格式化当前的所有内容
        if ((startLine == endLine) && (range.start.column == range.end.column)) {
            selectString.append(invocation.buffer.completeBuffer)
            removeIndexSet = IndexSet(0..<invocation.lines.count)
        } else {
            //有选中时,取出选中行的内容
            insertIndex = startLine
            let select = invocation.lines[startLine...endLine].joined(separator: "")
            selectString.append(select)
            removeIndexSet = IndexSet(range.start.line...endLine)
        }
        guard !selectString.isEmpty else { return }
        //let array = try selectString.format()
        let array = try formatWith(ocCode: selectString)
        if array.count > 0 {
            // 将格式化后的内容替换旧内容
            invocation.buffer.lines.removeObjects(at: removeIndexSet)
            invocation.buffer.lines.insert(array, at: IndexSet(insertIndex..<array.count+insertIndex))
        }
        
        let currentPosition = XCSourceTextPosition(line: newLine, column: 0)
        let updatedSelection = XCSourceTextRange(start: currentPosition, end: currentPosition)
        invocation.buffer.selections.setArray([updatedSelection])
    }
    
    /// Calculates the indentation string representation for a given source text buffer.
    ///
    /// - Returns: Indentation represented as a string
    ///
    /// NOTE: we cannot exactly replicate Xcode's indent logic in SwiftFormat because
    /// SwiftFormat doesn't support the concept of mixed tabs/spaces that Xcode does.
    ///
    /// But that's OK, because mixing tabs and spaces is really stupid.
    ///
    /// So in the event that the user has chosen to use tabs, but their chosen indentation
    /// width is not a multiple of the tab width, we'll just use spaces instead.
    private func indentationString(for buffer: XCSourceTextBuffer) -> String {
        if buffer.usesTabsForIndentation {
            let tabCount = buffer.indentationWidth / buffer.tabWidth
            if tabCount * buffer.tabWidth == buffer.indentationWidth {
                return String(repeating: "\t", count: tabCount)
            }
        }
        return String(repeating: " ", count: buffer.indentationWidth)
    }

    /// Given a source text range, an original source string and a modified target string this
    /// method will calculate the differences, and return a usable XCSourceTextRange based upon the original.
    ///
    /// - Parameters:
    ///   - textRange: Existing source text range
    ///   - sourceText: Original text
    ///   - targetText: Modified text
    /// - Returns: Source text range that should be usable with the passed modified text
    private func rangeForDifferences(in textRange: XCSourceTextRange,
                                     between _: String, and targetText: String) -> XCSourceTextRange {
        // Ensure that we're not greedy about end selections — this can cause empty lines to be removed
        let lineCountOfTarget = targetText.components(separatedBy: CharacterSet.newlines).count
        let finalLine = (textRange.end.column > 0) ? textRange.end.line : textRange.end.line - 1
        let range = textRange.start.line ... finalLine
        let difference = range.count - lineCountOfTarget
        let start = XCSourceTextPosition(line: textRange.start.line, column: 0)
        let end = XCSourceTextPosition(line: finalLine - difference, column: 0)

        return XCSourceTextRange(start: start, end: end)
    }
    
    // 需要通过homebrew安装uncrustify
    // 命令：brew install uncrustify
    // 使用本地的uncrustify
    func formatWith(ocCode:String) throws -> [String] {
        guard let cachesPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first else { return [] }
        let filePath = URL(fileURLWithPath: cachesPath).appendingPathComponent("\(Date().timeIntervalSince1970)")
        try ocCode.write(to: filePath, atomically: true, encoding: .utf8)
        guard let path = Bundle.main.path(forResource: "uncrustify", ofType: nil) else { return [] }
        guard let cfgPath = Bundle.main.path(forResource: "uncrustify.cfg", ofType: nil) else { return [] }
        let command = [path, "-c", cfgPath, "-l", "OC", "-q", "--no-backup", "--replace", filePath.path]
        let shell = Shell()
        let result = shell.capture(command)
        _ = try result.get()
        let data = try Data(contentsOf: filePath)
        try? FileManager.default.removeItem(at: filePath)
        guard let string = String(data: data, encoding: .utf8) else { return [] }
        return string.components(separatedBy: "\n")
    }
}

fileprivate extension String {

    //MARK: 调用uncrustify格式化OC代码
    func format() throws -> [String] {
        var result = [String]()
        
        var formatString = ""
        if let commandPath = Bundle.main.path(forResource: "uncrustify", ofType: nil), let cfgPath = Bundle.main.path(forResource: "uncrustify.cfg", ofType: nil) {
            let semaphore = DispatchSemaphore(value: 0)
            let command = ["-c=\(cfgPath)", "-l=OC", "-q"]
            let process = Process()
            process.launchPath = commandPath
            process.arguments = command

            let selector = Selector(("setStartsNewProcessGroup:"))
            if process.responds(to: selector) {
                process.perform(selector, with: false as NSNumber)
            }

            if let data = self.data(using: .utf8) {
                let inputPipe = Pipe()
                process.standardInput = inputPipe
                let stdinHandle = inputPipe.fileHandleForWriting
                stdinHandle.write(data)
                stdinHandle.closeFile()
            }
            let queue = DispatchQueue(label: "io.tuist.shell", qos: .default, attributes: [], autoreleaseFrequency: .inherit)
            // Because FileHandle's readabilityHandler might be called from a
            // different queue from the calling queue, avoid a data race by
            // protecting reads and writes to outputData and errorData on
            // a single dispatch queue.
            let outputPipe = Pipe()
            var error = ""
            process.standardOutput = outputPipe
            outputPipe.fileHandleForReading.readabilityHandler = { handler in
                queue.async {
                    let data = handler.availableData
                    if data.count > 0, let string = String(data: data, encoding: .utf8) {
                        formatString.append(string)
                    }
                }
            }

            let errorPipe = Pipe()
            process.standardError = errorPipe
            errorPipe.fileHandleForReading.readabilityHandler = { handler in
                queue.async {
                    let data = handler.availableData
                    if data.count > 0, let string = String(data: data, encoding: .utf8) {
                        error.append(string)
                    }
                }
            }

            process.terminationHandler = { _ in
                queue.async {
                    (process.standardOutput! as! Pipe).fileHandleForReading.readabilityHandler = nil
                    (process.standardError! as! Pipe).fileHandleForReading.readabilityHandler = nil
                }
            }
            process.launch()
            process.waitUntilExit()
            queue.sync {
                if process.terminationStatus != 0 {
                    print("失败：\(process.terminationReason)--\(error)")
                }
                semaphore.signal()
            }
            semaphore.wait()
        }
        
        formatString.enumerateLines { (line, _) in
            result.append(line)
        }
        return result
    }
}
