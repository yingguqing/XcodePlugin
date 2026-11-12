#!/usr/bin/env python3
"""维护配置界面的中文说明。

配置界面用 NSLocalizedString(title, comment: "") 查中文：
  - 规则行的 title 是规则名（camelCase，如 acronyms）
  - 选项行的 title 是 OptionDescriptor 的 displayName（英文，如 Indent）

本脚本把 EXTRA_ZH 里的翻译合并进 Localizable.xcstrings（真正参与构建的文件）
和 en.lproj/Localizable.strings（保持同步，便于人工查阅）。已有的翻译不会被覆盖。

用法：
    python3 scripts/sync-localizations.py           合并并写回两个文件
    python3 scripts/sync-localizations.py --check  只列出仍缺中文的 key，不写文件

升级 SwiftFormat 后跑一次 --check，把列出的新 key 补进 EXTRA_ZH 再跑一次即可。
"""
import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
XC = ROOT / "XcodePlugin/Supporting Files/Localizable.xcstrings"
STR = ROOT / "XcodePlugin/Supporting Files/en.lproj/Localizable.strings"
CORE = ROOT / "MyPlugin/SwiftFormat"

# 中文说明：规则名 / 选项显示名 -> 中文。新增规则后在这里补即可。
EXTRA_ZH = {
    # ---- 0.55 ~ 0.64 新增的规则 ----
    "blankLinesAfterGuardStatements": "移除连续 guard 语句之间的空行，并在最后一个 guard 后插入一个空行。",
    "commonTypos": "修正注释和标识符中的常见拼写错误。",
    "contentBuilder": "使用隐式或显式的 SwiftUI 结果构造器属性，如 @ContentBuilder。",
    "docCommentsBeforeModifiers": "把文档注释放在声明修饰符和属性之前。",
    "emptyExtensions": "移除空的、且不遵循协议的 extension。",
    "environmentEntry": "把 SwiftUI 的 EnvironmentValues 定义更新为使用 @Entry 宏。",
    "extensionAttributes": "把成员共有的属性提升到 extension 上。",
    "fileMacro": "统一使用 #file 或 #fileID（Swift 6 及以后两者行为一致）。",
    "forWhere": "过滤 for 循环时优先使用 where 子句或嵌套 if 语句。",
    "ifExpressions": "在函数和计算属性中优先使用 if 表达式而不是三元运算符。",
    "modifiersOnSameLine": "确保所有修饰符与声明关键字在同一行。",
    "nestedIf": "用逗号分隔的条件或 else-if 链合并嵌套的 if 语句。",
    "noForceTryInTests": "测试中使用 throws，而不是 try!。",
    "noForceUnwrapInTests": "测试用例中使用 XCTUnwrap 或 #require，而不是强制解包。",
    "noGuardInTests": "测试中不使用 guard 语句，改用其他断言方式。",
    "preferContains": "优先使用 contains，代替 filter(_:).isEmpty、first(where:) != nil 和 range(of:) != nil。",
    "preferCountWhere": "优先使用 count(where:)，代替 filter(_:).count。",
    "preferExplicitFalse": "优先使用 == false，而不是前缀取反 !。",
    "preferFinalClasses": "优先把不会被继承的类标记为 final。",
    "preferFirstWhere": "优先使用 first(where:)，代替 filter(_:).first。",
    "preferFlatMap": "优先使用 flatMap { ... }，代替 map { ... }.reduce([], +)。",
    "preferLazyMap": "在 min() 等单次遍历操作前优先使用 lazy.map 而不是 map。",
    "preferMinOverSorted": "优先使用 min()，代替 sorted().first。",
    "preferStructSwiftTestingSuites": "Swift Testing 测试套件尽可能使用结构体。",
    "preferSwiftStringAPI": "把 Objective-C 桥接的 String 方法替换为 Swift 原生等价方法。",
    "preferSwiftTesting": "优先使用 Swift Testing 框架而不是 XCTest。",
    "privateStateVariables": "为没有访问控制修饰符的 SwiftUI 状态属性添加 private。",
    "privateSwiftUIDynamicProperties": "为没有访问控制修饰符的 SwiftUI 动态属性添加 private。",
    "propertyTypes": "把属性声明统一为类型推断（let foo = Foo()）或显式类型（let foo: Foo = .init()）。",
    "redundantAsync": "移除函数声明中不含 await 表达式的多余 async 关键字。",
    "redundantClosure": "移除多余的闭包包装。",
    "redundantEmptyView": "移除 SwiftUI 结果构造器中多余的 else { EmptyView() } 分支。",
    "redundantEnumerated": "在索引未使用的 for 循环中移除 .enumerated()。",
    "redundantEquatable": "编译器合成的 Equatable 实现等价时，省略手写的实现。",
    "redundantExtendedLifetime": "移除测试中多余的 withExtendedLifetime 调用和 _ = value 语句。",
    "redundantMemberwiseInit": "移除多余的显式 internal 成员逐一构造器。",
    "redundantOverload": "用默认参数替代用于转发的重载函数。",
    "redundantPublic": "移除 internal 或 private 类型中声明上多余的 public 访问控制。",
    "redundantSendable": "移除非 public 结构体和枚举中多余的显式 Sendable 声明。",
    "redundantSwiftTestingSuite": "移除无参数的多余 @Suite 属性。",
    "redundantSwiftUIGroup": "移除多余的 SwiftUI Group 包装视图，改用 @ViewBuilder。",
    "redundantThrows": "移除函数声明中不会抛出错误的多余 throws 关键字。",
    "redundantVariable": "简化定义后立即返回的多余变量。",
    "redundantViewBuilder": "移除不需要的 @ViewBuilder 属性。",
    "repeatedGuard": "合并函数体相同的连续 guard 语句。",
    "simplifyGenericConstraints": "简化多余的泛型约束。",
    "singlePropertyPerLine": "每个属性定义单独一行使用 let/var 声明。",
    "swiftTestingTestCaseNames": "统一 Swift Testing 中 @Test 和 @Suite 的命名格式。",
    "testSuiteAccessControl": "测试方法使用配置的访问控制（默认 internal），测试套件中其他属性和函数应为 private。",
    "throwingTests": "测试中使用 throws，而不是 try!。",
    "unusedPrivateDeclarations": "移除未使用的 private 和 fileprivate 声明。",
    "urlMacro": "把强制解包的 URL(string:) 替换为配置的 #URL(_:) 宏。",
    "validateTestCases": "确保测试用例方法带有正确的 @Test 属性或 test 前缀。",
    "wrapCaseBodies": "把行内 switch case 的函数体换行到新的一行。",
    "wrapClosureBodies": "把指定函数的单行闭包体换成多行。",
    "wrapDoBodies": "把行内 do / catch 语句的函数体换成多行。",
    "wrapFunctionBodies": "把单行的函数、init 和 subscript 函数体换成多行。",
    "wrapGuardStatementBodies": "把 guard 语句的函数体换行到新的一行。",
    "wrapIfExpressionBodies": "把 if 表达式的函数体换行到新的一行。",
    "wrapIfStatementBodies": "把 if 语句的函数体换行到新的一行。",
    "wrapMultilineFunctionChains": "链式函数调用统一为全在同一行，或每个调用各占一行。",
    "wrapPropertyBodies": "把单行的属性函数体换成多行。",
    "wrapSingleLineStrings": "把超过 --max-width 的单行字符串字面量换行。",

    # ---- 选项 displayName（此前完全没有中文） ----
    'Blank line after "MARK"': "MARK 后空行",
    "Indent": "缩进",
    "Linebreak Character": "换行符",
    "Semicolons": "分号",
    "Operator Functions": "运算符函数空格",
    "Void Type": "Void 类型写法",
    "Indent Case": "缩进 switch case",
    "Trailing commas": "尾随逗号",
    "Trim White Space": "移除行尾空格",
    "Allman Braces": "Allman 大括号风格",
    "Header": "文件头注释",
    "Ifdef Indent": "#if 缩进",
    "Wrap Enum Cases": "枚举 case 换行",
    "Wrap Single-line Enum Cases": "单行枚举 case 换行",
    "Wrap Arguments": "函数参数换行",
    "Wrap Parameters": "调用实参换行",
    "Wrap Collections": "集合字面量换行",
    "Wrap Typealiases": "typealias 换行",
    "Wrap Return Type": "返回类型换行",
    "Wrap Function Effects": "函数效果（throws/async）换行",
    "Wrap Conditions": "条件表达式换行",
    "Wrap Ternary Operators": "三元运算符换行",
    "Wrap String Interpolation": "字符串插值换行",
    "Closing Paren Position": "右括号位置",
    "Call Site Closing Paren": "调用处右括号位置",
    "Hex Literal Case": "十六进制字母大小写",
    "Exponent Case": "指数 e 大小写",
    "Decimal Grouping": "十进制数字分组",
    "Fraction Grouping": "小数位分组",
    "Exponent Grouping": "指数位分组",
    "Binary Grouping": "二进制数字分组",
    "Octal Grouping": "八进制数字分组",
    "Hex Grouping": "十六进制数字分组",
    "Pattern Let": "模式中的 let/var 位置",
    "Strip Unused Arguments": "移除未使用参数",
    "Else Position": "else/catch 位置",
    "Guard Else Position": "guard 中 else 的位置",
    "Self": "显式 self",
    "Self Required": "需要显式 self 的函数/类型",
    "Throw Capturing": "抛出型 @autoclosure 函数",
    "Async Capturing": "异步 @autoclosure 函数",
    "Import Grouping": "import 排序分组",
    "Hoist Imports": "提升 import 到文件顶部",
    "Trailing Closure Functions": "使用尾随闭包的函数",
    "Never Trailing Functions": "不使用尾随闭包的函数",
    "Wrap Closure Bodies": "需要换行闭包体的函数",
    "Xcode Indentation": "匹配 Xcode 缩进",
    "Tab Width": "制表符宽度",
    "Max Width": "最大行宽",
    "List Wrap Threshold": "列表换行阈值",
    "Smart Tabs": "智能制表符",
    "Asset Literals": "颜色/图片字面量",
    "No-space Operators": "不留空格的运算符",
    "Type Delimiter Spacing": "类型分隔符空格",
    "Ranges": "区间运算符空格",
    "No-wrap Operators": "不换行运算符",
    "Modifier Order": "修饰符顺序",
    "Short Optional Syntax": "Optional 简写 ?",
    "Mark Types": "为类型添加 MARK",
    "Type Mark Comment": "类型 MARK 模板",
    "Mark Extensions": "为 extension 添加 MARK",
    "Extension Mark Comment": "独立 extension 的 MARK 模板",
    "Grouped Extension Mark Comment": "分组 extension 的 MARK 模板",
    "Mark Categories": "在分类之间插入 MARK",
    "Category Mark Comment": "分类 MARK 模板",
    "Before Marks": "放在首个 MARK 之前的声明",
    "Lifecycle Methods": "额外的生命周期方法",
    "Declaration Types to Organize": "参与整理的声明类型",
    "Organize Struct Threshold": "整理 struct 的最小行数",
    "Organize Class Threshold": "整理 class 的最小行数",
    "Organize Enum Threshold": "整理 enum 的最小行数",
    "Organize Extension Threshold": "整理 extension 的最小行数",
    "Mark Struct Threshold": "struct 添加 MARK 的最小行数",
    "Mark Class Threshold": "class 添加 MARK 的最小行数",
    "Mark Enum Threshold": "enum 添加 MARK 的最小行数",
    "Mark Extension Threshold": "extension 添加 MARK 的最小行数",
    "Declaration Organization Mode": "声明整理方式",
    "Type Body Mark Comments": "类型体内的 MARK 注释",
    "Organization Order For Visibility": "可见性分组顺序",
    "Organization Order For Declaration Types": "声明类型分组顺序",
    "Custom Visibility Marks": "自定义可见性分组 MARK",
    "Custom Type Marks": "自定义声明类型分组 MARK",
    "Blank Line After Subgroups": "子分组后留空行",
    "Declaration Name Patterns To Sort Alphabetically": "按字母排序的声明名模式",
    "Sorting Locale": "排序区域设置",
    "Function Attributes": "函数 @属性位置",
    "Type Attributes": "类型 @属性位置",
    "Stored Property Attributes": "存储属性 @属性位置",
    "Computed Property Attributes": "计算属性 @属性位置",
    "Complex Attributes": "复杂 @属性位置",
    "Complex Attribute exceptions": "排除的复杂 @属性",
    "Yoda Swap": "交换 Yoda 表达式操作数",
    "Extension Access Control Level Placement": "访问控制关键字位置",
    "Property Types": "属性声明的类型写法",
    "Inferred Types": "优先类型推断",
    "Empty Braces": "空大括号空格",
    "Acronyms": "自动大写的缩写词",
    "Preserve Acronyms": "保留不处理的符号",
    "Acronym Visibility": "缩写词可见性阈值",
    "Typo Visibility": "拼写修正可见性阈值",
    "Custom Typos": "自定义拼写修正映射",
    "Ignored Typos": "忽略的拼写错误",
    "Indent Blank Lines": "缩进空行",
    "Indent Strings": "缩进多行字符串",
    "Closure Void": "闭包中显式 Void 返回类型",
    "Enum Namespaces": "把命名空间类型改为枚举",
    "Type blank lines": "类型声明中的空行",
    "Scope blank lines": "作用域内的空行",
    "Additional generic types": "额外的泛型类型",
    "Use `some Any`": "使用 some Any 类型",
    "Anonymous forEach closures": "匿名 forEach 闭包转 for 循环",
    "Single-line forEach closures": "单行 forEach 闭包转 for 循环",
    "For loop where clauses": "for 循环使用 where 子句",
    "Doc comments": "文档注释位置",
    "Excluded Declaration Types": "不处理注释的声明类型",
    "Apply conditionalAssignment rule": "条件赋值使用 if/switch 表达式",
    "Return nil in init?(coder)": "不可用的 init?(coder:) 返回 nil",
    "Date format": "文件头日期格式",
    "Date format timezone": "文件头日期时区",
    "Nil init type": "Optional 属性的 nil 初始值",
    "Private Declarations to Exclude": "排除的私有声明",
    "Preserved Property Types": "保留原有类型的符号",
    "Additional XCTest symbols": "额外的 XCTest 符号",
    "Default test suite attributes": "转换时默认添加的测试套件属性",
    "Sort SwiftUI Dynamic Properties": "SwiftUI 属性排序",
    "The name and module of an Equatable conformance macro": "Equatable 宏名称与模块",
    "The name and module of a URL macro": "URL 宏名称与模块",
    "Preferred File Macro": "首选文件宏",
    "Blank Line Between Consecutive Guards": "连续 guard 之间留空行",
    "Blank Line After Switch Cases": "switch case 后留空行",
    "Redundant Throws": "移除多余的 throws",
    "Redundant Async": "移除多余的 async",
    "Allow Partial Wrapping": "允许部分参数换行",
    "Prefer Synthesized Init For Internal Structs": "internal 结构体优先使用合成构造器",
    "Test Case Name Format": "测试用例命名格式",
    "Suite Name Format": "测试套件命名格式",
    "Test Case Access Control": "测试方法访问控制",
    "Guard-Like If Statements": "测试中转换 guard 式尾随 if",
    "Boolean Guards In Tests": "测试中的布尔 guard",
    "Redundant Optional Binding": "简化的可选绑定",
    "Single Line Ternary": "单行三元表达式处理",
    "Content Builder": "SwiftUI 结果构造器属性",
    "Prefer Content Builder": "用 @ContentBuilder 替换旧构造器",
    "Fragment": "输入为更大文件的一部分",
    "Conflict Markers": "合并冲突标记",
    "Swift Version": "Swift 编译器版本",
    "Swift Language Mode": "Swift 语言模式",
    "Markdown Files": "Markdown 中的 Swift 代码",
    "Unknown Options": "未知规则或选项",
    "Comments": "注释（已废弃）",
    "Insert Lines": "插入行（已废弃）",
    "Remove Lines": "移除行（已废弃）",
    "Experimental Rules": "实验性规则",
    "Var Attributes": "属性 @属性位置",
    "Unknown Rules": "未知规则（已废弃）",
    "Empty": "空（已废弃）",
    "hex-literals": "十六进制字面量（已废弃）",
    "Wrap Elements": "元素换行（已废弃）",
    "Specifier Order": "修饰符顺序（已废弃）",
    "Redundant Type": "冗余类型（已废弃）",
    "Inlined forEach closures": "内联 forEach 闭包（已废弃）",
    "Preserved Symbols": "保留的符号（已废弃）",
}


