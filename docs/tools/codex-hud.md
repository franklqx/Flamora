# Codex HUD

`tools/codex-hud.mjs` is a local, zero-dependency HUD for Codex CLI sessions.
It is inspired by Claude HUD, but it does not use Claude Code's `statusLine`
API because Codex CLI does not currently expose an equivalent stable statusline
extension point.

## Run

From this repository:

```sh
./tools/codex-hud
```

Watch mode:

```sh
./tools/codex-hud --watch
```

Useful with a split terminal or tmux pane:

```sh
CODEX_HUD_INTERVAL_MS=500 ./tools/codex-hud --watch
```

Disable ANSI colors:

```sh
./tools/codex-hud --no-color
```

Force ANSI colors when your terminal wrapper strips TTY detection:

```sh
./tools/codex-hud --watch --color
```

Use ASCII progress bars:

```sh
./tools/codex-hud --ascii
```

Optional global shortcut:

```sh
ln -sf "$PWD/tools/codex-hud" /usr/local/bin/codex-hud
```

After that, run:

```sh
codex-hud --watch --color
```

## Codex With HUD

`tools/codex-with-hud` starts Codex and the HUD together in tmux:

```sh
codex-with-hud
```

It creates or attaches to a tmux session named `codex-hud`, with Codex in the
top pane and the HUD in a 5-line bottom pane.

Optional settings:

```sh
CODEX_HUD_SESSION=flamora CODEX_HUD_HEIGHT=6 codex-with-hud
```

The default layout follows Claude HUD's ordering:

```text
[gpt-5.4] │ GitHub/Flamora │ git:(main*)
Context  ████░░░░░░ 38%   (99k/258k)
Usage    █░░░░░░░░░ 11%   (4h 48m)
7-day    ██████░░░░ 60%   (2d)
```

## What It Shows

- Model/session label from the latest `~/.codex/sessions/**/*.jsonl` file.
- Current project path and git branch, dirty marker, and ahead/behind counts.
- Context progress bar from Codex `token_count` events.
- Rate limit progress bars when Codex writes `rate_limits` into the session log.

## Limits

This is a sidecar HUD, not an embedded Codex TUI statusline. It cannot render
under the Codex input box unless Codex adds a native statusline/plugin API like
Claude Code's `statusLine`.

Codex's local session schema is not a public API, so future CLI versions may
change fields. The script is intentionally defensive and hides unavailable
sections instead of failing.
