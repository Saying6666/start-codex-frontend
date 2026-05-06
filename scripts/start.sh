#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
SKILL_DIR="$(CDPATH= cd -- "${SCRIPT_DIR}/.." && pwd -P)"

PORT="${CODEX_FRONTEND_PORT:-}"
HOST="${CODEX_FRONTEND_HOST:-127.0.0.1}"
BIND_HOST="${CODEX_FRONTEND_BIND_HOST:-0.0.0.0}"
LOG_FILE="${CODEX_FRONTEND_LOG:-/tmp/codex-frontend.log}"
PID_FILE="${CODEX_FRONTEND_PID:-/tmp/codex-frontend.pid}"
STATE_FILE="${CODEX_FRONTEND_STATE:-/tmp/codex-frontend.env}"
URL=""
START_TIMEOUT="${CODEX_FRONTEND_START_TIMEOUT:-45}"
NPX_PACKAGE="${CODEX_FRONTEND_PACKAGE:-codexapp}"
CACHE_PACKAGE="${CODEX_FRONTEND_NPX_PACKAGE:-${NPX_PACKAGE}}"
CLEAR_PROXY="${CODEX_FRONTEND_CLEAR_PROXY:-1}"
PROJECT_REPO="${CODEX_FRONTEND_PROJECT_REPO:-https://github.com/friuns2/codexui.git}"
PROJECT_DIR="${CODEX_FRONTEND_PROJECT_DIR:-${XDG_DATA_HOME:-${HOME}/.local/share}/codex-frontend/codexui}"
GIT_PROXY="${CODEX_FRONTEND_GIT_PROXY:-}"
USE_LOCAL_PROJECT="${CODEX_FRONTEND_USE_LOCAL_PROJECT:-1}"
PACKAGE_MANAGER="${CODEX_FRONTEND_PACKAGE_MANAGER:-auto}"
INSTALL_DEPS="${CODEX_FRONTEND_INSTALL_DEPS:-1}"
BUILD_PROJECT="${CODEX_FRONTEND_BUILD_PROJECT:-1}"
PROJECT_ENTRY=""

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

url_for_port() {
  printf 'http://%s:%s' "${HOST}" "$1"
}

is_healthy() {
  curl -fsS --max-time 2 "${URL}/" >/dev/null 2>&1
}

is_healthy_port() {
  curl -fsS --max-time 2 "$(url_for_port "$1")/" >/dev/null 2>&1
}

valid_port() {
  [[ "$1" =~ ^[0-9]+$ ]] && (( $1 >= 1 && $1 <= 65535 ))
}

last_state_port() {
  [[ -f "${STATE_FILE}" ]] || return 1
  sed -n 's/^PORT=//p' "${STATE_FILE}" | tail -1
}

last_state_pid() {
  [[ -f "${STATE_FILE}" ]] || return 1
  sed -n 's/^PID=//p' "${STATE_FILE}" | tail -1
}

is_own_healthy_port() {
  local port="$1"
  local state_port state_pid

  state_port="$(last_state_port 2>/dev/null || true)"
  state_pid="$(last_state_pid 2>/dev/null || true)"

  [[ "${state_port}" == "${port}" ]] || return 1
  [[ -n "${state_pid}" ]] || return 1
  kill -0 "${state_pid}" 2>/dev/null || return 1
  is_healthy_port "${port}"
}

run_git() {
  if [[ -n "${GIT_PROXY}" ]]; then
    git -c "http.proxy=${GIT_PROXY}" -c "https.proxy=${GIT_PROXY}" "$@"
  else
    git "$@"
  fi
}

detect_package_manager() {
  if [[ "${PACKAGE_MANAGER}" != "auto" ]]; then
    printf '%s' "${PACKAGE_MANAGER}"
    return 0
  fi

  if [[ -f "${PROJECT_DIR}/pnpm-lock.yaml" ]] || grep -q '"pnpm ' "${PROJECT_DIR}/package.json" 2>/dev/null; then
    printf 'pnpm'
    return 0
  fi

  if command_exists pnpm; then
    printf 'pnpm'
    return 0
  fi

  printf 'npm'
}

run_package_manager() {
  local manager="$1"
  shift

  case "${manager}" in
    pnpm)
      pnpm "$@"
      ;;
    npm)
      npm "$@"
      ;;
    *)
      echo "Unsupported CODEX_FRONTEND_PACKAGE_MANAGER: ${manager}" >&2
      echo "Next command: CODEX_FRONTEND_PACKAGE_MANAGER=pnpm bash \"${SCRIPT_DIR}/start.sh\"" >&2
      exit 1
      ;;
  esac
}

