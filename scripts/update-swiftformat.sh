#!/usr/bin/env bash
# 一键更新项目内置的 SwiftFormat 源码
#
# 用法：
#   ./scripts/update-swiftformat.sh                 重新同步 SwiftFormat.version 里记录的版本
#   ./scripts/update-swiftformat.sh 0.64.6        升级（或回退）到指定版本
#   ./scripts/update-swiftformat.sh --latest      查看上游最新版本 + 当前内置版本
#   ./scripts/update-swiftformat.sh --current     只查看当前内置版本
#
# 同步关系（Xcode 工程已把这两个目录配成「文件夹自动同步」，
# 上游新增/删除文件时 Xcode 会自动识别，不需要再改 project.pbxproj）：
#   MyPlugin/SwiftFormat/     <- 上游 Sources/**/*.swift + EditorExtension/Shared/*.swift
#   MyPlugin/ExtensionOnly/   <- 上游 EditorExtension/Extension/ 里扩展专用的 3 个文件
#   XcodePlugin/SwiftFormat/  <- 上游 EditorExtension/Application/Source/*.swift（UI）
#
# 项目自有、不会被覆盖的文件：AppDelegate.swift、Main.storyboard、汉化文件、
# MyPlugin/ 下各命令文件（FormatCode.swift 等）。
#
# 如果必须对上游源码做本地改动：把改好的文件按项目内相同相对路径放进
# SwiftFormat-patches/，脚本同步结束后会自动覆盖回去，升级不会丢失。

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION_FILE="${ROOT}/SwiftFormat.version"
REPO="nicklockwood/SwiftFormat"

latest_version() {
    # 直接读 git tag：不依赖 GitHub API，不会被 rate limit / 403 挡住
    git ls-remote --tags --refs "https://github.com/${REPO}.git" 2>/dev/null \
        | sed -n 's|.*refs/tags/\([0-9][^/]*\)$|\1|p' \
        | sort -V \
        | tail -1
}

current_version() {
    if [ -f "${VERSION_FILE}" ]; then tr -d '[:space:]' < "${VERSION_FILE}"; else echo ""; fi
}

case "${1:-}" in
    --latest|-l)
        echo "上游最新版本：$(latest_version)"
        echo "当前内置版本：$(current_version)"
        exit 0 ;;
    --current|-c)
        echo "$(current_version)"
        exit 0 ;;
    -h|--help)
        sed -n '2,24p' "${0}"
        exit 0 ;;
esac

VERSION="${1:-$(current_version)}"
if [ -z "${VERSION}" ]; then
    echo "用法：$0 <版本号>，例如：$0 $(latest_version)" >&2
    exit 1
fi

TMP="$(mktemp -d "${TMPDIR:-/tmp}/swiftformat-update.XXXXXX")"
trap 'rm -rf "${TMP}"' EXIT

echo "→ 下载 SwiftFormat ${VERSION} ..."
URL="https://github.com/${REPO}/archive/refs/tags/${VERSION}.tar.gz"
if ! curl -fsSL --max-time 180 "${URL}" -o "${TMP}/src.tar.gz"; then
    echo "✗ 下载失败，请确认版本号存在：${URL}" >&2
    exit 1
fi

mkdir -p "${TMP}/src" "${TMP}/stage/core" "${TMP}/stage/ui" "${TMP}/stage/ext"
tar -xzf "${TMP}/src.tar.gz" -C "${TMP}/src" --strip-components=1
SRC="${TMP}/src"

for d in Sources EditorExtension/Shared EditorExtension/Extension EditorExtension/Application/Source; do
    if [ ! -d "${SRC}/${d}" ]; then
        echo "✗ 源码包结构不符合预期（缺少 ${d}），这个版本可能调整过目录布局" >&2
        echo "  请先检查 ${VERSION} 的仓库结构，再调整本脚本的同步清单。" >&2
        exit 1
    fi
done

DETECTED="$(sed -n 's/^let swiftFormatVersion = "\(.*\)"/\1/p' "${SRC}/Sources/SwiftFormat.swift" | head -1)"
[ -n "${DETECTED}" ] && echo "  源码内版本号：${DETECTED}"

