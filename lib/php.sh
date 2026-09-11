# LCKit PHP-FPM installer
# SPDX-License-Identifier: Apache-2.0

# Globals filled by php_install
PHP_FPM_UNIT=""
PHP_SOCKET=""

php_install() {
  local ver="$1"
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

php_tune_rhel() {
  local conf=/etc/php-fpm.d/www.conf
  local user
  user="$(_php_pool_user)"
  [[ -f "${conf}" ]] || return 0
  sed -i "s/^user = .*/user = ${user}/" "${conf}"
  sed -i "s/^group = .*/group = ${user}/" "${conf}"
  sed -i "s/^;listen.acl_users = .*/listen.acl_users = apache,nginx,caddy/" "${conf}"
  local ini=/etc/php.ini
  if [[ -f "${ini}" ]]; then
    sed -i 's/^expose_php = .*/expose_php = Off/' "${ini}"
    sed -i 's/^upload_max_filesize = .*/upload_max_filesize = 128M/' "${ini}"
    sed -i 's/^post_max_size = .*/post_max_size = 128M/' "${ini}"
  fi
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
  if [[ -f "${ini}" ]]; then
    sed -i 's/^expose_php = .*/expose_php = Off/' "${ini}"
    sed -i 's/^upload_max_filesize = .*/upload_max_filesize = 128M/' "${ini}"
    sed -i 's/^post_max_size = .*/post_max_size = 128M/' "${ini}"
  fi
  # session path via pool extra
  if ! grep -q 'php_value\[session.save_path\]' "${conf}"; then
    printf '\nphp_value[session.save_path] = /var/lib/lckit/php/session\n' >> "${conf}"
  fi
}
