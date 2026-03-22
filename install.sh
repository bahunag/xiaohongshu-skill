#!/bin/bash
# 小红书 Skill 一键安装脚本（macOS / Linux）
# 用法：bash <(curl -fsSL https://raw.githubusercontent.com/bahunag/xiaohongshu-skill/main/install.sh)

set -e

SKILL_DIR="$HOME/.claude/skills/xiaohongshu"
MCP_DIR="$HOME/xiaohongshu-mcp"
MCP_PORT=18060
MCP_REPO="xpzouying/xiaohongshu-mcp"

# 颜色
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info()  { echo -e "${GREEN}✓${NC} $1"; }
warn()  { echo -e "${YELLOW}!${NC} $1"; }
error() { echo -e "${RED}✗${NC} $1"; exit 1; }

echo ""
echo "=== 小红书 Skill 安装程序 ==="
echo ""

# 检测平台
OS=$(uname -s)
ARCH=$(uname -m)
case "$OS-$ARCH" in
  Darwin-arm64)  PLATFORM="darwin-arm64"  ;;
  Darwin-x86_64) PLATFORM="darwin-amd64"  ;;
  Linux-x86_64)  PLATFORM="linux-amd64"   ;;
  *) error "不支持的平台：$OS-$ARCH" ;;
esac
info "检测到平台：$OS $ARCH ($PLATFORM)"

# ── 第一步：安装 Skill ──────────────────────────────────────────
echo ""
echo "── 第一步：安装 Skill ──"
if [ -d "$SKILL_DIR" ]; then
  warn "Skill 已存在，更新中..."
  cd "$SKILL_DIR" && git pull --quiet
  info "Skill 已更新"
else
  git clone --quiet https://github.com/bahunag/xiaohongshu-skill.git "$SKILL_DIR"
  info "Skill 已安装到 $SKILL_DIR"
fi

# ── 第二步：下载 MCP 服务 ────────────────────────────────────────
echo ""
echo "── 第二步：下载 MCP 服务 ──"
mkdir -p "$MCP_DIR"

MCP_BIN="$MCP_DIR/xiaohongshu-mcp-$PLATFORM"
LOGIN_BIN="$MCP_DIR/xiaohongshu-login-$PLATFORM"

# 获取最新版本号
LATEST=$(curl -fsSL "https://api.github.com/repos/$MCP_REPO/releases/latest" \
  | grep '"tag_name"' | cut -d'"' -f4)
[ -z "$LATEST" ] && error "无法获取版本信息，请检查网络连接"
info "最新版本：$LATEST"

# 下载 MCP 服务（tar.gz 内同时包含 mcp 主程序和 login 登录工具）
MCP_URL="https://github.com/$MCP_REPO/releases/download/$LATEST/xiaohongshu-mcp-$PLATFORM.tar.gz"

if [ ! -f "$MCP_BIN" ]; then
  echo "  下载 xiaohongshu-mcp-$PLATFORM.tar.gz ..."
  curl -fsSL "$MCP_URL" | tar -xz -C "$MCP_DIR"
  info "MCP 服务及登录工具下载完成"
else
  info "MCP 服务已存在，跳过下载"
fi

# ── 第三步：赋权 ─────────────────────────────────────────────────
echo ""
echo "── 第三步：设置权限 ──"
chmod +x "$MCP_BIN" && info "MCP 服务已赋权"
chmod +x "$LOGIN_BIN" && info "登录工具已赋权"

# ── macOS 安全提示 ────────────────────────────────────────────────
if [ "$OS" = "Darwin" ]; then
  echo ""
  warn "macOS 安全提示：首次运行可能被系统拦截"
  echo "  如果弹出「无法打开，因为无法验证开发者」："
  echo "  → 系统设置 → 隐私与安全性 → 点「仍要打开」"
  echo "  → 或运行：xattr -d com.apple.quarantine $MCP_BIN $LOGIN_BIN"
  echo ""
  # 尝试自动去除隔离标记
  xattr -d com.apple.quarantine "$MCP_BIN" 2>/dev/null && info "已自动去除 macOS 隔离标记" || true
  xattr -d com.apple.quarantine "$LOGIN_BIN" 2>/dev/null || true
fi

# ── 第四步：扫码登录 ──────────────────────────────────────────────
echo ""
echo "── 第四步：扫码登录 ──"
echo "  即将打开登录窗口，请用小红书 App 扫码..."
"$LOGIN_BIN" || warn "登录程序退出，如已扫码成功可继续"
info "登录完成，Cookies 已保存到 /tmp/cookies.json"

# ── 第五步：启动服务 ──────────────────────────────────────────────
echo ""
echo "── 第五步：启动 MCP 服务 ──"

# 先停掉旧进程
pkill -f "xiaohongshu-mcp-$PLATFORM" 2>/dev/null || true
sleep 1

XHS_COOKIES_SRC=/tmp/cookies.json nohup "$MCP_BIN" -port :$MCP_PORT > /tmp/xhs-mcp.log 2>&1 &
sleep 3

# 验证服务
if python3 -c "import urllib.request; urllib.request.urlopen('http://localhost:$MCP_PORT/mcp', timeout=5)" 2>/dev/null; then
  info "MCP 服务运行正常（端口 $MCP_PORT）"
else
  warn "服务可能未就绪，查看日志：cat /tmp/xhs-mcp.log"
fi

# ── 完成 ──────────────────────────────────────────────────────────
echo ""
echo "══════════════════════════════════════"
echo " ✅ 安装完成！"
echo "══════════════════════════════════════"
echo ""
echo "  在 Claude Code 中直接说："
echo "  「帮我分析小红书账号「张三」近30天最火的笔记」"
echo ""
echo "  服务日志：cat /tmp/xhs-mcp.log"
echo "  重启服务：XHS_COOKIES_SRC=/tmp/cookies.json nohup $MCP_BIN -port :$MCP_PORT > /tmp/xhs-mcp.log 2>&1 &"
echo ""