install_dependencies() {
  local manager="$1"

  [[ "${INSTALL_DEPS}" != "0" ]] || return 0

  case "${manager}" in
    pnpm)
      if ! command_exists pnpm; then
        if command_exists corepack; then
          corepack enable >/dev/null 2>&1 || true
        fi
      fi
      if ! command_exists pnpm; then
        echo "pnpm is required for this frontend project but was not found in PATH." >&2
        echo "Next command: npm install -g pnpm && bash \"${SCRIPT_DIR}/start.sh\"" >&2
        exit 1
      fi
      [[ -d "${PROJECT_DIR}/node_modules" ]] || run_package_manager pnpm install
      ;;
    npm)
      if ! command_exists npm; then
        print_blocker "npm is required but was not found in PATH."
        exit 1
      fi
      [[ -d "${PROJECT_DIR}/node_modules" ]] || run_package_manager npm install
      ;;
  esac
}

build_frontend_project() {
  local manager="$1"

  [[ "${BUILD_PROJECT}" != "0" ]] || return 0
  [[ -f "${PROJECT_DIR}/dist-cli/index.js" ]] && [[ -d "${PROJECT_DIR}/dist" ]] && return 0

  case "${manager}" in
    pnpm)
      run_package_manager pnpm run build
      ;;
    npm)
      run_package_manager npm run build:frontend
      run_package_manager npm run build:cli
      ;;
  esac
}

