# LCKit backend application units (Go / Rust / any HTTP binary)
# SPDX-License-Identifier: Apache-2.0

: "${APPS_INDEX:=${LCKIT_STATE}/apps.tsv}"

apps_index_touch() {
  ensure_base_dirs
  if [[ ! -f "${APPS_INDEX}" ]]; then
    if ! mkdir -p "$(dirname "${APPS_INDEX}")" 2>/dev/null || ! : > "${APPS_INDEX}" 2>/dev/null; then
      return 0
    fi
  fi
  chmod 600 "${APPS_INDEX}" 2>/dev/null || true
}

apps_index_upsert() {
  local name="$1" unit="$2" bin="$3" port="$4" workdir="$5"
  apps_index_touch
  local tmp
  tmp="$(mktemp)"
  awk -F'\t' -v n="${name}" '$1 != n {print}' "${APPS_INDEX}" > "${tmp}" || true
  printf '%s\t%s\t%s\t%s\t%s\n' "${name}" "${unit}" "${bin}" "${port}" "${workdir}" >> "${tmp}"
  mv "${tmp}" "${APPS_INDEX}"
}

apps_index_drop() {
  local name="$1"
  apps_index_touch
  local tmp
  tmp="$(mktemp)"
  awk -F'\t' -v n="${name}" '$1 != n {print}' "${APPS_INDEX}" > "${tmp}" || true
  mv "${tmp}" "${APPS_INDEX}"
}

app_add() {
  local name="" bin="" port="8080" workdir="" user="root" extra="" pass_port="yes" force="no"
  local description="" 
  local -a envs=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --name) name="${2:-}"; shift 2 ;;
      --bin) bin="${2:-}"; shift 2 ;;
      --port) port="${2:-}"; shift 2 ;;
      --workdir) workdir="${2:-}"; shift 2 ;;
      --user) user="${2:-}"; shift 2 ;;
      --args) extra="${2:-}"; shift 2 ;;
      --env) envs+=("${2:-}"); shift 2 ;;
      --description) description="${2:-}"; shift 2 ;;
      --no-port-arg) pass_port="no"; shift ;;
      --force) force="yes"; shift ;;
      *) die "unknown app add option: $1" ;;
    esac
  done
  [[ -n "${name}" ]] || die "--name required"
  [[ -n "${bin}" ]] || die "--bin required"
  require_cmd_name "${name}" || die "invalid app name: ${name}"
  [[ "${port}" =~ ^[0-9]+$ ]] || die "invalid port: ${port}"
  if [[ -z "${workdir}" ]]; then
    workdir="$(dirname "${bin}")"
  fi
  if [[ -z "${description}" ]]; then
    description="LCKit backend ${name}"
  fi

  local unit
  unit="$(app_unit_name "${name}")"
  local path="${UNIT_DIR}/${unit}"
  if [[ -f "${path}" && "${force}" != "yes" ]]; then
    die "unit exists: ${unit} (use --force)"
  fi

  local exec_start="${bin}"
  if [[ "${pass_port}" == "yes" ]]; then
    exec_start+=" --port ${port}"
  fi
  if [[ -n "${extra}" ]]; then
    exec_start+=" ${extra}"
  fi

  {
    echo "[Unit]"
    echo "Description=${description}"
    echo "After=network-online.target"
    echo "Wants=network-online.target"
    echo
    echo "[Service]"
    echo "Type=simple"
    echo "User=${user}"
    echo "WorkingDirectory=${workdir}"
    echo "ExecStart=${exec_start}"
    echo "Restart=on-failure"
    echo "RestartSec=3"
    echo "LimitNOFILE=65535"
    local e
    for e in ${envs[@]+"${envs[@]}"}; do
      echo "Environment=\"${e}\""
    done
    echo
    echo "[Install]"
    echo "WantedBy=multi-user.target"
  } > "${path}"

  run "systemctl daemon-reload"
  try "systemctl enable ${unit}"
  try "systemctl restart ${unit}"
  apps_index_upsert "${name}" "${unit}" "${bin}" "${port}" "${workdir}"
  info "app unit ready: ${unit} (expected port ${port})"
  info "proxy example: lckit site add -d <domain> -t proxy --upstream http://127.0.0.1:${port}"
}

app_list() {
  apps_index_touch
  if [[ ! -s "${APPS_INDEX}" ]]; then
    echo "(no apps recorded)"
    return 0
  fi
  printf '%s\n' "NAME	UNIT	BIN	PORT	WORKDIR"
  cat "${APPS_INDEX}"
}

app_rm() {
  local name="${1:-}"
  [[ -n "${name}" ]] || die "usage: lckit app rm <name>"
  local unit
  unit="$(app_unit_name "${name}")"
  try "systemctl stop ${unit}"
  try "systemctl disable ${unit}"
  rm -f "${UNIT_DIR}/${unit}"
  run "systemctl daemon-reload"
  apps_index_drop "${name}"
  info "app removed: ${name}"
}

app_ctl() {
  local action="$1" name="${2:-}"
  [[ -n "${name}" ]] || die "usage: lckit app ${action} <name>"
  run "systemctl ${action} $(app_unit_name "${name}")"
}

app_usage() {
  cat <<'EOF'
Usage: lckit app <add|list|rm|start|stop|restart|status>

  lckit app add --name api --bin /opt/api/api --port 8080
      [--workdir DIR] [--user USER] [--args "..."] [--env K=V]
      [--no-port-arg] [--force]
  lckit app list
  lckit app rm <name>
  lckit app start|stop|restart|status <name>
EOF
}

cmd_app() {
  local sub="${1:-}"
  shift || true
  case "${sub}" in
    add) need_root; app_add "$@" ;;
    list|ls) app_list "$@" ;;
    rm|del) need_root; app_rm "$@" ;;
    start|stop|restart|status) need_root; app_ctl "${sub}" "$@" ;;
    ""|help|-h|--help) app_usage ;;
    *) die "unknown app subcommand: ${sub}" ;;
  esac
}
