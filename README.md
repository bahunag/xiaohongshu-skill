# 小红书 Skill for Claude Code

> 让 Claude 直接操作小红书——搜索笔记、分析竞品账号、追踪热点话题。

支持 **Windows / macOS / Linux** 三平台。

---

## 这是什么？

这是一个 [Claude Code](https://claude.ai/code) 的 Skill 插件，安装后你可以直接用中文告诉 Claude：

- 「帮我分析「张三」账号近30天最火的笔记」
- 「搜小红书上 AI 工具相关的热门内容」
- 「给我生成一份关于「减脂」话题的热点报告」

Claude 会自动调用后台服务完成操作，结果直接展示给你。

---

## 功能列表

| # | 功能 | 状态 |
|---|------|------|
| 1 | 检查登录状态 | ✅ 可用 |
| 2 | 扫码登录 | ✅ 可用 |
| 3 | 搜索笔记（支持按点赞/最新等排序） | ✅ 可用 |
| 4 | 获取首页推荐 | ✅ 可用 |
| 5 | 获取用户主页（粉丝数、笔记列表） | ✅ 可用 |
| 6 | 获取笔记详情（精确点赞/收藏/评论数） | ✅ 可用 |
| 7 | 清除登录状态 | ✅ 可用 |
| 8 | 发表评论 | 🔒 待开发 |
| 9 | 回复评论 | 🔒 待开发 |
| 10 | 点赞 / 取消点赞 | 🔒 待开发 |
| 11 | 收藏 / 取消收藏 | 🔒 待开发 |
| 12 | 发布图文笔记 | 🔒 待开发 |
| 13 | 发布视频笔记 | 🔒 待开发 |

**复合工作流：**
- 📊 竞品账号分析（自动找出近N天互动最好的N篇）
- 🔥 热点话题追踪报告
- 🖼️ 笔记导出为长图
- 💾 收藏笔记转为 AI 知识库

---

## 安装步骤

### macOS / Linux — 一键安装

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/bahunag/xiaohongshu-skill/main/install.sh)
```

脚本会自动完成：下载 MCP 服务 → 安装 Skill → 赋权 → 扫码登录 → 启动服务。

---

### Windows — 一键安装

在 **PowerShell** 中运行：

```powershell
irm https://raw.githubusercontent.com/bahunag/xiaohongshu-skill/main/install.ps1 | iex
```

> 如果提示执行策略受限，改用：
> ```powershell
> Set-ExecutionPolicy -Scope Process Bypass -Force; irm https://raw.githubusercontent.com/bahunag/xiaohongshu-skill/main/install.ps1 | iex
> ```

脚本会自动完成：下载 MCP 服务 → 安装 Skill → 扫码登录 → 同步 Cookies → 启动服务。

---

## 使用方式

安装完成后，在 Claude Code 中直接用中文说：

```
帮我分析小红书账号「张三」近30天发布的笔记，找出互动最好的5篇
```

```
搜小红书上关于「AI办公工具」的热门内容，按点赞数排序
```

```
给我生成一份关于「减脂饮食」话题的小红书热点报告
```

---

## 注意事项

- **Cookies 有效期约30天**，过期后重新扫码登录
- **请求频率**：单次会话建议不超过50次详情请求，避免触发风控
- **账号安全**：避免多设备同时操作同一账号
- **首次运行**：会自动下载 headless 浏览器（约150MB），需确保网络畅通
- **macOS 安全提示**：首次运行在「系统设置 → 隐私与安全性」里点「仍要打开」

---

## 技术架构

```
你（用中文说）
    ↓
Claude（理解意图，调用工具）
    ↓
小红书 Skill（操作指南）
    ↓
xiaohongshu-mcp（后台服务，端口 18060）
    ↓
小红书（获取真实数据）
```

底层由 [xiaohongshu-mcp](https://github.com/sanshao85/xiaohongshu-mcp)（go-rod 浏览器自动化）驱动。

---

## License

MIT
