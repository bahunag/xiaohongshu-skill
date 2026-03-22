---
name: xiaohongshu
version: 1.1.0
description: |
  当用户需要与小红书平台交互时使用此技能。包括搜索笔记、分析竞品账号、追踪热点话题、获取用户主页和笔记详情、发表评论、点赞收藏、发布图文或视频笔记、导出笔记为长图、将收藏笔记转为 AI 知识库等功能。当用户说"帮我分析XX账号近30天的笔记"、"搜小红书上关于XX的热门内容"、"给我生成XX话题的热点报告"、"帮我发布一篇小红书"、"把这篇笔记导出成长图"、"查看小红书上XX的互动数据"、"帮我在小红书上点赞"或"获取小红书用户信息"时触发此技能。
---

# 小红书 Skill

基于 `xiaohongshu-mcp`，支持 Windows、macOS、Linux 三平台，完整覆盖读取、写入和分析功能。

---

## 第零步：检测操作系统

**每次会话开始时**，先检测当前平台，后续步骤按对应平台执行：

```python
import platform
print(platform.system())   # Windows | Darwin | Linux
import struct
print(struct.calcsize("P") * 8)  # 位数：64 | 32
```

macOS 还需区分芯片：
```bash
uname -m   # arm64 = Apple Silicon (M1/M2/M3)，x86_64 = Intel
```

---

## 第一步：安装 MCP 服务

根据系统下载��应二进制，放到任意固定目录：

| 系统 | 二进制文件名 |
|------|-------------|
| Windows (x64) | `xiaohongshu-mcp-windows-amd64.exe` |
| macOS Apple Silicon (M1/M2/M3) | `xiaohongshu-mcp-darwin-arm64` |
| macOS Intel | `xiaohongshu-mcp-darwin-amd64` |
| Linux (x64) | `xiaohongshu-mcp-linux-amd64` |

下载地址：https://github.com/sanshao85/xiaohongshu-mcp/releases

**macOS / Linux 需要赋予执行权限：**
```bash
chmod +x ./xiaohongshu-mcp-darwin-arm64   # 替换为你的文件名
```

**macOS 首次运行可能触发安全提示**，在「系统设置 → 隐私与安全性」里点「仍要打开」。

---

## 第二步：首次登录

运行同目录下的登录工具完成扫码：

| 系统 | 登录工具文件名 |
|------|--------------|
| Windows | `xiaohongshu-login-windows-amd64.exe` |
| macOS Apple Silicon | `xiaohongshu-login-darwin-arm64` |
| macOS Intel | `xiaohongshu-login-darwin-amd64` |
| Linux | `xiaohongshu-login-linux-amd64` |

登录后 Cookies 保存位置：

| 系统 | Cookies 路径 |
|------|-------------|
| Windows | `C:\Users\<用户名>\AppData\Local\Temp\cookies.json` |
| macOS / Linux | `/tmp/cookies.json` |

**Windows 需要额外同步一步**（macOS/Linux 跳过）：
```powershell
# 将 cookies 复制到服务读取位置
Copy-Item "$env:LOCALAPPDATA\Temp\cookies.json" "C:\tmp\cookies.json" -Force
```
> Windows 上请确保 `C:\tmp\` 目录存在：`New-Item -ItemType Directory -Force C:\tmp`

---

## 第三步：启动 MCP 服务

### Windows

```powershell
$env:XHS_COOKIES_SRC = "C:\tmp\cookies.json"
Start-Process -NoNewWindow "C:\path\to\xiaohongshu-mcp-windows-amd64.exe" -ArgumentList "-port", ":18060"
```

### macOS / Linux

```bash
XHS_COOKIES_SRC=/tmp/cookies.json nohup ./xiaohongshu-mcp-darwin-arm64 -port :18060 > /tmp/xhs-mcp.log 2>&1 &
echo "服务已启动，PID: $!"
```

等待 3 秒后继续。

---

## 第四步：确认服务运行状态

每次会话开始时检查（三平台通用）：

```bash
python -c "import urllib.request; urllib.request.urlopen('http://localhost:18060/mcp'); print('运行中')" 2>/dev/null || echo "未运行"
```

若未运行，按第三步重新启动。

**停止服务：**

```bash
# macOS / Linux
pkill -f xiaohongshu-mcp

