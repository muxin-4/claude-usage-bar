#!/bin/bash
# AI Usage Bar — 在 Mac 菜单栏一个图标里同时显示 Claude + Codex 套餐用量
# https://github.com/muxin-4/claude-usage-bar
#
# 数据来自 Anthropic / ChatGPT 官方接口（与各自官网用量页同源，非第三方估算）。
# 凭证只在本机读取使用，不写盘、不上传。
# 文件名里的 5m = SwiftBar 每 5 分钟自动运行一次本脚本刷新数据。
#
# <bitbar.title>AI Usage Bar</bitbar.title>
# <bitbar.version>v2.0.0</bitbar.version>
# <bitbar.author>muxin-4</bitbar.author>
# <bitbar.author.github>muxin-4</bitbar.author.github>
# <bitbar.desc>菜单栏一个图标同时显示 Claude + Codex 套餐用量（5小时窗口+周额度），数据与官网同源</bitbar.desc>
# <bitbar.dependencies>Claude Code / Codex CLI（已登录）</bitbar.dependencies>
# <bitbar.abouturl>https://github.com/muxin-4/claude-usage-bar</bitbar.abouturl>
#
# <swiftbar.runInBash>false</swiftbar.runInBash>
# <swiftbar.hideAbout>true</swiftbar.hideAbout>
# <swiftbar.hideRunInTerminal>true</swiftbar.hideRunInTerminal>
# <swiftbar.hideLastUpdated>true</swiftbar.hideLastUpdated>
# <swiftbar.hideDisablePlugin>true</swiftbar.hideDisablePlugin>
# <swiftbar.hideSwiftBar>true</swiftbar.hideSwiftBar>

# ── 菜单"退出"动作 ──
# macOS 的 pkill 默认排除调用者的祖先进程，菜单点击时本脚本是 SwiftBar
# 的子进程，必须加 -a 把祖先纳入匹配，否则永远杀不到。
if [ "$1" = "quit" ]; then
  exec /usr/bin/pkill -a -x SwiftBar
fi

PLUGIN_PATH="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
export PLUGIN_PATH

# ── 预探测网络出口（只做一次，两个请求复用）──
# SwiftBar 是 GUI 应用不继承终端代理；国内直连两个域名都不通。
# 顺序：终端代理环境变量 → 系统代理 → 常见本地代理端口 → 直连兜底。
PROXY_LIST=()
[ -n "$https_proxy" ] && PROXY_LIST+=("")   # 空串 = 让 curl 自己读环境变量
SYS_PROXY=$(scutil --proxy | awk '/HTTPSEnable/{e=$3} /HTTPSProxy/{h=$3} /HTTPSPort/{p=$3} END{if(e==1 && h && p) print "http://"h":"p}')
[ -n "$SYS_PROXY" ] && PROXY_LIST+=("-x $SYS_PROXY")
for port in 7897 7890; do  # Clash Verge / Clash 默认端口
  nc -z -w 1 127.0.0.1 "$port" 2>/dev/null && PROXY_LIST+=("-x http://127.0.0.1:$port")
done
PROXY_LIST+=("")  # 最后再裸连兜底

# fetch <url> <header...>：按出口列表逐个尝试，返回第一个非空响应
fetch() {
  local opt r
  for opt in "${PROXY_LIST[@]}"; do
    r=$(curl -s --max-time 12 $opt "$@")
    [ -n "$r" ] && { printf '%s' "$r"; return; }
  done
}

