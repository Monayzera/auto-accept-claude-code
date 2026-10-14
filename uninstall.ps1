& {
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

    function Uninstall-AutoAccept {
        $marketplace = 'monayzera-plugins'
        $plugin = 'auto-accept@' + $marketplace

        Write-Host 'auto-accept uninstaller' -ForegroundColor Cyan
        $claude = Find-Claude
        if ($null -eq $claude) {
            Write-Host 'Claude Code was not found. Nothing to uninstall.' -ForegroundColor Red
            return
        }
        Write-Host ('Using Claude Code ' + $claude.Version + ' at ' + $claude.Path)

        Write-Host ('Uninstalling ' + $plugin + ' ...')
        $result = Invoke-Claude $claude.Path @('plugin', 'uninstall', $plugin, '--scope', 'user')
        if ($result.Code -ne 0) {
            Write-Host ('Plugin uninstall returned: ' + $result.Output) -ForegroundColor Yellow
        }

        Write-Host ('Removing marketplace ' + $marketplace + ' ...')
        $result = Invoke-Claude $claude.Path @('plugin', 'marketplace', 'remove', $marketplace)
        if ($result.Code -ne 0) {
            Write-Host ('Marketplace remove returned: ' + $result.Output) -ForegroundColor Yellow
        }

        Write-Host ''
        Write-Host 'Done. Restart open Claude Code sessions (or run /reload-plugins) to stop the hook.' -ForegroundColor Green
    }

    Uninstall-AutoAccept
}
