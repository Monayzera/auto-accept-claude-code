---
name: auto-accept
description: Turn the auto-accept plugin on or off, or show its status and recent approvals.
argument-hint: on | off | status
disable-model-invocation: true
shell: powershell
allowed-tools: PowerShell(powershell.exe *) Bash(powershell.exe *)
---

!`powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/toggle.ps1" -DataDir "${CLAUDE_PLUGIN_DATA}" $ARGUMENTS`

Show the output above to the user exactly as printed, inside a code block. Do not run any tool and do not add anything else.
