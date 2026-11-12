//
//  AppDelegate.swift
//  XcodePlugin
//
//  Created by 影孤清 on 2019/11/20.
//  Copyright © 2019 影孤清. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    var window: NSWindow? {
        return NSApp.mainWindow
    }

    func loadConfiguration(_ url: URL) -> Bool {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            showError(FormatError.reading("Problem reading configuration from \(url.path). [\(error)]"))
            return false
        }

        let options: Options
        do {
            // 0.55+ 起 parseConfigFile 支持配置文件的分段写法，返回 [[String: String]]；
            // 本 App 不做分段配置，只取第一段。
            let configs = try parseConfigFile(data)
            if configs.count > 1 {
                showError(FormatError.options("配置文件包含多个分段，仅加载第一段。"))
            }
            let args = configs.first ?? [:]
            options = try Options(args, in: url.deletingLastPathComponent().path)
            OptionsStore().inferOptions = Set(args.keys)
                .intersection(formattingArguments)
                .subtracting([Descriptors.swiftVersion.argumentName])
                .isEmpty
        } catch {
            showError(error)
            return false
        }

        // 0.55+ 移除了 allRules.subtracting(FormatRules.disabledByDefault)，改用 defaultRules
        let rules = options.rules ?? defaultRules
        RulesStore().restore(Set(FormatRules.byName.keys).map {
            Rule(name: $0, isEnabled: rules.contains($0))
        })
        if let formatOptions = options.formatOptions {
            OptionsStore().restore(formatOptions)
        }
        return true
    }

    func application(_: NSApplication, openFile file: String) -> Bool {
        let url = URL(fileURLWithPath: file)
        if loadConfiguration(url) {
            NSDocumentController.shared.noteNewRecentDocumentURL(url)
            NotificationCenter.default.post(name: .applicationDidLoadNewConfiguration, object: nil)
            return true
        }
        return false
    }

    @IBAction func resetToDefault(_: NSMenuItem) {
        UserDefaults(suiteName: UserDefaults.groupDomain)?.clearAll(in: UserDefaults.groupDomain)
        RulesStore().resetRulesToDefaults()
        OptionsStore().resetOptionsToDefaults()
        NotificationCenter.default.post(name: .applicationDidLoadNewConfiguration, object: nil)
    }

    @IBAction func openConfiguration(_: NSMenuItem) {
        guard let window = window else {
            return
        }

        let dialog = NSOpenPanel()
        dialog.title = "Choose a configuration file"
        dialog.delegate = self
        dialog.showsHiddenFiles = true
        dialog.showsResizeIndicator = true
        dialog.allowsMultipleSelection = false

        dialog.beginSheetModal(for: window) { response in
            guard response == .OK, let url = dialog.url, self.loadConfiguration(url) else {
                return
            }
            NSDocumentController.shared.noteNewRecentDocumentURL(url)
            NotificationCenter.default.post(name: .applicationDidLoadNewConfiguration, object: nil)
        }
    }

    @IBAction func saveConfiguration(_: NSMenuItem) {
        guard let window = window else {
            return
        }

        let dialog = NSSavePanel()
        dialog.title = "Export Configuration"
        dialog.showsHiddenFiles = true
        dialog.nameFieldStringValue = swiftFormatConfigurationFile
        dialog.beginSheetModal(for: window) { response in
            guard response == .OK, let url = dialog.url else {
                return
            }

            let optionsStore = OptionsStore()
            let formatOptions = optionsStore.inferOptions ? nil : optionsStore.formatOptions
            let rules = RulesStore().rules.compactMap { $0.isEnabled ? $0.name : nil }
            let config = serialize(
                options: Options(formatOptions: formatOptions, rules: Set(rules)),
                swiftVersion: optionsStore.formatOptions.swiftVersion
            ) + "\n"
            do {
                try config.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                self.showError(FormatError.writing("Problem writing configuration to \(url.path). [\(error)]"))
            }
        }
    }

    private func showError(_ error: Error) {
        guard let window = window else {
            return
        }

        let alert = NSAlert(error: error)
        alert.addButton(withTitle: "OK")
        alert.alertStyle = .critical
        alert.beginSheetModal(for: window)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
        return true
    }
}

extension AppDelegate: NSOpenSavePanelDelegate {
    func panel(_: Any, shouldEnable url: URL) -> Bool {
        return url.hasDirectoryPath ||
            url.pathExtension == swiftFormatConfigurationFile.dropFirst() ||
            url.lastPathComponent == swiftFormatConfigurationFile
    }
}

extension NSNotification.Name {
    static let applicationDidLoadNewConfiguration = NSNotification.Name("ApplicationDidLoadNewConfiguration")
}

