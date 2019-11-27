//
//  String.swift
//  MyPlugin
//
//  Created by 影孤清 on 2019/11/20.
//  Copyright © 2019 影孤清. All rights reserved.
//

import Cocoa

extension String {
    private func validIndex(original: Int) -> String.Index {
        switch original {
        case ...startIndex.utf16Offset(in: self): return startIndex
        case endIndex.utf16Offset(in: self)...: return endIndex
        default: return index(startIndex, offsetBy: original)
        }
    }
    
    private func validStartIndex(original: Int) -> String.Index? {
        guard original <= endIndex.utf16Offset(in: self) else { return nil }
        return self.validIndex(original: original)
    }
    
    private func validEndIndex(original: Int) -> String.Index? {
        guard original >= startIndex.utf16Offset(in: self) else { return nil }
        return self.validIndex(original: original)
    }
    
    subscript(_ range: CountableRange<Int>) -> String {
        guard
            let startIndex = validStartIndex(original: range.lowerBound),
            let endIndex = validEndIndex(original: range.upperBound),
            startIndex < endIndex
        else {
            return ""
        }
        return String(self[startIndex..<endIndex])
    }

    //MARK: 删除文字前面的空格
    var deleteFirstSpace:String {
        guard !self.isEmpty else { return self }
        var newString = self
        while newString.count > 0 {
            guard newString.hasPrefix(" ") else { break }
            newString = String(newString.suffix(newString.count-1))
        }
        return newString
    }
    
    //MARK: 获取前面的空格
    var frontSpace:String {
        guard !self.isEmpty else { return "" }
        var newString = self
        var result = ""
        while newString.count > 0 {
            guard newString.hasPrefix(" ") else { break }
            newString = String(newString.suffix(newString.count-1))
            result.append(" ")
        }
        return result
    }
    
    func appending(pathComponent: String) -> String {
        return (self as NSString).appendingPathComponent(pathComponent)
    }
    
    /// 删除后缀的文件名
    var fileNameWithoutExtension: String {
        return ((self as NSString).lastPathComponent as NSString).deletingPathExtension
    }
    
    /// 获得文件的扩展类型（不带'.'）
    var pathExtension: String {
        return (self as NSString).pathExtension
    }
    
    /// 从路径中获得完整的文件名（带后缀）
    var lastPathComponent: String {
        return (self as NSString).lastPathComponent
    }
    
    /// 删除最后一个/后面的内容 可以是整个文件名,可以是文件夹名
    var deletingLastPathComponent: String {
        return (self as NSString).deletingLastPathComponent
    }
    
    /// 获得文件名（不带后缀）
    var deletingPathExtension: String {
        return (self as NSString).deletingPathExtension
    }
    
    /// 文件是否存在
    var fileExists: Bool {
        guard !self.isEmpty else { return false }
        return FileManager.default.fileExists(atPath: self)
    }
    
    /// 目录是否存在，非目录时，返回false
    var directoryExists: Bool {
        guard !self.isEmpty else { return false }
        var isDirectory = ObjCBool(booleanLiteral: false)
        let isExists = FileManager.default.fileExists(atPath: self, isDirectory: &isDirectory)
        return isDirectory.boolValue && isExists
    }
    
    // 生成目录所有文件
    func createFilePath(isDelOldPath: Bool = false) throws {
        guard !self.isEmpty else { return }
        if isDelOldPath, self.fileExists {
            try self.pathRemove()
        } else if self.fileExists {
            return
        }
        try FileManager.default.createDirectory(atPath: self, withIntermediateDirectories: true, attributes: nil)
    }
    
    func pathRemove() throws {
        guard !self.isEmpty, self.fileExists else { return }
        try FileManager.default.removeItem(atPath: self)
    }
}


func show(message:String, style:NSAlert.Style) {
    let alert = NSAlert()
    alert.messageText = (style == .informational) ? "👍" : "🤕"
    alert.informativeText = message
    alert.alertStyle = style
    alert.addButton(withTitle: "OK")
    alert.runModal()
}