# ── Claude：钥匙串取 token → Anthropic 用量接口 ──
CLAUDE_RESP=""
CRED=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null)
if [ -n "$CRED" ]; then
  CTOKEN=$(printf '%s' "$CRED" | /usr/bin/python3 -c "import sys,json;print(json.load(sys.stdin)['claudeAiOauth']['accessToken'])" 2>/dev/null)
  # 套餐档位接口里没有，但钥匙串凭证里有：subscriptionType + rateLimitTier（含 5x/20x 倍率）
  CLAUDE_PLAN=$(printf '%s' "$CRED" | /usr/bin/python3 -c "
import sys, json, re
o = json.load(sys.stdin)['claudeAiOauth']
st = (o.get('subscriptionType') or '').capitalize()
m = re.search(r'(\d+x)', o.get('rateLimitTier') or '')
print((st + (' ' + m.group(1) if m else '')).strip())
" 2>/dev/null)
  [ -n "$CTOKEN" ] && CLAUDE_RESP=$(fetch https://api.anthropic.com/api/oauth/usage \
    -H "Authorization: Bearer $CTOKEN" -H "anthropic-beta: oauth-2025-04-20")
fi

# ── Codex：~/.codex/auth.json 取 token → ChatGPT 用量接口 ──
CODEX_RESP=""
AUTH_FILE="$HOME/.codex/auth.json"
if [ -f "$AUTH_FILE" ]; then
  XCREDS=$(AUTH_FILE="$AUTH_FILE" /usr/bin/python3 -c "
import os, json
t = (json.load(open(os.environ['AUTH_FILE'])).get('tokens') or {})
print((t.get('access_token') or '') + '\t' + (t.get('account_id') or ''))
" 2>/dev/null)
  XTOKEN="${XCREDS%%	*}"; XACCT="${XCREDS##*	}"
  [ -n "$XTOKEN" ] && CODEX_RESP=$(fetch https://chatgpt.com/backend-api/wham/usage \
    -H "Authorization: Bearer $XTOKEN" -H "ChatGPT-Account-Id: $XACCT" \
    -H "User-Agent: codex-cli" -H "Accept: application/json")
fi

# ── 渲染 ──
CLAUDE_RESP="$CLAUDE_RESP" CODEX_RESP="$CODEX_RESP" CLAUDE_PLAN="$CLAUDE_PLAN" /usr/bin/python3 <<'PY'
import os, json, datetime, zlib, struct, base64

now = datetime.datetime.now().astimezone()
wd = "一二三四五六日"
CLAUDE_URL = "https://claude.ai/settings/usage"
CODEX_URL = "https://chatgpt.com/codex/settings/usage"

# 三色阈值：蓝 <60 / 黄 60–84 / 红 ≥85。
# 颜色一律用圆点（实心 PNG）表达——半透明磨砂下拉菜单上彩色文字会糊看不清，
# 文字必须保持系统默认色（自适应深浅背景）。
COLORS = {"blue": "#2A78D6", "yellow": "#FAB219", "red": "#C14842", "gray": "#8E8E93"}

def level(p):
    p = p or 0
    return "red" if p >= 85 else ("yellow" if p >= 60 else "blue")

# SwiftBar 的 sfimage 永远按模板图渲染（sfcolor 无效），彩色圆点用现场生成的
# PNG 走 image= 参数。注意菜单栏标题一行只能挂一个 image。
_dot_cache = {}
def circle_png(hex_color, size=24):
    r, g, b = (int(hex_color[i:i+2], 16) for i in (1, 3, 5))
    c = (size - 1) / 2; rad = size / 2 - 1.5; raw = b""
    for y in range(size):
        row = bytearray(b"\x00")
        for x in range(size):
            dist = ((x - c) ** 2 + (y - c) ** 2) ** 0.5
            a = max(0.0, min(1.0, rad - dist + 0.5))
            row += bytes((r, g, b, int(a * 255)))
        raw += bytes(row)
    def chunk(typ, data):
        return struct.pack(">I", len(data)) + typ + data + struct.pack(">I", zlib.crc32(typ + data) & 0xFFFFFFFF)
    png = (b"\x89PNG\r\n\x1a\n"
           + chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0))
           + chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b""))
    return base64.b64encode(png).decode()

def dot(p=None, color=None):
    color = color or COLORS[level(p)]
    if color not in _dot_cache:
        _dot_cache[color] = circle_png(color)
    return f" | image={_dot_cache[color]} width=12 height=12"

def iso_local(ts):
    if not ts: return None
    return datetime.datetime.fromisoformat(ts).astimezone()

def unix_local(ts):
    if not ts: return None
    return datetime.datetime.fromtimestamp(ts).astimezone()

def fmt_reset(t):
    """重置时间：今天只给时间，跨天给前缀。"""
    if not t: return "空闲"
    days = (t.date() - now.date()).days
    prefix = "" if days == 0 else ("明天 " if days == 1 else t.strftime("%m-%d "))
    return prefix + t.strftime("%H:%M")

def cache_io(path, fresh):
    """fresh 非 None 时写盘返回 (fresh, None)；为 None 时读旧数据返回 (data, 时间)。"""
    p = os.path.expanduser(path)
    if fresh is not None:
        try:
            os.makedirs(os.path.dirname(p), exist_ok=True)
            with open(p, "w") as f:
                json.dump({"at": now.isoformat(), "data": fresh}, f)
        except Exception:
            pass
        return fresh, None
    try:
        with open(p) as f:
            c = json.load(f)
        return c["data"], datetime.datetime.fromisoformat(c["at"])
    except Exception:
        return None, None

