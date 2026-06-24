---
name: session-sync
description: >-
  Sync Codex conversations into a user-configured Markdown memory root and read them back, with optional scoped memory folders. Use when the user says "/会话同步", "会话同步", "同步当前会话", "同步会话到work", "同步会话到home", "work会话同步", "home会话同步", "公司记忆保存", "个人记忆保存", asks to copy/save the current session, asks to list/read recent memory sessions, asks to load a specified synced session, or wants completed nodes, decisions, commands, and artifacts written to or read from memory-session. Important routing: "work" and "home" are memory scopes under the configured memory root, not workspace folders. Without explicit work/home/global scope, save to global root and read across all scopes.
---

# Session Sync

## Purpose

Sync Codex sessions with Markdown notes in a user-configurable memory directory.

Directory resolution order:

1. explicit `-Destination` or `-MemoryDir` script argument
2. `SESSION_SYNC_MEMORY_DIR` environment variable
3. no implicit fallback; ask the user to choose a memory directory, then run `scripts/configure_memory_dir.ps1`

Memory scopes:

- `global`: Markdown files directly under the memory directory
- `work`: Markdown files under `memory-session\work`
- `home`: Markdown files under `memory-session\home`

When the user prefixes a request with `work:` or says company/work memory, pass `-Scope work`. When the user prefixes a request with `home:` or says home/personal/local memory, pass `-Scope home`. Without an explicit scope, save as `global`; read/list across all scopes. Never interpret `work` or `home` as a relative folder in the current workspace for this skill.

The skill has two directions:

- save the current Codex session into a timestamped Markdown note
- list or read existing memory notes so a later session can recover context

## Save Workflow

1. Treat `/会话同步` and `会话同步` as an explicit request to run this skill.
2. Before the first save, if neither `SESSION_SYNC_MEMORY_DIR` nor an explicit destination is available, ask the user for the memory directory and run `scripts/configure_memory_dir.ps1 -MemoryDir <path>`.
3. Run `scripts/sync_session.ps1` from this skill directory. Use `pwsh` when available, otherwise use Windows PowerShell `powershell`. Pass `-Destination` when the user gives a one-off memory path. Pass `-Scope work` or `-Scope home` when the user explicitly chooses that scope.
4. If the script cannot identify the current session exactly, it should use the most recently modified Codex session JSONL file.
5. After the script writes the Markdown file, report the saved path to the user.
6. If the current turn contains very recent work that has not yet appeared in the session JSONL, append a short note in the final response so the user knows what may be missing.

## Read Workflow

Use this when the user asks to read, load, review, recover, or continue from synced memory sessions.

1. Run `scripts/read_session.ps1` from this skill directory. Pass `-MemoryDir` when the user gives a memory path. Pass `-Scope work`, `-Scope home`, or `-Scope global` only when the user explicitly narrows the scope; otherwise leave default `all`.
2. If neither `SESSION_SYNC_MEMORY_DIR` nor an explicit memory directory is available, ask the user for the memory directory and run `scripts/configure_memory_dir.ps1 -MemoryDir <path>`.
3. If the user asks for recent sessions, list recent files first.
4. If the user asks for the latest session, read the latest Markdown note.
5. If the user gives a filename, path, timestamp, or session id fragment, pass it as `-Session`.
6. Summarize the recovered context and mention the source file path.

## Scripts

Configure the memory directory:

```powershell
$shell = if (Get-Command pwsh -ErrorAction SilentlyContinue) { 'pwsh' } else { 'powershell' }
& $shell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\session-sync\scripts\configure_memory_dir.ps1"
```

Run the default sync:

```powershell
$shell = if (Get-Command pwsh -ErrorAction SilentlyContinue) { 'pwsh' } else { 'powershell' }
& $shell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\session-sync\scripts\sync_session.ps1"
```

Run with an explicit memory directory:

```powershell
$shell = if (Get-Command pwsh -ErrorAction SilentlyContinue) { 'pwsh' } else { 'powershell' }
& $shell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\session-sync\scripts\sync_session.ps1" -Destination "D:\Notes\memory-session"
```

Save to work or home scoped memory:

```powershell
$shell = if (Get-Command pwsh -ErrorAction SilentlyContinue) { 'pwsh' } else { 'powershell' }
& $shell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\session-sync\scripts\sync_session.ps1" -Scope work
& $shell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\session-sync\scripts\sync_session.ps1" -Scope home
```

Run with an explicit session file:

```powershell
$shell = if (Get-Command pwsh -ErrorAction SilentlyContinue) { 'pwsh' } else { 'powershell' }
& $shell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\session-sync\scripts\sync_session.ps1" -SessionFile "$env:USERPROFILE\.codex\sessions\YYYY\MM\DD\rollout-....jsonl"
```

The script prints the Markdown output path on success.

List recent synced sessions:

```powershell
$shell = if (Get-Command pwsh -ErrorAction SilentlyContinue) { 'pwsh' } else { 'powershell' }
& $shell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\session-sync\scripts\read_session.ps1" -List -RecentCount 5
```

List or read a specific scope:

```powershell
$shell = if (Get-Command pwsh -ErrorAction SilentlyContinue) { 'pwsh' } else { 'powershell' }
& $shell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\session-sync\scripts\read_session.ps1" -Scope work -List
& $shell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\session-sync\scripts\read_session.ps1" -Scope home -Latest
```

Read the latest synced session:

```powershell
$shell = if (Get-Command pwsh -ErrorAction SilentlyContinue) { 'pwsh' } else { 'powershell' }
& $shell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\session-sync\scripts\read_session.ps1" -Latest
```

Read from an explicit memory directory:

```powershell
$shell = if (Get-Command pwsh -ErrorAction SilentlyContinue) { 'pwsh' } else { 'powershell' }
& $shell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\session-sync\scripts\read_session.ps1" -MemoryDir "D:\Notes\memory-session" -Latest
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
