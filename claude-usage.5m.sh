#!/bin/bash
# Claude Usage Bar — 在 Mac 菜单栏实时显示 Claude 套餐用量
# https://github.com/muxin-4/claude-usage-bar
#
# 数据来自 Anthropic 官方接口（与 claude.ai 设置页完全同源，不是第三方估算）。
# 凭证只在本机读取使用，不写盘、不上传。
# 文件名里的 5m = SwiftBar 每 5 分钟自动运行一次本脚本刷新数据。
#
# <bitbar.title>Claude Usage Bar</bitbar.title>
# <bitbar.version>v1.0.0</bitbar.version>
# <bitbar.author>muxin-4</bitbar.author>
# <bitbar.author.github>muxin-4</bitbar.author.github>
# <bitbar.desc>在菜单栏实时显示 Claude 套餐用量（5小时窗口+周额度），数据与 claude.ai 官网同源</bitbar.desc>
# <bitbar.dependencies>Claude Code（已登录）</bitbar.dependencies>
# <bitbar.abouturl>https://github.com/muxin-4/claude-usage-bar</bitbar.abouturl>
#
# runInBash=false：跳过登录 shell 包装直接执行，菜单动作即点即发
# （登录 shell 配置慢的机器上，不关这个点"退出"要等好几秒）
# <swiftbar.runInBash>false</swiftbar.runInBash>
#
# 隐藏 SwiftBar 自带的菜单项，下拉菜单只保留本插件的内容
# <swiftbar.hideAbout>true</swiftbar.hideAbout>
# <swiftbar.hideRunInTerminal>true</swiftbar.hideRunInTerminal>
# <swiftbar.hideLastUpdated>true</swiftbar.hideLastUpdated>
# <swiftbar.hideDisablePlugin>true</swiftbar.hideDisablePlugin>
# <swiftbar.hideSwiftBar>true</swiftbar.hideSwiftBar>

# ── 菜单"退出"动作：本脚本带 quit 参数被调起时，退出 SwiftBar ──
# macOS 的 pkill 默认排除"调用者的祖先进程"，而菜单点击时本脚本是
# SwiftBar 的子进程，必须加 -a 把祖先纳入匹配，否则永远杀不到。
if [ "$1" = "quit" ]; then
  exec /usr/bin/pkill -a -x SwiftBar
fi

# 本脚本的绝对路径，供"退出"菜单项回调自己
PLUGIN_PATH="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
export PLUGIN_PATH

# ── 读取 Claude Code 的 OAuth 凭证（macOS 钥匙串）──
CRED=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null)
if [ -z "$CRED" ]; then
  echo "⌛?"
  echo "---"
  echo "读不到钥匙串里的 Claude Code 凭证"
  echo "请先安装并登录 Claude Code，然后点此重试 | refresh=true"
  exit 0
fi

TOKEN=$(printf '%s' "$CRED" | /usr/bin/python3 -c "import sys,json;print(json.load(sys.stdin)['claudeAiOauth']['accessToken'])" 2>/dev/null)
if [ -z "$TOKEN" ]; then
  echo "⌛?"
  echo "---"
  echo "凭证格式解析失败，打开一次 Claude Code 后点此重试 | refresh=true"
  exit 0
fi

# ── 请求官方用量接口 ──
# SwiftBar 是 GUI 应用，不继承终端的代理环境变量；部分网络环境下
# 直连 api.anthropic.com 不通。按以下顺序依次尝试：
#   终端代理环境变量 → 系统代理设置 → 常见本地代理端口 → 直连
try_curl() {
  curl -s --max-time 12 "$@" https://api.anthropic.com/api/oauth/usage \
    -H "Authorization: Bearer $TOKEN" \
    -H "anthropic-beta: oauth-2025-04-20"
}

RESP=""
if [ -n "$https_proxy" ]; then
  RESP=$(try_curl)
fi
if [ -z "$RESP" ]; then
  SYS_PROXY=$(scutil --proxy | awk '/HTTPSEnable/{e=$3} /HTTPSProxy/{h=$3} /HTTPSPort/{p=$3} END{if(e==1 && h && p) print "http://"h":"p}')
  [ -n "$SYS_PROXY" ] && RESP=$(try_curl -x "$SYS_PROXY")
fi
if [ -z "$RESP" ]; then
  for port in 7897 7890; do  # Clash Verge / Clash 默认端口
    if nc -z -w 1 127.0.0.1 "$port" 2>/dev/null; then
      RESP=$(try_curl -x "http://127.0.0.1:$port")
      [ -n "$RESP" ] && break
    fi
  done
fi
[ -z "$RESP" ] && RESP=$(try_curl)

