# 同学日安 · Bonjour Campus

一个**单文件**的像素风校园互动叙事小游戏：把「同学日安」的一天做成可以点击、可以走动的交互场景，包含教室传纸条、校园偶遇、手机界面、成长面板与结局收集等玩法。

游戏本体就是仓库根目录的 **`index.html`**（**约 54.6 MB / 5,725 万字节**）：像素画面由 Canvas 代码实时绘制、音效由 WebAudio 合成、Three.js 与 GLTFLoader 直接内联，另有内嵌的 base64 视频（约 38 MB，`<script>` 里的 `HOME_VIDEO_BASE64`）、八音盒音频（约 1.2 MB）与 3 个 glTF 模型。**没有后端**，双击打开就能玩。

在线试玩：**https://duyuanxi.github.io/bonjour-campus/**（GitHub Pages）

仓库：https://github.com/duyuanxi/bonjour-campus

---

## 快速开始

### 本地玩

直接双击 `index.html` 用浏览器打开即可（`file://` 下也能正常运行）；也可以起一个静态服务器：

```bash
python -m http.server 8000
# 打开 http://127.0.0.1:8000/
```

建议使用较新的 Chrome / Edge / Safari（用到 Canvas 2D、WebAudio、CSS container queries）。

### 发布到 GitHub（含在线试玩）

已经发布完成，仓库为 `duyuanxi/bonjour-campus`，Pages 已开启（Deploy from a branch → `main` → `/ (root)`）。

以后要更新，在本目录执行：

```powershell
pwsh -File .\publish.ps1 -DryRun                                   # 只做安全检查，不动 git
git add -A
git commit -m "更新说明"
git push
```

> **注意**：本机 git 的全局代理（`http.proxy` / `https.proxy` → `127.0.0.1:3118x`）会让大文件 push 卡死；仓库已配置 `http.https://github.com.proxy = ""` 强制直连，若换机器推送超大文件请照此设置。
> 单文件 54.6 MB 超过 GitHub 建议的 50 MB，push 时会收到 `GH001: Large files detected` 警告，属正常提示（未使用 Git LFS）。

---

## 仓库结构

```
.
├── index.html                  # 游戏本体（单文件，全部逻辑 + 内联 Three.js + 内嵌媒体）
├── publish.ps1                 # 一键发布脚本（含发布前敏感信息检查）
├── .gitignore                  # 白名单式：只放行列出的文件
├── SECURITY-AUDIT.md           # 发布前安全核查报告
├── README.md
└── LICENSE                     # MIT + 第三方组件声明
```

> 游戏原始文件另存于本机工作目录 `新/geshihua_v15.6.html`（与 `index.html` 内容相同），**不纳入仓库**，避免在仓库里放两份 54.6 MB 的文件。

`.gitignore` 采用白名单方式，只会提交上面列出的文件；同目录下的其他视频工程、素材与 `node_modules` 都不会进仓库。

---

## 安全说明（发布前核查结论）

对完整文件（9,661 行 + 内嵌 base64 媒体）逐行核查，**文件内没有写入任何密钥、令牌或口令**。详细证据见 [SECURITY-AUDIT.md](SECURITY-AUDIT.md)，摘要：

| 检查项 | 结果 |
| --- | --- |
| API Key / Token / Secret / 口令 | 文件内**没有真实密钥**（`sk-`、`AIza`、`ghp_`、`AKIA`、`Bearer <值>`、私钥块等均无匹配） |
| 与 AI 接口相关的代码 | **有**：内嵌的「学生端」应用可让**使用者自己填写** API Key / 接口地址 / 模型，用 `fetch(...+'/chat/completions')` 调用（预置智谱 GLM、DeepSeek、通义千问、Kimi 与本地 Ollama/LM Studio）。密钥只在运行时从浏览器 `localStorage`（键名 `echo_ai_key`）读取，**不随文件分发** |
| 外部网络请求 | 页面加载时**零请求**；只有使用者主动配置 AI 后才会访问其填写的接口 |
| 外链资源标签 | 无（`<script src=`、`<link href=`、`<img src=外链` 均无匹配） |
| 文件内的 http(s) 链接 | 37 行是内联 GLTFLoader 源码注释里的规范文档链接，纯注释不发起请求 |
| 统计埋点 | 无（无 gtag / UA- / G-XXXX / 百度统计） |
| 个人隐私数据 | 未发现真实姓名、电话、邮箱、住址、证件号；无本机绝对路径（角色与学校名均为虚构） |

⚠️ **发布前请注意（非密钥问题）**：

1. **版权**：文件内嵌了一段 38 MB 的 base64 视频（元数据含 `BILIAVC.2.0.1 ... Bilibili Inc` 编码器标记，即 B 站转码的第三方视频）与 1.2 MB 八音盒音频（游戏内显示曲名《死別》シャノン）。**若你没有再分发授权，公开仓库有被投诉下架的风险**（已由项目所有者确认自行承担）。
2. **体积**：单文件 54.6 MB，超过 GitHub 单文件 50 MB 的警告线（硬上限 100 MB），push 会偏慢。
3. **公开即失效**：游戏内彩蛋口令 `GAOKAO2024`（第 2584 行）与 `zhouzhou` 打字彩蛋（第 3091 行）发布后任何人都能看到；调试面板由 `CHEAT` 开关保护。
4. **署名合规**：场景模型作者署名的"查看作者、来源与许可"链接目前是 `href="#"` 占位，CC BY 4.0 的署名链要求尚未完全满足。

任何改动后，建议 push 前再跑一次 `pwsh -File .\publish.ps1 -DryRun`。

---

## 版本与许可

- 当前版本：**v15.6**（游戏本体 `index.html`；原始文件为 `新/geshihua_v15.6.html`）
- 许可：MIT，见 [LICENSE](LICENSE)（署名 `Copyright (c) 2026 duyuanxi`，如需变更请直接修改该行）
