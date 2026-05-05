#!/usr/bin/env bash
set -euo pipefail

PORT="${CODEX_FRONTEND_PORT:-18923}"
HOST="${CODEX_FRONTEND_HOST:-127.0.0.1}"
LOG_FILE="${CODEX_FRONTEND_LOG:-/tmp/codex-frontend.log}"
PID_FILE="${CODEX_FRONTEND_PID:-/tmp/codex-frontend.pid}"
URL="http://${HOST}:${PORT}"

is_healthy() {
  curl -fsS --max-time 2 "${URL}/" >/dev/null 2>&1
}

print_running() {
  echo "Codex frontend is running."
  echo "URL: ${URL}"
  if [[ -f "${LOG_FILE}" ]]; then
    password="$(grep -Eo 'Password: .+' "${LOG_FILE}" | tail -1 | sed 's/^Password: //')"
    if [[ -n "${password:-}" ]]; then
      echo "Password: ${password}"
    else
      echo "Password: not found in ${LOG_FILE}"
    fi
  else
    echo "Password: service was not started by this script; check the original terminal output"
  fi
  echo "Log: ${LOG_FILE}"
}

if is_healthy; then
  print_running
  exit 0
fi

if [[ -f "${PID_FILE}" ]]; then
  old_pid="$(cat "${PID_FILE}" 2>/dev/null || true)"
  if [[ -n "${old_pid}" ]] && kill -0 "${old_pid}" 2>/dev/null; then
    echo "Found process ${old_pid}, but ${URL} is not healthy yet."
    echo "Log: ${LOG_FILE}"
    exit 1
  fi
fi

if ! command -v node >/dev/null 2>&1; then
  echo "Node.js is required but was not found in PATH." >&2
  exit 1
fi

if ! command -v npx >/dev/null 2>&1; then
  echo "npx is required but was not found in PATH." >&2
  exit 1
fi

if ! command -v codex >/dev/null 2>&1; then
  echo "Codex CLI is required but was not found in PATH." >&2
  exit 1
fi

mkdir -p "$(dirname "${LOG_FILE}")"
: > "${LOG_FILE}"

(
  unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY all_proxy
  exec npx -y codexapp --no-tunnel --no-login --port "${PORT}"
) >>"${LOG_FILE}" 2>&1 &

pid="$!"
echo "${pid}" > "${PID_FILE}"

for _ in $(seq 1 45); do
  if is_healthy; then
    print_running
    exit 0
  fi
  if ! kill -0 "${pid}" 2>/dev/null; then
    echo "Codex frontend failed to start." >&2
    echo "Log: ${LOG_FILE}" >&2
    tail -80 "${LOG_FILE}" >&2 || true
    exit 1
  fi
  sleep 1
done

echo "Codex frontend process started but did not become healthy within 45 seconds." >&2
echo "PID: ${pid}" >&2
echo "URL: ${URL}" >&2
echo "Log: ${LOG_FILE}" >&2
tail -80 "${LOG_FILE}" >&2 || true
exit 1
