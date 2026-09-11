# LCKit PHP-FPM installer
# SPDX-License-Identifier: Apache-2.0

# Globals filled by php_install; also persisted for later site add
PHP_FPM_UNIT=""
PHP_SOCKET=""

php_save_state() {
  ensure_base_dirs
  printf 'PHP_FPM_UNIT=%s\nPHP_SOCKET=%s\nPHP_VERSION=%s\n' \
    "${PHP_FPM_UNIT}" "${PHP_SOCKET}" "${1:-}" > "${LCKIT_STATE}/php"
}

php_load_state() {
  if [[ -f "${LCKIT_STATE}/php" ]]; then
    # shellcheck disable=SC1090
    source "${LCKIT_STATE}/php" || true
  fi
}

php_detect_socket() {
  if [[ -S /run/php/php-fpm.sock ]]; then
    echo "unix//run/php/php-fpm.sock"
    return 0
  fi
  if [[ -S /run/php-fpm/www.sock ]]; then
    echo "unix//run/php-fpm/www.sock"
    return 0
  fi
  php_load_state
  if [[ -n "${PHP_SOCKET:-}" ]]; then
    echo "${PHP_SOCKET}"
    return 0
  fi
  echo "unix//run/php/php-fpm.sock"
}

php_install() {
  local ver="${1:-8.4}"
  PHP_FPM_UNIT=""
  PHP_SOCKET=""

  if os_is_rhel; then
    case "$(os_major)" in
      8) run "dnf install -y https://rpms.remirepo.net/enterprise/remi-release-8.rpm" ;;
      9) run "dnf install -y https://rpms.remirepo.net/enterprise/remi-release-9.rpm" ;;
      10) run "dnf install -y https://rpms.remirepo.net/enterprise/remi-release-10.rpm" ;;
    esac
    run "dnf module reset -y php"
    run "dnf module install -y php:remi-${ver}"
    pkg_install php-fpm php-cli php-opcache php-mysqlnd php-pgsql php-gd php-mbstring php-xml php-intl
    PHP_FPM_UNIT="php-fpm"
    PHP_SOCKET="unix//run/php-fpm/www.sock"
    php_tune_rhel
  else
    local sury
    sury="$(mirror_sury_base)"
    [[ -n "${sury}" ]] || sury="https://packages.sury.org/php"
    if [[ "$(os_id)" == "debian" ]]; then
      run "curl -sSLo /usr/share/keyrings/deb.sury.org-php.gpg https://packages.sury.org/php/apt.gpg"
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/deb.sury.org-php.gpg] ${sury}/ $(os_codename) main" \
        > /etc/apt/sources.list.d/php.list
    else
      run "add-apt-repository -y ppa:ondrej/php"
    fi
    run "apt-get update"
    pkg_install \
      "php${ver}-common" "php${ver}-cli" "php${ver}-fpm" "php${ver}-opcache" \
      "php${ver}-mysql" "php${ver}-pgsql" "php${ver}-gd" "php${ver}-mbstring" \
      "php${ver}-xml" "php${ver}-curl" "php${ver}-intl" "php${ver}-zip" "php${ver}-sqlite3"
    PHP_FPM_UNIT="php${ver}-fpm"
    PHP_SOCKET="unix//run/php/php-fpm.sock"
    php_tune_deb "${ver}"
  fi

  run "systemctl enable --now ${PHP_FPM_UNIT}"
  try "systemctl restart ${PHP_FPM_UNIT}"
  php_save_state "${ver}"
  info "PHP ${ver} ready (unit=${PHP_FPM_UNIT}, socket=${PHP_SOCKET})"
}

_php_pool_user() {
  if id caddy >/dev/null 2>&1; then
    echo caddy
  elif id www-data >/dev/null 2>&1; then
    echo www-data
  else
    echo nginx
  fi
}

_php_ini_hardening() {
  local ini="$1"
  [[ -f "${ini}" ]] || return 0
  sed -i 's/^expose_php\s*=.*/expose_php = Off/' "${ini}"
  sed -i 's/^upload_max_filesize\s*=.*/upload_max_filesize = 64M/' "${ini}"
  sed -i 's/^post_max_size\s*=.*/post_max_size = 64M/' "${ini}"
  sed -i 's/^max_execution_time\s*=.*/max_execution_time = 60/' "${ini}"
  sed -i 's/^session.cookie_httponly\s*=.*/session.cookie_httponly = On/' "${ini}"
  sed -i 's/^session.cookie_secure\s*=.*/session.cookie_secure = On/' "${ini}"
  # Commented keys may need enabling
  if grep -q '^;session.cookie_httponly' "${ini}"; then
    sed -i 's/^;session.cookie_httponly\s*=.*/session.cookie_httponly = On/' "${ini}"
  fi
  if grep -q '^;session.cookie_secure' "${ini}"; then
    sed -i 's/^;session.cookie_secure\s*=.*/session.cookie_secure = On/' "${ini}"
  fi
  # Dangerous functions — only set if disable_functions line exists (avoid duplicating)
  if grep -qE '^;?disable_functions\s*=' "${ini}"; then
    sed -i 's/^;*disable_functions\s*=.*/disable_functions = exec,passthru,shell_exec,system,proc_open,popen,curl_multi_exec,parse_ini_file,show_source/' "${ini}"
  fi
}

