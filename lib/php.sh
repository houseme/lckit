# LCKit PHP-FPM installer
# SPDX-License-Identifier: Apache-2.0

# Globals filled by php_install; also persisted for later site add
PHP_FPM_UNIT=""
PHP_SOCKET=""

php_save_state() {
  ensure_base_dirs
  mkdir -p /var/lib/lckit/php-data 2>/dev/null || true
  # Avoid clashing with /var/lib/lckit/php session directory
  printf 'PHP_FPM_UNIT=%s\nPHP_SOCKET=%s\nPHP_VERSION=%s\n' \
    "${PHP_FPM_UNIT}" "${PHP_SOCKET}" "${1:-}" > "${LCKIT_STATE}/php.env"
}

php_load_state() {
  if [[ -f "${LCKIT_STATE}/php.env" ]]; then
    # shellcheck disable=SC1090
    source "${LCKIT_STATE}/php.env" || true
  fi
}

php_detect_socket() {
  # Prefer live sockets on disk (Ubuntu/ondrej uses /run/php/phpX.Y-fpm.sock)
  local s
  if [[ -d /run/php ]]; then
    # newest versioned socket first
    s="$(ls -1 /run/php/*.sock 2>/dev/null | sort -V | tail -n1 || true)"
    if [[ -n "${s}" && -S "${s}" ]]; then
      echo "unix//${s}"
      return 0
    fi
  fi
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
    PHP_SOCKET="unix//run/php/php${ver}-fpm.sock"
    php_tune_deb "${ver}"
    # Resolve the real socket after tune/restart
    PHP_SOCKET="$(php_detect_socket)"
    php_save_state "${ver}"
  fi

  run "systemctl enable --now ${PHP_FPM_UNIT}"
  try "systemctl restart ${PHP_FPM_UNIT}"
  sleep 1
  # Re-detect socket after FPM is up (Ubuntu uses phpX.Y-fpm.sock)
  PHP_SOCKET="$(php_detect_socket)"
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
  # Allow Caddy (or pool user) to connect to the FPM socket
  if grep -qE '^;?listen.owner' "${conf}"; then
    sed -i "s/^;*listen.owner\s*=.*/listen.owner = ${user}/" "${conf}"
  fi
  if grep -qE '^;?listen.group' "${conf}"; then
    sed -i "s/^;*listen.group\s*=.*/listen.group = ${user}/" "${conf}"
  fi
  if grep -qE '^;?listen.mode' "${conf}"; then
    sed -i "s/^;*listen.mode\s*=.*/listen.mode = 0660/" "${conf}"
  fi
  if grep -qE '^;?listen.acl_users' "${conf}"; then
    sed -i "s/^;*listen.acl_users\s*=.*/listen.acl_users = caddy,nginx,apache,${user}/" "${conf}"
  fi
  # Ubuntu default listen path is versioned — keep it, detect later
  if grep -qE '^;?listen\s*=' "${conf}"; then
    sed -i "s|^;*listen\s*=.*|listen = /run/php/php${ver}-fpm.sock|" "${conf}"
  fi
  mkdir -p /var/lib/lckit/php/session /var/lib/lckit/php/cache
  chown -R "${user}:${user}" /var/lib/lckit/php 2>/dev/null || true
  chmod 750 /var/lib/lckit/php /var/lib/lckit/php/session /var/lib/lckit/php/cache 2>/dev/null || true
  _php_pool_performance "${conf}"
  _php_ini_hardening "${ini}"
  _php_opcache_tune "/etc/php/${ver}/fpm/conf.d"
  if ! grep -q 'php_value\[session.save_path\]' "${conf}"; then
    printf '\nphp_value[session.save_path] = /var/lib/lckit/php/session\n' >> "${conf}"
  fi
}

# ---------------------------------------------------------------------------
# PHP extensions
# ---------------------------------------------------------------------------

