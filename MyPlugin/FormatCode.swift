//
//  FormatCode.swift
//  MyPlugin
//
//  Created by 影孤清 on 2019/11/20.
//  Copyright © 2019 影孤清. All rights reserved.
//

import Cocoa
import XcodeKit

// MARK: - 自定义规则：删除 // MARK: 后面紧跟的空白行

private extension FormatRule {
    /// SwiftFormat 自带的 blankLinesAroundMark 只负责「插入」空行，
    /// line-after-marks 关掉后也不会删除已有空行。这条规则补上删除逻辑。
    /// 注意：applyRules 会按依赖关系重排规则顺序，所以这条规则不混进 rules 数组，
    /// 而是在 format() 完成后单独再跑一次（见 formatSwift）。
    static let removeBlankLineAfterMark = FormatRule(
        help: "Remove blank lines immediately after MARK: comments."
    ) { formatter in
        formatter.forEachToken { i, token in
            guard case let .commentBody(comment) = token,
                  comment.hasPrefix("MARK:"),
                  let startIndex = formatter.index(of: .nonSpace, before: i),
                  formatter.tokens[startIndex] == .startOfScope("//"),
                  let linebreakIndex = formatter.index(of: .linebreak, after: i)
            else { return }

            // 跳过空格后仍是换行符 => MARK 行后面跟着空白行。
            // 连同空白行里的空格一起删掉，只保留 MARK 行本身的换行。
            while let nextIndex = formatter.index(of: .nonSpace, after: linebreakIndex),
                  formatter.tokens[nextIndex].isLinebreak
            {
                formatter.removeTokens(in: linebreakIndex + 1 ... nextIndex)
            }
        }
    } examples: {
        """
        ```diff
        - // MARK: Properties
        -
        + // MARK: Properties
          let name: String
        ```
        """
    }
}

// MARK: 格式化代码
class FormatCode : NSObject, XCSourceEditorCommand {
    func perform(with invocation: XCSourceEditorCommandInvocation, completionHandler: @escaping (Error?) -> Void ) -> Void {
        do {
            if invocation.language == .Swift {
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

        var output: [Token]
        do {
            output = try format(input, rules: rules, options: formatOptions).tokens
            // 后处理：删除 // MARK: 后面紧跟的空白行。
            // SwiftFormat 的 applyRules 会重排规则顺序，所以这里单独再跑一次，
            // 保证一定在 blankLinesAroundMark / organizeDeclarations 等规则之后执行。
            // 想恢复 SwiftFormat 原生行为时，注释掉下面这一段即可。
            output = try applyRules(
                [.removeBlankLineAfterMark], to: output,
                with: formatOptions, trackChanges: false, range: nil
            ).tokens
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
        guard let path = Bundle.main.path(forResource: "uncrustify", ofType: nil),
              let cfgPath = Bundle.main.path(forResource: "uncrustify.cfg", ofType: nil)
        else { return [] }

        // 临时文件只写在扩展自己的沙盒容器内。
        // 之前用 NSSearchPathForDirectoriesInDomains(.documentDirectory) 会指向用户「文稿」目录，
        // 属于 macOS 受 TCC 保护的位置，每次格式化都会弹「想要访问…文件夹中的文件」授权框。
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("XcodePluginFormatter", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let filePath = dir.appendingPathComponent(UUID().uuidString + ".m")
        defer { try? FileManager.default.removeItem(at: filePath) }

        try ocCode.write(to: filePath, atomically: true, encoding: .utf8)
        let command = [path, "-c", cfgPath, "-l", "OC", "-q", "--no-backup", "--replace", filePath.path]
        let shell = Shell()
        let result = shell.capture(command)
        _ = try result.get()
        let data = try Data(contentsOf: filePath)
        guard let string = String(data: data, encoding: .utf8) else { return [] }
        return string.components(separatedBy: "\n")
    }
}