# Windows (PowerShell)
# taskkill /F /IM xiaohongshu-mcp-windows-amd64.exe
```

---

## 调用工具：Python MCP 客户端

所有工具调用使用以下 Python 函数模式。将脚本写入临时文件后执行。

```python
import urllib.request, json, sys, io

# Windows 需要这行；macOS/Linux 可省略
if sys.platform == "win32":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

MCP_URL = "http://localhost:18060/mcp"

def mcp_call(tool_name, arguments={}):
    headers = {
        "Content-Type": "application/json",
        "Accept": "application/json, text/event-stream"
    }

    def post(data, extra_headers={}):
        h = {**headers, **extra_headers}
        req = urllib.request.Request(MCP_URL, json.dumps(data).encode(), h)
        with urllib.request.urlopen(req, timeout=120) as r:
            return r.read().decode(), dict(r.headers)

    # Initialize
    _, resp_headers = post({"jsonrpc":"2.0","id":1,"method":"initialize",
        "params":{"protocolVersion":"2024-11-05","capabilities":{},
                  "clientInfo":{"name":"claude","version":"1.0"}}})
    session_id = resp_headers.get("Mcp-Session-Id","")
    if not session_id:
        print("ERROR: MCP 服务未响应，请先启动服务")
        sys.exit(1)

    sh = {"Mcp-Session-Id": session_id}

    # Initialized notification
    post({"jsonrpc":"2.0","method":"notifications/initialized"}, sh)

    # Call tool
    result, _ = post({"jsonrpc":"2.0","id":2,"method":"tools/call",
        "params":{"name": tool_name, "arguments": arguments}}, sh)

    data = json.loads(result)
    if "result" in data and "content" in data["result"]:
        for item in data["result"]["content"]:
            if item.get("type") == "text":
                try:
                    print(json.dumps(json.loads(item["text"]), ensure_ascii=False, indent=2))
                except:
                    print(item["text"])
    else:
        print(json.dumps(data, ensure_ascii=False, indent=2))

# 调用示例（修改下面两行）：
mcp_call("check_login_status")
```

---

## 工具清单

### 1. check_login_status — 检查登录状态

```python
mcp_call("check_login_status")
```

Returns login status. If not logged in, call `get_login_qrcode` to re-authenticate.

---

### 2. get_login_qrcode — 获取登录二维码

```python
mcp_call("get_login_qrcode")
```

Returns a Base64-encoded PNG QR code. Decode and save the Base64 content as an image file, then scan with the Xiaohongshu app to log in.

---

### 3. search_feeds — 搜索笔记

```python
mcp_call("search_feeds", {
    "keyword": "AI工具",
    "filters": {
        "sort_by": "最多点赞",      # 综合 | 最新 | 最多点赞 | 最多评论 | 最多收藏
        "note_type": "不限",        # 不限 | 视频 | 图文
        "publish_time": "一个月内"   # 不限 | 一天内 | 一周内 | 半年内
    }
})
```

返回笔记列表，每项含：
- `id` → 后续操作的 `feed_id`
- `xsecToken` → 后续操作的 `xsec_token`
- `noteCard.title`：标题
- `noteCard.user.userId`：作者 userId
- `noteCard.interactInfo`：点赞数等

> **关键**：`id` 和 `xsecToken` 必须配对使用，保存好。

---

### 4. list_feeds — 获取首页推荐

```python
mcp_call("list_feeds")
```

---

### 5. user_profile — 获取用户主页

```python
mcp_call("user_profile", {
    "user_id": "从 noteCard.user.userId 获取",
    "xsec_token": "对应的 xsecToken"
})
```

返回：粉丝数、获赞数、笔记列表（每项含 id 和 xsecToken）。

---

### 6. get_feed_detail — 获取笔记详情

```python
mcp_call("get_feed_detail", {
    "feed_id": "笔记 id",
    "xsec_token": "对应 xsecToken",
    "load_all_comments": False,   # True 则滚动加载全部评论
    "limit": 20
})
```

返回：完整正文、图片列表、**精确**点赞数/收藏数/评论数、评论列表。

---

### 7. post_comment_to_feed — 发表评论 🔒 待开发

> ⚠️ 此功能尚未开放，请勿调用。

---

### 8. reply_comment_in_feed — 回复评论 🔒 待开发

> ⚠️ 此功能尚未开放，请勿调用。

---

### 9. like_feed — 点赞 / 取消点赞 🔒 待开发

> ⚠️ 此功能尚未开放，请勿调用。

---

### 10. favorite_feed — 收藏 / 取消收藏 🔒 待开发

> ⚠️ 此功能尚未开放，请勿调用。

---

### 11. publish_content — 发布图文笔记 🔒 待开发

> ⚠️ 此功能尚未开放，请勿调用。

---

### 12. publish_with_video — 发布视频笔记 🔒 待开发

> ⚠️ 此功能尚未开放，请勿调用。

---

### 13. delete_cookies — 清除登录状态

```python
mcp_call("delete_cookies")
```

---

## 复合工作流

### 竞品账号分析

用户要求「分析 XX 账号近N天互动最好的N篇」时，执行以下流程：

1. `search_feeds` 搜账号名 → 找到目标用户，取其 `userId` + `xsecToken`
2. `user_profile` 获取主页 → 拿到所有笔记列表（含 `id` 和 `xsecToken`）
3. 对每篇笔记 `get_feed_detail` → 获取精确互动数字和发布时间
4. 过滤指定天数内的笔记，按点赞数降序排列
5. 输出标准报告：

```markdown
## 账号分析：<账号名>
> 分析时间：<日期>  范围：近<N>天

