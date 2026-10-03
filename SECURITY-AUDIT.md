# 发布前安全核查报告 · 同学日安（Bonjour Campus）

- **被查文件**：`新/geshihua_v15.6.html`（9,661 行，游戏本体，约 1 MB）
- **核查目的**：确认把该文件公开到 GitHub 不会泄露密钥、凭证、隐私信息或引入外部 API 依赖
- **核查方式**：全文逐行通读 + 针对高危模式逐条定向检索（每条模式单独验证，避免宽泛匹配）
- **结论**：**可以发布**。未发现任何密钥 / 令牌 / 私钥 / 凭证 / 外部 API 调用 / 统计埋点 / 真实个人隐私数据。

---

## 1. 密钥与凭证（高危模式）

逐条定向检索，**全部无匹配**：

| 模式 | 覆盖的泄露类型 | 结果 |
| --- | --- | --- |
| `sk-[A-Za-z0-9_-]{20,}` | OpenAI / DeepSeek 等 `sk-` 开头密钥 | 无 |
| `AIza[0-9A-Za-z_-]{30,}` | Google API Key | 无 |
| `gh[pousr]_…` / `github_pat_…` | GitHub Token | 无 |
| `AKIA[0-9A-Z]{16}` | AWS Access Key | 无 |
| `xox[abprs]-…` | Slack Token | 无 |
| `-----BEGIN … PRIVATE KEY-----` | 私钥块 | 无 |
| `eyJ….eyJ….` | JWT | 无 |
| `Bearer ` / `Authorization:` / `Basic …` | 认证头 | 无 |
| `X-Amz-Signature` / `access_token=` / `&sig=` | 签名 URL 与令牌参数 | 无 |
| `(password\|passwd\|api_key\|secret_key\|auth_token)\s*[=:]\s*"…"` | 硬编码口令赋值 | 无 |
| `client_secret` / `account_key` | 云服务密钥 | 无 |
| `webhook` / `hooks.slack` / `discord.com/api` / `t.me` | 外发通道 | 无 |

## 2. 网络调用与外部依赖

| 检查项 | 结果 |
| --- | --- |
| `<script src=` / `<link href=` / `<img src=` 外链标签 | **全为 0**，贴图与音效均由 Canvas / WebAudio 代码生成 |
| `<img` 标签 | 完全没有出现（图案全部程序化绘制） |
| `src="http…"` / `href="http…"` | 无 |
| `fetch(` | 仅出现在内联的 Three.js 库源码中（库的 FileLoader 实现），**游戏逻辑未调用** |
| `XMLHttpRequest` | 仅出现在内联 Three.js 库源码中，**游戏逻辑未调用** |
| `new WebSocket` / `new EventSource` / `sendBeacon` | 无 |
| `axios` / `.listen(` | 无（也不含任何服务端代码） |
| `API_BASE` / `apiBase` / `BASE_URL` / `endpoint` | 无 |
| 文件内出现的 http(s) 链接 | 全部是内联 Three.js / GLTFLoader **源码注释**里的规范文档地址（`github.com/KhronosGroup/glTF/...`、`github.com/mrdoob/three.js/issues/...`、`en.wikipedia.org/...`），纯注释，不会产生任何请求 |
| 统计 / 埋点 | 无 `gtag(`、`googletagmanager`、`google-analytics`、`hm.baidu.com`、`_hmt` |
| 本地存储 | 仅用 `localStorage` 存游戏自身进度与解锁记录（`geshihua_save` 等键），不上传 |
| `navigator.clipboard` | 出现在内联的学生端演示页面字符串中（复制文案用），不涉及数据外发 |
| `getUserMedia` | 无（不调用摄像头 / 麦克风） |
| `document.cookie` / `sessionStorage` / `indexedDB` | 无 |

**自包含性**：整个游戏是单文件、零外部请求，`file://` 直接双击即可运行，部署到 GitHub Pages 后也不需要任何后端。

## 3. 个人与隐私信息

| 检查项 | 结果 |
| --- | --- |
| 邮箱地址（`xxx@yyy.zz`） | 无 |
| 学生 / 真实姓名、电话、住址、证件号 | 未发现（文件中的姓名均为游戏虚构角色） |
| 本机绝对路径（`C:\…`、`D:\…`） | 无 |
| 机器名、内网域名、账号 | 无 |
| `localhost` / `127.0.0.1` | 仅第 5521 行（内联演示页字符串）出现 1 次 `localhost`，且**没有端口号、没有调用它的代码**（`127.0.0.1`、`:3000`、`:8080`、`:5173`、`:8000` 与 `localhost:端口` 的组合均无匹配），属演示文案，不产生请求 |

## 4. 需要留意但不算泄露的内容

1. **内联了第三方库**：Three.js（版本串为 `128`，即 r128，第 337 行起）与 GLTFLoader（约第 5,600 行起）直接内联在文件里。
   - 不影响安全，但**发布到公开仓库时请保留其 MIT 许可声明**（本文件保留了库头部的 `@license`/`Specification` 注释，未删改）。
   - 若后续要规范化，可在 README 里注明 `three.js r128 (MIT, © three.js authors)`。
2. **游戏内有调试/作弊相关的代码路径**（`CHEAT`、`#debug`、快速存档等）。这不是密钥泄露，但公开后任何人都能看到并触发；若不想公开，请在发布前删减相关分支。
3. **第 5521 行是一个超长行**（内联了完整的“学生端”演示页面字符串，约数百 KB）。
   - 它导致普通 `grep` 工具解析该行时体积过大；本次核查对该行的内容采用“定向模式逐条验证 + 读取裁剪”的方式确认，未发现密钥类内容。
   - 若以后要在 GitHub 上浏览/维护，建议把这段内联 HTML 拆成独立文件，可读性会好很多。
4. **署名与版权**：`LICENSE` 目前写的是 `Copyright (c) 2025 同学日安 Bonjour Campus`，请按需替换为你的名字/组织。

## 5. 复现方式

本项目根目录的 `publish.ps1 -DryRun` 会把上面第 1、2 节的检查再自动跑一遍（并列出将要提交的文件清单）：

```powershell
pwsh -File .\publish.ps1 -DryRun
```

发现 HIGH 级匹配时脚本会中止，确认误报可加 `-Force`。

---

**最终结论：该文件没有 API Key、密钥、令牌、隐私数据，也没有任何外部 API 依赖与埋点，可以安全公开到 GitHub。**
