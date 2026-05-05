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

You can also run the script directly:

```bash
bash scripts/start.sh
```

The default URL is:

```text
http://127.0.0.1:18923
```

To use a different port:

```bash
CODEX_FRONTEND_PORT=19000 bash scripts/start.sh
```
