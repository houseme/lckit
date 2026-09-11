# LCKit OS detection & system prepare
# SPDX-License-Identifier: Apache-2.0
# Repository: https://github.com/houseme/lckit

os_id() {
  awk -F= '/^ID=/{gsub(/"/,"",$2); print $2}' /etc/os-release 2>/dev/null || true
}

os_version_id() {
  awk -F= '/^VERSION_ID=/{gsub(/"/,"",$2); print $2}' /etc/os-release 2>/dev/null || true
}

os_codename() {
  local n
  n="$(awk -F= '/^VERSION_CODENAME=/{gsub(/"/,"",$2); print $2}' /etc/os-release 2>/dev/null || true)"
  if [[ -z "${n}" ]] && have lsb_release; then
    n="$(lsb_release -sc 2>/dev/null || true)"
  fi
  printf '%s' "${n}"
}

os_pretty() {
  awk -F= '/^PRETTY_NAME=/{gsub(/^"|"$/,"",$2); print $2}' /etc/os-release 2>/dev/null || uname -s
}

os_is_rhel() {
  local id
  id="$(os_id)"
  [[ "${id}" =~ ^(rhel|centos|rocky|almalinux|ol|fedora)$ ]] || [[ -f /etc/redhat-release ]]
}

os_is_debian_family() {
  local id
  id="$(os_id)"
  [[ "${id}" == "debian" || "${id}" == "ubuntu" ]]
}

os_major() {
  local v
  v="$(os_version_id)"
  echo "${v%%.*}"
}

os_supported() {
  local id ver
  id="$(os_id)"
  ver="$(os_version_id)"
  if os_is_rhel; then
    local maj="${ver%%.*}"
    [[ "${maj}" =~ ^(8|9|10)$ ]] && return 0
  fi
  if [[ "${id}" == "debian" ]]; then
    local maj="${ver%%.*}"
    [[ "${maj}" =~ ^(11|12|13)$ ]] && return 0
  fi
  if [[ "${id}" == "ubuntu" ]]; then
    [[ "${ver}" == "22.04" || "${ver}" == "24.04" ]] && return 0
  fi
  return 1
}

os_extras_repo() {
  # RHEL8 powertools / RHEL9+ crb
  local maj
  maj="$(os_major)"
  if [[ "${maj}" == "8" ]]; then
    echo "powertools"
  else
    echo "crb"
  fi
}

enable_epel() {
  local maj base
  maj="$(os_major)"
  base="$(mirror_epel_base)"
  run "dnf install -y ${base}/epel-release-latest-${maj}.noarch.rpm"
  if [[ "$(mirror_profile)" != "official" ]]; then
    mirror_rewire_epel
  fi
  if have subscription-manager; then
    try "subscription-manager repos --enable codeready-builder-for-rhel-${maj}-\$(uname -m)-rpms"
  elif [[ -s "/etc/yum.repos.d/oracle-linux-ol${maj}.repo" ]]; then
    run "dnf config-manager --set-enabled ol${maj}_codeready_builder"
  else
    run "dnf config-manager --set-enabled $(os_extras_repo)"
  fi
}

sysctl_enable_bbr() {
  local kern
  kern="$(uname -r | cut -d- -f1)"
  version_ge "${kern}" "4.9.0" || { warnl "kernel < 4.9, skip BBR"; return 0; }
  local current
  current="$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || true)"
  [[ "${current}" == "bbr" ]] && { info "BBR already active"; return 0; }
  local f=/etc/sysctl.d/99-lckit-bbr.conf
  cat > "${f}" <<'EOF'
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.core.rmem_max = 2500000
EOF
  try "sysctl --system"
}

open_edge_ports() {
  if have firewall-cmd && systemctl is-active --quiet firewalld; then
    local zone
    zone="$(firewall-cmd --get-default-zone)"
    try "firewall-cmd --permanent --zone=${zone} --add-service=http"
    try "firewall-cmd --permanent --zone=${zone} --add-service=https"
    try "firewall-cmd --permanent --zone=${zone} --add-port=443/udp"
    try "firewall-cmd --reload"
  elif have ufw && ufw status 2>/dev/null | grep -q 'Status: active'; then
    try "ufw allow http"
    try "ufw allow https"
    try "ufw allow 443/udp"
  else
    warnl "no active firewall manager detected; ensure 80/443 are allowed upstream"
  fi
}

sys_prepare() {
  os_supported || die "Unsupported OS. Need EL8-10 / Debian 11-13 / Ubuntu 22.04|24.04"
  info "Host: $(os_pretty) ($(uname -m))"
  mirror_bootstrap_os
  if os_is_rhel; then
    enable_epel
    run "dnf makecache"
    pkg_install curl ca-certificates tar unzip git jq tree vim wget
  else
    pkg_install curl ca-certificates tar unzip git jq tree vim wget gnupg lsb-release apt-transport-https
  fi
  if [[ -s /etc/selinux/config ]] && grep -q '^SELINUX=enforcing' /etc/selinux/config; then
    sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
    try "setenforce 0"
    info "SELinux set to disabled (takes full effect after reboot)"
  fi
  sysctl_enable_bbr
  open_edge_ports
  ensure_base_dirs
}
