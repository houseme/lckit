# LCKit database installers (MariaDB / PostgreSQL)
# SPDX-License-Identifier: Apache-2.0

# Persist last install metadata
db_mark_installed() {
  local engine="$1" detail="$2"
  ensure_base_dirs
  printf '%s\n' "${detail}" > "${LCKIT_STATE}/db-${engine}"
}

db_status_line() {
  local unit="$1"
  if systemctl list-unit-files "${unit}.service" >/dev/null 2>&1; then
    systemctl is-active "${unit}.service" 2>/dev/null || echo inactive
  else
    echo "not-installed"
  fi
}

_db_tune_mariadb_cnf() {
  local cnf="$1"
  [[ -f "${cnf}" ]] || return 0
  local mem_mb
  mem_mb="$(awk '/MemTotal/{printf "%d", $2/1024}' /proc/meminfo 2>/dev/null || echo 512)"
  local pool=128
  if (( mem_mb >= 4096 )); then pool=512
  elif (( mem_mb >= 2048 )); then pool=256
  elif (( mem_mb >= 1024 )); then pool=128
  else pool=64
  fi

  # Drop previous LCKit block if present, then append tuned settings
  if grep -q '^# BEGIN LCKit' "${cnf}" 2>/dev/null; then
    sed -i '/^# BEGIN LCKit/,/^# END LCKit/d' "${cnf}"
  fi

  # Prefer a dedicated drop-in when directory exists
  local dropin_dir=""
  if [[ -d /etc/mysql/mariadb.conf.d ]]; then
    dropin_dir=/etc/mysql/mariadb.conf.d
  elif [[ -d /etc/my.cnf.d ]]; then
    dropin_dir=/etc/my.cnf.d
  fi

  local content
  content=$(cat <<EOF
# BEGIN LCKit
[mysqld]
bind-address = 127.0.0.1
skip-name-resolve
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci
innodb_buffer_pool_size = ${pool}M
innodb_log_file_size = 64M
max_allowed_packet = 64M
max_connections = 100
# END LCKit
EOF
)
  if [[ -n "${dropin_dir}" ]]; then
    printf '%s\n' "${content}" > "${dropin_dir}/99-lckit.cnf"
  else
    printf '\n%s\n' "${content}" >> "${cnf}"
  fi
}

