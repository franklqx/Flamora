---
description: Show the current Codex usage HUD with context, token, and rate-limit status.
---

# Codex HUD

Run the local HUD command and relay its output exactly enough for the user to see current usage:

```bash
codex-hud --color
```

If `codex-hud` is not available on `PATH`, run:

```bash
/Users/frankli/.local/bin/codex-hud --color
```

If the user asks for a compact one-line HUD, use:

```bash
codex-hud --compact --color
```

If the user asks for a live HUD, use:

```bash
codex-hud --watch --color
```

Treat this as local Codex telemetry, not billing data.
