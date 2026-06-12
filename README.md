# Claude Usage Bar

在 Mac 菜单栏实时显示你的 Claude 套餐用量，不用再每天打开 claude.ai 网页查额度。

```
菜单栏长这样：   🔵 已用 41% ↻18:00
```

- **🔵 已用 41%**：当前 5 小时窗口已用的额度百分比（和 claude.ai 官网设置页的数字完全一致）
- **↻18:00**：这个窗口的重置时间，到点额度满血
- **圆点颜色**：🔵 <60% 随便用 · 🟡 60–84% 注意节奏 · 🔴 ≥85% 快到上限了
- **点开下拉菜单**：5 小时窗口、周额度、Sonnet 单独额度的明细和各自重置时间
- 每 5 分钟自动刷新，数据来自 Anthropic 官方接口，**不是第三方估算**

## 前提

- macOS 11 及以上
- 已安装并登录 [Claude Code](https://claude.com/claude-code)（本工具读取它的登录凭证来查询你的用量）
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
| **退出**（菜单栏图标消失） | 点菜单栏「已用 xx%」→ 退出 |
| **再次打开** | `⌘ + 空格` 搜 **SwiftBar** 回车，或终端运行 `open -a SwiftBar` |
| **开机自动启动** | 系统设置 → 通用 → 登录项 → ➕ 添加 **SwiftBar** |
| **立即刷新数据** | 点菜单栏「已用 xx%」→ 点此立即刷新 |

## 常见问题

| 现象 | 原因和解决 |
|---|---|
| 菜单栏显示 `⌛–` | 网络不通。国内网络需要代理，插件会自动尝试：系统代理 → Clash 常见端口（7897/7890）→ 直连。确认你的代理在运行即可 |
| 显示「登录态过期」 | 打开一次 Claude Code 随便用一下，登录凭证会自动续期，然后点刷新 |
| 显示 `⌛?` | 没装 Claude Code 或没登录。终端运行 `claude` 完成登录后点刷新 |
| 钥匙串授权框点了「拒绝」 | 点菜单里的「点此重试」会重新弹授权框，这次选「始终允许」 |
| 菜单栏什么都没有 | SwiftBar 没在运行，`open -a SwiftBar` 打开它 |

## 隐私和原理

整个工具就是**一个 shell 脚本**（[claude-usage.5m.sh](claude-usage.5m.sh)），欢迎审计：

1. 从 macOS 钥匙串读取 Claude Code 的 OAuth 凭证（Claude Code 登录时自己存的）
2. 用它调用 Anthropic 官方用量接口 `api.anthropic.com/api/oauth/usage`
3. 把百分比画到菜单栏

凭证**不写盘、不上传任何第三方服务器**，全程只和 Anthropic 官方域名通信。菜单栏的显示能力由开源工具 [SwiftBar](https://github.com/swiftbar/SwiftBar) 提供。

## 卸载

```bash
curl -fsSL https://raw.githubusercontent.com/muxin-4/claude-usage-bar/main/uninstall.sh | bash
```

只删插件，SwiftBar 保留；想一起删再跑 `brew uninstall --cask swiftbar`。

## License

[MIT](LICENSE)