# Known extension aliases -> logical name
php_ext_normalize() {
  local raw
  raw="$(echo "$1" | tr '[:upper:]' '[:lower:]')"
  case "${raw}" in
    php_redis|php-redis) echo redis ;;
    php_opcache|php-opcache|zendopcache) echo opcache ;;
    php_imagick|php-pecl-imagick|imagick) echo imagick ;;
    php_memcached|php-memcached) echo memcached ;;
    php_sodium|php-sodium|sodium|libsodium) echo sodium ;;
    php_swoole|php-swoole|swoole) echo swoole ;;
    php_imap|php-imap|imap) echo imap ;;
    php_bz2|php-bz2|bz2) echo bz2 ;;
    php_ldap|php-ldap|ldap) echo ldap ;;
    php_fileinfo|php-fileinfo|fileinfo) echo fileinfo ;;
    php_exif|php-exif|exif) echo exif ;;
    php_mysql|php-mysql|mysqli|pdo_mysql) echo mysql ;;
    php_pgsql|php-pgsql|pgsql|pdo_pgsql) echo pgsql ;;
    php_gd|php-gd|gd) echo gd ;;
    php_mbstring|php-mbstring|mbstring) echo mbstring ;;
    php_xml|php-xml|xml|dom|simplexml) echo xml ;;
    php_curl|php-curl|curl) echo curl ;;
    php_intl|php-intl|intl) echo intl ;;
    php_zip|php-zip|zip) echo zip ;;
    php_sqlite3|php-sqlite3|sqlite3) echo sqlite3 ;;
    php_redis|redis) echo redis ;;
    ioncube|ioncube_loader|loader) echo ioncube ;;
    sourceguardian|ixed|ixed.7|ixed.8) echo sourceguardian ;;
    xcache) echo xcache ;;
    eaccelerator) echo eaccelerator ;;
    *) echo "${raw}" ;;
  esac
}

php_ext_available_list() {
  cat <<'EOF'
# Core / common (usually packaged with PHP)
opcache
gd
mbstring
xml
curl
intl
zip
bcmath
calendar
exif
ffi
fileinfo
ftp
gettext
iconv
pdo
shmop
sockets
sysvmsg
sysvsem
sysvshm
tokenizer
# Database
mysql
mysqli
pdo_mysql
pgsql
pdo_pgsql
sqlite3
pdo_sqlite
# Popular PECL / extra
redis
memcached
imagick
swoole
apcu
igbinary
msgpack
mongodb
amqp
# Mail / directory
imap
ldap
# Compression
bz2
zstd
lz4
# Crypto
sodium
# Commercial loaders (special)
ioncube
sourceguardian
# Obsolete (PHP 5 era — not installable on modern PHP)
xcache
eaccelerator
EOF
}

# Map logical ext name -> package name(s) for current OS
php_ext_packages() {
  local ext="$1"
  local ver="${2:-}"
  if os_is_rhel; then
    case "${ext}" in
      opcache) echo "php-opcache" ;;
      redis) echo "php-pecl-redis" ;;
      memcached) echo "php-pecl-memcached" ;;
      imagick) echo "php-pecl-imagick" ;;
      swoole) echo "php-pecl-swoole" ;;
      apcu) echo "php-pecl-apcu" ;;
      igbinary) echo "php-pecl-igbinary" ;;
      msgpack) echo "php-pecl-msgpack" ;;
      mongodb) echo "php-pecl-mongodb" ;;
      amqp) echo "php-pecl-amqp" ;;
      bz2) echo "php-bz2" ;;
      zstd) echo "php-zstd" ;;
      lz4) echo "php-lz4" ;;
      sodium) echo "php-sodium" ;;
      imap) echo "php-imap" ;;
      ldap) echo "php-ldap" ;;
      exif) echo "php-exif" ;;
      fileinfo) echo "php-process" ;; # fileinfo often in php-common/process on RHEL
      gd) echo "php-gd" ;;
      mbstring) echo "php-mbstring" ;;
      xml) echo "php-xml" ;;
      curl) echo "php-pecl-curl" ;;
      intl) echo "php-intl" ;;
      zip) echo "php-pecl-zip" ;;
      bcmath) echo "php-bcmath" ;;
      mysql|mysqli|pdo_mysql) echo "php-mysqlnd" ;;
      pgsql|pdo_pgsql) echo "php-pgsql" ;;
      sqlite3|pdo_sqlite) echo "php-pdo" ;;
      *) echo "php-${ext}" ;;
    esac
  else
    # Debian / Ubuntu (sury / ondrej)
    local p="php${ver}-${ext}"
    case "${ext}" in
      opcache) p="php${ver}-opcache" ;;
      mysql|mysqli|pdo_mysql) p="php${ver}-mysql" ;;
      pgsql|pdo_pgsql) p="php${ver}-pgsql" ;;
      sqlite3|pdo_sqlite) p="php${ver}-sqlite3" ;;
      fileinfo) p="" ;; # bundled
      iconv|pdo|tokenizer|shmop|sockets|sysvmsg|sysvsem|sysvshm|calendar|ftp|gettext)
        p="" ;; # usually bundled in common/cli
      ioncube|sourceguardian|xcache|eaccelerator)
        p="" ;;
      *) p="php${ver}-${ext}" ;;
    esac
    echo "${p}"
  fi
}

