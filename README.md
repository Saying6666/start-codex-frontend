# start-codex-frontend

Codex skill for starting or reusing the local Codex Web frontend service.

## Files

- `SKILL.md`: skill instructions
- `scripts/start.sh`: starts or checks the local frontend service
- `agents/openai.yaml`: optional display metadata

## Usage

Install this directory as a Codex skill, then ask Codex to start the frontend:

```text
启动 Codex 前端
```

You can also run the script directly from this directory:

```bash
bash scripts/start.sh
```

The script automatically selects an available local port and prints the URL after startup. It also reuses the last healthy service started by the script.

## Local Frontend Checkout

By default, the script checks for a local `codexui` checkout at:

```bash
${XDG_DATA_HOME:-$HOME/.local/share}/codex-frontend/codexui
```

If the checkout is missing, it clones:

```text
https://github.com/friuns2/codexui.git
```

It installs dependencies and builds the project when build outputs are missing, then starts the local build with:

```bash
node dist-cli/index.js --no-tunnel --no-login --port <selected-port>
```

To use a different checkout:

```bash
CODEX_FRONTEND_PROJECT_DIR=/path/to/codexui bash scripts/start.sh
```

To download through a Git proxy:

```bash
CODEX_FRONTEND_GIT_PROXY=http://127.0.0.1:7890 bash scripts/start.sh
```

To skip the local checkout and use the published npm package:

```bash
CODEX_FRONTEND_USE_LOCAL_PROJECT=0 bash scripts/start.sh
```

## Options

To prefer a specific port:

```bash
CODEX_FRONTEND_PORT=19000 bash scripts/start.sh
```

If the preferred port is unavailable, the script prints the alternate URL it selected.

To keep proxy variables in the launched process:

```bash
CODEX_FRONTEND_CLEAR_PROXY=0 bash scripts/start.sh
```

To skip install or build steps when managing the checkout yourself:

```bash
CODEX_FRONTEND_INSTALL_DEPS=0 CODEX_FRONTEND_BUILD_PROJECT=0 bash scripts/start.sh
```

Runtime files default to:

- Log: `/tmp/codex-frontend.log`
- PID: `/tmp/codex-frontend.pid`
- State: `/tmp/codex-frontend.env`