_db_set_mariadb_password() {
  local password="$1"
  # Avoid putting the password on argv when possible
  local defaults
  defaults="$(mktemp)"
  chmod 600 "${defaults}"
  cat > "${defaults}" <<EOF
[client]
user=root
password=${password}
EOF
  if ! mariadb --defaults-extra-file="${defaults}" -e "SELECT 1;" >/dev/null 2>&1; then
    # First boot: set password via unix socket without auth
    mariadb -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${password//\'/\\\'}';" 2>/dev/null \
      || mariadb -e "SET PASSWORD FOR 'root'@'localhost' = PASSWORD('${password//\'/\\\'}');" 2>/dev/null \
      || true
    # Remove anonymous users / test DB (best effort)
    mariadb -e "DELETE FROM mysql.user WHERE User=''; DROP DATABASE IF EXISTS test; FLUSH PRIVILEGES;" 2>/dev/null || true
  fi
  # Confirm
  if mariadb --defaults-extra-file="${defaults}" -e "SELECT 1;" >/dev/null 2>&1; then
    rm -f "${defaults}"
    return 0
  fi
  rm -f "${defaults}"
  warnl "MariaDB password confirmation failed; check service logs"
  return 0
}

db_install_mariadb() {
  local series="${1:-11.4}"
  local password="${2:-}"

  if [[ -z "${password}" ]]; then
    password="$(secret_generate)"
  fi
  secret_store "mariadb_root" "${password}"

  info "configuring MariaDB ${series} repositories"
  local setup=/tmp/lckit-mariadb-repo-setup.sh
  if ! curl -fsSL -o "${setup}" https://downloads.mariadb.com/MariaDB/mariadb_repo_setup; then
    curl -fsSL -o "${setup}" https://raw.githubusercontent.com/MariaDB/mariadb_repo_setup/main/mariadb_repo_setup \
      || die "unable to download MariaDB repo setup"
  fi
  chmod +x "${setup}"
  if os_is_rhel && [[ "$(os_major)" == "10" ]] && have update-crypto-policies; then
    try "update-crypto-policies --set LEGACY"
  fi
  if ! "${setup}" --mariadb-server-version="mariadb-${series}" >>"${LCKIT_LOG}" 2>&1; then
    warnl "MariaDB repo setup returned non-zero; continuing if packages exist"
  fi
  rm -f "${setup}"

  local cnf_path
  if os_is_rhel; then
    try "dnf config-manager --disable mariadb-maxscale"
    pkg_install MariaDB-common MariaDB-server MariaDB-client MariaDB-shared
    cnf_path=/etc/my.cnf.d/server.cnf
  else
    if [[ -f /etc/apt/sources.list.d/mariadb.list ]]; then
      sed -i 's|^deb \[arch=amd64,arm64\] https://dlm.mariadb.com/repo/maxscale/latest/apt|#&|' \
        /etc/apt/sources.list.d/mariadb.list || true
      local mb
      mb="$(mirror_mariadb_base)"
      if [[ -n "${mb}" ]]; then
        sed -i "s#https://dlm\.mariadb\.com/repo/#${mb}/repo/#g" /etc/apt/sources.list.d/mariadb.list || true
      fi
    fi
    run "apt-get update"
    run "DEBIAN_FRONTEND=noninteractive apt-get install -y mariadb-server mariadb-client"
    cnf_path=/etc/mysql/mariadb.conf.d/50-server.cnf
  fi

  _db_tune_mariadb_cnf "${cnf_path}"
  run "systemctl enable --now mariadb"
  sleep 2
  try "systemctl restart mariadb"
  sleep 1
  _db_set_mariadb_password "${password}"
  db_mark_installed mariadb "series=${series}"
  info "MariaDB ${series} ready on 127.0.0.1 (password stored in ${LCKIT_STATE}/secrets/mariadb_root)"
}

_db_tune_postgres() {
  local conf_dir="$1"
  local conf="${conf_dir}/postgresql.conf"
  [[ -f "${conf}" ]] || return 0
  local mem_mb
  mem_mb="$(awk '/MemTotal/{printf "%d", $2/1024}' /proc/meminfo 2>/dev/null || echo 512)"
  local shared=128
  if (( mem_mb >= 4096 )); then shared=256
  elif (( mem_mb >= 2048 )); then shared=128
  else shared=64
  fi
  cat >> "${conf}" <<EOF

# BEGIN LCKit
listen_addresses = 'localhost'
shared_buffers = ${shared}MB
effective_cache_size = $(( mem_mb * 3 / 4 ))MB
maintenance_work_mem = 64MB
max_connections = 100
# END LCKit
EOF
  local hba="${conf_dir}/pg_hba.conf"
  if [[ -f "${hba}" ]]; then
    # Local socket can stay peer for admin; TCP from localhost uses scram
    sed -i 's/^\(host\s\+all\s\+all\s\+127.0.0.1\/32\s\+\)md5/\1scram-sha-256/' "${hba}" || true
    sed -i 's/^\(host\s\+all\s\+all\s\+::1\/128\s\+\)md5/\1scram-sha-256/' "${hba}" || true
    sed -i 's/^\(host\s\+all\s\+all\s\+127.0.0.1\/32\s\+\)peer/\1scram-sha-256/' "${hba}" || true
  fi
}

db_install_postgresql() {
  local password="${1:-}"
  local major="${PG_MAJOR}"
  if [[ -z "${password}" ]]; then
    password="$(secret_generate)"
  fi
  secret_store "postgresql_postgres" "${password}"

  info "installing PostgreSQL ${major} via PGDG"
  if os_is_rhel; then
    local maj conf_dir
    maj="$(os_major)"
    run "dnf install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-${maj}-\$(uname -m)/pgdg-redhat-repo-latest.noarch.rpm"
    try "dnf -qy module disable postgresql"
    pkg_install "postgresql${major}-server" "postgresql${major}" "postgresql${major}-contrib"
    run "/usr/pgsql-${major}/bin/postgresql-${major}-setup initdb"
    conf_dir="/var/lib/pgsql/${major}/data"
    _db_tune_postgres "${conf_dir}"
    run "systemctl enable --now postgresql-${major}"
    sleep 2
    try "sudo -u postgres psql -c \"ALTER USER postgres WITH PASSWORD '${password//\'/\\\'}';\""
    db_mark_installed postgresql "major=${major} unit=postgresql-${major}"
  else
    local codename pg
    codename="$(os_codename)"
    [[ -n "${codename}" ]] || die "cannot detect distro codename"
    pg="$(mirror_pgdg_base)"
    pkg_install postgresql-common
    install -d /usr/share/postgresql-common/pgdg
    run "curl -fsSL -o /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc https://www.postgresql.org/media/keys/ACCC4CF8.asc"
    echo "deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc] ${pg} ${codename}-pgdg main" \
      > /etc/apt/sources.list.d/pgdg.list
    run "apt-get update"
    run "DEBIAN_FRONTEND=noninteractive apt-get install -y postgresql-${major} postgresql-client-${major}"
    # Cluster conf usually /etc/postgresql/<ver>/main
    local conf_dir="/etc/postgresql/${major}/main"
    if [[ ! -d "${conf_dir}" ]]; then
      conf_dir="$(find /etc/postgresql -maxdepth 2 -type d -name main 2>/dev/null | head -n1 || true)"
    fi
    [[ -n "${conf_dir}" ]] && _db_tune_postgres "${conf_dir}"
    run "systemctl enable --now postgresql"
    sleep 2
    try "sudo -u postgres psql -c \"ALTER USER postgres WITH PASSWORD '${password//\'/\\\'}';\""
    try "systemctl restart postgresql"
    db_mark_installed postgresql "major=${major} unit=postgresql"
  fi
  info "PostgreSQL ${major} ready on localhost (password stored in ${LCKIT_STATE}/secrets/postgresql_postgres)"
}

cmd_db() {
  local sub="${1:-status}"
  shift || true
  case "${sub}" in
    install)
      need_root
      local engine="" series="11.4" password=""
      while [[ $# -gt 0 ]]; do
        case "$1" in
          mariadb)
            engine="mariadb"
            shift
            ;;
          postgresql|postgres)
            engine="postgresql"
            shift
            ;;
          --series) series="${2:-11.4}"; shift 2 ;;
          --password) password="${2:-}"; shift 2 ;;
          *) die "unknown db install option: $1" ;;
        esac
      done
      case "${engine}" in
        mariadb)
          db_install_mariadb "${series}" "${password}"
          ;;
        postgresql)
          db_install_postgresql "${password}"
          ;;
        *)
          die "usage: lckit db install mariadb|postgresql [--series 11.4] [--password SECRET]"
          ;;
      esac
      ;;
    status)
      echo "mariadb:     $(db_status_line mariadb)"
      echo "postgresql:  $(db_status_line postgresql)"
      if [[ "$(os_is_rhel && echo yes || echo no)" == "yes" ]]; then
        echo "postgresql-${PG_MAJOR}: $(db_status_line "postgresql-${PG_MAJOR}")"
      fi
      ;;
    ""|help|-h|--help)
      cat <<'EOF'
Usage: lckit db <install|status>

  lckit db install mariadb [--series 11.4] [--password SECRET]
  lckit db install postgresql [--password SECRET]
  lckit db status

Notes:
  - If --password is omitted, a strong random password is generated
    and stored under /var/lib/lckit/secrets/ (mode 0600).
  - Databases listen on localhost only.
EOF
      ;;
    *)
      die "unknown db subcommand: ${sub}"
      ;;
  esac
}
