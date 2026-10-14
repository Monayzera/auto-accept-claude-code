function Get-ClaudeVersion([string]$Path) {
    try {
        $text = (& $Path --version 2>$null | Out-String)
        if ($text -match '(\d+\.\d+\.\d+)') { return [version]$Matches[1] }
    } catch {
    }
    return $null
}

function Find-Claude {
    $candidates = New-Object System.Collections.Generic.List[string]
    try {
        foreach ($command in @(Get-Command claude -CommandType Application -ErrorAction SilentlyContinue)) {
            if ($command.Source) { $candidates.Add($command.Source) }
        }
    } catch {
    }
    try {
        $desktopRoot = Join-Path $env:APPDATA 'Claude\claude-code'
        if (Test-Path -LiteralPath $desktopRoot) {
            foreach ($file in @(Get-ChildItem -LiteralPath $desktopRoot -Recurse -Filter 'claude.exe' -File -ErrorAction SilentlyContinue)) {
                $candidates.Add($file.FullName)
            }
        }
    } catch {
    }
    $best = $null
    $bestVersion = $null
    foreach ($candidate in ($candidates | Select-Object -Unique)) {
        $version = Get-ClaudeVersion $candidate
        if ($null -ne $version -and ($null -eq $bestVersion -or $version -gt $bestVersion)) {
            $best = $candidate
            $bestVersion = $version
        }
    }
    if ($null -eq $best) { return $null }
    return [pscustomobject]@{ Path = $best; Version = $bestVersion }
}

function Invoke-Claude([string]$Path, [string[]]$Arguments) {
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = & $Path @Arguments 2>&1 | ForEach-Object { "$_" }
        return [pscustomobject]@{ Code = $LASTEXITCODE; Output = ($output -join [Environment]::NewLine).Trim() }
    } catch {
        return [pscustomobject]@{ Code = 1; Output = $_.Exception.Message }
    } finally {
        $ErrorActionPreference = $previous
    }
}

function Install-AutoAccept {
    $source = 'Monayzera/auto-accept-claude-code'
    $marketplace = 'monayzera-plugins'
    $plugin = 'auto-accept@' + $marketplace

    Write-Host 'auto-accept installer' -ForegroundColor Cyan
    $claude = Find-Claude
    if ($null -eq $claude) {
        Write-Host 'Claude Code was not found. Install Claude Code (CLI or Desktop) and run this again.' -ForegroundColor Red
        return
    }
    Write-Host ('Using Claude Code ' + $claude.Version + ' at ' + $claude.Path)

    Write-Host ('Adding marketplace ' + $source + ' ...')
    $result = Invoke-Claude $claude.Path @('plugin', 'marketplace', 'add', $source)
    if ($result.Code -ne 0) {
        $update = Invoke-Claude $claude.Path @('plugin', 'marketplace', 'update', $marketplace)
        if ($update.Code -ne 0) {
            Write-Host 'Could not add or update the marketplace:' -ForegroundColor Red
            Write-Host $result.Output
            Write-Host $update.Output
            return
        }
        Write-Host 'Marketplace already present, updated.'
    }

    Write-Host ('Installing ' + $plugin + ' (user scope) ...')
    $result = Invoke-Claude $claude.Path @('plugin', 'install', $plugin, '--scope', 'user')
    if ($result.Code -ne 0) {
        $update = Invoke-Claude $claude.Path @('plugin', 'update', $plugin, '--scope', 'user')
        if ($update.Code -ne 0) {
            Write-Host 'Could not install the plugin:' -ForegroundColor Red
            Write-Host $result.Output
            Write-Host $update.Output
            return
        }
        Write-Host 'Plugin already installed, updated.'
    }

    $enable = Invoke-Claude $claude.Path @('plugin', 'enable', $plugin, '--scope', 'user')
    if ($enable.Code -ne 0 -and $enable.Output -notmatch 'already') {
        Write-Host ('Note: enable returned: ' + $enable.Output) -ForegroundColor Yellow
    }

    Write-Host ''
    Write-Host 'Done. auto-accept is installed (ON by default).' -ForegroundColor Green
    Write-Host 'Open a new session (or run /reload-plugins in an open one) in the Claude Code Desktop app or CLI.'
    Write-Host 'Keep the permission mode on Manual. Use /auto-accept status | on | off to control it.'
}

Install-AutoAccept
