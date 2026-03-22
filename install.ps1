# 小红书 Skill 一键安装脚本（Windows）
# 用法（管理员 PowerShell 或普通用户均可）：
#   irm https://raw.githubusercontent.com/bahunag/xiaohongshu-skill/main/install.ps1 | iex
# 如果提示执行策略受限，改用：
#   Set-ExecutionPolicy -Scope Process Bypass -Force; irm https://raw.githubusercontent.com/bahunag/xiaohongshu-skill/main/install.ps1 | iex

$ErrorActionPreference = "Stop"

$SKILL_REPO  = "https://github.com/bahunag/xiaohongshu-skill.git"
$MCP_REPO    = "xpzouying/xiaohongshu-mcp"
$SKILL_DIR   = "$env:USERPROFILE\.claude\skills\xiaohongshu"
$MCP_DIR     = "$env:USERPROFILE\xiaohongshu-mcp"
$MCP_PORT    = 18060
$PLATFORM    = "windows-amd64"
$MCP_BIN     = "$MCP_DIR\xiaohongshu-mcp-$PLATFORM.exe"
$LOGIN_BIN   = "$MCP_DIR\xiaohongshu-login-$PLATFORM.exe"
$COOKIES_SRC = "$env:LOCALAPPDATA\Temp\cookies.json"
$COOKIES_DST = "C:\tmp\cookies.json"

function Write-OK   { param($msg) Write-Host "  [OK] $msg" -ForegroundColor Green }
function Write-Warn { param($msg) Write-Host "  [!]  $msg" -ForegroundColor Yellow }
function Write-Fail { param($msg) Write-Host "  [X]  $msg" -ForegroundColor Red; exit 1 }

Write-Host ""
Write-Host "=== 小红书 Skill 安装程序（Windows）===" -ForegroundColor Cyan
Write-Host ""

# ── 第一步：安装 Skill ──────────────────────────────────────────
Write-Host "── 第一步：安装 Skill ──"
if (Test-Path $SKILL_DIR) {
    Write-Warn "Skill 已存在，更新中..."
    Push-Location $SKILL_DIR
    git pull --quiet
    Pop-Location
    Write-OK "Skill 已更新"
} else {
    git clone --quiet $SKILL_REPO $SKILL_DIR
    Write-OK "Skill 已安装到 $SKILL_DIR"
}

# ── 第二步：下载 MCP 服务 ────────────────────────────────────────
Write-Host ""
Write-Host "── 第二步：下载 MCP 服务 ──"
New-Item -ItemType Directory -Force $MCP_DIR | Out-Null

# 获取最新版本号
try {
    $release = Invoke-RestMethod "https://api.github.com/repos/$MCP_REPO/releases/latest"
    $LATEST = $release.tag_name
    Write-OK "最新版本：$LATEST"
} catch {
    Write-Fail "无法获取版本信息，请检查网络连接"
}

# 下载并解压（zip 内同时包含 mcp 主程序和 login 登录工具）
if (-not (Test-Path $MCP_BIN)) {
    $ZIP_URL  = "https://github.com/$MCP_REPO/releases/download/$LATEST/xiaohongshu-mcp-$PLATFORM.zip"
    $ZIP_FILE = "$MCP_DIR\xiaohongshu-mcp-$PLATFORM.zip"
    Write-Host "  下载 xiaohongshu-mcp-$PLATFORM.zip ..."
    Invoke-WebRequest -Uri $ZIP_URL -OutFile $ZIP_FILE -UseBasicParsing
    Expand-Archive -Path $ZIP_FILE -DestinationPath $MCP_DIR -Force
    Remove-Item $ZIP_FILE
    Write-OK "MCP 服务及登录工具下载完成"
} else {
    Write-OK "MCP 服务已存在，跳过下载"
}

if (-not (Test-Path $MCP_BIN))   { Write-Fail "MCP 服务文件未找到：$MCP_BIN" }
if (-not (Test-Path $LOGIN_BIN)) { Write-Fail "登录工具未找到：$LOGIN_BIN" }

# ── 第三步：准备目录 ──────────────────────────────────────────────
Write-Host ""
Write-Host "── 第三步：准备目录 ──"
New-Item -ItemType Directory -Force "C:\tmp" | Out-Null
Write-OK "C:\tmp 目录已就绪"

# ── 第四步：扫码登录 ──────────────────────────────────────────────
Write-Host ""
Write-Host "── 第四步：扫码登录 ──"
Write-Host "  即将打开登录窗口，请用小红书 App 扫码..."
try {
    & $LOGIN_BIN
} catch {
    Write-Warn "登录程序退出，如已扫码成功可继续"
}

# 同步 Cookies 到服务读取位置
if (Test-Path $COOKIES_SRC) {
    Copy-Item $COOKIES_SRC $COOKIES_DST -Force
    Write-OK "Cookies 已同步到 $COOKIES_DST"
} else {
    Write-Fail "未找到 Cookies 文件（$COOKIES_SRC），请确认已完成扫码登录"
}

# ── 第五步：启动 MCP 服务 ──────────────────────────────────────────
Write-Host ""
Write-Host "── 第五步：启动 MCP 服务 ──"

# 停掉旧进程（如有）
$procName = "xiaohongshu-mcp-$PLATFORM"
if (Get-Process -Name $procName -ErrorAction SilentlyContinue) {
    Stop-Process -Name $procName -Force
    Start-Sleep -Seconds 2
    Write-OK "已停止旧进程"
}

$env:XHS_COOKIES_SRC = $COOKIES_DST
Start-Process -FilePath $MCP_BIN -ArgumentList "-port", ":$MCP_PORT" -WindowStyle Hidden
Start-Sleep -Seconds 3

# 验证服务
try {
    $null = Invoke-WebRequest "http://localhost:$MCP_PORT/mcp" -UseBasicParsing -TimeoutSec 5
    Write-OK "MCP 服务运行正常（端口 $MCP_PORT）"
} catch {
    Write-Warn "服务可能未就绪，检查进程：Get-Process *xiaohongshu*"
}

# ── 完成 ──────────────────────────────────────────────────────────
Write-Host ""
Write-Host "══════════════════════════════════════" -ForegroundColor Cyan
Write-Host " OK 安装完成！" -ForegroundColor Green
Write-Host "══════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "  在 Claude Code 中直接说："
Write-Host "  「帮我分析小红书账号「张三」近30天最火的笔记」"
Write-Host ""
Write-Host "  重启服务："
Write-Host "  `$env:XHS_COOKIES_SRC='$COOKIES_DST'; Start-Process '$MCP_BIN' -ArgumentList '-port',':$MCP_PORT' -WindowStyle Hidden"
Write-Host ""
