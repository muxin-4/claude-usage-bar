#!/bin/bash
# Claude Usage Bar 一键安装
# 用法（两种均可）：
#   curl -fsSL https://raw.githubusercontent.com/muxin-4/claude-usage-bar/main/install.sh | bash
#   git clone 本仓库后：bash install.sh
set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/muxin-4/claude-usage-bar/main"
PLUGIN_NAME="claude-usage.5m.sh"

echo "==> Claude Usage Bar 安装程序"

# 仅支持 macOS
if [ "$(uname)" != "Darwin" ]; then
  echo "❌ 本工具仅支持 macOS"
  exit 1
fi

# 检查 Claude Code 登录凭证（插件靠它查询用量）
if ! security find-generic-password -s "Claude Code-credentials" >/dev/null 2>&1; then
  echo "❌ 未找到 Claude Code 的登录凭证。"
  echo "   请先安装并登录 Claude Code（终端运行 claude 完成登录），再重新执行本安装。"
  exit 1
fi

# 安装 SwiftBar（开源菜单栏插件容器）
if [ ! -d "/Applications/SwiftBar.app" ] && [ ! -d "$HOME/Applications/SwiftBar.app" ]; then
  if command -v brew >/dev/null 2>&1; then
    echo "==> 安装 SwiftBar ..."
    brew install --cask swiftbar
  else
    echo "❌ 需要 Homebrew 来安装 SwiftBar。两个选择："
    echo "   1) 先装 Homebrew：https://brew.sh ，再重新执行本安装"
    echo "   2) 手动下载 SwiftBar 放入 /Applications：https://github.com/swiftbar/SwiftBar/releases ，再重新执行本安装"
    exit 1
  fi
fi

# 插件目录：尊重 SwiftBar 已有配置，没有则用 ~/.swiftbar/plugins
PLUGIN_DIR=$(defaults read com.ameba.SwiftBar PluginDirectory 2>/dev/null || true)
if [ -z "$PLUGIN_DIR" ]; then
  PLUGIN_DIR="$HOME/.swiftbar/plugins"
  defaults write com.ameba.SwiftBar PluginDirectory -string "$PLUGIN_DIR"
fi
mkdir -p "$PLUGIN_DIR"

# 获取插件脚本：本地仓库里有就直接拷（git clone 场景），否则从 GitHub 拉（curl|bash 场景）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/$PLUGIN_NAME" ]; then
  cp "$SCRIPT_DIR/$PLUGIN_NAME" "$PLUGIN_DIR/$PLUGIN_NAME"
else
  curl -fsSL "$REPO_RAW/$PLUGIN_NAME" -o "$PLUGIN_DIR/$PLUGIN_NAME"
fi
chmod +x "$PLUGIN_DIR/$PLUGIN_NAME"

# 重启 SwiftBar 加载插件
pkill -x SwiftBar 2>/dev/null || true
sleep 1
open -a SwiftBar

echo ""
echo "✅ 安装完成！菜单栏右上角应已出现「已用 xx%」。"
echo ""
echo "   ⚠️ 首次运行会弹 1-2 个授权框："
echo "   · 钥匙串授权（读取 Claude Code 登录凭证）→ 点「始终允许」"
echo "   · 如提示 SwiftBar 是从互联网下载的应用 → 点「打开」"
echo ""
echo "   退出：    点菜单栏「已用 xx%」→ 退出"
echo "   再次打开：⌘+空格 搜 SwiftBar 回车，或终端运行 open -a SwiftBar"
echo "   开机自启：系统设置 → 通用 → 登录项 → ➕ 添加 SwiftBar"
