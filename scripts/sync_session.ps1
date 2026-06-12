param(
    [string]$SessionFile,
    [string]$Destination,
    [int]$MaxOutputChars = 2000,
    [int]$MaxToolCalls = 80,
    [int]$MaxMessages = 160
)

$ErrorActionPreference = 'Stop'

function Get-LatestSessionFile {
    $sessionsRoot = Join-Path $env:USERPROFILE '.codex\sessions'
    if (-not (Test-Path -LiteralPath $sessionsRoot)) {
        throw "Codex sessions folder not found: $sessionsRoot"
    }

    $latest = Get-ChildItem -LiteralPath $sessionsRoot -Recurse -File -Filter '*.jsonl' |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    if (-not $latest) {
        throw "No Codex session JSONL files found under: $sessionsRoot"
    }

    return $latest.FullName
}

function Get-DefaultDestination {
    if (-not [string]::IsNullOrWhiteSpace($env:SESSION_SYNC_MEMORY_DIR)) {
        return $env:SESSION_SYNC_MEMORY_DIR
    }

    $documents = [Environment]::GetFolderPath('MyDocuments')
    if ([string]::IsNullOrWhiteSpace($documents)) {
        $documents = $env:USERPROFILE
    }
    return (Join-Path $documents 'session-sync-memory')
}

function ConvertTo-SafeFilePart {
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) {
        return 'codex-session'
    }
    $safe = $Text -replace '[\\/:*?"<>|]', '-'
    $safe = $safe -replace '\s+', '-'
    $safe = $safe.Trim('-')
    if ($safe.Length -gt 72) {
        $safe = $safe.Substring(0, 72).Trim('-')
    }
    if ([string]::IsNullOrWhiteSpace($safe)) {
        return 'codex-session'
    }
    return $safe
}

