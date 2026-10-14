# auto-accept

A Claude Code plugin that answers permission prompts with **Allow (once)**. You stay in **Manual** mode, and the plugin clicks Allow for you.

Built for the Claude Code Desktop app on Windows. It also works in the Claude Code CLI on the same machine, because both read the same plugin settings.

[Leia em português](README.pt-BR.md)

## Why

`"permissions": { "allow": ["*"] }` does not work. Claude Code skips an unanchored glob like `"*"` with a warning, so it approves nothing. This plugin uses the official `PermissionRequest` hook instead. The hook runs at the moment Claude Code is about to show a permission dialog and returns the same decision as clicking Allow once.

## Install

**Option 1: one command in PowerShell**

```powershell
irm https://raw.githubusercontent.com/Monayzera/auto-accept-claude-code/main/install.ps1 | iex
```

The script finds the newest Claude Code on the machine (CLI on PATH or the copy bundled with the Desktop app), adds the marketplace and installs the plugin at user scope.

**Option 2: inside Claude Code**

```
/plugin marketplace add Monayzera/auto-accept-claude-code
/plugin install auto-accept@monayzera-plugins
```

After installing, open a new session or run `/reload-plugins` in an open one. Keep the permission mode on **Manual**.

## Usage

| Command | Effect |
| --- | --- |
| `/auto-accept on` | Turns auto-accept on (default after install) |
| `/auto-accept off` | Turns it off; prompts are shown normally |
| `/auto-accept status` | Shows the state, the log path and the last 10 approvals |

The on/off state is saved in the plugin data directory, so it applies to every session and survives restarts and plugin updates. Claude itself cannot run this command.

## What it approves

| Situation | Behavior |
| --- | --- |
| Permission prompt in Manual (`default`) or Plan mode | Allow (once) |
| `AskUserQuestion` and `ExitPlanMode` | Never answered; you see them as usual |
| Other modes (acceptEdits, auto, bypassPermissions, ...) | Not touched |
| Plugin turned off | Not touched |
| Any internal error (bad input, unreadable state) | Not touched; the normal dialog shows |

Allow (once) writes no rules into your settings. Turn the plugin off and every prompt comes back.

## Limits

These come from Claude Code itself, and no hook can change them:

- Your own `deny` and `ask` rules still win over the hook.
- MCP tools that require user interaction always prompt.
- `/auto-accept` runs through the PowerShell tool, which is on by default on Windows. If you turned it off with `CLAUDE_CODE_USE_POWERSHELL_TOOL=0`, the command does not work. The hook still does.

Tested on Claude Code 2.1.295 (Windows 11): the hook approves Bash, Write and writes to the protected `.claude` folder, and after `/auto-accept off` the prompt is shown again.

## Log

Every automatic approval adds one line to `approvals.log` in the plugin data directory: time, session, mode, tool and a short summary of the command or file. When the log reaches 1 MB it is rotated to `approvals.log.1`. `/auto-accept status` prints the path.

## How it works

```
hooks/hooks.json          PermissionRequest hook, matcher "*"
scripts/run.cmd           runs approve.js with Node if installed, else approve.ps1
scripts/approve.js        decision logic (Node)
scripts/approve.ps1       same logic (Windows PowerShell, no dependencies)
scripts/toggle.ps1        on / off / status
skills/auto-accept/       the /auto-accept command
```

Node.js is optional. Without it, the PowerShell handler is used, which adds roughly 0.4 s per prompt.

## Uninstall

```powershell
irm https://raw.githubusercontent.com/Monayzera/auto-accept-claude-code/main/uninstall.ps1 | iex
```

Or inside Claude Code: `/plugin uninstall auto-accept@monayzera-plugins`.

## Warning

With auto-accept on, any command Claude decides to run is approved without you seeing it. That includes commands suggested by a web page or file Claude reads. It also includes calls from sessions that cannot show a prompt, such as background subagents, which Claude Code would otherwise deny. Use `/auto-accept off` when working with untrusted content, and check the log.

## License

MIT
