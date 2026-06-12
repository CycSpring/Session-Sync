# Session Sync Skill

`Session Sync` 是一个给 Codex / Claude Code 使用的会话同步 Skill。

它的用途很简单：

- 把当前 Codex 会话保存成 Markdown 记忆文件
- 查看最近保存过的会话记忆
- 读取最新会话记忆
- 按文件名、时间片段、路径或 session id 片段读取指定会话记忆

会话记忆目录可以由用户自己指定。

目录优先级：

1. 运行脚本时显式传入 `-Destination` 或 `-MemoryDir`
2. 环境变量 `SESSION_SYNC_MEMORY_DIR`
3. 未配置时使用 `Documents\session-sync-memory`

## 仓库结构

```text
session-sync/
├── SKILL.md
├── agents/
│   └── openai.yaml
└── scripts/
    ├── sync_session.ps1
    └── read_session.ps1
```

说明：

- `SKILL.md`：告诉 Codex / Claude Code 什么时候使用这个 Skill，以及怎么使用。
- `sync_session.ps1`：把 Codex 本地 session JSONL 转成可读的 Markdown 会话记忆。
- `read_session.ps1`：列出或读取已经保存的 Markdown 会话记忆。

## 安装到 Codex

推荐安装到 Codex 当前通用 Skills 目录：

```powershell
New-Item -ItemType Directory -Force "$env:USERPROFILE\.agents\skills" | Out-Null
git clone https://github.com/CycSpring/Session-Sync.git "$env:USERPROFILE\.agents\skills\session-sync"
```

如果你的 Codex 环境使用的是 `.codex\skills`，则安装到：

```powershell
New-Item -ItemType Directory -Force "$env:USERPROFILE\.codex\skills" | Out-Null
git clone https://github.com/CycSpring/Session-Sync.git "$env:USERPROFILE\.codex\skills\session-sync"
```

安装后如果 Skill 没有立刻出现，重启 Codex。

Codex 中可以这样调用：

```text
$session-sync
```

也可以直接说：

```text
/会话同步
会话同步
同步当前会话
读取最近会话
从 memory-session 恢复上下文
```

## 安装到 Claude Code

个人级安装：

```powershell
New-Item -ItemType Directory -Force "$env:USERPROFILE\.claude\skills" | Out-Null
git clone https://github.com/CycSpring/Session-Sync.git "$env:USERPROFILE\.claude\skills\session-sync"
```

项目级安装，在项目根目录执行：

```powershell
New-Item -ItemType Directory -Force ".claude\skills" | Out-Null
git clone https://github.com/CycSpring/Session-Sync.git ".claude\skills\session-sync"
```

Claude Code 中可以这样调用：

```text
/session-sync
```

也可以直接说：

```text
保存当前会话
读取最新会话记忆
加载 20260612-163002 这个会话
```

## 手动运行脚本

正常情况下，Codex / Claude Code 会根据 `SKILL.md` 自动选择脚本。你也可以手动运行。

### 配置记忆目录

推荐设置环境变量，这样保存和读取都会使用同一个目录：

**这里推荐使用 Obsidian 云同步、坚果云或其他云同步工具里的某个目录**，这样不同电脑上的 Codex / Claude Code 都可以读写同一份会话记忆。

示例：

```powershell
$env:SESSION_SYNC_MEMORY_DIR = "D:\Notes\memory-session"
```

如果想长期生效，可以设置为用户环境变量：

```powershell
[Environment]::SetEnvironmentVariable("SESSION_SYNC_MEMORY_DIR", "D:\Notes\memory-session", "User")
```

也可以每次运行脚本时显式指定目录：

```powershell
-Destination "D:\Notes\memory-session"
-MemoryDir "D:\Notes\memory-session"
```

先把 `$SkillDir` 设置成实际安装目录：

```powershell
$SkillDir = "$env:USERPROFILE\.agents\skills\session-sync"  # Codex 当前推荐位置
# $SkillDir = "$env:USERPROFILE\.codex\skills\session-sync" # Codex 本地旧位置
# $SkillDir = "$env:USERPROFILE\.claude\skills\session-sync" # Claude Code 个人位置
```

保存最近的 Codex 本地会话：

```powershell
$shell = if (Get-Command pwsh -ErrorAction SilentlyContinue) { 'pwsh' } else { 'powershell' }
& $shell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $SkillDir "scripts\sync_session.ps1")
```

保存到指定记忆目录：

```powershell
$shell = if (Get-Command pwsh -ErrorAction SilentlyContinue) { 'pwsh' } else { 'powershell' }
& $shell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $SkillDir "scripts\sync_session.ps1") -Destination "D:\Notes\memory-session"
```

保存指定的 Codex session JSONL：

```powershell
$shell = if (Get-Command pwsh -ErrorAction SilentlyContinue) { 'pwsh' } else { 'powershell' }
& $shell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $SkillDir "scripts\sync_session.ps1") -SessionFile "C:\Users\you\.codex\sessions\YYYY\MM\DD\rollout-....jsonl"
```

列出最近保存的会话记忆：

```powershell
$shell = if (Get-Command pwsh -ErrorAction SilentlyContinue) { 'pwsh' } else { 'powershell' }
& $shell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $SkillDir "scripts\read_session.ps1") -List -RecentCount 5
```

读取最新会话记忆：

```powershell
$shell = if (Get-Command pwsh -ErrorAction SilentlyContinue) { 'pwsh' } else { 'powershell' }
& $shell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $SkillDir "scripts\read_session.ps1") -Latest
```

从指定记忆目录读取最新会话：

```powershell
$shell = if (Get-Command pwsh -ErrorAction SilentlyContinue) { 'pwsh' } else { 'powershell' }
& $shell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $SkillDir "scripts\read_session.ps1") -MemoryDir "D:\Notes\memory-session" -Latest
```

读取指定会话记忆：

```powershell
$shell = if (Get-Command pwsh -ErrorAction SilentlyContinue) { 'pwsh' } else { 'powershell' }
& $shell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $SkillDir "scripts\read_session.ps1") -Session "20260612-163002"
```

## 注意事项

- 脚本兼容 Windows PowerShell 5.1，也支持 `pwsh`。
- 记忆目录不是固定路径，建议通过 `SESSION_SYNC_MEMORY_DIR` 或脚本参数指定。
- `read_session.ps1` 默认只把 `# Codex Session Sync` 开头的 Markdown 文件当作会话记忆。
- 如果想列出记忆目录里的所有 Markdown 文件，可以给 `read_session.ps1` 加 `-AllMarkdown`。
- 会话记忆是上下文恢复辅助，不是当前事实来源。真正改文件或操作仓库前，仍然要检查当前文件和 Git 状态。

## 更新

如果是通过 `git clone` 安装的，可以进入安装目录拉取更新：

```powershell
git -C "$env:USERPROFILE\.agents\skills\session-sync" pull
```

如果你安装在 `.codex\skills` 或 `.claude\skills`，把命令里的路径替换成对应安装目录。

## 参考

- [Codex Agent Skills](https://developers.openai.com/codex/skills)
- [Claude Code Skills](https://code.claude.com/docs/en/skills)
