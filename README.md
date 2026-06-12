# Session Sync Skill

Session Sync is an agent skill for saving and reading Codex/Claude Code session memory.

It can:

- save the current session as a Markdown note
- list recent saved session notes
- read the latest saved session note
- read a specific saved session by filename, timestamp, path, or session id fragment

Default memory folder:

```text
D:\Notes\文档-公司\Markdown文档\memory-session
```

## What Is In This Repo

```text
session-sync/
├── SKILL.md
├── agents/
│   └── openai.yaml
└── scripts/
    ├── sync_session.ps1
    └── read_session.ps1
```

`SKILL.md` tells the agent when and how to use the skill.

`sync_session.ps1` saves a Codex session JSONL file into a readable Markdown note.

`read_session.ps1` lists or reads saved Markdown session notes.

## Install For Codex

Use one of these locations.

For current Codex skill discovery, install to:

```powershell
New-Item -ItemType Directory -Force "$env:USERPROFILE\.agents\skills" | Out-Null
git clone https://github.com/CycSpring/Session-Sync.git "$env:USERPROFILE\.agents\skills\session-sync"
```

If your Codex setup already uses `.codex\skills`, install to:

```powershell
New-Item -ItemType Directory -Force "$env:USERPROFILE\.codex\skills" | Out-Null
git clone https://github.com/CycSpring/Session-Sync.git "$env:USERPROFILE\.codex\skills\session-sync"
```

Restart Codex if the skill does not appear immediately.

Then invoke it with:

```text
$session-sync
```

Natural language triggers also work, for example:

```text
/会话同步
会话同步
同步当前会话
读取最近会话
从 memory-session 恢复上下文
```

## Install For Claude Code

Personal install:

```powershell
New-Item -ItemType Directory -Force "$env:USERPROFILE\.claude\skills" | Out-Null
git clone https://github.com/CycSpring/Session-Sync.git "$env:USERPROFILE\.claude\skills\session-sync"
```

Project install:

```powershell
New-Item -ItemType Directory -Force ".claude\skills" | Out-Null
git clone https://github.com/CycSpring/Session-Sync.git ".claude\skills\session-sync"
```

Claude Code can invoke the skill directly with:

```text
/session-sync
```

You can also ask in natural language:

```text
save this session to memory-session
read the latest session memory
load the session from 20260612-163002
```

## Direct Script Usage

The skill normally runs these scripts for you. You can also run them manually.

Set `SkillDir` to wherever you cloned the skill:

```powershell
$SkillDir = "$env:USERPROFILE\.agents\skills\session-sync"  # Codex current default
# $SkillDir = "$env:USERPROFILE\.codex\skills\session-sync" # Codex legacy/local setup
# $SkillDir = "$env:USERPROFILE\.claude\skills\session-sync" # Claude Code personal setup
```

Save the latest local Codex session:

```powershell
$shell = if (Get-Command pwsh -ErrorAction SilentlyContinue) { 'pwsh' } else { 'powershell' }
& $shell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $SkillDir "scripts\sync_session.ps1")
```

Save a specific Codex session JSONL:

```powershell
$shell = if (Get-Command pwsh -ErrorAction SilentlyContinue) { 'pwsh' } else { 'powershell' }
& $shell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $SkillDir "scripts\sync_session.ps1") -SessionFile "C:\Users\you\.codex\sessions\YYYY\MM\DD\rollout-....jsonl"
```

List recent saved session notes:

```powershell
$shell = if (Get-Command pwsh -ErrorAction SilentlyContinue) { 'pwsh' } else { 'powershell' }
& $shell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $SkillDir "scripts\read_session.ps1") -List -RecentCount 5
```

Read the latest saved session note:

```powershell
$shell = if (Get-Command pwsh -ErrorAction SilentlyContinue) { 'pwsh' } else { 'powershell' }
& $shell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $SkillDir "scripts\read_session.ps1") -Latest
```

Read a specified saved session note:

```powershell
$shell = if (Get-Command pwsh -ErrorAction SilentlyContinue) { 'pwsh' } else { 'powershell' }
& $shell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $SkillDir "scripts\read_session.ps1") -Session "20260612-163002"
```

## Notes

- The scripts are Windows PowerShell compatible and also work with `pwsh`.
- `read_session.ps1` treats files starting with `# Codex Session Sync` as session notes by default.
- Use `-AllMarkdown` with `read_session.ps1` if you want to list every Markdown file in the memory folder.
- The saved notes are context recovery aids. Verify current files and repository state before making changes based on old notes.

## Update

For a cloned install:

```powershell
git -C "$env:USERPROFILE\.codex\skills\session-sync" pull
```

Use the matching install path if you installed under `.agents\skills` or `.claude\skills`.

## References

- [Codex Agent Skills](https://developers.openai.com/codex/skills)
- [Claude Code Skills](https://code.claude.com/docs/en/skills)
