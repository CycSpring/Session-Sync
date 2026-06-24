param(
    [string]$MemoryDir,
    [string]$Session,
    [ValidateSet('all', 'global', 'work', 'home')]
    [string]$Scope = 'all',
    [switch]$Latest,
    [switch]$List,
    [switch]$AllMarkdown,
    [int]$RecentCount = 5,
    [int]$MaxChars = 30000
)

$ErrorActionPreference = 'Stop'

function Get-DefaultMemoryDir {
    $userValue = [Environment]::GetEnvironmentVariable('SESSION_SYNC_MEMORY_DIR', 'User')
    if (-not [string]::IsNullOrWhiteSpace($userValue)) {
        return $userValue
    }

    if (-not [string]::IsNullOrWhiteSpace($env:SESSION_SYNC_MEMORY_DIR)) {
        return $env:SESSION_SYNC_MEMORY_DIR
    }

    $machineValue = [Environment]::GetEnvironmentVariable('SESSION_SYNC_MEMORY_DIR', 'Machine')
    if (-not [string]::IsNullOrWhiteSpace($machineValue)) {
        return $machineValue
    }

    $configureScript = Join-Path $PSScriptRoot 'configure_memory_dir.ps1'
    throw @"
Session Sync memory directory is not configured.

Choose the memory folder before reading sessions. Either pass -MemoryDir explicitly, set SESSION_SYNC_MEMORY_DIR, or run:

powershell -NoProfile -ExecutionPolicy Bypass -File "$configureScript"
"@
}

function Limit-Text {
    param(
        [string]$Text,
        [int]$Limit
    )
    if ($null -eq $Text) {
        return ''
    }
    if ($Text.Length -le $Limit) {
        return $Text
    }
    return $Text.Substring(0, $Limit) + "`n...[truncated $($Text.Length - $Limit) chars]"
}

function Get-MemoryFiles {
    param(
        [string]$Dir,
        [string]$MemoryScope
    )
    if (-not (Test-Path -LiteralPath $Dir)) {
        throw "Memory directory not found: $Dir"
    }

    $items = @()
    $scopeDirs = @()
    if ($MemoryScope -eq 'all') {
        $scopeDirs += [pscustomobject]@{ Scope = 'global'; Path = $Dir }
        foreach ($childScope in @('work', 'home')) {
            $childDir = Join-Path $Dir $childScope
            if (Test-Path -LiteralPath $childDir) {
                $scopeDirs += [pscustomobject]@{ Scope = $childScope; Path = $childDir }
            }
        }
    } elseif ($MemoryScope -eq 'global') {
        $scopeDirs += [pscustomobject]@{ Scope = 'global'; Path = $Dir }
    } else {
        $scopeDirs += [pscustomobject]@{ Scope = $MemoryScope; Path = (Join-Path $Dir $MemoryScope) }
    }

    foreach ($scopeDir in $scopeDirs) {
        if (-not (Test-Path -LiteralPath $scopeDir.Path)) {
            continue
        }
        $items += Get-ChildItem -LiteralPath $scopeDir.Path -File -Filter '*.md' | ForEach-Object {
            $_ | Add-Member -NotePropertyName MemoryScope -NotePropertyValue $scopeDir.Scope -Force -PassThru
        }
    }
    return @($items | Sort-Object LastWriteTime -Descending)
}

function Test-SessionSyncFile {
    param([System.IO.FileInfo]$File)
    try {
        $lines = @(Get-Content -LiteralPath $File.FullName -Encoding UTF8 -TotalCount 40)
        if ($lines.Count -eq 0) {
            return $false
        }

        $title = ([string]$lines[0]).Trim()
        if (
            $title -like '# Codex Session Sync*' -or
            $title -like '# Codex Session Summary*'
        ) {
            return $true
        }

        $sample = $lines -join "`n"
        $hasSessionTitle = $title -match '(?i)(codex|session|会话|交接笔记)'
        $hasSyncTime = $sample -match '(?m)^(同步时间|Synced)\s*[：:]'
        $hasWorkspace = $sample -match '(?m)^(工作目录|CWD)\s*[：:]|^\s*-\s*CWD\s*:'
        $hasUserContext = $sample -match '(?m)^(用户称呼|User Context)\s*[：:]'

        return ($hasSessionTitle -and $hasSyncTime -and ($hasWorkspace -or $hasUserContext))
    } catch {
        return $false
    }
}

