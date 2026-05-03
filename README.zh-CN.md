<p align="center">
  <img src="docs/images/cover.jpeg" alt="claude-code-statusline" width="100%">
</p>

# ◆ claude-code-statusline

[English](README.md) | [繁體中文](README.zh-TW.md) | **简体中文**

为 [Claude Code](https://docs.anthropic.com/en/docs/claude-code)（Anthropic 的 CLI 工具）打造的实时状态列：在保留**渐变进度条**与**用量配色**的同时，展示 **Plan [Pro/Max]**、**提示缓存命中率**、**会话 In/Out token**、**带重置时间的速率限制**、**仓库 (分支)** 与 **`git_worktree`** 等来自官方 JSON 的字段（与 [statusline 文档](https://code.claude.com/docs/en/statusline) 一致）。

- **macOS / Linux**：使用 [statusline.sh](statusline.sh)（Bash）与旁路文件 [statusline.jq](statusline.jq)（`jq` 从文件读取，便于维护）。
- **Windows**：使用 [statusline.ps1](statusline.ps1)（PowerShell 5.1+），同样依赖同目录下的 `statusline.jq` 与可执行文件 `jq`。

## 预览

与 [README.md](README.md) 中相同的示意图片适用于本主题：正常 / 警告 / 危险 / 启动态。

## 功能（摘要）

| 功能 | 说明 |
|------|------|
| **渐变进度条** | 真彩色或 ANSI/ASCII 回退，与 `used_percentage` 联动。 |
| **Plan** | 由 `model.id` 粗判 `[Pro]` 或 `[Max]`。 |
| **提示缓存** | 使用 `current_usage` 计算缓存读取占比（越高越好配色）。 |
| **会话 Token** | `total_input_tokens` / `total_output_tokens`（约 k 展示）。 |
| **速率限制** | `five_hour` / `seven_day` 用量百分比；若存在 `resets_at` 则显示本地重置时间。 |
| **Git** | 仓库目录名、`分支`、脏标记 `*`（缓存约 5 秒）；可选 `workspace.git_worktree`。 |
| **其余** | 费用、时长、`+/-` 行数、Agent / worktree 指示器等与 Bash 版一致。 |

## Windows 安装与配置

### 前置条件

- 已安装 [Claude Code](https://docs.anthropic.com/en/docs/claude-code)。
- [jq](https://jqlang.org/)：例如 `winget install jqlang.jq`，或 [Chocolatey](https://chocolatey.org/) / [Scoop](https://scoop.sh/) 安装，确保 `jq` 在 **PATH** 中。
- （可选）Git for Windows，以便显示分支与仓库名。

### 手动安装

1. 将以下两个文件复制到同一目录（例如 `%USERPROFILE%\.claude\`）：

   - `statusline.ps1`
   - `statusline.jq`（**必须与 `statusline.ps1` 同目录**，脚本通过 `$PSScriptRoot` 查找）

2. 编辑 **`%USERPROFILE%\.claude\settings.json`**，加入或合并 `statusLine`（路径请改成你的实际 `.ps1` 绝对路径）：

```json
{
  "statusLine": {
    "type": "command",
    "command": "powershell.exe -NoProfile -ExecutionPolicy Bypass -File \"C:\\Users\\你的用户名\\.claude\\statusline.ps1\"",
    "timeout": 10
  }
}
```

若执行策略仍拦截，可对**当前用户**放宽脚本策略（管理员 PowerShell 可选）：

```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

重启 Claude Code。首次对话后状态列会出现。

### Windows 环境变量

可在「用户环境变量」或启动 Claude Code 前的会话中设置：

| 变量 | 默认 | 说明 |
|------|------|------|
| `CLAUDE_STATUSLINE_ASCII` | `0` | 设为 `1` 使用纯 ASCII 进度条。 |
| `CLAUDE_STATUSLINE_NERDFONT` | `0` | 设为 `1` 使用扩展符号（需终端字体支持）。 |
| `CLAUDE_STATUSLINE_POWERLINE` | 随 NERDFONT | 设为 `1` 使用更紧凑分隔。 |
| `COLORTERM` | （可选） | 设为 `truecolor` 或 `24bit` 时启用真彩色渐变（视终端而定）。 |

### 本地测试（PowerShell）

将下方 JSON 存为 `mock.json`（或自行替换），在项目目录执行：

```powershell
Get-Content .\mock.json -Raw | powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\statusline.ps1
```

若输出两行彩色文本且含 `Cache:`、`In:`/`Out:`、速率等字段，即表示管道与 `jq` 正常。

## macOS / Linux（简要）

与仓库根目录 [README.md](README.md) 相同：**同时复制** `statusline.sh` 与 `statusline.jq` 到 `~/.claude/`，`settings.json` 中 `command` 指向 `~/.claude/statusline.sh`。也可用 `./install.sh` 一键复制二者。

测试（需 Bash + jq）：

```bash
chmod +x examples/test-mock.sh
./examples/test-mock.sh merged
```

## 运作说明

- Claude Code 将 session 状态以 JSON 经 **stdin** 写入脚本；脚本将解析结果格式化为 **一至两行** ANSI 文本写出。
- 解析逻辑集中在 **`statusline.jq`**，Bash 与 PowerShell 共用，避免两套字段漂移。
- Git 状态缓存在 **临时目录**（Unix：`$TMPDIR`/`/tmp`/`$TEMP`；Windows：`%TEMP%\claude-statusline-git-cache`），避免每次刷新都扫描仓库。

## 授权

MIT — 见 [LICENSE](LICENSE)。

## 致谢

灵感来自[官方 statusline 文档](https://code.claude.com/docs/en/statusline)及社群实现。
