#!/usr/bin/env node

import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { execFileSync } from "node:child_process";

const args = new Set(process.argv.slice(2));
const watch = args.has("--watch") || args.has("-w");
const forceColor = args.has("--color") || args.has("--force-color") || process.env.FORCE_COLOR === "1";
const noColor = !forceColor && (args.has("--no-color") || !process.stdout.isTTY);
const ascii = args.has("--ascii") || process.env.CODEX_HUD_ASCII === "1";
const intervalMs = Number(process.env.CODEX_HUD_INTERVAL_MS || 700);
const codexHome = process.env.CODEX_HOME || path.join(os.homedir(), ".codex");
const cwd = process.cwd();
let frame = 0;

const colors = {
  dim: "",
  green: "\x1b[92m",
  yellow: "\x1b[93m",
  red: "\x1b[91m",
  cyan: "\x1b[96m",
  magenta: "\x1b[95m",
  reset: "\x1b[0m",
};

function color(name, text) {
  if (noColor) return text;
  const code = colors[name] || "";
  if (!code) return text;
  return `${code}${text}${colors.reset}`;
}

function pad(text, width) {
  const visible = stripAnsi(String(text));
  const extra = Math.max(0, width - visible.length);
  return `${text}${" ".repeat(extra)}`;
}

function stripAnsi(text) {
  return text.replace(/\x1b\[[0-9;]*m/g, "");
}

function run(command, commandArgs, options = {}) {
  try {
    return execFileSync(command, commandArgs, {
      cwd,
      encoding: "utf8",
      stdio: ["ignore", "pipe", "ignore"],
      ...options,
    }).trim();
  } catch {
    return "";
  }
}

function walkFiles(directory, predicate, limit = 5000) {
  const out = [];
  const stack = [directory];
  while (stack.length && out.length < limit) {
    const current = stack.pop();
    let entries = [];
    try {
      entries = fs.readdirSync(current, { withFileTypes: true });
    } catch {
      continue;
    }
    for (const entry of entries) {
      const full = path.join(current, entry.name);
      if (entry.isDirectory()) stack.push(full);
      if (entry.isFile() && predicate(full)) out.push(full);
    }
  }
  return out;
}

function newestSessionFile() {
  const sessionsDir = path.join(codexHome, "sessions");
  const files = walkFiles(sessionsDir, (file) => file.endsWith(".jsonl"));
  return files
    .map((file) => ({ file, mtime: fs.statSync(file).mtimeMs }))
    .sort((a, b) => b.mtime - a.mtime)[0]?.file;
}

function safeJson(line) {
  try {
    return JSON.parse(line);
  } catch {
    return null;
  }
}

function parseSession(file) {
  if (!file) return {};
  let lines = [];
  try {
    lines = fs.readFileSync(file, "utf8").trim().split("\n").filter(Boolean);
  } catch {
    return {};
  }

  const state = {
    file,
    meta: null,
    token: null,
    tools: [],
    todos: null,
    latestMessage: "",
  };

  for (const line of lines) {
    const event = safeJson(line);
    if (!event) continue;
    if (event.type === "session_meta") state.meta = event.payload;
    if (event.type === "turn_context" && event.payload?.model) {
      state.meta = { ...(state.meta || {}), model: event.payload.model };
    }
    if (event.type === "event_msg" && event.payload?.type === "token_count") {
      state.token = event.payload;
    }
    if (event.type === "event_msg" && event.payload?.type === "agent_message") {
      state.latestMessage = event.payload.message || "";
    }
    if (event.type === "response_item" && event.payload?.type === "function_call") {
      const name = event.payload.name || "tool";
      const argsText = event.payload.arguments || "";
      state.tools.push({ name, status: "running", detail: summarizeTool(name, argsText) });
      if (name === "update_plan") state.todos = summarizePlan(argsText);
    }
    if (event.type === "response_item" && event.payload?.type === "function_call_output") {
      const lastRunning = [...state.tools].reverse().find((tool) => tool.status === "running");
      if (lastRunning) lastRunning.status = "done";
    }
  }

  return state;
}

function summarizeTool(name, argsText) {
  const parsed = safeJson(argsText);
  if (name === "exec_command" && parsed?.cmd) return parsed.cmd.split(/\s+/).slice(0, 4).join(" ");
  if (name === "apply_patch") return "patch";
  if (name === "update_plan") return "plan";
  if (parsed?.path) return parsed.path;
  if (parsed?.ref_id) return parsed.ref_id;
  return name;
}

function summarizePlan(argsText) {
  const parsed = safeJson(argsText);
  const plan = parsed?.plan;
  if (!Array.isArray(plan)) return null;
  const done = plan.filter((item) => item.status === "completed").length;
  const active = plan.find((item) => item.status === "in_progress")?.step;
  return { done, total: plan.length, active };
}

function projectLabel(meta) {
  const projectPath = meta?.cwd || cwd;
  const parts = projectPath.split(path.sep).filter(Boolean);
  return parts.slice(-2).join(path.sep) || projectPath;
}

function gitInfo() {
  const branch = run("git", ["branch", "--show-current"]) || run("git", ["rev-parse", "--short", "HEAD"]);
  if (!branch) return "";
  const status = run("git", ["status", "--porcelain"]);
  const dirty = status ? "*" : "";
  const aheadBehind = run("git", ["rev-list", "--left-right", "--count", "HEAD...@{upstream}"]);
  let remote = "";
  if (aheadBehind) {
    const [ahead, behind] = aheadBehind.split(/\s+/).map(Number);
    remote = `${ahead ? ` ↑${ahead}` : ""}${behind ? ` ↓${behind}` : ""}`;
  }
  return `git:(${branch}${dirty}${remote})`;
}

function progressBar(percent, width = 10, tone = "green") {
  const value = Math.max(0, Math.min(100, Number(percent) || 0));
  const full = Math.round((value / 100) * width);
  const filledChar = ascii ? "#" : "█";
  const emptyChar = ascii ? "." : "░";
  const filled = color(tone, filledChar.repeat(full));
  const empty = color("dim", emptyChar.repeat(width - full));
  return `${filled}${empty}`;
}

function spinner() {
  const frames = ascii ? ["-", "\\", "|", "/"] : ["◐", "◓", "◑", "◒"];
  return frames[frame % frames.length];
}

function compactNumber(value) {
  const n = Number(value) || 0;
  if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(1)}m`;
  if (n >= 1_000) return `${Math.round(n / 1_000)}k`;
  return String(n);
}

function contextLine(token) {
  const usage = token?.info?.last_token_usage;
  const window = token?.info?.model_context_window;
  if (!usage || !window) return "Context unavailable";
  const percent = Math.min(100, Math.round((usage.total_tokens / window) * 100));
  const tone = percent >= 90 ? "red" : percent >= 75 ? "yellow" : "green";
  return metricLine("Context", percent, tone, `(${compactNumber(usage.total_tokens)}/${compactNumber(window)})`);
}

function usageLine(rateLimits) {
  const primary = rateLimits?.primary;
  const secondary = rateLimits?.secondary;
  if (!primary && !secondary) return "";
  const percent = Math.round(primary?.used_percent ?? secondary?.used_percent ?? 0);
  const tone = percent >= 90 ? "red" : percent >= 75 ? "yellow" : "cyan";
  const reset = primary?.resets_at ? `(${formatReset(primary.resets_at)})` : "";
  return metricLine("Usage", percent, tone, reset);
}

function weeklyUsageLine(rateLimits) {
  const weekly = rateLimits?.secondary;
  if (!weekly) return "";
  const percent = Math.round(weekly.used_percent);
  const tone = percent >= 90 ? "red" : percent >= 75 ? "yellow" : "cyan";
  const reset = weekly.resets_at ? `(${formatReset(weekly.resets_at)})` : "";
  return metricLine("7-day", percent, tone, reset);
}

function metricLine(label, percent, tone, suffix = "") {
  return [
    color("dim", pad(label, 8)),
    progressBar(percent, 10, tone),
    pad(color(tone, `${Math.round(percent)}%`), 5),
    color("dim", suffix),
  ].filter(Boolean).join(" ");
}

function formatReset(epochSeconds) {
  const seconds = Math.max(0, Number(epochSeconds) - Math.floor(Date.now() / 1000));
  if (!seconds) return "now";
  const hours = Math.floor(seconds / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  if (hours >= 24) return `${Math.round(hours / 24)}d`;
  if (hours) return `${hours}h ${minutes}m`;
  return `${minutes}m`;
}

function toolLine(tools) {
  const recent = tools.slice(-4);
  if (!recent.length) return "";
  return `${color("dim", pad("Tools", 8))} ${recent
    .map((tool) => `${tool.status === "running" ? spinner() : "✓"} ${tool.name}:${tool.detail}`)
    .join(" | ")}`;
}

function todoLine(todos) {
  if (!todos) return "";
  const percent = todos.total ? Math.round((todos.done / todos.total) * 100) : 0;
  const label = todos.active || "Todo";
  return `${color("dim", pad("Todo", 8))} ${progressBar(percent, 10, "green")} ${pad(`${percent}%`, 5)} ▸ ${label} ${color("dim", `(${todos.done}/${todos.total})`)}`;
}

function render() {
  const session = parseSession(newestSessionFile());
  const model = session.meta?.model || "codex";
  const header = [
    color("cyan", `[${model}]`),
    color("yellow", projectLabel(session.meta)),
    color("magenta", gitInfo()),
  ].filter(Boolean).join(` ${color("dim", "│")} `);
  const lines = [
    "codex-hud:",
    header,
    contextLine(session.token),
    usageLine(session.token?.rate_limits),
    weeklyUsageLine(session.token?.rate_limits),
  ].filter(Boolean);
  return `${lines.join("\n")}\n`;
}

function paint() {
  frame += 1;
  const output = render();
  if (watch && process.stdout.isTTY) {
    process.stdout.write("\x1b[2J\x1b[H");
  }
  process.stdout.write(output);
}

if (watch) {
  paint();
  setInterval(paint, intervalMs);
} else {
  paint();
}
