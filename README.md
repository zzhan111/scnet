# SCNet Token Plan 剩余额度（Omarchy bar widget）

把 SCNet（超算互联网）Token Plan 的月度 Credits 剩余额度显示在 Omarchy 顶栏。
数据来自 SCNet 控制台 API，登录态复用浏览器 cookie。

## 功能

- 顶栏显示剩余 Credits（默认），滚轮切换为百分比 / 已用
- 点击打开面板：套餐名、剩余、百分比、到期时间
- 每 5 分钟自动刷新（登录态在浏览器里保持，插件只读）

## 安装

```sh
omarchy plugin add ~/Projects/scnet --enable
omarchy restart shell
```

## 使用

```sh
omarchy bar set local.scnet display percent   # remaining · percent · used
```

## 工作原理

- `bin/scnet-watch` 从 `~/.config/chromium` 或 `~/.bb-browser` 的 Cookie 库解密
  `www.scnet.cn` 的 `Token` cookie（Chromium v10 + libsecret 密钥）
- 查询 `https://www.scnet.cn/acx/charge/account/currentuser/tokenplan/list`
- 取未用尽套餐的 `totalAmount - usedAmount`，输出单行 JSON
- `Widget.qml` 渲染栏条目和面板

### 需要的依赖

- Python 3 + `cryptography`（cookie 解密）：`python3 -m pip install cryptography`
- `secret-tool`（libsecret，读 Chromium 密钥）

## 布局

| 文件 | 说明 |
|---|---|
| `bin/scnet-watch` | 读 cookie → 查 API → 输出 JSON |
| `Widget.qml` | 栏条目 + 面板 |

## 限制

- 依赖浏览器 Cookie 加密密钥格式（v10 + libsecret），其他浏览器需扩展 `COOKIE_PROFILES`
- SCNet 控制台 API 无文档契约，字段变化需同步更新 `bin/scnet-watch`