function Resolve-MemoryFile {
    param(
        [object[]]$Files,
        [string]$Query,
        [bool]$UseLatest,
        [string]$MemoryRoot
    )

    if ($UseLatest -or [string]::IsNullOrWhiteSpace($Query)) {
        return $Files | Select-Object -First 1
    }

    $queryScope = $null
    $queryText = $Query
    if ($Query -match '^(work|home|global)[:/\\](.+)$') {
        $queryScope = $Matches[1]
        $queryText = $Matches[2]
        $Files = @($Files | Where-Object { $_.MemoryScope -eq $queryScope })
    }

    if (Test-Path -LiteralPath $queryText) {
        return Get-Item -LiteralPath $queryText
    }

    $relativeCandidates = @()
    if ($queryScope -and $queryScope -ne 'global') {
        $relativeCandidates += Join-Path (Join-Path $MemoryRoot $queryScope) $queryText
    } else {
        $relativeCandidates += Join-Path $MemoryRoot $queryText
        foreach ($childScope in @('work', 'home')) {
            $relativeCandidates += Join-Path (Join-Path $MemoryRoot $childScope) $queryText
        }
    }
    foreach ($candidate in $relativeCandidates) {
        if (Test-Path -LiteralPath $candidate) {
            return Get-Item -LiteralPath $candidate
        }
    }

    $exact = $Files | Where-Object { $_.Name -eq $queryText -or $_.BaseName -eq $queryText } | Select-Object -First 1
    if ($exact) {
        return $exact
    }

    $wildcard = $Files | Where-Object { $_.Name -like "*$queryText*" -or $_.FullName -like "*$queryText*" } | Select-Object -First 1
    if ($wildcard) {
        return $wildcard
    }

    $contentMatch = $Files | Where-Object {
        Select-String -LiteralPath $_.FullName -Pattern ([regex]::Escape($queryText)) -Quiet -ErrorAction SilentlyContinue
    } | Select-Object -First 1
    if ($contentMatch) {
        return $contentMatch
    }

    throw "No memory session matched: $Query"
}

if ([string]::IsNullOrWhiteSpace($MemoryDir)) {
    $MemoryDir = Get-DefaultMemoryDir
}

$allFiles = Get-MemoryFiles -Dir $MemoryDir -MemoryScope $Scope
$sessionFiles = @($allFiles | Where-Object { Test-SessionSyncFile $_ })
$files = if ($AllMarkdown -or $Latest -or $List -or -not [string]::IsNullOrWhiteSpace($Session)) { $allFiles } else { $sessionFiles }

if ($List -or (-not $Latest -and [string]::IsNullOrWhiteSpace($Session))) {
    if ($files.Count -eq 0) {
        Write-Output "No Codex Session Sync notes found in: $MemoryDir"
        Write-Output "Use -AllMarkdown to list every Markdown file in this directory."
        exit 0
    }
    $files |
        Select-Object -First $RecentCount @{Name='Modified';Expression={$_.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')}}, @{Name='Scope';Expression={$_.MemoryScope}}, Length, Name, FullName |
        Format-Table -AutoSize | Out-String -Width 4096
    exit 0
}

$target = Resolve-MemoryFile -Files $files -Query $Session -UseLatest ([bool]$Latest) -MemoryRoot $MemoryDir
if (-not $target) {
    throw "No Codex Session Sync notes found in: $MemoryDir"
}

$content = Get-Content -LiteralPath $target.FullName -Encoding UTF8 -Raw
Write-Output "Source: $($target.FullName)"
if ($target.PSObject.Properties.Name -contains 'MemoryScope') {
    Write-Output "Scope: $($target.MemoryScope)"
}
Write-Output "Modified: $($target.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))"
Write-Output "Length: $($target.Length)"
Write-Output ""
Write-Output (Limit-Text $content $MaxChars)