php_ext_is_loaded() {
  local ext="$1"
  local ver="${2:-}"
  local bin="php"
  if [[ -n "${ver}" ]] && have "php${ver}"; then
    bin="php${ver}"
  fi
  # opcache appears as "Zend OPcache" in php -m
  local pattern="^${ext}$"
  if [[ "${ext}" == "opcache" ]]; then
    pattern='^(Zend OPcache|opcache)$'
  fi
  "${bin}" -m 2>/dev/null | grep -qiE "${pattern}"
}

php_ext_bundle_common() {
  echo "opcache gd mbstring xml curl intl zip bcmath exif fileinfo sqlite3"
}

php_ext_bundle_full() {
  echo "$(php_ext_bundle_common) redis memcached imagick imap ldap bz2 sodium mysql pgsql"
}

php_ext_install_one() {
  local ext="$1"
  local ver="${2:-}"

  case "${ext}" in
    xcache|eaccelerator)
      warnl "${ext} is obsolete (PHP 5 era) and not supported on modern PHP — skipped"
      return 0
      ;;
    ioncube)
      php_ext_install_ioncube "${ver}"
      return $?
      ;;
    sourceguardian)
      php_ext_install_sourceguardian "${ver}"
      return $?
      ;;
  esac

  if php_ext_is_loaded "${ext}" "${ver}"; then
    info "extension already loaded: ${ext}"
    return 0
  fi

  local pkgs
  pkgs="$(php_ext_packages "${ext}" "${ver}")"
  if [[ -z "${pkgs}" ]]; then
    info "extension '${ext}' is typically bundled — checking load state only"
    php_ext_is_loaded "${ext}" "${ver}" && return 0
    warnl "extension not loaded and no package mapping: ${ext}"
    return 0
  fi

  info "installing packages for ${ext}: ${pkgs}"
  # shellcheck disable=SC2086
  pkg_install ${pkgs} || {
    warnl "package install failed for ${ext} (${pkgs})"
    return 1
  }
  return 0
}

php_ext_restart() {
  php_load_state
  local unit="${PHP_FPM_UNIT:-}"
  if [[ -z "${unit}" ]]; then
    if [[ -n "${PHP_VERSION:-}" ]] && [[ -f "/etc/php/${PHP_VERSION}/fpm/pool.d/www.conf" ]]; then
      unit="php${PHP_VERSION}-fpm"
    elif os_is_rhel; then
      unit="php-fpm"
    fi
  fi
  if [[ -n "${unit}" ]]; then
    try "systemctl restart ${unit}"
  fi
}

