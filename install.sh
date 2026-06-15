#!/bin/bash
# AI Usage Bar 一键安装
# 用法（两种均可）：
#   curl -fsSL https://raw.githubusercontent.com/muxin-4/claude-usage-bar/main/install.sh | bash
#   git clone 本仓库后：bash install.sh
set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/muxin-4/claude-usage-bar/main"
PLUGIN_NAME="ai-usage.5m.sh"

echo "==> AI Usage Bar 安装程序（Claude + Codex）"

# 仅支持 macOS
if [ "$(uname)" != "Darwin" ]; then
  echo "❌ 本工具仅支持 macOS"
  exit 1
fi

# 至少要有一个产品的登录凭证（插件靠它查询用量）：
#   Claude → 钥匙串 Claude Code-credentials
#   Codex  → ~/.codex/auth.json（ChatGPT 套餐登录）
HAS_CLAUDE=0; HAS_CODEX=0
security find-generic-password -s "Claude Code-credentials" >/dev/null 2>&1 && HAS_CLAUDE=1
[ -f "$HOME/.codex/auth.json" ] && HAS_CODEX=1
if [ "$HAS_CLAUDE" = 0 ] && [ "$HAS_CODEX" = 0 ]; then
  echo "❌ 既没找到 Claude Code 凭证，也没找到 Codex 登录文件。"
  echo "   至少登录其一后再装："
  echo "   · Claude Code：终端运行 claude 完成登录"
  echo "   · Codex CLI：用 ChatGPT 套餐登录 codex"
  exit 1
fi
[ "$HAS_CLAUDE" = 1 ] && echo "   ✓ 检测到 Claude Code 登录凭证"
[ "$HAS_CODEX" = 1 ] && echo "   ✓ 检测到 Codex 登录文件"

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

# 清理旧版单 Claude 插件（如果之前装过），避免菜单栏出现两个图标
rm -f "$PLUGIN_DIR/claude-usage.5m.sh"

# 重启 SwiftBar 加载插件
pkill -x SwiftBar 2>/dev/null || true
sleep 1
open -a SwiftBar

echo ""
echo "✅ 安装完成！菜单栏右上角应已出现「C xx% … Cx xx%」。"
echo ""
echo "   ⚠️ 首次运行会弹授权框："
echo "   · 钥匙串授权（读取 Claude Code 登录凭证）→ 点「始终允许」"
echo "   · 如提示 SwiftBar 是从互联网下载的应用 → 点「打开」"
echo ""
echo "   退出：    点菜单栏图标 → 退出"
echo "   再次打开：⌘+空格 搜 SwiftBar 回车，或终端运行 open -a SwiftBar"
echo "   开机自启：系统设置 → 通用 → 登录项 → ➕ 添加 SwiftBar"
