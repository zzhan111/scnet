# SCNet 面板内登录（plugin 自持登录态）——调查报告

> 状态：**待开发**（阶段 1 方案已定，未实现）
> 调查日期：2026-09-18
> 结论先行：可行，价值 = 插件彻底摆脱浏览器依赖（独立工作，无需 ma-browser）；
> 跳过微信/短信登录与密码记住功能（安全红线）。

## 一、动机

当前 `bin/scnet-watch` 依赖运行中的浏览器（CDP 拿登录 cookie）。若在插件面板
内直接登录（账号/密码 + 登录按钮），插件自持 cookie，则：

- 浏览器不开也有数据（自持 cookie 优先，CDP 降级为 fallback）
- 插件可装到任何没有 ma-browser 的机器

## 二、登录链路（2026-09-18 实测）

登录页：`https://www.scnet.cn/sso/login`（CAS SSO 标准流程）。

| 环节 | 实测结果 | 实现难度 |
|---|---|---|
| 登录方式 | CAS webflow：`execution` 一次性票据 + `_eventId=submit` | 低 |
| 密码加密 | RSA-512 公钥硬编码于前端 JS，`jsencrypt encryptLong` 分段加密 | 低 |
| 图形验证码 | 按需：`GET /sso/needCaptcha.action` 当前返回 `data:false`（多次失败后才要求）；图片在 `GET /sso/captcha.action`（与 JSESSIONID 绑定） | 中 |
| 短信登录 | `phone-login-form`（phoneNum + SMS code） | 不做 |
| 微信扫码 | `getQRcodeUrl.action` / `getQRcodeLoginInfo.action` | 不做 |
| 登录产物 | `TGC`（CAS 票据 cookie）→ 302 链经 `ac/api/auth/loginSsoRedirect.action` 换业务 `Token` cookie | — |

### 关键端点

```
GET  https://www.scnet.cn/sso/login?service=<...>/ac/api/auth/loginSsoRedirect.action
     → 下发 execution 票据（hidden input）+ JSESSIONID
POST https://www.scnet.cn/sso/login
     字段：username, password(=RSA 加密), encrypted=true, mode,
           execution, _eventId=submit, geolocation, sensorsAnonId
     → Set-Cookie: TGC → 302 → 业务 cookie（Token）
GET  https://www.scnet.cn/sso/needCaptcha.action    → {"data": true|false}
GET  https://www.scnet.cn/sso/captcha.action        → 验证码图（同 cookie jar）
```

### RSA 公钥（摘自 login js，改版需同步）

```
MFwwDQYJKoZIhvcNAQEBBQADSwAwSAJBALaXEnbjI6fjy+t9W9AiO/KS0q+b/OZFS+7ykinLbir
iUx9P8BcuuHnVbXNiZp5jW70eVGBtX4DhGUPzJa1YT/8CAwEAAQ==
```

`encryptLong` 对超长明文分段；密码 ≤53 字节时单段即可（512-bit RSA 单块上限）。
前端源：`/sso/themes/sso/js/login-<hash>.js`（文件名带 hash，改版后重新抓）。

## 三、方案（阶段 1）

1. `Widget.qml` 面板加登录区：`TextField`（账号，echoMode Normal）+
   `TextField`（密码，`echoMode: Password`）+ 登录按钮；`Ctrl+L` 或按钮触发
2. `bin/scnet-watch` 加子命令：
   - `--login`：stdin 收账号/密码 → GET execution → POST（RSA）→ 跟 302 拿
     `Token` → JSON 输出结果（含 cookie 集），不回显密码
   - 正常轮询时 cookie 来源优先级：自持 cookie 文件 > CDP
3. cookie 存储：`~/.local/state/omarchy/scnet/session.json`（0600，仅
   scnet.cn 域的 cookie 值 + 保存时间）；无过期时间字段——401 即视为失效
4. 面板状态区显示登录来源（自持 / 浏览器 / 未登录）

## 四、安全红线

- 密码只在面板输入、进程内存使用，**永不落盘**（不提供"记住密码"）
- cookie 文件 0600、仅存 scnet.cn 域；登出 = 删除该文件
- RSA 公钥与端点均为逆向所得，SCNet 改版需同步修（同 omabot 对 Grok Bot
  状态文件的态度：无契约，防御式解析）

## 五、风险

- 连续失败可能触发 needCaptcha / 账号锁定：登录失败面板明示原因；
  验证码路径（阶段 2）实现前，失败后引导用户右键开浏览器登录
- CAS/接口变更：watcher 修复点集中在 `--login` 分支，不影响纯读取路径
- 多设备登录互踢可能性未知：实测同一账号浏览器 + 插件并存无冲突（TGC 并存）

## 六、跳过项

- 微信扫码 / 短信登录（流程重、收益低）
- 记住密码（安全红线）
- 自动续期（401 即要求重新登录，不做静默重试）