def unescape(raw):
    try:
        return json.loads('"' + raw + '"')
    except Exception:
        return raw


def collect_keys():
    """UI 里会作为 NSLocalizedString 的 key 出现的字符串。"""
    registry = (CORE / "RuleRegistry.generated.swift").read_text()
    rules = re.findall(r'^\s*"([^"]+)":\s*\.\w+,', registry, re.M)
    descriptors = (CORE / "OptionDescriptor.swift").read_text()
    options = []
    for m in re.finditer(r'displayName:\s*"((?:[^"\\]|\\.)*)"', descriptors):
        key = unescape(m.group(1))
        if key not in options:
            options.append(key)
    return rules + options


def zh_value(entry):
    loc = entry.get("localizations", {})
    unit = loc.get("zh-Hans", {}).get("stringUnit", {})
    return unit.get("value")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true", help="只报告缺失的 key")
    args = ap.parse_args()

    xc = json.loads(XC.read_text())
    existing = set(xc["strings"])
    keys = collect_keys()

    if args.check:
        missing = [k for k in keys if k not in existing and k not in EXTRA_ZH]
        print(f"UI key 总数：{len(keys)}，已有中文：{sum(1 for k in keys if k in existing or k in EXTRA_ZH)}")
        if missing:
            print(f"仍缺中文 {len(missing)} 项：")
            for k in missing:
                print("  " + k)
            return 1
        print("✓ 全部已覆盖")
        return 0

    # 合并：已有条目原样保留；缺失的用 EXTRA_ZH 补上
    added = 0
    for key in keys:
        if key in existing or key not in EXTRA_ZH:
            continue
        xc["strings"][key] = {
            "extractionState": "manual",
            "localizations": {
                "zh-Hans": {
                    "stringUnit": {"state": "translated", "value": EXTRA_ZH[key]}
                }
            },
        }
        existing.add(key)
        added += 1

    # en.lproj/Localizable.strings 里独有的旧翻译也并入 xcstrings
    str_pairs = dict(
        re.findall(
            r'^"((?:[^"\\]|\\.)*)"\s*=\s*"((?:[^"\\]|\\.)*)";',
            STR.read_text(), re.M,
        )
    )
    for key, value in str_pairs.items():
        if key not in existing:
            xc["strings"][key] = {
                "extractionState": "manual",
                "localizations": {
                    "zh-Hans": {
                        "stringUnit": {"state": "translated", "value": unescape(value)}
                    }
                },
            }
            existing.add(key)
            added += 1

    XC.write_text(json.dumps(xc, ensure_ascii=False, indent=2, sort_keys=True) + "\n")

    # 让 .strings 与 .xcstrings 完全一致（便于人工查阅和 diff）
    lines = [
        "/*",
        "  Localizable.strings —— 由 scripts/sync-localizations.py 生成，请勿手工编辑。",
        "  真正参与构建的是 Localizable.xcstrings。",
        "*/",
        "",
    ]
    for key in sorted(xc["strings"]):
        value = zh_value(xc["strings"][key])
        if value is None:
            continue
        k = key.replace("\\", "\\\\").replace('"', '\\"')
        v = value.replace("\\", "\\\\").replace('"', '\\"')
        lines.append(f'"{k}"="{v}";')
    STR.write_text("\n".join(lines) + "\n")

    print(f"✓ 新增中文 {added} 项，当前共 {sum(1 for v in xc['strings'].values() if zh_value(v))} 项")
    missing = [k for k in keys if not zh_value(xc["strings"].get(k, {}))]
    print(f"  UI key 覆盖：{len(keys) - len(missing)}/{len(keys)}")
    if missing:
        print("  仍缺：", ", ".join(missing[:20]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