# ionCube Loader — commercial; download from official site (best effort)
php_ext_install_ioncube() {
  local ver="${1:-}"
  php_load_state
  ver="${ver:-${PHP_VERSION:-8.4}}"
  local arch
  arch="$(uname -m)"
  case "${arch}" in
    x86_64|amd64) arch=x86-64 ;;
    aarch64|arm64) arch=aarch64 ;;
    *) warnl "unsupported arch for ionCube: ${arch}"; return 1 ;;
  esac
  local ver_nodot="${ver//./}"
  local url="https://downloads.ioncube.com/loader_downloads/ioncube_loaders_lin_${arch}.tar.gz"
  local tmp=/tmp/ioncube_loaders.tgz
  info "downloading ionCube loaders"
  if ! curl -fsSL -o "${tmp}" "${url}"; then
    warnl "ionCube download failed; install manually from https://www.ioncube.com/loaders.php"
    return 1
  fi
  local dir=/opt/ioncube
  mkdir -p "${dir}"
  tar zxf "${tmp}" -C /opt
  rm -f "${tmp}"
  local so
  so="$(find /opt -name "ioncube_loader_lin_${ver}.so" 2>/dev/null | head -n1)"
  if [[ -z "${so}" ]]; then
    warnl "no ionCube loader for PHP ${ver}"
    return 1
  fi
  local confd=""
  if os_is_rhel; then
    confd=/etc/php.d
  else
    confd="/etc/php/${ver}/fpm/conf.d"
    mkdir -p "${confd}" "/etc/php/${ver}/cli/conf.d"
  fi
  local line="zend_extension=${so}"
  if [[ -n "${confd}" && -d "${confd}" ]]; then
    echo "${line}" > "${confd}/00-ioncube.ini"
    if [[ -d "/etc/php/${ver}/cli/conf.d" ]]; then
      echo "${line}" > "/etc/php/${ver}/cli/conf.d/00-ioncube.ini"
    fi
  else
    warnl "cannot locate PHP conf.d for ionCube"
    return 1
  fi
  info "ionCube loader installed (${so})"
  return 0
}

# SourceGuardian loader — commercial; best effort
php_ext_install_sourceguardian() {
  local ver="${1:-}"
  php_load_state
  ver="${ver:-${PHP_VERSION:-8.4}}"
  local arch
  arch="$(uname -m)"
  case "${arch}" in
    x86_64|amd64) arch=x86-64 ;;
    aarch64|arm64) arch=aarch64 ;;
    *) warnl "unsupported arch for SourceGuardian: ${arch}"; return 1 ;;
  esac
  local url="https://www.sourceguardian.com/loaders/download/loaders.lin-${arch}.tar.gz"
  local tmp=/tmp/ixed-loaders.tgz
  info "downloading SourceGuardian loaders"
  if ! curl -fsSL -o "${tmp}" "${url}"; then
    warnl "SourceGuardian download failed; see https://www.sourceguardian.com/loaders.php"
    return 1
  fi
  local dir=/opt/sourceguardian
  mkdir -p "${dir}"
  tar zxf "${tmp}" -C "${dir}" || true
  rm -f "${tmp}"
  local so
  so="$(find "${dir}" -name "ixed.${ver}*.lin" 2>/dev/null | head -n1)"
  if [[ -z "${so}" ]]; then
    # try ixed.8.4.lin style already extracted flat
    so="$(find "${dir}" /opt -name "ixed.${ver}.lin" 2>/dev/null | head -n1)"
  fi
  if [[ -z "${so}" ]]; then
    warnl "no SourceGuardian loader for PHP ${ver}; place ixed.${ver}.lin manually"
    return 1
  fi
  local confd=""
  if os_is_rhel; then
    confd=/etc/php.d
  else
    confd="/etc/php/${ver}/fpm/conf.d"
    mkdir -p "${confd}"
  fi
  echo "extension=${so}" > "${confd}/00-sourceguardian.ini"
  info "SourceGuardian loader installed (${so})"
  return 0
}

