#!/bin/bash
# 小红书 Skill 一键安装脚本（macOS / Linux）
# 用法：bash <(curl -fsSL https://raw.githubusercontent.com/bahunag/xiaohongshu-skill/main/install.sh)

set -e

SKILL_DIR="$HOME/.claude/skills/xiaohongshu"
MCP_DIR="$HOME/xiaohongshu-mcp"
MCP_PORT=18060

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
  cd "$SKILL_DIR" && git pull
else
  git clone https://github.com/bahunag/xiaohongshu-skill.git "$SKILL_DIR"
  info "Skill 已安装到 $SKILL_DIR"
fi

# ── 第二步：检查 MCP 服务 ────────────────────────────────────────
echo ""
echo "── 第二步：检查 MCP 服务 ──"
MCP_BIN="$MCP_DIR/xiaohongshu-mcp-$PLATFORM"
LOGIN_BIN="$MCP_DIR/xiaohongshu-login-$PLATFORM"

if [ -f "$MCP_BIN" ]; then
  info "MCP 服务已存在：$MCP_BIN"
else
  warn "未找到 MCP 服务二进制文件"
  echo ""
  echo "  请手动下载以下两个文件，放到 $MCP_DIR/ 目录："
  echo "    - xiaohongshu-mcp-$PLATFORM"
  echo "    - xiaohongshu-login-$PLATFORM"
  echo ""
  echo "  下载后运行以下命令完成安装："
  echo "    mkdir -p $MCP_DIR"
  echo "    chmod +x $MCP_BIN $LOGIN_BIN"
  echo "    $LOGIN_BIN        # 扫码登录"
  echo "    XHS_COOKIES_SRC=/tmp/cookies.json nohup $MCP_BIN -port :$MCP_PORT > /tmp/xhs-mcp.log 2>&1 &"
  echo ""
  info "Skill 文件已就绪，等待你手动放入 MCP 二进制后即可使用"
  exit 0
fi

# ── 第三步：赋权 ─────────────────────────────────────────────────
echo ""
echo "── 第三步：设置权限 ──"
chmod +x "$MCP_BIN" 2>/dev/null && info "MCP 服务已赋权"
[ -f "$LOGIN_BIN" ] && chmod +x "$LOGIN_BIN" 2>/dev/null && info "登录工具已赋权"

# ── macOS 安全提示 ────────────────────────────────────────────────
if [ "$OS" = "Darwin" ]; then
  echo ""
  warn "macOS 安全提示：首次运行可能被拦截"
  echo "  如遇弹窗，请前往：系统设置 → 隐私与安全性 → 仍要打开"
fi

# ── 第四步：登录 ─────────────────────────────────────────────────
echo ""
echo "── 第四步：扫码登录 ──"
if [ -f "$LOGIN_BIN" ]; then
  echo "  即将打开登录窗口，请用小红书 App 扫码..."
  "$LOGIN_BIN" || warn "登录程序退出，如已扫码成功可继续"
  info "登录完成，Cookies 已保存到 /tmp/cookies.json"
else
  warn "未找到登录工具 $LOGIN_BIN，跳过登录步骤"
fi

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
echo "═══════════════════════════════════"
echo " 安装完成！"
echo "═══════════════════════════════════"
echo ""
echo "  在 Claude Code 中直接说："
echo "  「帮我分析小红书账号「张三」近30天最火的笔记」"
echo ""
