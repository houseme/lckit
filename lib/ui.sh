# LCKit interactive setup & doctor
# SPDX-License-Identifier: Apache-2.0

_ask_yn() {
  local prompt="$1" default="$2"
  local ans
  read -r -p "${prompt} [${default}]: " ans || true
  ans="${ans:-${default}}"
  case "${ans}" in
    [Yy]|[Yy][Ee][Ss]) echo "yes" ;;
    *) echo "no" ;;
  esac
}

_ask_mirror() {
  local choice
  cat >&2 <<'EOF'
Mirror profile:
  1) official
  2) tuna
  3) aliyun
  4) ustc
EOF
  while true; do
    read -r -p "Select mirror [1]: " choice || true
    choice="${choice:-1}"
    case "${choice}" in
      1) echo "official"; return ;;
      2) echo "tuna"; return ;;
      3) echo "aliyun"; return ;;
      4) echo "ustc"; return ;;
      *) echo "invalid, try again" >&2 ;;
    esac
  done
}

_ask_mariadb_series() {
  local c
  echo "MariaDB series: 1) 10.11  2) 11.4  3) 11.8" >&2
  read -r -p "Select [2]: " c || true
  case "${c:-2}" in
    1) echo "10.11" ;;
    3) echo "11.8" ;;
    *) echo "11.4" ;;
  esac
}

_ask_php_ver() {
  local c
  echo "PHP version: 1) 8.2  2) 8.3  3) 8.4  4) 8.5" >&2
  read -r -p "Select [3]: " c || true
  case "${c:-3}" in
    1) echo "8.2" ;;
    2) echo "8.3" ;;
    4) echo "8.5" ;;
    *) echo "8.4" ;;
  esac
}

_ask_secret() {
  local label="$1"
  local val
  read -r -s -p "${label} (default: ${DB_DEFAULT_PASS}): " val || true
  echo
  echo "${val:-${DB_DEFAULT_PASS}}"
}

cmd_setup() {
  need_root
  ensure_base_dirs

  info "LCKit ${LCKIT_VERSION} setup"
  local mprof
  mprof="$(_ask_mirror)"
  mirror_set_profile "${mprof}"

  local want_caddy want_mariadb want_php want_pg
  want_caddy="$(_ask_yn "Install Caddy web front-end?" "Y")"
  want_mariadb="$(_ask_yn "Install MariaDB (optional)?" "n")"
  want_php="$(_ask_yn "Install PHP-FPM (optional)?" "n")"
  want_pg="$(_ask_yn "Install PostgreSQL ${PG_MAJOR} (optional)?" "n")"

  if [[ "${want_caddy}" == "no" && "${want_mariadb}" == "no" \
     && "${want_php}" == "no" && "${want_pg}" == "no" ]]; then
    die "select at least one component"
  fi

  local mariadb_series="" php_ver="" db_pass="" pg_pass=""
  [[ "${want_mariadb}" == "yes" ]] && mariadb_series="$(_ask_mariadb_series)"
  [[ "${want_php}" == "yes" ]] && php_ver="$(_ask_php_ver)"
  [[ "${want_mariadb}" == "yes" ]] && db_pass="$(_ask_secret "MariaDB root password")"
  [[ "${want_pg}" == "yes" ]] && pg_pass="$(_ask_secret "PostgreSQL postgres password")"

  echo
  info "summary:"
  echo "  mirror:     ${mprof}"
  echo "  caddy:      ${want_caddy}"
  echo "  mariadb:    ${want_mariadb} ${mariadb_series}"
  echo "  php:        ${want_php} ${php_ver}"
  echo "  postgresql: ${want_pg} ${PG_MAJOR}"
  echo
  read -r -p "Press Enter to continue or Ctrl+C to abort... " _

  sys_prepare

  if [[ "${want_caddy}" == "yes" ]]; then
    web_install_and_configure
  fi
  if [[ "${want_mariadb}" == "yes" ]]; then
    db_install_mariadb "${mariadb_series}" "${db_pass}"
  fi
  if [[ "${want_php}" == "yes" ]]; then
    php_install "${php_ver}"
  fi
  if [[ "${want_pg}" == "yes" ]]; then
    db_install_postgresql "${pg_pass}"
  fi

  # Install CLI tree under /usr/local
  local lckit_libhome=/usr/local/lib/lckit
  mkdir -p "${lckit_libhome}"
  cp -f "${LCKIT_HOME}/lckit" "${lckit_libhome}/lckit"
  rm -rf "${lckit_libhome}/lib" "${lckit_libhome}/share"
  cp -a "${LCKIT_HOME}/lib" "${lckit_libhome}/lib"
  cp -a "${LCKIT_HOME}/share" "${lckit_libhome}/share"
  cat > /usr/local/bin/lckit <<WRAP
#!/usr/bin/env bash
exec bash ${lckit_libhome}/lckit "\$@"
WRAP
  chmod +x /usr/local/bin/lckit "${lckit_libhome}/lckit"

  info "CLI installed: /usr/local/bin/lckit"
  cmd_doctor
  info "setup complete"
}

cmd_doctor() {
  echo "LCKit ${LCKIT_VERSION}"
  echo "host:    $(os_pretty) ($(uname -m))"
  echo "mirror:  $(mirror_profile)"
  echo "webroot: ${WEB_ROOT}"
  echo "sites:   ${CADDY_SITES}"
  echo "secrets: ${LCKIT_STATE}/secrets"
  echo
  echo "services:"
  local s st
  for s in caddy mariadb postgresql "postgresql-${PG_MAJOR}" php-fpm php8.2-fpm php8.3-fpm php8.4-fpm php8.5-fpm; do
    if systemctl list-unit-files "${s}.service" >/dev/null 2>&1; then
      st="$(systemctl is-active "${s}.service" 2>/dev/null || echo inactive)"
      printf '  %-18s %s\n' "${s}" "${st}"
    fi
  done
  # app units
  local unit
  for unit in /etc/systemd/system/lckit-app-*.service; do
    [[ -e "${unit}" ]] || continue
    st="$(systemctl is-active "$(basename "${unit}")" 2>/dev/null || echo inactive)"
    printf '  %-18s %s\n' "$(basename "${unit}")" "${st}"
  done
  echo
  echo "components:"
  if declare -F cmd_db >/dev/null 2>&1; then
    cmd_db status 2>/dev/null | sed 's/^/  /' || true
  fi
  if declare -F cmd_php >/dev/null 2>&1; then
    cmd_php status 2>/dev/null | sed 's/^/  /' || true
  fi
  echo
  echo "sites:"
  site_list || true
  echo
  echo "apps:"
  app_list || true
}
