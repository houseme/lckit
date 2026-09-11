# LCKit package mirror profiles
# SPDX-License-Identifier: Apache-2.0

MIRROR_FILE="${LCKIT_ETC}/mirror.conf"
MIRROR_BACKUP="${LCKIT_STATE}/mirror-backup"

mirror_profile() {
  if [[ -f "${MIRROR_FILE}" ]]; then
    # shellcheck disable=SC1090
    source "${MIRROR_FILE}" || true
  fi
  case "${LCKIT_MIRROR:-official}" in
    official|tuna|aliyun|ustc) echo "${LCKIT_MIRROR:-official}" ;;
    *) echo "official" ;;
  esac
}

mirror_set_profile() {
  local p="$1"
  case "${p}" in
    official|tuna|aliyun|ustc) ;;
    *) die "unknown mirror profile: ${p}" ;;
  esac
  ensure_base_dirs
  printf 'LCKIT_MIRROR=%s\n' "${p}" > "${MIRROR_FILE}"
  info "mirror profile -> ${p}"
}

mirror_label() {
  case "$1" in
    official) echo "Official upstream" ;;
    tuna)     echo "TUNA (Tsinghua)" ;;
    aliyun)   echo "Aliyun" ;;
    ustc)     echo "USTC" ;;
  esac
}

mirror_debian_base() {
  case "$(mirror_profile)" in
    official) echo "http://deb.debian.org/debian" ;;
    tuna)     echo "https://mirrors.tuna.tsinghua.edu.cn/debian" ;;
    aliyun)   echo "https://mirrors.aliyun.com/debian" ;;
    ustc)     echo "https://mirrors.ustc.edu.cn/debian" ;;
  esac
}

mirror_debian_security() {
  case "$(mirror_profile)" in
    official) echo "http://security.debian.org/debian-security" ;;
    tuna)     echo "https://mirrors.tuna.tsinghua.edu.cn/debian-security" ;;
    aliyun)   echo "https://mirrors.aliyun.com/debian-security" ;;
    ustc)     echo "https://mirrors.ustc.edu.cn/debian-security" ;;
  esac
}

mirror_ubuntu_base() {
  case "$(mirror_profile)" in
    official) echo "http://archive.ubuntu.com/ubuntu" ;;
    tuna)     echo "https://mirrors.tuna.tsinghua.edu.cn/ubuntu" ;;
    aliyun)   echo "https://mirrors.aliyun.com/ubuntu" ;;
    ustc)     echo "https://mirrors.ustc.edu.cn/ubuntu" ;;
  esac
}

mirror_epel_base() {
  case "$(mirror_profile)" in
    official) echo "https://dl.fedoraproject.org/pub/epel" ;;
    tuna)     echo "https://mirrors.tuna.tsinghua.edu.cn/epel" ;;
    aliyun)   echo "https://mirrors.aliyun.com/epel" ;;
    ustc)     echo "https://mirrors.ustc.edu.cn/epel" ;;
  esac
}

mirror_pgdg_base() {
  case "$(mirror_profile)" in
    official) echo "https://apt.postgresql.org/pub/repos/apt" ;;
    tuna)     echo "https://mirrors.tuna.tsinghua.edu.cn/postgresql/repos/apt" ;;
    aliyun)   echo "https://mirrors.aliyun.com/postgresql/repos/apt" ;;
    ustc)     echo "https://mirrors.ustc.edu.cn/postgresql/repos/apt" ;;
  esac
}

mirror_mariadb_base() {
  case "$(mirror_profile)" in
    official) echo "" ;;
    tuna)     echo "https://mirrors.tuna.tsinghua.edu.cn/mariadb" ;;
    aliyun)   echo "https://mirrors.aliyun.com/mariadb" ;;
    ustc)     echo "" ;;
  esac
}

mirror_sury_base() {
  case "$(mirror_profile)" in
    official) echo "https://packages.sury.org/php" ;;
    tuna)     echo "https://mirrors.tuna.tsinghua.edu.cn/sury/php" ;;
    *)        echo "" ;;
  esac
}

_mirror_backup() {
  local f="$1"
  [[ -f "${f}" ]] || return 0
  mkdir -p "${MIRROR_BACKUP}"
  local key="${f//\//_}"
  [[ -f "${MIRROR_BACKUP}/${key}" ]] || cp -a "${f}" "${MIRROR_BACKUP}/${key}"
}

mirror_rewire_epel() {
  local profile
  profile="$(mirror_profile)"
  [[ "${profile}" == "official" ]] && return 0
  local base
  base="$(mirror_epel_base)"
  local f
  for f in /etc/yum.repos.d/epel.repo /etc/yum.repos.d/epel-modular.repo; do
    [[ -f "${f}" ]] || continue
    _mirror_backup "${f}"
    sed -i 's/^metalink=/#metalink=/g' "${f}"
    sed -i "s#https\?://download\.fedoraproject\.org/pub/epel#${base}#g" "${f}"
    sed -i "s#https\?://dl\.fedoraproject\.org/pub/epel#${base}#g" "${f}"
  done
  try "dnf makecache"
}

