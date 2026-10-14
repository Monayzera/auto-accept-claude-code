$ErrorActionPreference = 'Stop'

$SkippedTools = @('AskUserQuestion', 'ExitPlanMode')
$ActiveModes = @('default', 'plan')
$LogMaxBytes = 1MB
$SummaryMaxChars = 300
$AllowOutput = '{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"allow"}}}'
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Read-Stdin {
    try {
        $reader = New-Object System.IO.StreamReader([Console]::OpenStandardInput(), $Utf8NoBom)
        try {
            return $reader.ReadToEnd().TrimStart([char]0xFEFF)
        } finally {
            $reader.Dispose()
        }
    } catch {
        return ''
    }
}

function ConvertTo-Event([string]$Raw) {
    try {
        if ([string]::IsNullOrWhiteSpace($Raw)) { return $null }
        $value = $Raw | ConvertFrom-Json
        if ($value -is [System.Management.Automation.PSCustomObject]) { return $value }
        return $null
    } catch {
        return $null
    }
}

function Get-Field($Object, [string]$Name) {
    try {
        if ($null -eq $Object) { return $null }
        $property = $Object.PSObject.Properties[$Name]
        if ($null -eq $property) { return $null }
        return $property.Value
    } catch {
        return $null
    }
}

function Get-DataDir {
    $dir = $env:CLAUDE_PLUGIN_DATA
    if ([string]::IsNullOrWhiteSpace($dir)) { return $null }
    return $dir
}

function Test-Enabled([string]$DataDir) {
    $statePath = Join-Path $DataDir 'state.json'
    try {
        if (-not (Test-Path -LiteralPath $statePath -PathType Leaf)) { return $true }
        $raw = [System.IO.File]::ReadAllText($statePath, $Utf8NoBom).TrimStart([char]0xFEFF)
        $state = $raw | ConvertFrom-Json
        return ((Get-Field $state 'enabled') -is [bool]) -and ((Get-Field $state 'enabled') -eq $true)
    } catch {
        return $false
    }
}

function Test-ShouldApprove($HookEvent) {
    if ($null -eq $HookEvent) { return $false }
    $eventName = Get-Field $HookEvent 'hook_event_name'
    if (($null -ne $eventName) -and ($eventName -cne 'PermissionRequest')) { return $false }
    $toolName = Get-Field $HookEvent 'tool_name'
    if (-not ($toolName -is [string]) -or $toolName -eq '') { return $false }
    if ($SkippedTools -ccontains $toolName) { return $false }
    $mode = Get-Field $HookEvent 'permission_mode'
    return ($mode -is [string]) -and ($ActiveModes -ccontains $mode)
}

function Format-Clean($Value) {
    if ($null -eq $Value) { return '' }
    $text = ([string]$Value -replace '[\r\n\t]+', ' ').Trim()
    if ($text.Length -gt $SummaryMaxChars) { return $text.Substring(0, $SummaryMaxChars) + '...' }
    return $text
}

function Get-Summary($ToolInput) {
    if ($null -eq $ToolInput) { return '' }
    foreach ($key in @('command', 'file_path', 'notebook_path', 'path', 'url', 'query', 'pattern')) {
        $value = Get-Field $ToolInput $key
        if (($value -is [string]) -and $value -ne '') { return Format-Clean $value }
    }
    try {
        return Format-Clean ($ToolInput | ConvertTo-Json -Compress -Depth 5)
    } catch {
        return ''
    }
}

function Write-ApprovalLog([string]$DataDir, $HookEvent) {
    try {
        [System.IO.Directory]::CreateDirectory($DataDir) | Out-Null
        $logPath = Join-Path $DataDir 'approvals.log'
        try {
            if ((Test-Path -LiteralPath $logPath -PathType Leaf) -and ((Get-Item -LiteralPath $logPath).Length -ge $LogMaxBytes)) {
                Move-Item -LiteralPath $logPath -Destination ($logPath + '.1') -Force
            }
        } catch {
        }
        $line = @(
            [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ss.fffZ'),
            (Format-Clean (Get-Field $HookEvent 'session_id')),
            (Format-Clean (Get-Field $HookEvent 'permission_mode')),
            (Format-Clean (Get-Field $HookEvent 'tool_name')),
            (Get-Summary (Get-Field $HookEvent 'tool_input'))
        ) -join "`t"
        [System.IO.File]::AppendAllText($logPath, $line + "`n", $Utf8NoBom)
    } catch {
    }
}

try {
    $dataDir = Get-DataDir
    if ($null -ne $dataDir) {
        $hookEvent = ConvertTo-Event (Read-Stdin)
        if ((Test-ShouldApprove $hookEvent) -and (Test-Enabled $dataDir)) {
            [Console]::Out.Write($AllowOutput)
            [Console]::Out.Flush()
            Write-ApprovalLog $dataDir $hookEvent
        }
    }
} catch {
}
exit 0