### 账号概况
- 粉丝：XX  |  获赞与收藏：XX

### 互动 Top N

| # | 标题 | 点赞 | 收藏 | 评论 | 赞藏比 | 发布时间 |
|---|------|------|------|------|--------|---------|
| 1 | ...  | ...  | ...  | ...  | 1:0.X  | X天前   |

### 内容规律
（选题类型 / 标题结构 / 发布节奏 / 爆款共性）
```

---

### 热点话题追踪报告

1. `search_feeds` 搜关键词，`sort_by: 最多点赞`，`publish_time: 一周内`
2. 提取 Top 10-20 笔记基础数据
3. 对排名前 5 的笔记 `get_feed_detail`，提取正文摘要 + 热门评论
4. 生成报告：

```markdown
# 小红书话题报告：<话题>
> 采集时间：<日期>  采集数量：<N>篇

## 概览
- 总互动量：XX  |  平均点赞：XX  |  平均收藏：XX

## 热帖 Top 5

### 1. <标题>
- **作者**：XXX  **发布**：X天前
- **数据**：点赞 XX | 收藏 XX | 评论 XX
- **摘要**：正文前100字...
- **热评**：（高频关键词）

## 评论区情绪
## 趋势判断
```

---

### 长图导出

将笔记导出为白底黑字 JPG 长图，需先安装 Pillow：

```bash
pip install Pillow
```

准备 `posts.json`（从搜索/详情结果整理）：

```json
[{
  "title": "帖子标题",
  "author": "作者名",
  "stats": "1.3万赞 100收藏",
  "desc": "正文摘要（前200字）",
  "images": ["https://图片URL"]
}]
```

执行导出脚本（三平台通用）：

```bash
python scripts/export-long-image.py --posts-file posts.json -o output.jpg
```

---

### 记忆导出（收藏→AI知识库）

将小红书收藏/点赞笔记转为可搜索的 Markdown 知识库：

1. 浏览器安装 Tampermonkey 扩展
2. 打开小红书网页版 → 进入「收藏」或「点赞」页面
3. 运行油猴��本批量提取链接，保存到 `links.md`
4. 执行批量下载和导出：

```bash
# 安装 XHS-Downloader（如尚未安装）
git clone https://github.com/JoeanAmier/XHS-Downloader.git
pip install -r XHS-Downloader/requirements.txt

# 批量下载
python XHS-Downloader/batch_download.py links.md

# 导出为 Markdown 知识库
python XHS-Downloader/export_to_workspace.py
```

---

## 注意事项

| 项目 | 说明 |
|------|------|
| Cookies 有效期 | 约30天，过期调用 `get_login_qrcode` 重新扫码 |
| 请求频率 | 单次会话建议不超过50次详情请求，避免风控 |
| 发布限制 | 标题≤20字，正文≤1000字，每日发布≤50条 |
| 账号安全 | 避免多设备同时操作同一账号 |
| MCP 服务 | 重启电脑后需重新启动服务 |
| 首次运行 | 会自动下载 headless 浏览器（约150MB），需确保网络畅通 |
| Windows Cookies | 登录后需手动将 `%LOCALAPPDATA%\Temp\cookies.json` 复制到 `C:\tmp\cookies.json` |
| macOS 安全限制 | 首次运行二进制需在「系统设置 → 隐私与安全性」手动允许 |
