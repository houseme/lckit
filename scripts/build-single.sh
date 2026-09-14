#!/usr/bin/env bash
# Assemble modular lib/*.sh into a single-file ./lckit
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${ROOT}/lckit"
{
  cat <<'HDR'
#!/usr/bin/env bash
# LCKit — Linux + Caddy Kit (single-file build)
# Independent implementation. Idea inspiration only; not derived from GPL sources.
# SPDX-License-Identifier: Apache-2.0
# Repository: https://github.com/houseme/lckit
#
# One-file install:
#   curl -fsSL https://raw.githubusercontent.com/houseme/lckit/main/lckit -o lckit
#   chmod +x lckit && sudo ./lckit setup
#
set -euo pipefail

LCKIT_HOME="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
export LCKIT_HOME
LCKIT_SINGLE_FILE=1

# ===== lib/core.sh =====
HDR
  sed '1,3d' "${ROOT}/lib/core.sh"
  echo; echo "# ===== lib/os.sh ====="
  sed '1,3d' "${ROOT}/lib/os.sh"
  echo; echo "# ===== lib/mirrors.sh ====="
  sed '1,3d' "${ROOT}/lib/mirrors.sh"
  echo; echo "# ===== lib/web.sh ====="
  sed '1,3d' "${ROOT}/lib/web.sh"
  echo; echo "# ===== lib/db.sh ====="
  sed '1,3d' "${ROOT}/lib/db.sh"
  echo; echo "# ===== lib/php.sh ====="
  sed '1,3d' "${ROOT}/lib/php.sh"
  echo; echo "# ===== lib/sites.sh ====="
  sed '1,3d' "${ROOT}/lib/sites.sh"
  echo; echo "# ===== lib/apps.sh ====="
  sed '1,3d' "${ROOT}/lib/apps.sh"
  echo; echo "# ===== lib/ui.sh ====="
  sed '1,3d' "${ROOT}/lib/ui.sh"
  echo; echo "# ===== CLI entry ====="
  # Keep usage+main from a small entry template (not sourced modules)
  cat <<'ENTRY'
usage() {
  cat <<'EOF'
LCKit — Linux + Caddy Kit

Usage:
  lckit setup              Interactive stack setup
  lckit site <cmd>         Manage sites (static | php | proxy)
  lckit app  <cmd>         Manage backend app units (Go/Rust/any HTTP binary)
  lckit db   <cmd>         Install / inspect MariaDB or PostgreSQL
  lckit php  <cmd>         Install / inspect PHP-FPM
  lckit mirror <cmd>       Show or switch package mirrors
  lckit doctor             Print environment summary
  lckit help               This help

Site commands:
  lckit site add -d example.com -t static|php|proxy [options]
  lckit site list | show <domain> | rm <domain>

App commands:
  lckit app add --name api --bin /opt/api/api --port 8080
  lckit app list | rm <name> | start|stop|restart|status <name>

Database (can be installed AFTER setup):
  lckit db install mariadb [--series 11.4] [--password SECRET]
  lckit db install postgresql [--password SECRET]
  lckit db status

PHP (can be installed AFTER setup):
  lckit php install [--version 8.4]
  lckit php status
  lckit php ext install redis opcache imagick memcached swoole ...
  lckit php ext install common|full
  lckit php ext list | status

Mirror commands:
  lckit mirror show | set official|tuna|aliyun|ustc | apply | list

Examples:
  lckit setup
  lckit db install mariadb
  lckit php install --version 8.4
  lckit site add -d api.example.com -t proxy --upstream http://127.0.0.1:8080

One-file install:
  curl -fsSL https://raw.githubusercontent.com/houseme/lckit/main/lckit -o lckit
  chmod +x lckit && sudo ./lckit setup

Repository: https://github.com/houseme/lckit
License:    Apache-2.0
EOF
}

main() {
  local cmd="${1:-help}"
  shift || true
  case "${cmd}" in
    setup|install) cmd_setup "$@" ;;
    site) cmd_site "$@" ;;
    app) cmd_app "$@" ;;
    db) cmd_db "$@" ;;
    php) cmd_php "$@" ;;
    mirror) cmd_mirror "$@" ;;
    doctor|status) cmd_doctor "$@" ;;
    help|-h|--help) usage ;;
    *) usage >&2; return 1 ;;
  esac
}

main "$@"
ENTRY
} > "${OUT}"
chmod +x "${OUT}"
bash -n "${OUT}"
echo "Built ${OUT} ($(wc -l < "${OUT}") lines)"
