'use strict';

const fs = require('fs');
const path = require('path');

const SKIPPED_TOOLS = new Set(['AskUserQuestion', 'ExitPlanMode']);
const ACTIVE_MODES = new Set(['default', 'plan']);
const LOG_MAX_BYTES = 1024 * 1024;
const SUMMARY_MAX_CHARS = 300;
const ALLOW_OUTPUT = JSON.stringify({
  hookSpecificOutput: {
    hookEventName: 'PermissionRequest',
    decision: { behavior: 'allow' }
  }
});

function readStdin() {
  try {
    return fs.readFileSync(0, 'utf8').replace(/^\uFEFF/, '');
  } catch (error) {
    return '';
  }
}

function parseEvent(raw) {
  try {
    const value = JSON.parse(raw);
    return value && typeof value === 'object' && !Array.isArray(value) ? value : null;
  } catch (error) {
    return null;
  }
}

function getDataDir() {
  const dir = process.env.CLAUDE_PLUGIN_DATA;
  return typeof dir === 'string' && dir.trim() !== '' ? dir : null;
}

function isEnabled(dataDir) {
  const statePath = path.join(dataDir, 'state.json');
  let raw;
  try {
    raw = fs.readFileSync(statePath, 'utf8');
  } catch (error) {
    return error && error.code === 'ENOENT';
  }
  try {
    const state = JSON.parse(raw.replace(/^\uFEFF/, ''));
    return Boolean(state) && state.enabled === true;
  } catch (error) {
    return false;
  }
}

function shouldApprove(event) {
  if (!event) return false;
  if (event.hook_event_name !== undefined && event.hook_event_name !== 'PermissionRequest') return false;
  if (typeof event.tool_name !== 'string' || event.tool_name === '') return false;
  if (SKIPPED_TOOLS.has(event.tool_name)) return false;
  return typeof event.permission_mode === 'string' && ACTIVE_MODES.has(event.permission_mode);
}

function clean(value) {
  const text = String(value).replace(/[\r\n\t]+/g, ' ').trim();
  return text.length > SUMMARY_MAX_CHARS ? text.slice(0, SUMMARY_MAX_CHARS) + '...' : text;
}

function summarize(input) {
  if (!input || typeof input !== 'object') return '';
  const keys = ['command', 'file_path', 'notebook_path', 'path', 'url', 'query', 'pattern'];
  for (const key of keys) {
    if (typeof input[key] === 'string' && input[key] !== '') return clean(input[key]);
  }
  try {
    return clean(JSON.stringify(input));
  } catch (error) {
    return '';
  }
}

function writeLog(dataDir, event) {
  try {
    fs.mkdirSync(dataDir, { recursive: true });
    const logPath = path.join(dataDir, 'approvals.log');
    try {
      if (fs.statSync(logPath).size >= LOG_MAX_BYTES) {
        fs.renameSync(logPath, logPath + '.1');
      }
    } catch (error) {
    }
    const line = [
      new Date().toISOString(),
      clean(event.session_id || ''),
      clean(event.permission_mode || ''),
      clean(event.tool_name || ''),
      summarize(event.tool_input)
    ].join('\t') + '\n';
    fs.appendFileSync(logPath, line, 'utf8');
  } catch (error) {
  }
}

function main() {
  const dataDir = getDataDir();
  if (!dataDir) return;
  const event = parseEvent(readStdin());
  if (!shouldApprove(event)) return;
  if (!isEnabled(dataDir)) return;
  process.stdout.write(ALLOW_OUTPUT);
  writeLog(dataDir, event);
}

try {
  main();
} catch (error) {
}
process.exitCode = 0;