# ── 渲染菜单 ──
RESP="$RESP" /usr/bin/python3 <<'PY'
import os, json, datetime

def fail(msg):
    print("⌛–")
    print("---")
    print(msg)
    print("点此重试 | refresh=true")
    print("打开 claude.ai 用量页 | href=https://claude.ai/settings/usage")
    raise SystemExit

try:
    d = json.loads(os.environ.get("RESP", ""))
except Exception:
    fail("接口请求失败（检查网络/代理）")

if "five_hour" not in d:
    # 多半是 token 过期返回了错误体；打开 Claude Code 用一下会自动续期
    fail("登录态过期？打开一次 Claude Code 用一下即可续期")

def pct(x):
    if x and x.get("utilization") is not None:
        return int(round(x["utilization"]))
    return None

def local(ts):
    # 窗口空闲（夜里没用/打满后窗口到期）时接口返回 resets_at: null，必须容错
    if not ts:
        return None
    return datetime.datetime.fromisoformat(ts).astimezone()

now = datetime.datetime.now().astimezone()
s, w = pct(d["five_hour"]), pct(d["seven_day"])

rs, rw = local(d["five_hour"].get("resets_at")), local(d["seven_day"].get("resets_at"))
wd = "一二三四五六日"

# 三色阈值：蓝 <60 / 黄 60–84 / 红 ≥85（红档对齐官方 Approaching limit 警告区间）
# 色值取自 claude.ai 官网用量条
COLORS = {
    "blue": "#2A78D6",
    "yellow": "#FAB219",
    "red": "#C14842",
}

def level(p):
    p = p or 0
    return "red" if p >= 85 else ("yellow" if p >= 60 else "blue")

# SwiftBar 把 SF 符号强制按模板图渲染（永远灰色，sfcolor 无效），
# 所以彩色圆点用现场生成的 PNG 走 image= 参数（按原色渲染，不会被模板化）。
# 文字一律系统默认色——半透明磨砂菜单上彩色文字看不清。
import zlib, struct, base64

def circle_png(hex_color, size=24):
    """生成 size×size 的抗锯齿实心圆 RGBA PNG，返回 base64。纯标准库，无依赖。"""
    r, g, b = (int(hex_color[i:i+2], 16) for i in (1, 3, 5))
    c = (size - 1) / 2
    rad = size / 2 - 1.5
    raw = b""
    for y in range(size):
        row = bytearray(b"\x00")  # PNG 行滤波器: None
        for x in range(size):
            dist = ((x - c) ** 2 + (y - c) ** 2) ** 0.5
            a = max(0.0, min(1.0, rad - dist + 0.5))
            row += bytes((r, g, b, int(a * 255)))
        raw += bytes(row)
    def chunk(typ, data):
        return struct.pack(">I", len(data)) + typ + data + struct.pack(">I", zlib.crc32(typ + data) & 0xFFFFFFFF)
    png = (b"\x89PNG\r\n\x1a\n"
           + chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0))
           + chunk(b"IDAT", zlib.compress(raw))
           + chunk(b"IEND", b""))
    return base64.b64encode(png).decode()

_dot_cache = {}

def dot(p):
    color = COLORS[level(p)]
    if color not in _dot_cache:
        _dot_cache[color] = circle_png(color)
    return f" | image={_dot_cache[color]} width=12 height=12"

# 标题：已用% + 当前 5 小时窗口的重置时间；圆点按 session/周 中更差的那个亮灯
title = f"已用{s or 0}%"
if rs:
    title += f" ↻{rs.strftime('%H:%M')}"
print(f"{title}{dot(max(s or 0, w or 0))}")
print("---")

def fmt_session(t):
    days = (t.date() - now.date()).days
    prefix = "" if days == 0 else ("明天 " if days == 1 else t.strftime("%m-%d "))
    return prefix + t.strftime("%H:%M")

sess = f"当前 session：已用 {s or 0}%"
sess += f"（{fmt_session(rs)} 重置）" if rs else "（空闲）"
print(f"{sess}{dot(s)}")
week = f"本周额度：已用 {w or 0}%"
if rw:
    week += f"（周{wd[rw.weekday()]} {rw.strftime('%H:%M')} 重置）"
print(f"{week}{dot(w)}")
son = pct(d.get("seven_day_sonnet"))
if son is not None:
    print(f"Sonnet 单独额度：已用 {son}%")
print("---")
print(f"更新于 {now.strftime('%H:%M')} · 点此立即刷新 | refresh=true")
print("打开 claude.ai 用量页 | href=https://claude.ai/settings/usage")
print("---")
print(f'退出 | shell="{os.environ.get("PLUGIN_PATH", "")}" param1=quit terminal=false')
PY
