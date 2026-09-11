# LCKit core helpers
# SPDX-License-Identifier: Apache-2.0
# Repository: https://github.com/houseme/lckit

: "${LCKIT_REPO:=https://github.com/houseme/lckit}"
: "${LCKIT_LICENSE:=Apache-2.0}"
: "${LCKIT_STATE:=/var/lib/lckit}"
: "${LCKIT_LOG:=/var/log/lckit.log}"
: "${LCKIT_ETC:=/etc/lckit}"
: "${WEB_ROOT:=/data/web}"
: "${WEB_DEFAULT:=/data/web/default}"
: "${CADDY_MAIN:=/etc/caddy/Caddyfile}"
: "${CADDY_SITES:=/etc/caddy/sites}"
: "${UNIT_DIR:=/etc/systemd/system}"
: "${PG_MAJOR:=18}"
# Passwords are generated at install time; this is only a last-resort fallback label.
: "${DB_DEFAULT_PASS:=}"

# shellcheck disable=SC2034
LCKIT_VERSION="1.0.0"

_color() {
  local c="$1"; shift
  printf '\033[%sm%s\033[0m' "${c}" "$*"
}
ok()   { _color "1;32" "$*"; }
warn() { _color "1;33" "$*"; }
err()  { _color "1;31" "$*"; }

log_line() {
  local level="$1"; shift
  local ts
  ts="$(date '+%Y-%m-%d %H:%M:%S')"
  local msg="[${ts}] [${level}] $*"
  mkdir -p "$(dirname "${LCKIT_LOG}")" 2>/dev/null || true
  printf '%s\n' "${msg}" | tee -a "${LCKIT_LOG}" 2>/dev/null || printf '%s\n' "${msg}"
}

info()  { log_line "INFO" "$*"; }
warnl() { log_line "WARN" "$(warn "$*")"; }
die()   { log_line "ERROR" "$(err "$*")" >&2; exit 2; }

have() { command -v "$1" >/dev/null 2>&1; }

need_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    die "Root privileges are required"
  fi
}

ensure_base_dirs() {
  mkdir -p \
    "${LCKIT_STATE}" \
    "${LCKIT_ETC}" \
    "${WEB_ROOT}" \
    "${CADDY_SITES}" \
    /var/log/caddy 2>/dev/null || true
}

run() {
  local cmdline="$1"
  info "run: ${cmdline}"
  if ! bash -c "${cmdline}" >>"${LCKIT_LOG}" 2>&1; then
    die "command failed: ${cmdline}"
  fi
}

try() {
  local cmdline="$1"
  info "try: ${cmdline}"
  if ! bash -c "${cmdline}" >>"${LCKIT_LOG}" 2>&1; then
    warnl "non-zero exit (ignored): ${cmdline}"
  fi
  return 0
}

# Join args into a package install command for the host platform.
pkg_install() {
  if os_is_rhel; then
    run "dnf install -y $*"
  else
    run "DEBIAN_FRONTEND=noninteractive apt-get install -y $*"
  fi
}

version_ge() {
  # true when $1 >= $2 (dotted)
  [[ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -n1)" == "$2" ]]
}

state_put() {
  local key="$1" value="$2"
  ensure_base_dirs
  printf '%s=%s\n' "${key}" "${value}" > "${LCKIT_STATE}/${key}"
}

state_get() {
  local key="$1"
  local file="${LCKIT_STATE}/${key}"
  if [[ -f "${file}" ]]; then
    # file content is key=value; return value only
    sed -n 's/^[^=]*=//p' "${file}" | head -n1
  fi
}

require_cmd_name() {
  local name="$1"
  [[ "${name}" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,62}$ ]]
}

require_domain() {
  local d="$1"
  [[ "${d}" =~ ^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?)*$ ]]
}

secret_dir() {
  echo "${LCKIT_STATE}/secrets"
}

secret_store() {
  local name="$1" value="$2"
  mkdir -p "$(secret_dir)"
  chmod 700 "$(secret_dir)" 2>/dev/null || true
  local f
  f="$(secret_dir)/${name}"
  printf '%s' "${value}" > "${f}"
  chmod 600 "${f}" 2>/dev/null || true
  # Never echo the secret
  info "secret stored: ${f}"
}

secret_read() {
  local name="$1"
  local f
  f="$(secret_dir)/${name}"
  [[ -f "${f}" ]] || return 1
  cat "${f}"
}

secret_generate() {
  # 24-char url-safe secret
  if have openssl; then
    openssl rand -base64 24 | tr -d '=+/' | cut -c1-24
  else
    tr -dc 'A-Za-z0-9' </dev/urandom | head -c 24
  fi
}

site_conf_path() {
  local domain="$1"
  echo "${CADDY_SITES}/${domain}.caddy"
}

site_docroot() {
  local domain="$1"
  echo "${WEB_ROOT}/${domain}"
}

app_unit_name() {
  echo "lckit-app-$1.service"
}
