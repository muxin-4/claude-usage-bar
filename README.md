# AI Usage Bar

在 Mac 菜单栏实时显示你的 **Claude + Codex** 套餐用量，不用再每天打开网页查额度。一个菜单栏图标，两个产品的额度一眼看全。

```
菜单栏长这样：   🔵 C 4% ↻16:00  Cx 1% ↻16:15
```

- **C 4%**：Claude 当前 5 小时窗口已用百分比 · **Cx 1%**：Codex 当前 5 小时窗口已用百分比
- **↻16:00**：该窗口的重置时间，到点额度满血
- **圆点颜色**：取两边更紧张的那个亮灯 — 🔵 <60% 随便用 · 🟡 60–84% 注意节奏 · 🔴 ≥85% 快到上限
- **点开下拉菜单**：Claude 和 Codex 各自的 5 小时窗口、周额度、套餐档位、各自重置时间（Claude 还有 Sonnet 单独额度）
- 每 5 分钟自动刷新，数据来自 Anthropic / ChatGPT **官方接口**，不是第三方估算
- 网络瞬断时不清空菜单栏，自动降级显示上次缓存的数据（圆点转灰提示）

> 只装了其中一个产品也能用：缺哪个就只显示另一个，两边互不影响（Codex 接口挂了不影响 Claude 显示，反之亦然）。

## 前提

- macOS 11 及以上
- 至少登录其中一个产品（本工具读取它们的本地登录凭证来查询用量）：
  - [Claude Code](https://claude.com/claude-code) — 显示 Claude 额度
  - [Codex CLI](https://developers.openai.com/codex)（用 **ChatGPT 套餐**登录，非 API key 模式）— 显示 Codex 额度
- [Homebrew](https://brew.sh)（用来安装 SwiftBar）

## 安装

**方式一：丢给 Claude Code（推荐，最省事）**

把下面这句话直接发给 Claude Code，它会自己装好：

> 帮我安装这个工具：https://github.com/muxin-4/claude-usage-bar ，克隆仓库后运行 install.sh，遇到问题按 README 的常见问题处理

**方式二：一行命令**

```bash
curl -fsSL https://raw.githubusercontent.com/muxin-4/claude-usage-bar/main/install.sh | bash
```

**方式三：手动**

```bash
git clone https://github.com/muxin-4/claude-usage-bar.git
cd claude-usage-bar
bash install.sh
```

> **首次运行会弹授权框**：macOS 会问"是否允许读取钥匙串中的 Claude Code-credentials"，点 **「始终允许」**（插件需要它查询你的用量；凭证不出本机）。如果提示 SwiftBar 是从互联网下载的应用，点「打开」。

## 怎么开、怎么关

| 想干什么 | 怎么做 |
|---|---|
| **退出**（菜单栏图标消失） | 点菜单栏图标 → 退出 |
| **再次打开** | `⌘ + 空格` 搜 **SwiftBar** 回车，或终端运行 `open -a SwiftBar` |
| **开机自动启动** | 系统设置 → 通用 → 登录项 → ➕ 添加 **SwiftBar** |
| **立即刷新数据** | 点菜单栏图标 → 点此立即刷新 |

## 常见问题

| 现象 | 原因和解决 |
|---|---|
| 某一段显示「接口请求失败」 | 网络不通。国内网络需要代理，插件会自动尝试：终端代理 → 系统代理 → Clash 常见端口（7897/7890）→ 直连。确认代理在运行即可 |
| Claude 段显示「登录态过期」 | 打开一次 Claude Code 随便用一下，凭证会自动续期，然后点刷新 |
| Codex 段显示「登录态过期」 | 在终端跑一次 `codex` 用一下即可续期，然后点刷新 |
| Codex 段一直不出现 | 确认 Codex 用的是 **ChatGPT 套餐登录**而非 API key（API key 模式没有套餐额度概念） |
| 菜单栏什么都没有 | SwiftBar 没在运行，`open -a SwiftBar` 打开它 |

## 隐私和原理

整个工具就是**一个 shell 脚本**（[ai-usage.5m.sh](ai-usage.5m.sh)），欢迎审计：

1. 从本地读取登录凭证 —— Claude 从 macOS 钥匙串，Codex 从 `~/.codex/auth.json`（都是各自 CLI 登录时自己存的）
2. 用它们分别调官方用量接口：
   - Claude：`api.anthropic.com/api/oauth/usage`
   - Codex：`chatgpt.com/backend-api/wham/usage`
3. 把百分比画到菜单栏

凭证**不写盘、不上传任何第三方服务器**，全程只和 Anthropic / ChatGPT 官方域名通信。菜单栏的显示能力由开源工具 [SwiftBar](https://github.com/swiftbar/SwiftBar) 提供。

## 卸载

```bash
curl -fsSL https://raw.githubusercontent.com/muxin-4/claude-usage-bar/main/uninstall.sh | bash
```

只删插件，SwiftBar 保留；想一起删再跑 `brew uninstall --cask swiftbar`。

## License

[MIT](LICENSE)
