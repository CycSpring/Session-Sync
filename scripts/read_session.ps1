param(
    [string]$MemoryDir,
    [string]$Session,
    [switch]$Latest,
    [switch]$List,
    [switch]$AllMarkdown,
    [int]$RecentCount = 5,
    [int]$MaxChars = 30000
)

$ErrorActionPreference = 'Stop'

function Get-DefaultMemoryDir {
    if (-not [string]::IsNullOrWhiteSpace($env:SESSION_SYNC_MEMORY_DIR)) {
        return $env:SESSION_SYNC_MEMORY_DIR
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
    param([string]$Dir)
    if (-not (Test-Path -LiteralPath $Dir)) {
        throw "Memory directory not found: $Dir"
    }
    return @(Get-ChildItem -LiteralPath $Dir -File -Filter '*.md' | Sort-Object LastWriteTime -Descending)
}

function Test-SessionSyncFile {
    param([System.IO.FileInfo]$File)
    try {
        $firstLine = Get-Content -LiteralPath $File.FullName -Encoding UTF8 -TotalCount 1
        return ([string]$firstLine).Trim() -like '# Codex Session Sync*'
    } catch {
        return $false
    }
}

function Resolve-MemoryFile {
    param(
        [object[]]$Files,
        [string]$Query,
        [bool]$UseLatest
    )

    if ($UseLatest -or [string]::IsNullOrWhiteSpace($Query)) {
        return $Files | Select-Object -First 1
    }

    if (Test-Path -LiteralPath $Query) {
        return Get-Item -LiteralPath $Query
    }

    $exact = $Files | Where-Object { $_.Name -eq $Query -or $_.BaseName -eq $Query } | Select-Object -First 1
    if ($exact) {
        return $exact
    }

    $wildcard = $Files | Where-Object { $_.Name -like "*$Query*" -or $_.FullName -like "*$Query*" } | Select-Object -First 1
    if ($wildcard) {
        return $wildcard
    }

    $contentMatch = $Files | Where-Object {
        Select-String -LiteralPath $_.FullName -Pattern ([regex]::Escape($Query)) -Quiet -ErrorAction SilentlyContinue
    } | Select-Object -First 1
    if ($contentMatch) {
        return $contentMatch
    }

    throw "No memory session matched: $Query"
}

if ([string]::IsNullOrWhiteSpace($MemoryDir)) {
    $MemoryDir = Get-DefaultMemoryDir
}

$allFiles = Get-MemoryFiles $MemoryDir
$sessionFiles = @($allFiles | Where-Object { Test-SessionSyncFile $_ })
$files = if ($AllMarkdown -or -not [string]::IsNullOrWhiteSpace($Session)) { $allFiles } else { $sessionFiles }

if ($List -or (-not $Latest -and [string]::IsNullOrWhiteSpace($Session))) {
    if ($files.Count -eq 0) {
        Write-Output "No Codex Session Sync notes found in: $MemoryDir"
        Write-Output "Use -AllMarkdown to list every Markdown file in this directory."
        exit 0
    }
    $files |
        Select-Object -First $RecentCount @{Name='Modified';Expression={$_.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')}}, Length, Name, FullName |
        Format-Table -AutoSize | Out-String -Width 4096
    exit 0
}

$target = Resolve-MemoryFile -Files $files -Query $Session -UseLatest ([bool]$Latest)
if (-not $target) {
    throw "No Codex Session Sync notes found in: $MemoryDir"
}

$content = Get-Content -LiteralPath $target.FullName -Encoding UTF8 -Raw
Write-Output "Source: $($target.FullName)"
Write-Output "Modified: $($target.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))"
Write-Output "Length: $($target.Length)"
Write-Output ""
Write-Output (Limit-Text $content $MaxChars)