function Get-TextFromContent {
    param($Content)
    if ($null -eq $Content) {
        return ''
    }

    if ($Content -is [string]) {
        return $Content
    }

    $parts = @()
    foreach ($item in @($Content)) {
        if ($null -ne $item.text) {
            $parts += [string]$item.text
        } elseif ($null -ne $item.input_text) {
            $parts += [string]$item.input_text
        } elseif ($null -ne $item.output_text) {
            $parts += [string]$item.output_text
        }
    }
    return ($parts -join "`n")
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

function Add-SectionLine {
    param(
        [System.Collections.Generic.List[string]]$Lines,
        [string]$Line = ''
    )
    [void]$Lines.Add($Line)
}

if ([string]::IsNullOrWhiteSpace($SessionFile)) {
    $SessionFile = Get-LatestSessionFile
}

$SessionFile = (Resolve-Path -LiteralPath $SessionFile).Path

if ([string]::IsNullOrWhiteSpace($Destination)) {
    $Destination = Get-DefaultDestination
}

if (-not (Test-Path -LiteralPath $Destination)) {
    New-Item -ItemType Directory -Path $Destination -Force | Out-Null
}

$sessionMeta = $null
$messages = New-Object 'System.Collections.Generic.List[object]'
$toolCalls = New-Object 'System.Collections.Generic.List[object]'
$toolOutputsByCallId = @{}
$completedNodes = New-Object 'System.Collections.Generic.List[string]'
$decisions = New-Object 'System.Collections.Generic.List[string]'
$lineNumber = 0

Get-Content -LiteralPath $SessionFile -Encoding UTF8 | ForEach-Object {
    $lineNumber += 1
    if ([string]::IsNullOrWhiteSpace($_)) {
        return
    }

    try {
        $record = $_ | ConvertFrom-Json
    } catch {
        return
    }

    if ($record.type -eq 'session_meta') {
        $sessionMeta = $record.payload
        return
    }

    if ($record.type -ne 'response_item') {
        return
    }

    $payload = $record.payload
    if ($payload.type -eq 'message') {
        $text = Get-TextFromContent $payload.content
        if (-not [string]::IsNullOrWhiteSpace($text)) {
            if ($messages.Count -lt $MaxMessages) {
                $messages.Add([pscustomobject]@{
                    Timestamp = $record.timestamp
                    Role = $payload.role
                    Phase = $payload.phase
                    Text = Limit-Text $text ($MaxOutputChars * 2)
                }) | Out-Null
            }

            if ($payload.role -eq 'assistant') {
                $short = ($text -replace '\s+', ' ').Trim()
                if ($short.Length -gt 180) {
                    $short = $short.Substring(0, 180) + '...'
                }
                if ($payload.phase -eq 'commentary' -or $payload.phase -eq 'final' -or $short -match '(done|completed|created|saved|wrote|generated|verified|synced|updated|installed|ran|fixed)') {
                    $completedNodes.Add($short) | Out-Null
                }
            }

            if ($text -match '(skill|plugin|Agents\.md|memory-session|session-sync|sync_session|global|recommend|recommended|decision|decided|should)') {
                $shortDecision = ($text -replace '\s+', ' ').Trim()
                if ($shortDecision.Length -gt 220) {
                    $shortDecision = $shortDecision.Substring(0, 220) + '...'
                }
                $decisions.Add($shortDecision) | Out-Null
            }
        }
        return
    }

    if ($payload.type -eq 'function_call') {
        if ($toolCalls.Count -lt $MaxToolCalls) {
            $toolCalls.Add([pscustomobject]@{
                Timestamp = $record.timestamp
                CallId = [string]$payload.call_id
                Name = [string]$payload.name
                Arguments = Limit-Text ([string]$payload.arguments) $MaxOutputChars
            }) | Out-Null
        }
        return
    }

    if ($payload.type -eq 'function_call_output') {
        if ($toolOutputsByCallId.Count -lt $MaxToolCalls) {
            $toolOutputsByCallId[[string]$payload.call_id] = Limit-Text ([string]$payload.output) $MaxOutputChars
        }
        return
    }
}

$sessionId = if ($sessionMeta -and $sessionMeta.id) { [string]$sessionMeta.id } else { [IO.Path]::GetFileNameWithoutExtension($SessionFile) }
$cwd = if ($sessionMeta -and $sessionMeta.cwd) { [string]$sessionMeta.cwd } else { '' }
$started = if ($sessionMeta -and $sessionMeta.timestamp) { [string]$sessionMeta.timestamp } else { '' }
$now = Get-Date
$stamp = $now.ToString('yyyyMMdd-HHmmss')
$titlePart = ConvertTo-SafeFilePart $sessionId
$outFile = Join-Path $Destination "$stamp-$titlePart.md"

New-Item -ItemType File -Path $outFile -Force | Out-Null
$writer = New-Object System.IO.StreamWriter($outFile, $false, (New-Object System.Text.UTF8Encoding($false)))
try {
function Write-Line {
    param([string]$Line = '')
    $writer.WriteLine($Line)
}

Write-Line "# Codex Session Sync - $stamp"
Write-Line
Write-Line "## Metadata"
Write-Line
Write-Line "- Session ID: $sessionId"
Write-Line "- Started: $started"
Write-Line "- Synced: $($now.ToString('yyyy-MM-dd HH:mm:ss'))"
Write-Line "- CWD: $cwd"
Write-Line "- Source JSONL: $SessionFile"
Write-Line "- Limits: MaxToolCalls=$MaxToolCalls; MaxMessages=$MaxMessages; MaxOutputChars=$MaxOutputChars"
Write-Line

Write-Line "## Completed Nodes"
Write-Line
if ($completedNodes.Count -eq 0) {
    Write-Line "- No explicit completed nodes were detected from assistant messages."
} else {
    $completedNodes | Select-Object -Unique -First 30 | ForEach-Object {
        Write-Line "- $_"
    }
}
Write-Line

Write-Line "## Decisions And Agreements"
Write-Line
if ($decisions.Count -eq 0) {
    Write-Line "- No key decisions were detected."
} else {
    $decisions | Select-Object -Unique -First 30 | ForEach-Object {
        Write-Line "- $_"
    }
}
Write-Line

Write-Line "## Tool And Command Log"
Write-Line
if ($toolCalls.Count -eq 0) {
    Write-Line "- No tool calls were found in this session record."
} else {
    foreach ($call in $toolCalls) {
        Write-Line ('### {0} `{1}`' -f $call.Name, $call.CallId)
        Write-Line
        Write-Line "Arguments:"
        Write-Line '```json'
        Write-Line $call.Arguments
        Write-Line '```'
        if ($toolOutputsByCallId.ContainsKey([string]$call.CallId)) {
            Write-Line
            Write-Line "Output:"
            Write-Line '```text'
            Write-Line $toolOutputsByCallId[[string]$call.CallId]
            Write-Line '```'
        }
        Write-Line
    }
}

Write-Line "## Conversation"
Write-Line
if ($messages.Count -eq 0) {
    Write-Line "- No exportable conversation messages were found."
} else {
    $i = 0
    foreach ($message in $messages) {
        $i += 1
        $role = if ($message.Role) { $message.Role } else { 'unknown' }
        $phase = if ($message.Phase) { " / $($message.Phase)" } else { '' }
        Write-Line "### $i. $role$phase"
        Write-Line
        Write-Line ([string]$message.Text).Trim()
        Write-Line
    }
}
} finally {
    $writer.Dispose()
}
Write-Output $outFile