php_ext_install_many() {
  local ver="${1:-}"
  shift || true
  php_load_state
  ver="${ver:-${PHP_VERSION:-8.4}}"
  if [[ -z "${ver}" || "${ver}" == "unknown" ]]; then
    # try detect
    if have php; then
      ver="$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;' 2>/dev/null || echo 8.4)"
    else
      ver=8.4
    fi
  fi

  local -a wanted=()
  local item norm
  for item in "$@"; do
    case "${item}" in
      common|default)
        # shellcheck disable=SC2046
        wanted+=($(php_ext_bundle_common))
        ;;
      full|all)
        # shellcheck disable=SC2046
        wanted+=($(php_ext_bundle_full))
        ;;
      *)
        norm="$(php_ext_normalize "${item}")"
        wanted+=("${norm}")
        ;;
    esac
  done

  if [[ ${#wanted[@]} -eq 0 ]]; then
    die "usage: lckit php ext install <name...|common|full>"
  fi

  local ext failed=0
  for ext in "${wanted[@]}"; do
    php_ext_install_one "${ext}" "${ver}" || failed=$((failed + 1))
  done
  php_ext_restart
  info "extension install finished (failed=${failed})"
  echo
  php_ext_status
  return 0
}

php_ext_status() {
  php_load_state
  local ver="${PHP_VERSION:-}"
  local bin="php"
  if [[ -n "${ver}" ]] && have "php${ver}"; then
    bin="php${ver}"
  fi
  echo "php binary: $(command -v "${bin}" 2>/dev/null || echo missing)"
  echo "version:    $(${bin} -v 2>/dev/null | head -n1 || echo unknown)"
  echo
  echo "loaded modules:"
  ${bin} -m 2>/dev/null | sed 's/^/  /' || true
  echo
  echo "selected checks:"
  local e
  for e in opcache redis memcached imagick swoole sodium imap ldap bz2 fileinfo exif gd; do
    if php_ext_is_loaded "${e}" "${ver}"; then
      printf '  %-12s OK\n' "${e}"
    else
      printf '  %-12s --\n' "${e}"
    fi
  done
}

cmd_php_ext() {
  local sub="${1:-list}"
  shift || true
  case "${sub}" in
    install|add)
      need_root
      local ver=""
      local -a names=()
      while [[ $# -gt 0 ]]; do
        case "$1" in
          --version|-v) ver="${2:-}"; shift 2 ;;
          *) names+=("$1"); shift ;;
        esac
      done
      php_ext_install_many "${ver}" "${names[@]}"
      ;;
    list|available)
      php_ext_available_list
      ;;
    status|ls)
      php_ext_status
      ;;
    ""|help|-h|--help)
      cat <<'EOF'
Usage: lckit php ext <install|list|status>

  lckit php ext install redis opcache imagick memcached
  lckit php ext install common          # opcache, gd, mbstring, xml, curl, intl, zip, ...
  lckit php ext install full            # common + redis/memcached/imagick/imap/ldap/sodium/bz2/db
  lckit php ext install ioncube         # commercial loader (best-effort download)
  lckit php ext install sourceguardian
  lckit php ext list
  lckit php ext status

Notes:
  - xcache / eaccelerator are obsolete (PHP 5) and skipped on modern PHP.
  - ionCube / SourceGuardian require their official loaders; install is best-effort.
  - fileinfo/iconv/pdo/etc. are often already bundled — install is a no-op if loaded.
EOF
      ;;
    *)
      die "unknown php ext subcommand: ${sub}"
      ;;
  esac
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
    ext|extensions)
      cmd_php_ext "$@"
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
Usage: lckit php <install|ext|status>

  lckit php install [--version 8.4]
  lckit php install 8.3
  lckit php status
  lckit php ext install redis imagick memcached swoole
  lckit php ext install common
  lckit php ext install full
  lckit php ext list
  lckit php ext status

After install, create a PHP site:
  lckit site add -d blog.example.com -t php
EOF
      ;;
    *)
      die "unknown php subcommand: ${sub}"
      ;;
  esac
}
