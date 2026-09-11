# LCKit database installers (MariaDB / PostgreSQL)
# SPDX-License-Identifier: Apache-2.0

db_install_mariadb() {
  local series="${1:-11.4}"
  local password="${2:-${DB_DEFAULT_PASS}}"

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
  try "${setup} --mariadb-server-version=mariadb-${series}"
  rm -f "${setup}"

  local cnf_path
  if os_is_rhel; then
    try "dnf config-manager --disable mariadb-maxscale"
    pkg_install MariaDB-common MariaDB-server MariaDB-client MariaDB-shared MariaDB-backup
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
    run "DEBIAN_FRONTEND=noninteractive apt-get install -y mariadb-common mariadb-server mariadb-client mariadb-backup"
    cnf_path=/etc/mysql/mariadb.conf.d/50-server.cnf
  fi

  if [[ -f "${cnf_path}" ]]; then
    if grep -q '^\[mysqld\]' "${cnf_path}"; then
      sed -i "/^\[mysqld\]/a character-set-server = utf8mb4" "${cnf_path}" || true
    fi
  fi

  run "systemctl enable --now mariadb"
  sleep 2
  mariadb -e "ALTER USER 'root'@'localhost' IDENTIFIED VIA mysql_native_password USING PASSWORD('${password}');" 2>/dev/null \
    || mariadb -e "SET PASSWORD FOR 'root'@'localhost' = PASSWORD('${password}');" 2>/dev/null \
    || true
  mariadb -uroot -p"${password}" -e "FLUSH PRIVILEGES;" 2>/dev/null || true
  info "MariaDB ${series} ready (root password set)"
}

db_install_postgresql() {
  local password="${1:-${DB_DEFAULT_PASS}}"
  local major="${PG_MAJOR}"

  info "installing PostgreSQL ${major} via PGDG"
  if os_is_rhel; then
    local maj
    maj="$(os_major)"
    run "dnf install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-${maj}-\$(uname -m)/pgdg-redhat-repo-latest.noarch.rpm"
    try "dnf -qy module disable postgresql"
    pkg_install "postgresql${major}-server" "postgresql${major}" "postgresql${major}-contrib"
    run "/usr/pgsql-${major}/bin/postgresql-${major}-setup initdb"
    run "systemctl enable --now postgresql-${major}"
    local hba="/var/lib/pgsql/${major}/data/pg_hba.conf"
    if [[ -f "${hba}" ]]; then
      sed -i 's/^\(local\s\+all\s\+all\s\+\)peer/\1scram-sha-256/' "${hba}" || true
      sed -i 's/^\(host\s\+all\s\+all\s\+127.0.0.1\/32\s\+\)md5/\1scram-sha-256/' "${hba}" || true
      systemctl restart "postgresql-${major}"
      sleep 2
    fi
    try "sudo -u postgres psql -c \"ALTER USER postgres WITH PASSWORD '${password}';\""
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
    run "systemctl enable --now postgresql"
    sleep 2
    try "sudo -u postgres psql -c \"ALTER USER postgres WITH PASSWORD '${password}';\""
  fi
  info "PostgreSQL ${major} ready"
}
