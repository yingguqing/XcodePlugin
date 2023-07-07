//
//  SwiftFormatMyRules.swift
//  MyPlugin
//
//  Created by zhouziyuan on 2023/7/7.
//  Copyright © 2023 影孤清. All rights reserved.
//

import Cocoa


extension Rule: Codable {
    
    static func userRules(path:String) -> [Rule]? {
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            let jsonDecoder = JSONDecoder()
            let all = try jsonDecoder.decode([Rule].self, from: data)
            return all.isEmpty ? nil : all
        } catch {
            print("解析失败")
            return nil
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Keys.self)
        try container.encode(name, forKey: .name)
        try container.encode(isEnabled, forKey: .isEnabled)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
    }

    enum Keys: CodingKey {
        case name
        case isEnabled
    }
}