# 1) 核心库（含 Sources/Rules/ 子目录）+ App/扩展共享的配置 Store
rsync -a --include='*/' --include='*.swift' --exclude='*' "${SRC}/Sources/" "${TMP}/stage/core/"
cp "${SRC}"/EditorExtension/Shared/*.swift "${TMP}/stage/core/"

# 2) 扩展专用文件：这 3 个文件在 project.pbxproj 里有固定引用，只覆盖内容、不改文件名
for f in CommandErrors.swift SupportedContentUTIs.swift XCSourceTextBuffer+SwiftFormat.swift; do
    if [ ! -f "${SRC}/EditorExtension/Extension/${f}" ]; then
        echo "✗ 上游缺少 ${f}，请检查该版本的 EditorExtension/Extension 目录" >&2
        exit 1
    fi
    cp "${SRC}/EditorExtension/Extension/${f}" "${TMP}/stage/ext/${f}"
done

# 3) 宿主 App 的 UI：项目有自己的 AppDelegate / storyboard / 汉化，不覆盖 AppDelegate
#    AboutViewController 对应上游独有的 About 页面，本项目没有，也排除
for f in "${SRC}"/EditorExtension/Application/Source/*.swift; do
    case "$(basename "${f}")" in
        AppDelegate.swift|AboutViewController.swift) continue ;;
    esac
    cp "${f}" "${TMP}/stage/ui/"
done

CORE="${ROOT}/MyPlugin/SwiftFormat"
EXTONLY="${ROOT}/MyPlugin/ExtensionOnly"
UI="${ROOT}/XcodePlugin/SwiftFormat"
mkdir -p "${CORE}" "${EXTONLY}" "${UI}"

# 避免与项目自有源文件同名：Xcode 会为同名 .swift 生成同名 .stringsdata，
# 导致 "Multiple commands produce ..." 构建错误（0.64.6 的 Sources/CommandLine.swift
# 就与项目里的 MyPlugin/CommandLine.swift 撞名）。Swift 不依赖文件名，直接加前缀即可。
for f in "${TMP}"/stage/core/*.swift "${TMP}"/stage/ui/*.swift; do
    [ -f "${f}" ] || continue
    name="$(basename "${f}")"
    if [ -f "${ROOT}/MyPlugin/${name}" ] || [ -f "${ROOT}/XcodePlugin/${name}" ]; then
        echo "  · 避重名：${name} -> SF-${name}"
        mv "${f}" "$(dirname "${f}")/SF-${name}"
    fi
done

# --delete 让上游已删除的文件同步消失（例如 0.55 起 Rules.swift 被拆成 Rules/ 目录）
rsync -a --delete "${TMP}/stage/core/" "${CORE}/"
rsync -a --delete "${TMP}/stage/ui/" "${UI}/"
cp "${TMP}/stage/ext/"*.swift "${EXTONLY}/"

# 4) 应用本地补丁（目录结构与项目根一致）
PATCHES="${ROOT}/SwiftFormat-patches"
if [ -d "${PATCHES}" ]; then
    echo "→ 应用本地补丁 SwiftFormat-patches/ ..."
    rsync -a --exclude='.gitkeep' --exclude='.DS_Store' "${PATCHES}/" "${ROOT}/"
fi

echo "${VERSION}" > "${VERSION_FILE}"

echo "→ 变更摘要："
if git -C "${ROOT}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git -C "${ROOT}" status --short -- \
        MyPlugin/SwiftFormat MyPlugin/ExtensionOnly XcodePlugin/SwiftFormat SwiftFormat.version \
        | head -40
else
    echo "  (非 git 仓库，跳过)"
fi

COUNT="$(find "${CORE}" "${EXTONLY}" "${UI}" -name '*.swift' | wc -l | tr -d ' ')"
echo
echo "✓ SwiftFormat 已更新到 ${VERSION}（共 ${COUNT} 个 Swift 文件）"
echo "  Xcode 会自动识别新增/删除的源码，无需手动改工程文件。"
echo "  建议先 Clean Build Folder 再编译；若报错，通常是上游 API 变化，需适配项目自有代码。"
echo "  回退：git checkout -- MyPlugin/SwiftFormat MyPlugin/ExtensionOnly XcodePlugin/SwiftFormat SwiftFormat.version"
