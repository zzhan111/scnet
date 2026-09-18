# scnet — SCNet Token Plan 剩余额度（Omarchy bar widget）

把 SCNet（超算互联网）Token Plan 的月度 Credits 剩余额度显示在 Omarchy 顶栏。

## 功能

- 栏上显示剩余 Credits（默认），中键切换：剩余 / 百分比 / 已用
- 剩余低于 10% 变警告色
- 点击打开面板：剩余大字、用量条、套餐名、到期时间、更新时间
- 右键打开 SCNet 控制台 Token Plan 页；面板内 `r` 换显示、`Enter` 打开控制台
- 每 5 分钟自动刷新；`omarchy-shell local.scnet refresh` 立即刷新

## 安装

```sh
omarchy plugin add ~/Projects/scnet --enable
omarchy restart shell
```

## 使用

```sh
omarchy bar set local.scnet display percent     # remaining · percent · used
omarchy-shell local.scnet demo                  # 假数据，再调回真数据
omarchy-shell local.scnet state                 # 当前快照 JSON
```

## 工作原理

```
浏览器（CDP 端口 19825/9222，须有一个 scnet.cn 页面）
  → bin/scnet-watch：CDP Network.getAllCookies 拿登录 cookie
  → GET https://www.scnet.cn/acx/charge/account/currentuser/tokenplan/list
  → 取 status=enable 且剩余最多的套餐，输出单行 JSON
  → Widget.qml 渲染栏条目与面板
```

登录态来自**运行中的浏览器**（经 CDP，浏览器自己解密 cookie），插件本身零解密
依赖、不碰 Chromium cookie 库。CDP WebSocket 握手需不发 `Origin` 头
（websocket-client 的 `suppress_origin=True`）。

### 依赖

- Python 3 + `websocket-client`（`pip install websocket-client`）
- 浏览器开着且已登录 scnet.cn（页面存在即可，不要求在前台）

## 布局

| 文件 | 说明 |
|---|---|
| `bin/scnet-watch` | CDP 拿 cookie → 查 API → 输出 JSON |
| `Widget.qml` | 栏条目 + 面板；设置（display）也在这里 |
| `manifest.json` | omarchy 插件清单（bar-widget） |

## 限制

- 浏览器没开时显示 `—`，恢复后 30s 内自动重连；不需要开着 scnet.cn 页面（任意 tab 即可）
- SCNet 控制台 API 无文档契约，字段变化需同步更新 `bin/scnet-watch`
- 只读：不写浏览器、不改网站状态
