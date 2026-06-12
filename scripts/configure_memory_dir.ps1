param(
    [string]$MemoryDir,
    [switch]$NoPrompt
)

$ErrorActionPreference = 'Stop'

function ConvertTo-FullPath {
    param([string]$PathText)

    $expanded = [Environment]::ExpandEnvironmentVariables($PathText)
    if ([System.IO.Path]::IsPathRooted($expanded)) {
        return [System.IO.Path]::GetFullPath($expanded)
    }
    return [System.IO.Path]::GetFullPath((Join-Path (Get-Location).Path $expanded))
}

$current = [Environment]::GetEnvironmentVariable('SESSION_SYNC_MEMORY_DIR', 'User')

if ([string]::IsNullOrWhiteSpace($MemoryDir) -and -not $NoPrompt) {
    Write-Host 'Session Sync memory directory is required before first use.'
    if (-not [string]::IsNullOrWhiteSpace($current)) {
        Write-Host "Current user setting: $current"
    }
    $MemoryDir = Read-Host 'Enter memory directory path'
}

if ([string]::IsNullOrWhiteSpace($MemoryDir)) {
    if (-not [string]::IsNullOrWhiteSpace($current)) {
        $MemoryDir = $current
    } else {
        throw 'No memory directory was provided.'
    }
}

$fullPath = ConvertTo-FullPath $MemoryDir

if (-not (Test-Path -LiteralPath $fullPath)) {
    $create = 'Y'
    if (-not $NoPrompt) {
        $create = Read-Host "Directory does not exist. Create it? [Y/n]"
    }
    if ($create -match '^(n|no)$') {
        throw "Memory directory does not exist: $fullPath"
    }
    New-Item -ItemType Directory -Path $fullPath -Force | Out-Null
}

[Environment]::SetEnvironmentVariable('SESSION_SYNC_MEMORY_DIR', $fullPath, 'User')
$env:SESSION_SYNC_MEMORY_DIR = $fullPath

Write-Output "SESSION_SYNC_MEMORY_DIR=$fullPath"
