param(
    [string]$DataDir = '',
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Rest = @()
)

$ErrorActionPreference = 'Stop'
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$RecentLines = 10

function Get-State([string]$StatePath) {
    try {
        if (-not (Test-Path -LiteralPath $StatePath -PathType Leaf)) { return 'ON' }
        $raw = [System.IO.File]::ReadAllText($StatePath, $Utf8NoBom).TrimStart([char]0xFEFF)
        $state = $raw | ConvertFrom-Json
        $property = $state.PSObject.Properties['enabled']
        if (($null -ne $property) -and ($property.Value -is [bool]) -and $property.Value) { return 'ON' }
        if (($null -ne $property) -and ($property.Value -is [bool])) { return 'OFF' }
        return 'OFF (state file is invalid, run /auto-accept on to repair)'
    } catch {
        return 'OFF (state file is unreadable, run /auto-accept on to repair)'
    }
}

function Set-State([string]$Dir, [string]$StatePath, [bool]$Enabled) {
    [System.IO.Directory]::CreateDirectory($Dir) | Out-Null
    $json = if ($Enabled) { '{"enabled":true}' } else { '{"enabled":false}' }
    $tempPath = $StatePath + '.' + [System.Guid]::NewGuid().ToString('N') + '.tmp'
    try {
        [System.IO.File]::WriteAllText($tempPath, $json, $Utf8NoBom)
        Move-Item -LiteralPath $tempPath -Destination $StatePath -Force
    } finally {
        if (Test-Path -LiteralPath $tempPath) { Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue }
    }
}

function Write-Status([string]$StatePath, [string]$LogPath) {
    Write-Output ('auto-accept: ' + (Get-State $StatePath))
    Write-Output ('Active in: Manual (default) and Plan modes')
    Write-Output ('Never answered: AskUserQuestion, ExitPlanMode')
    Write-Output ('Log file: ' + $LogPath)
    try {
        if (Test-Path -LiteralPath $LogPath -PathType Leaf) {
            $lines = @(Get-Content -LiteralPath $LogPath -Encoding UTF8 -Tail $RecentLines)
            Write-Output ('Last ' + $lines.Count + ' approvals:')
            foreach ($line in $lines) { Write-Output ('  ' + $line) }
        } else {
            Write-Output 'No approvals logged yet.'
        }
    } catch {
        Write-Output ('Could not read the log: ' + $_.Exception.Message)
    }
}

try {
    if ([string]::IsNullOrWhiteSpace($DataDir) -or $DataDir.Contains('${')) {
        Write-Output 'auto-accept: plugin data directory is not available. Reinstall the plugin or update Claude Code.'
        exit 0
    }
    $statePath = Join-Path $DataDir 'state.json'
    $logPath = Join-Path $DataDir 'approvals.log'
    $action = (($Rest -join ' ').Trim()).ToLowerInvariant()

    switch ($action) {
        'on' {
            Set-State $DataDir $statePath $true
            Write-Output 'auto-accept is now ON. Permission prompts in Manual and Plan modes are answered with Allow (once).'
        }
        'off' {
            Set-State $DataDir $statePath $false
            Write-Output 'auto-accept is now OFF. Permission prompts are shown normally.'
        }
        { $_ -eq '' -or $_ -eq 'status' } {
            Write-Status $statePath $logPath
        }
        default {
            Write-Output ('Unknown option "' + $action + '". Usage: /auto-accept on | off | status')
        }
    }
} catch {
    Write-Output ('auto-accept: failed: ' + $_.Exception.Message)
}
exit 0