_php_opcache_tune() {
  local ini_dir="$1"  # e.g. /etc/php/8.4/fpm/conf.d or /etc/php.d
  local f
  f="$(ls "${ini_dir}"/*opcache*.ini 2>/dev/null | head -n1 || true)"
  [[ -n "${f}" && -f "${f}" ]] || return 0
  cat >> "${f}" <<'EOF'
; LCKit opcache
opcache.enable=1
opcache.memory_consumption=128
opcache.interned_strings_buffer=16
opcache.max_accelerated_files=10000
opcache.validate_timestamps=0
EOF
}

_php_pool_performance() {
  local conf="$1"
  [[ -f "${conf}" ]] || return 0
  # ondemand is lighter for small VPS; dynamic is fine for busier hosts
  local mem_mb
  mem_mb="$(awk '/MemTotal/{printf "%d", $2/1024}' /proc/meminfo 2>/dev/null || echo 512)"
  if (( mem_mb < 1024 )); then
    sed -i 's/^pm\s*=.*/pm = ondemand/' "${conf}" || true
    sed -i 's/^pm.max_children\s*=.*/pm.max_children = 10/' "${conf}" || true
  else
    sed -i 's/^pm\s*=.*/pm = dynamic/' "${conf}" || true
    sed -i 's/^pm.max_children\s*=.*/pm.max_children = 20/' "${conf}" || true
    sed -i 's/^pm.start_servers\s*=.*/pm.start_servers = 4/' "${conf}" || true
    sed -i 's/^pm.min_spare_servers\s*=.*/pm.min_spare_servers = 2/' "${conf}" || true
    sed -i 's/^pm.max_spare_servers\s*=.*/pm.max_spare_servers = 8/' "${conf}" || true
  fi
  # Restrict pool listener if keys exist
  if grep -q '^;listen.allowed_clients' "${conf}"; then
    sed -i 's/^;listen.allowed_clients\s*=.*/listen.allowed_clients = 127.0.0.1/' "${conf}"
  fi
}

php_tune_rhel() {
  local conf=/etc/php-fpm.d/www.conf
  local user
  user="$(_php_pool_user)"
  [[ -f "${conf}" ]] || return 0
  sed -i "s/^user = .*/user = ${user}/" "${conf}"
  sed -i "s/^group = .*/group = ${user}/" "${conf}"
  sed -i "s/^;listen.acl_users = .*/listen.acl_users = apache,nginx,caddy/" "${conf}"
  _php_pool_performance "${conf}"
  _php_ini_hardening /etc/php.ini
  _php_opcache_tune /etc/php.d
}

php_tune_deb() {
  local ver="$1"
  local conf="/etc/php/${ver}/fpm/pool.d/www.conf"
  local ini="/etc/php/${ver}/fpm/php.ini"
  local user
  user="$(_php_pool_user)"
  [[ -f "${conf}" ]] || return 0
  sed -i "s/^user = .*/user = ${user}/" "${conf}"
  sed -i "s/^group = .*/group = ${user}/" "${conf}"
  mkdir -p /var/lib/lckit/php/{session,cache}
  chown -R "${user}:${user}" /var/lib/lckit/php 2>/dev/null || true
  chmod 750 /var/lib/lckit/php /var/lib/lckit/php/session /var/lib/lckit/php/cache 2>/dev/null || true
  _php_pool_performance "${conf}"
  _php_ini_hardening "${ini}"
  _php_opcache_tune "/etc/php/${ver}/fpm/conf.d"
  if ! grep -q 'php_value\[session.save_path\]' "${conf}"; then
    printf '\nphp_value[session.save_path] = /var/lib/lckit/php/session\n' >> "${conf}"
  fi
}

cmd_php() {
  local sub="${1:-status}"
  shift || true
  case "${sub}" in
    install)
      need_root
      local ver="8.4"
      while [[ $# -gt 0 ]]; do
        case "$1" in
          --version|-v) ver="${2:-8.4}"; shift 2 ;;
          8.2|8.3|8.4|8.5|7.4|8.0|8.1) ver="$1"; shift ;;
          *) die "unknown php install option: $1" ;;
        esac
      done
      php_install "${ver}"
      ;;
    status)
      php_load_state
      echo "version: ${PHP_VERSION:-unknown}"
      echo "unit:    ${PHP_FPM_UNIT:-unknown}"
      echo "socket:  ${PHP_SOCKET:-unknown}"
      if [[ -n "${PHP_FPM_UNIT:-}" ]]; then
        echo "active:  $(systemctl is-active "${PHP_FPM_UNIT}" 2>/dev/null || echo unknown)"
      fi
      ;;
    ""|help|-h|--help)
      cat <<'EOF'
Usage: lckit php <install|status>

  lckit php install [--version 8.4]
  lckit php install 8.3
  lckit php status

After install, create a PHP site:
  lckit site add -d blog.example.com -t php
EOF
      ;;
    *)
      die "unknown php subcommand: ${sub}"
      ;;
  esac
}