mirror_rewire_debian_os() {
  local profile
  profile="$(mirror_profile)"
  [[ "${profile}" == "official" ]] && return 0
  os_is_debian_family || return 0

  local deb secpkg
  deb="$(mirror_debian_base)"
  local files=()
  [[ -f /etc/apt/sources.list ]] && files+=(/etc/apt/sources.list)
  if [[ -d /etc/apt/sources.list.d ]]; then
    local n
    while IFS= read -r n; do
      files+=("${n}")
    done < <(find /etc/apt/sources.list.d -maxdepth 1 -type f \( -name '*.list' -o -name '*.sources' \) 2>/dev/null)
  fi

  local f base
  for f in "${files[@]}"; do
    [[ -f "${f}" ]] || continue
    base="$(basename "${f}")"
    case "${base}" in
      caddy*|php*|pgdg*|mariadb*|docker*|nodesource*) continue ;;
    esac
    _mirror_backup "${f}"
    if os_is_rhel; then
      :
    elif [[ "$(os_id)" == "debian" ]]; then
      secpkg="$(mirror_debian_security)"
      sed -i "s#https\?://deb\.debian\.org/debian#${deb}#g" "${f}"
      sed -i "s#https\?://security\.debian\.org/debian-security#${secpkg}#g" "${f}"
    else
      local ubu
      ubu="$(mirror_ubuntu_base)"
      sed -i "s#https\?://archive\.ubuntu\.com/ubuntu#${ubu}#g" "${f}"
      sed -i "s#https\?://security\.ubuntu\.com/ubuntu#${ubu}#g" "${f}"
    fi
  done
  try "apt-get update"
}

mirror_bootstrap_os() {
  # Called before base packages; only rewires apt sources for CN profiles.
  if os_is_debian_family && [[ "$(mirror_profile)" != "official" ]]; then
    mirror_rewire_debian_os
  else
    if os_is_debian_family; then
      try "apt-get update"
    fi
  fi
}

mirror_apply_all() {
  local profile
  profile="$(mirror_profile)"
  info "applying mirror profile: $(mirror_label "${profile}")"
  if os_is_debian_family; then
    mirror_rewire_debian_os
    if [[ -f /etc/apt/sources.list.d/pgdg.list ]]; then
      local pg
      pg="$(mirror_pgdg_base)"
      _mirror_backup /etc/apt/sources.list.d/pgdg.list
      sed -i "s#https\?://apt\.postgresql\.org/pub/repos/apt#${pg}#g" /etc/apt/sources.list.d/pgdg.list
      try "apt-get update"
    fi
    if [[ -f /etc/apt/sources.list.d/php.list ]]; then
      local sy
      sy="$(mirror_sury_base)"
      if [[ -n "${sy}" ]]; then
        _mirror_backup /etc/apt/sources.list.d/php.list
        sed -i "s#https\?://packages\.sury\.org/php#${sy}#g" /etc/apt/sources.list.d/php.list
        try "apt-get update"
      fi
    fi
    if [[ -f /etc/apt/sources.list.d/mariadb.list ]]; then
      local mb
      mb="$(mirror_mariadb_base)"
      if [[ -n "${mb}" ]]; then
        _mirror_backup /etc/apt/sources.list.d/mariadb.list
        sed -i "s#https://dlm\.mariadb\.com/repo/#${mb}/repo/#g" /etc/apt/sources.list.d/mariadb.list
        try "apt-get update"
      fi
    fi
  elif os_is_rhel; then
    mirror_rewire_epel
  fi
}

cmd_mirror() {
  local sub="${1:-show}"
  shift || true
  case "${sub}" in
    show)
      local p
      p="$(mirror_profile)"
      echo "profile: ${p} ($(mirror_label "${p}"))"
      echo "file:    ${MIRROR_FILE}"
      echo "epel:    $(mirror_epel_base)"
      echo "pgdg:    $(mirror_pgdg_base)"
      echo "sury:    $(mirror_sury_base)"
      echo "mariadb: $(mirror_mariadb_base)"
      ;;
    set)
      local p="${1:-}"
      [[ -n "${p}" ]] || die "usage: lckit mirror set <official|tuna|aliyun|ustc>"
      need_root
      mirror_set_profile "${p}"
      mirror_apply_all
      ;;
    apply)
      need_root
      mirror_apply_all
      ;;
    list)
      printf '%s\n' \
        "official  upstream public repositories" \
        "tuna      https://mirrors.tuna.tsinghua.edu.cn" \
        "aliyun    https://mirrors.aliyun.com" \
        "ustc      https://mirrors.ustc.edu.cn"
      ;;
    *)
      die "usage: lckit mirror show|set|apply|list"
      ;;
  esac
}
