#!/bin/bash
# 卸载 Claude Usage Bar 插件（SwiftBar 本体保留）
set -uo pipefail

PLUGIN_DIR=$(defaults read com.ameba.SwiftBar PluginDirectory 2>/dev/null || echo "$HOME/.swiftbar/plugins")
rm -f "$PLUGIN_DIR/claude-usage.5m.sh"

# 重启 SwiftBar 让菜单栏项消失
if pgrep -x SwiftBar >/dev/null 2>&1; then
  pkill -x SwiftBar
  sleep 1
  open -a SwiftBar
fi

echo "✅ 已卸载 Claude Usage Bar 插件。"
echo "   如需连 SwiftBar 一起删除：brew uninstall --cask swiftbar"
