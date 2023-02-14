//
//  Util.swift
//  MyPlugin
//
//  Created by 影孤清 on 2019/11/20.
//  Copyright © 2019 影孤清. All rights reserved.
//

import Cocoa

import XcodeKit

enum Language {
    case UnKnow
    case Swift
    case ObjectC
    case Ruby
    
    init(uti:String) {
        switch uti {
            case "public.swift-source",
                "com.apple.dt.playground",
                "com.apple.dt.playgroundpage",
                "com.apple.dt.swiftpm-package-manifest":
                self = .Swift
            case "public.ruby-script":
                self = .Ruby
            case "public.objective-c-source", "public.c-header":
                self = .ObjectC
            default:
                self = .UnKnow
        }
    }
}

extension XCSourceEditorCommandInvocation {
    
    /// 当前文本的语言类型
    var language:Language {
        Language(uti: buffer.contentUTI)
    }
}


func show(msg:String) {
    OperationQueue.main.addOperation({
        let doubleImportAlert = NSAlert()
        doubleImportAlert.messageText = msg
        doubleImportAlert.addButton(withTitle: "确定")
        // We're creating a "fake" view so that the text doesn't wrap on two lines
        let fakeRect: NSRect = NSRect.init(x: 0, y: 0, width: 307, height: 0)
        let fakeView = NSView.init(frame: fakeRect)
        doubleImportAlert.accessoryView = fakeView
        NSSound.beep()
        let frontmostApplication = NSWorkspace.shared.frontmostApplication
        let appWindow = doubleImportAlert.window
        appWindow.makeKeyAndOrderFront(appWindow)
        NSApp.activate(ignoringOtherApps: true)
        doubleImportAlert.runModal()
        NSApp.deactivate()
        frontmostApplication?.activate(options: [])
    })
}

extension XCSourceEditorCommandInvocation {
    
    var selections:[XCSourceTextRange] {
        return self.buffer.selections as? [XCSourceTextRange] ?? []
    }
    
    var lines:[String] {
        return self.buffer.lines as? [String] ?? []
    }
}


enum CommandError: Error, LocalizedError, CustomNSError {
    case notSwiftLanguage
    case noSelection
    case invalidSelection

    var localizedDescription: String {
        switch self {
        case .notSwiftLanguage:
            return "Error: not a Swift source file."
        case .noSelection:
            return "Error: no text selected."
        case .invalidSelection:
            return "Error: invalid selection."
        }
    }

    var errorUserInfo: [String: Any] {
        return [NSLocalizedDescriptionKey: localizedDescription]
    }
}