ensure_frontend_project() {
  [[ "${USE_LOCAL_PROJECT}" != "0" ]] || return 0

  if [[ -d "${PROJECT_DIR}/.git" ]]; then
    echo "Frontend project: ${PROJECT_DIR}"
  elif [[ -e "${PROJECT_DIR}" ]] && [[ -n "$(find "${PROJECT_DIR}" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]; then
    echo "Frontend project path exists but is not a Git checkout: ${PROJECT_DIR}" >&2
    echo "Next command: CODEX_FRONTEND_PROJECT_DIR=<empty-or-git-dir> bash \"${SCRIPT_DIR}/start.sh\"" >&2
    exit 1
  elif ! command_exists git; then
    print_blocker "Git is required to download the Codex frontend project but was not found in PATH."
    exit 1
  else
    mkdir -p "$(dirname "${PROJECT_DIR}")"
    echo "Frontend project not found; cloning ${PROJECT_REPO} to ${PROJECT_DIR}."
    if ! run_git clone --depth 1 "${PROJECT_REPO}" "${PROJECT_DIR}"; then
      echo "Failed to download the Codex frontend project." >&2
      echo "Repo: ${PROJECT_REPO}" >&2
      echo "Target: ${PROJECT_DIR}" >&2
      echo "Next command: CODEX_FRONTEND_PROJECT_DIR=<empty-dir> bash \"${SCRIPT_DIR}/start.sh\"" >&2
      exit 1
    fi
  fi

  if [[ ! -f "${PROJECT_DIR}/package.json" ]]; then
    echo "Frontend project is missing package.json: ${PROJECT_DIR}" >&2
    echo "Next command: CODEX_FRONTEND_PROJECT_DIR=<codexui-checkout> bash \"${SCRIPT_DIR}/start.sh\"" >&2
    exit 1
  fi

  manager="$(detect_package_manager)"
  echo "Frontend package manager: ${manager}"
  (
    cd "${PROJECT_DIR}"
    install_dependencies "${manager}"
    build_frontend_project "${manager}"
  )

  PROJECT_ENTRY="${PROJECT_DIR}/dist-cli/index.js"
  if [[ ! -f "${PROJECT_ENTRY}" ]]; then
    echo "Frontend project build did not produce ${PROJECT_ENTRY}." >&2
    echo "Next command: CODEX_FRONTEND_BUILD_PROJECT=1 bash \"${SCRIPT_DIR}/start.sh\"" >&2
    exit 1
  fi
}

choose_free_port() {
  node - "${BIND_HOST}" "${1:-}" <<'NODE'
const net = require("net");
const host = process.argv[2];
const preferred = process.argv[3];

function canBind(port) {
  return new Promise((resolve) => {
    const server = net.createServer();
    server.unref();
    server.once("error", () => resolve(false));
    server.listen({ host, port }, () => server.close(() => resolve(true)));
  });
}

async function main() {
  const wanted = Number(preferred);
  if (Number.isInteger(wanted) && wanted >= 1 && wanted <= 65535 && await canBind(wanted)) {
    console.log(wanted);
    return;
  }

  const server = net.createServer();
  server.unref();
  server.once("error", (error) => {
    console.error(error.message);
    process.exit(1);
  });
  server.listen({ host, port: 0 }, () => {
    const address = server.address();
    server.close(() => console.log(address.port));
  });
}

main();
NODE
}

extract_password() {
  [[ -f "${LOG_FILE}" ]] || return 1
  sed -n 's/.*Password:[[:space:]]*//p' "${LOG_FILE}" | tail -1
}

print_running() {
  echo "Codex frontend is running."
  echo "URL: ${URL}"
  if [[ -f "${LOG_FILE}" ]]; then
    password="$(extract_password 2>/dev/null || true)"
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

print_blocker() {
  echo "$1" >&2
  echo "Next command: bash \"${SCRIPT_DIR}/start.sh\"" >&2
}

if [[ -n "${PORT}" ]] && ! valid_port "${PORT}"; then
  print_blocker "Invalid CODEX_FRONTEND_PORT: ${PORT}"
  exit 1
fi

if ! [[ "${START_TIMEOUT}" =~ ^[0-9]+$ ]] || (( START_TIMEOUT < 1 )); then
  print_blocker "Invalid CODEX_FRONTEND_START_TIMEOUT: ${START_TIMEOUT}"
  exit 1
fi

if ! command_exists curl; then
  print_blocker "curl is required but was not found in PATH."
  exit 1
fi

if [[ -n "${PORT}" ]] && is_own_healthy_port "${PORT}"; then
  URL="$(url_for_port "${PORT}")"
  print_running
  exit 0
fi

if [[ -z "${PORT}" ]]; then
  previous_port="$(last_state_port 2>/dev/null || true)"
  if [[ -n "${previous_port:-}" ]] && valid_port "${previous_port}" && is_own_healthy_port "${previous_port}"; then
    PORT="${previous_port}"
    URL="$(url_for_port "${PORT}")"
    print_running
    exit 0
  fi
fi

if ! command_exists node; then
  print_blocker "Node.js is required but was not found in PATH."
  exit 1
fi

ensure_frontend_project

if [[ -z "${PROJECT_ENTRY}" ]] && ! command_exists npx; then
  print_blocker "npx is required but was not found in PATH."
  exit 1
fi

requested_port="${PORT:-}"
PORT="$(choose_free_port "${requested_port}" 2>/tmp/codex-frontend-port-error.log || true)"
if [[ -z "${PORT}" ]] || ! valid_port "${PORT}"; then
  print_blocker "Could not find an available local port on ${HOST}."
  if [[ -s /tmp/codex-frontend-port-error.log ]]; then
    tail -20 /tmp/codex-frontend-port-error.log >&2 || true
  fi
  exit 1
fi

if [[ -n "${requested_port}" ]] && [[ "${PORT}" != "${requested_port}" ]]; then
  echo "Port ${requested_port} is not available; using ${PORT} instead."
fi

URL="$(url_for_port "${PORT}")"

mkdir -p "$(dirname "${LOG_FILE}")"
mkdir -p "$(dirname "${PID_FILE}")"
mkdir -p "$(dirname "${STATE_FILE}")"
: > "${LOG_FILE}"

(
  if [[ "${CLEAR_PROXY}" != "0" ]]; then
    unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY all_proxy
  fi
  if [[ -n "${PROJECT_ENTRY}" ]]; then
    cd "${PROJECT_DIR}"
    exec node "${PROJECT_ENTRY}" --no-tunnel --no-login --port "${PORT}"
  fi

  cd "${SKILL_DIR}"
  exec npx -y "${CACHE_PACKAGE}" --no-tunnel --no-login --port "${PORT}"
) >>"${LOG_FILE}" 2>&1 &

pid="$!"
echo "${pid}" > "${PID_FILE}"
{
  echo "HOST=${HOST}"
  echo "BIND_HOST=${BIND_HOST}"
  echo "PORT=${PORT}"
  echo "URL=${URL}"
  echo "PID=${pid}"
  echo "PROJECT_DIR=${PROJECT_DIR}"
  echo "PROJECT_REPO=${PROJECT_REPO}"
} > "${STATE_FILE}"

for _ in $(seq 1 "${START_TIMEOUT}"); do
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

echo "Codex frontend process started but did not become healthy within ${START_TIMEOUT} seconds." >&2
echo "PID: ${pid}" >&2
echo "URL: ${URL}" >&2
echo "Log: ${LOG_FILE}" >&2
tail -80 "${LOG_FILE}" >&2 || true
exit 1
