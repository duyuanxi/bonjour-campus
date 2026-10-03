# publish.ps1 — 发布「同学日安 · Bonjour Campus」到 GitHub
#
# 本脚本放在仓库根目录（即 D:\下载\黑客松汇报），游戏本体是 新\geshihua_v15.6.html。
#
# 用法：
#   pwsh -File .\publish.ps1 -DryRun                                   # 只做发布前安全检查，不动 git
#   pwsh -File .\publish.ps1 -RepoUrl https://github.com/你/bonjour-campus.git
#   pwsh -File .\publish.ps1 -RepoUrl git@github.com:你/bonjour-campus.git -Branch main
#
# 脚本流程：① 检查密钥/令牌/隐私信息 ② 检查游戏文件是否为自包含单文件
#           ③ 显示将要提交的文件清单 ④ git init + commit ⑤ 设置 remote ⑥ push
# 发现 HIGH 级问题时脚本中止，确认是误报可加 -Force。

[CmdletBinding()]
param(
  [string]$RepoUrl = '',
  [string]$Branch  = 'main',
  [string]$GameFile = '新\geshihua_v15.6.html',
  [switch]$DryRun,
  [switch]$Force
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $repo
Write-Host "== 仓库目录: $repo" -ForegroundColor Cyan

# ---------- ① 敏感信息扫描 ----------
$HighPatterns = @(
  @{ Name = 'GitHub Token';        Re = 'gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}' },
  @{ Name = 'OpenAI/DeepSeek Key'; Re = 'sk-[A-Za-z0-9_-]{20,}' },
  @{ Name = 'Google API Key';      Re = 'AIza[0-9A-Za-z_-]{30,}' },
  @{ Name = 'AWS Access Key';      Re = 'AKIA[0-9A-Z]{16}' },
  @{ Name = 'Slack Token';         Re = 'xox[abprs]-[A-Za-z0-9-]{10,}' },
  @{ Name = '私钥块';              Re = '-----BEGIN [A-Z ]*PRIVATE KEY-----' },
  @{ Name = '云服务密钥赋值';      Re = '(client_secret|account_key|subscription_key)\s*[=:]\s*["'']?[A-Za-z0-9_\-\.]{16,}' },
  @{ Name = 'JWT';                 Re = 'eyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.' },
  @{ Name = '签名/令牌 URL 参数';  Re = '(X-Amz-Signature|X-Amz-Credential|[?&]access_token=|&sig=)' },
  @{ Name = '硬编码口令';          Re = '(password|passwd|pwd|apikey|api_key|access_key|secret_key|auth_token)\s*[=:]\s*["''][^"'']{6,}["'']' }
)
$WarnPatterns = @(
  @{ Name = '密钥关键字';   Re = '(?i)(api[_-]?key|apikey|secret|bearer|password|passwd|credential)' },
  @{ Name = 'http(s) 链接'; Re = 'https?://[A-Za-z0-9\.\-]+' },
  @{ Name = '外链资源';     Re = '(?i)<(script|link|img|iframe)[^>]{0,120}(src|href)\s*=\s*["'']?(https?:)?//' },
  @{ Name = '本机绝对路径'; Re = '[A-Za-z]:\\' },
  @{ Name = '邮箱地址';     Re = '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' },
  @{ Name = '统计埋点';     Re = '(?i)(gtag\(|googletagmanager|google-analytics|hm\.baidu\.com|_hmt)' }
)

Write-Host "`n== ① 敏感信息扫描（按 .gitignore 实际会提交的文件）" -ForegroundColor Cyan
if (-not (Test-Path (Join-Path $repo '.git'))) {
  Write-Host "  （仓库尚未 git init，先按目录内文本文件扫描）" -ForegroundColor DarkGray
  $targets = Get-ChildItem -Path $repo -Recurse -File -Force |
             Where-Object { $_.FullName -notmatch '\\\.git\\' -and
                            $_.FullName -notmatch '\\(node_modules|__pycache__|格式化宣传片|同学日安宣传片)\\' -and
                            $_.Extension -in @('.html', '.htm', '.js', '.mjs', '.cjs', '.ts', '.json', '.md', '.txt', '.css', '.ps1', '.sh', '.yml', '.yaml', '.env') -and
                            $_.Name -notmatch '^\.env' }
} else {
  $targets = @()
  foreach ($p in (git ls-files)) {
    $full = Join-Path $repo $p
    if (Test-Path -LiteralPath $full) { $targets += Get-Item -LiteralPath $full }
  }
}

$highHits = 0; $warnHits = 0; $warnDetail = @{}
foreach ($f in $targets) {
  $rel = $f.FullName.Substring($repo.Length).TrimStart('\')
  $lines = Get-Content -LiteralPath $f.FullName -ErrorAction SilentlyContinue
  if (-not $lines) { continue }
  for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    if ($line.Length -gt 3000) { $scan = $line.Substring(0, 3000) } else { $scan = $line }
    foreach ($p in $HighPatterns) {
      $m = [regex]::Match($scan, $p.Re)
      if ($m.Success) {
        $highHits++
        $v = $m.Value; if ($v.Length -gt 60) { $v = $v.Substring(0, 60) + '…' }
        Write-Host ("  [HIGH] {0}:{1}  {2}  ->  {3}" -f $rel, ($i + 1), $p.Name, $v) -ForegroundColor Red
      }
    }
    foreach ($p in $WarnPatterns) {
      if ([regex]::IsMatch($scan, $p.Re)) {
        $warnHits++
        if (-not $warnDetail.ContainsKey($p.Name)) { $warnDetail[$p.Name] = 0 }
        $warnDetail[$p.Name]++
      }
    }
  }
}
if ($highHits -eq 0) { Write-Host "  [OK] 未发现密钥、令牌、私钥、硬编码口令" -ForegroundColor Green }
else { Write-Host "  [!!] 发现 $highHits 处高危匹配，逐条确认后再发布" -ForegroundColor Red }
if ($warnHits -gt 0) {
  Write-Host "  [INFO] 低风险提示 $warnHits 处：" -ForegroundColor Yellow
  foreach ($k in $warnDetail.Keys) { Write-Host ("         - {0}: {1}" -f $k, $warnDetail[$k]) }
}

# ---------- ② 自包含性检查 ----------
Write-Host "`n== ② 游戏文件自包含性" -ForegroundColor Cyan
$game = Join-Path $repo $GameFile
if (-not (Test-Path -LiteralPath $game)) {
  Write-Host "  [ERROR] 找不到游戏文件：$GameFile" -ForegroundColor Red
  exit 1
}
$gi = Get-Item -LiteralPath $game
Write-Host ("  {0}  {1:N0} 字节 = {2:N2} MB" -f $GameFile, $gi.Length, ($gi.Length / 1MB))
$raw = Get-Content -LiteralPath $game -Raw
$extScript = ([regex]::Matches($raw, '(?i)<script[^>]{0,120}\ssrc=')).Count
$extLink   = ([regex]::Matches($raw, '(?i)<link[^>]{0,120}\shref=')).Count
$extImg    = ([regex]::Matches($raw, '(?i)<img[^>]{0,120}\ssrc=')).Count
if (($extScript + $extLink + $extImg) -eq 0) {
  Write-Host "  [OK] 没有外链 script/link/img，贴图与音效由代码生成，单文件可离线运行" -ForegroundColor Green
} else {
  Write-Host ("  [WARN] 发现外链标签：script={0} link={1} img={2}，发布后可能依赖外部资源" -f $extScript, $extLink, $extImg) -ForegroundColor Yellow
}
$proto = ([regex]::Matches($raw, "(?i)(fetch\s*\(|new\s+WebSocket|new\s+EventSource)")).Count
Write-Host "  [INFO] 网络调用关键字命中 $proto 处（含内联 Three.js 库源码，需人工确认非游戏逻辑）"

$idx = Join-Path $repo 'index.html'
if (Test-Path -LiteralPath $idx) {
  $idxRaw = Get-Content -LiteralPath $idx -Raw
  if ($idxRaw -match 'geshihua_v15\.6\.html') { Write-Host "  [OK] 根 index.html 跳转目标正确（GitHub Pages 首页可用）" -ForegroundColor Green }
  else { Write-Host "  [WARN] 根 index.html 未指向 $GameFile，Pages 首页可能打不开游戏" -ForegroundColor Yellow }
} else {
  Write-Host "  [WARN] 缺少根 index.html，GitHub Pages 首页会 404" -ForegroundColor Yellow
}

if ($highHits -gt 0 -and -not $Force -and -not $DryRun) {
  Write-Host "`n发现 $highHits 处高危匹配，已中止。确认误报可加 -Force。" -ForegroundColor Red
  exit 2
}
if ($DryRun) { Write-Host "`n== DryRun 结束：未执行任何 git 操作" -ForegroundColor Cyan; exit 0 }

# ---------- ③④⑤ git ----------
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
  Write-Host "`n[ERROR] 找不到 git，请安装 Git for Windows 并确保在 PATH 中。" -ForegroundColor Red
  exit 3
}
Write-Host "`n== ③ 将要提交的文件" -ForegroundColor Cyan
git add -A
git diff --cached --name-only | ForEach-Object { Write-Host "    $_" }
$staged = @(git diff --cached --name-only).Count
if ($staged -eq 0) { Write-Host "  （没有需要提交的改动）" -ForegroundColor DarkGray }

