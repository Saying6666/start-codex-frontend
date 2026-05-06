---
name: start-codex-frontend
description: Use this skill when the user asks to start, open, launch, run, or check the Codex frontend, Codex Web UI, Codex browser UI, or says "前端", "启动前端", "打开前端", "Codex 前端", "Web 前端". It starts or reuses the local codexUI/codexapp service for using Codex in a browser.
---

# Start Codex Frontend

## Quick Start

Run the bundled script from this skill directory:

```bash
bash scripts/start.sh
```

The script:

- reuses the last healthy service started by this script
- otherwise chooses an available local port automatically
- if `CODEX_FRONTEND_PORT` is set but unavailable, falls back to another available local port
- checks for a local Codex frontend project checkout
- clones the frontend project from GitHub if the checkout is missing
- installs dependencies and builds the local project if build outputs are missing
- starts the local build with `node dist-cli/index.js --no-tunnel --no-login`
- falls back to `npx codexapp --no-tunnel --no-login` only when local project mode is disabled
- clears local proxy environment variables for the launched process by default
- writes logs to `/tmp/codex-frontend.log`
- writes the background PID to `/tmp/codex-frontend.pid`
- writes the selected host, port, URL, PID, and project path to `/tmp/codex-frontend.env`
- validates the port and startup timeout before launching
- reports a clear next command when a blocker is detected

## Defaults

- Port: selected automatically
- URL: printed after startup
- Bind host used for port probing: `0.0.0.0`
- Package: `codexapp`
- Frontend repo: `https://github.com/friuns2/codexui.git`
- Frontend project directory: `${XDG_DATA_HOME:-$HOME/.local/share}/codex-frontend/codexui`
- Package manager: auto-detected, preferring `pnpm`
- Public tunnel: disabled
- Forced login: disabled
- Local proxy variables: cleared for the launched process

To prefer a specific port:

```bash
CODEX_FRONTEND_PORT=19000 bash scripts/start.sh
```

If that port is unavailable, the script prints the alternate URL it selected.

To use a different local project checkout:

```bash
CODEX_FRONTEND_PROJECT_DIR=/path/to/codexui bash scripts/start.sh
```

To download through a Git proxy:

```bash
CODEX_FRONTEND_GIT_PROXY=http://127.0.0.1:7890 bash scripts/start.sh
```

To skip the local project checkout and use the published npm package:

```bash
CODEX_FRONTEND_USE_LOCAL_PROJECT=0 bash scripts/start.sh
```

To skip install or build steps when managing the checkout yourself:

```bash
CODEX_FRONTEND_INSTALL_DEPS=0 CODEX_FRONTEND_BUILD_PROJECT=0 bash scripts/start.sh
```

If you need to run it without clearing proxy variables:

```bash
CODEX_FRONTEND_CLEAR_PROXY=0 bash scripts/start.sh
```

## Response

After running the script, tell the user:

- the local URL
- the password printed by the script, if present
- where logs are stored

If the script reports a blocker, summarize the exact blocker and the next command to run.
