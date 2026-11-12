# XcodePlugin
xcode常用功能的插件，swift语言开发<br/>

1--向上复制<br/>
&nbsp;&nbsp;将选中代码向选中位置上面一行复制,可以选中多行代码<br/>
2--向下复制<br/>
&nbsp;&nbsp;功能和向上复制类似<br/>
3--删除当前行<br/>
&nbsp;&nbsp;删除选中行所有代码,使用的时候,不需要将代码全部选中<br/>
4--选中内容大写<br/>
5--选中内容小写<br/>
6--使用//注释选中行代码<br/>
&nbsp;&nbsp;xcode本身这个功能有bug,所以编写了这个功能<br/>
7--格式化代码<br/>
&nbsp;&nbsp;不选中代码时,格式化当前编辑区所有代码,选中代码时,格式化选中代码,使用uncrustify格式化代码,格式化样式可以自己修改,修改uncrustify.cfg文件就可以<br/>
自动识别OC和Swift语言，swift格式化规则在app里设置<br/>
8--向上添加一个回车<br/>
9--向下添加一个回车<br/>

## 更新内置的 SwiftFormat

SwiftFormat 以源码方式集成（因为配置界面要用到上游的 internal API），版本记录在 `SwiftFormat.version`。
Xcode 工程已把源码目录配置成「文件夹自动同步」，上游新增/删除文件会自动进入对应 target，**不需要再改 `project.pbxproj`**。

```
./scripts/update-swiftformat.sh --latest     # 查看上游最新版本和当前版本
./scripts/update-swiftformat.sh 0.64.6      # 升级 / 回退到指定版本
./scripts/update-swiftformat.sh             # 按 SwiftFormat.version 重新同步
```

同步目录：`MyPlugin/SwiftFormat/`（核心库 + 配置 Store）、`MyPlugin/ExtensionOnly/`（扩展专用 3 个文件）、
`XcodePlugin/SwiftFormat/`（配置界面）。`AppDelegate.swift`、`FormatCode.swift`、storyboard、汉化文件等项目自有文件不会被覆盖。

如果要改上游源码，把改好的文件按项目内相同路径放进 `SwiftFormat-patches/`，每次同步结束会自动覆盖回去。
跨大版本升级后若编译报错，通常是上游 API 变化，需要适配 `FormatCode.swift` / `AppDelegate.swift`。

## 关于 macOS 的「访问文件与文件夹」授权弹窗

格式化全程只在内存和扩展自己的沙盒容器内完成，扩展不再请求用户目录权限
（OC 格式化的临时文件放在 `FileManager.default.temporaryDirectory`，appex 也移除了 `files.user-selected` entitlement）。
若系统仍弹出授权框，属于 Xcode 把项目文件交给扩展时的系统授权，去
「系统设置 → 隐私与安全性 → 文件和文件夹」给 `xcode插件` 勾选一次即可；
每次重新编译安装后又弹，是开发签名变化导致 TCC 记录失效，用固定证书签名并把 App 固定在 `/Applications` 运行。

## 配置界面的中文说明

规则名和选项名都会通过 `NSLocalizedString` 查中文（英文原文仍保留在 tooltip 里）。
`Localizable.xcstrings` 是唯一参与构建的翻译源，中文文案由 `scripts/sync-localizations.py` 维护：

```
python3 scripts/sync-localizations.py --check   # 升级 SwiftFormat 后检查有没有漏汉化
python3 scripts/sync-localizations.py           # 把新增中文合并进 xcstrings / strings
```

升级后若 `--check` 列出新 key，把中文补进脚本顶部的 `EXTRA_ZH` 再跑一次即可。
界面的汉化显示逻辑放在 `SwiftFormat-patches/XcodePlugin/SwiftFormat/` 下，
每次运行 `update-swiftformat.sh` 会自动覆盖回去，升级不会丢失。

## // MARK: 后面的空行

SwiftFormat 的 `line-after-marks`（界面里显示为「MARK 后空行」）只控制是否**插入**空行，
把它关掉也不会删除已经存在的空行。项目在 `FormatCode.swift` 里加了一条自定义规则，
在格式化结束后单独执行一次，删除 `// MARK:` 下一行的空白行（连续多个也一起删），
普通空行、MARK 前面的空行和缩进都不受影响。

想恢复 SwiftFormat 原生行为，注释掉 `formatSwift` 里
`applyRules([.removeBlankLineAfterMark], ...)` 那一段即可。