# 每个产品解析成统一结构：{s, w, rs, rw, extra, stale_at, err}
def parse_claude(raw):
    try:
        d = json.loads(raw) if raw else None
    except Exception:
        d = None
    if d is not None and "five_hour" not in d:
        return {"err": "登录态过期？打开一次 Claude Code 即可续期"}
    d, stale = cache_io("~/.cache/ai-usage-bar/claude.json", d)
    if d is None:
        return {"err": "接口请求失败（检查网络/代理）"}
    def pct(x): return int(round(x["utilization"])) if x and x.get("utilization") is not None else None
    extra = []
    son = pct(d.get("seven_day_sonnet"))
    if son is not None: extra.append((f"Sonnet 单独额度：{son}%", son))
    plan = os.environ.get("CLAUDE_PLAN")
    if plan: extra.append((f"套餐：{plan}", None))
    return {
        "s": pct(d["five_hour"]), "w": pct(d["seven_day"]),
        "rs": iso_local(d["five_hour"].get("resets_at")),
        "rw": iso_local(d["seven_day"].get("resets_at")),
        "extra": extra, "stale_at": stale, "err": None,
    }

def parse_codex(raw):
    try:
        d = json.loads(raw) if raw else None
    except Exception:
        d = None
    if d is not None and "rate_limit" not in d:
        return {"err": "登录态过期？在终端跑一次 codex 即可续期"}
    d, stale = cache_io("~/.cache/ai-usage-bar/codex.json", d)
    if d is None:
        return {"err": "接口请求失败（检查网络/代理）"}
    rl = d.get("rate_limit") or {}
    wins = [x for x in (rl.get("primary_window"), rl.get("secondary_window")) if x]
    # 按窗口时长区分，不信字段名（官方源码警告 primary/secondary 标签可能反）
    short = min(wins, key=lambda x: x.get("limit_window_seconds", 0)) if wins else None
    longw = max(wins, key=lambda x: x.get("limit_window_seconds", 0)) if wins else None
    if short is longw: longw = None
    def pct(x): return int(round(x["used_percent"])) if x and x.get("used_percent") is not None else None
    extra = []
    if d.get("plan_type"): extra.append((f"套餐：{d['plan_type'].capitalize()}", None))
    return {
        "s": pct(short), "w": pct(longw),
        "rs": unix_local((short or {}).get("reset_at")),
        "rw": unix_local((longw or {}).get("reset_at")),
        "extra": extra, "stale_at": stale, "err": None,
    }

claude = parse_claude(os.environ.get("CLAUDE_RESP", ""))
codex = parse_codex(os.environ.get("CODEX_RESP", ""))

# ── 标题：C<claude>% ↻时间  Cx<codex>% ↻时间（Claude 在前，带 5 小时窗口重置时间）──
# 文字默认色；一个圆点表达整体预警（取两边 5 小时窗口里更高档位，与"标题只看 5 小时"一致）。
def title_seg(label, info):
    if info.get("err") and info.get("s") is None:
        return f"{label}–"
    t = info.get("rs")
    r = f" ↻{t.strftime('%H:%M')}" if t else ""
    return f"{label}{info.get('s') or 0}%{r}"

fivep = [v for v in (claude.get("s"), codex.get("s")) if v is not None]
any_stale = claude.get("stale_at") or codex.get("stale_at")
if not fivep:
    head_dot = dot(color=COLORS["gray"])
elif any_stale:
    head_dot = dot(color=COLORS["gray"])   # 有旧数据时整体置灰提示不全新
else:
    head_dot = dot(max(fivep))
print(f"{title_seg('C', claude)}  {title_seg('Cx', codex)}{head_dot}")
print("---")

# ── 下拉：每个产品一段，文字默认色，行尾圆点按各自档位上色 ──
def block(name, info, url, opener):
    print(name)   # 产品名
    if info.get("err") and info.get("s") is None:
        print(f"⚠️ {info['err']}")
    else:
        if info.get("stale_at"):
            t = info["stale_at"]
            ago = (t.strftime("%m-%d ") if t.date() != now.date() else "") + t.strftime("%H:%M")
            print(f"⚠️ 接口失败，下面是 {ago} 的旧数据")
        s = info.get("s")
        print(f"当前 session：{s or 0}%（{fmt_reset(info.get('rs'))} 重置）{dot(s)}")
        if info.get("w") is not None or info.get("rw"):
            rw = info.get("rw")
            wk = f"本周额度：{info.get('w') or 0}%"
            if rw: wk += f"（周{wd[rw.weekday()]} {rw.strftime('%H:%M')} 重置）"
            print(f"{wk}{dot(info.get('w'))}")
        for text, p in info.get("extra", []):
            print(f"{text}{dot(p)}" if p is not None else text)
    print(f"打开{opener}用量页 | href={url}")

block("Claude", claude, CLAUDE_URL, "Claude ")
print("---")
block("Codex", codex, CODEX_URL, "Codex ")
print("---")
print(f"更新于 {now.strftime('%H:%M')} · 点此立即刷新 | refresh=true")
print("---")
print(f'退出 | shell="{os.environ.get("PLUGIN_PATH", "")}" param1=quit terminal=false')
PY
