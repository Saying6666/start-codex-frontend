---
name: start-codex-frontend
description: Use this skill when the user asks to start, open, launch, run, or check the Codex frontend, Codex Web UI, Codex browser UI, or says "前端", "启动前端", "打开前端", "Codex 前端", "Web 前端". It starts or reuses the local codexUI/codexapp service for using Codex in a browser.
---

# Start Codex Frontend

## Quick Start

Run the bundled script:

```bash
bash /home/wjy_2024/.codex/skills/start-codex-frontend/scripts/start.sh
```

The script:

- reuses an existing healthy service on the configured port
- otherwise starts `npx codexapp --no-tunnel --no-login`
- clears the broken local proxy variables for the launched process
- writes logs to `/tmp/codex-frontend.log`
- writes the background PID to `/tmp/codex-frontend.pid`

## Defaults

- Port: `18923`
- URL: `http://127.0.0.1:18923`
- Package: `codexapp`
- Public tunnel: disabled
- Forced login: disabled

To use a different port:

```bash
CODEX_FRONTEND_PORT=19000 bash /home/wjy_2024/.codex/skills/start-codex-frontend/scripts/start.sh
```

## Response

After running the script, tell the user:

- the local URL
- the password printed by the script, if present
- where logs are stored

If the script reports a blocker, summarize the exact blocker and the next command to run.