Write-Host "`n== ④ 提交" -ForegroundColor Cyan
if (-not (Test-Path (Join-Path $repo '.git'))) {
  git init -b $Branch | Out-Null
  Write-Host "  已初始化本地仓库（分支 $Branch）"
}
if ($staged -gt 0) {
  git commit -m "feat: 同学日安 Bonjour Campus 单文件像素校园叙事 (v15.6)" | Out-Null
  Write-Host "  已提交 $staged 个文件" -ForegroundColor Green
}

if (-not $RepoUrl) {
  Write-Host "`n== ⑤ 未提供 -RepoUrl，已停在本地提交。补远端即可推送：" -ForegroundColor Yellow
  Write-Host "    git remote add origin https://github.com/<你的用户名>/bonjour-campus.git"
  Write-Host "    git push -u origin $Branch"
  exit 0
}
Write-Host "`n== ⑤ 推送" -ForegroundColor Cyan
$existing = git remote get-url origin 2>$null
if ($existing) { git remote set-url origin $RepoUrl; Write-Host "  已更新 origin -> $RepoUrl" }
else { git remote add origin $RepoUrl; Write-Host "  已添加 origin -> $RepoUrl" }
git push -u origin $Branch

Write-Host "`n完成！接着去仓库 Settings → Pages：Source 选 'Deploy from a branch'，Branch 选 '$Branch'，目录选 '/(root)'。" -ForegroundColor Green
Write-Host "1-2 分钟后访问 https://<你的用户名>.github.io/<仓库名>/ 即可在线游玩。" -ForegroundColor Green
