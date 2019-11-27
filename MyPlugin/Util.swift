//
//  Util.swift
//  MyPlugin
//
//  Created by 影孤清 on 2019/11/20.
//  Copyright © 2019 影孤清. All rights reserved.
//

import Cocoa

import XcodeKit

extension XCSourceEditorCommandInvocation {
    
    var selections:[XCSourceTextRange] {
        return self.buffer.selections as? [XCSourceTextRange] ?? []
    }
    
    var lines:[String] {
        return self.buffer.lines as? [String] ?? []
    }
}

extension XCSourceTextBuffer {
    var isSwiftSource: Bool {
        return ["public.swift-source", "com.apple.dt.playground", "com.apple.dt.playgroundpage"].contains(self.contentUTI)
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
