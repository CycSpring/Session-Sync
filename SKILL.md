---
name: session-sync
description: Sync Codex conversations with a Markdown memory folder. Use when the user says "/会话同步", "会话同步", "同步当前会话", asks to copy/save the current session, asks to list/read recent memory sessions, asks to load a specified synced session, or wants completed nodes, decisions, commands, and artifacts written to or read from D:\Notes\文档-公司\Markdown文档\memory-session.
---

# Session Sync

## Purpose

Sync Codex sessions with Markdown notes under:

`D:\Notes\文档-公司\Markdown文档\memory-session`

The skill has two directions:

- save the current Codex session into a timestamped Markdown note
- list or read existing memory notes so a later session can recover context

## Save Workflow

1. Treat `/会话同步` and `会话同步` as an explicit request to run this skill.
2. Run `scripts/sync_session.ps1` from this skill directory. Use `pwsh` when available, otherwise use Windows PowerShell `powershell`. Use the default destination unless the user gives another path.
3. If the script cannot identify the current session exactly, it should use the most recently modified Codex session JSONL file.
4. After the script writes the Markdown file, report the saved path to the user.
5. If the current turn contains very recent work that has not yet appeared in the session JSONL, append a short note in the final response so the user knows what may be missing.

## Read Workflow

Use this when the user asks to read, load, review, recover, or continue from synced memory sessions.

1. Run `scripts/read_session.ps1` from this skill directory.
2. If the user asks for recent sessions, list recent files first.
3. If the user asks for the latest session, read the latest Markdown note.
4. If the user gives a filename, path, timestamp, or session id fragment, pass it as `-Session`.
5. Summarize the recovered context and mention the source file path.

## Scripts

Run the default sync:

```powershell
$shell = if (Get-Command pwsh -ErrorAction SilentlyContinue) { 'pwsh' } else { 'powershell' }
& $shell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\session-sync\scripts\sync_session.ps1"
```

Run with an explicit session file:

```powershell
$shell = if (Get-Command pwsh -ErrorAction SilentlyContinue) { 'pwsh' } else { 'powershell' }
& $shell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\session-sync\scripts\sync_session.ps1" -SessionFile "C:\Users\SpringChen\.codex\sessions\YYYY\MM\DD\rollout-....jsonl"
```

The script prints the Markdown output path on success.

List recent synced sessions:

```powershell
$shell = if (Get-Command pwsh -ErrorAction SilentlyContinue) { 'pwsh' } else { 'powershell' }
& $shell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\session-sync\scripts\read_session.ps1" -List -RecentCount 5
```

Read the latest synced session:

```powershell
$shell = if (Get-Command pwsh -ErrorAction SilentlyContinue) { 'pwsh' } else { 'powershell' }
& $shell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\session-sync\scripts\read_session.ps1" -Latest
```

Read a specified synced session:

```powershell
$shell = if (Get-Command pwsh -ErrorAction SilentlyContinue) { 'pwsh' } else { 'powershell' }
& $shell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\session-sync\scripts\read_session.ps1" -Session "20260612-161943"
```

## Output Expectations

The generated note should include:

- session metadata: id, timestamp, cwd, source file
- completed nodes inferred from successful tool calls and assistant updates
- important decisions and durable instructions visible in the session
- conversation transcript with user and assistant messages
- tool calls and command outputs, truncated to keep the note readable

Do not delete or overwrite older memory notes. Create a timestamped Markdown file for each save.

When reading memory notes, do not assume the note is complete truth. Treat it as recovered context, then verify files or current state before making changes.
