# LCKit site (vhost) management
# SPDX-License-Identifier: Apache-2.0
# Repository: https://github.com/houseme/lckit

: "${SITES_INDEX:=${LCKIT_STATE}/sites.tsv}"

sites_index_touch() {
  ensure_base_dirs
  if [[ ! -f "${SITES_INDEX}" ]]; then
    if ! mkdir -p "$(dirname "${SITES_INDEX}")" 2>/dev/null || ! : > "${SITES_INDEX}" 2>/dev/null; then
      return 0
    fi
  fi
  chmod 600 "${SITES_INDEX}" 2>/dev/null || true
}

sites_index_upsert() {
  # domain type detail docroot tls conf
  local domain="$1" stype="$2" detail="$3" docroot="$4" tls="$5" conf="$6"
  sites_index_touch
  local tmp
  tmp="$(mktemp)"
  awk -F'\t' -v d="${domain}" '$1 != d {print}' "${SITES_INDEX}" > "${tmp}" || true
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
    "${domain}" "${stype}" "${detail}" "${docroot}" "${tls}" "${conf}" >> "${tmp}"
  mv "${tmp}" "${SITES_INDEX}"
}

sites_index_drop() {
  local domain="$1"
  sites_index_touch
  local tmp
  tmp="$(mktemp)"
  awk -F'\t' -v d="${domain}" '$1 != d {print}' "${SITES_INDEX}" > "${tmp}" || true
  mv "${tmp}" "${SITES_INDEX}"
}

_site_headers_block() {
  cat <<'EOF'
	header {
		X-Content-Type-Options nosniff
		X-Frame-Options SAMEORIGIN
		Referrer-Policy strict-origin-when-cross-origin
	}
EOF
}

_site_log_block() {
  local domain="$1"
  cat <<EOF
	log {
		output file /var/log/caddy/${domain}.access.log {
			roll_size 32MiB
			roll_keep 3
			roll_keep_for 7d
		}
	}
EOF
}

_site_label() {
  local domain="$1" tls="$2"
  if [[ "${tls}" == "off" ]]; then
    echo "http://${domain}"
  else
    echo "${domain}"
  fi
}

site_write_static() {
  local domain="$1" docroot="$2" tls="$3"
  local conf
  conf="$(site_conf_path "${domain}")"
  mkdir -p "${docroot}"
  if [[ ! -f "${docroot}/index.html" ]]; then
    cat > "${docroot}/index.html" <<EOF
<!DOCTYPE html>
<html lang="zh-CN"><head><meta charset="utf-8"><title>${domain}</title></head>
<body><h1>${domain}</h1><p>LCKit static site</p></body></html>
EOF
  fi
  if id caddy >/dev/null 2>&1; then
    chown -R caddy:caddy "${docroot}" 2>/dev/null || true
  fi
  {
    echo "$(_site_label "${domain}" "${tls}") {"
    echo "	encode zstd gzip"
    echo "	root * ${docroot}"
    echo "	file_server {"
    echo "		index index.html index.htm"
    echo "	}"
    _site_headers_block
    _site_log_block "${domain}"
    echo "}"
  } > "${conf}"
}

site_write_php() {
  local domain="$1" docroot="$2" socket="$3" tls="$4"
  local conf
  conf="$(site_conf_path "${domain}")"
  mkdir -p "${docroot}"
  if [[ ! -f "${docroot}/index.php" ]]; then
    cat > "${docroot}/index.php" <<EOF
<?php
// LCKit placeholder — replace with your application.
header('Content-Type: text/plain; charset=utf-8');
echo "LCKit PHP site: ${domain}\\n";
echo "PHP " . PHP_VERSION . "\\n";
EOF
  fi
  if id caddy >/dev/null 2>&1; then
    chown -R caddy:caddy "${docroot}" 2>/dev/null || true
  fi
  {
    echo "$(_site_label "${domain}" "${tls}") {"
    echo "	encode zstd gzip"
    echo "	root * ${docroot}"
    echo "	php_fastcgi ${socket}"
    echo "	file_server"
    _site_headers_block
    _site_log_block "${domain}"
    echo "}"
  } > "${conf}"
}

site_write_proxy() {
  local domain="$1" upstream="$2" tls="$3"
  local conf
  conf="$(site_conf_path "${domain}")"
  {
    echo "$(_site_label "${domain}" "${tls}") {"
    echo "	encode zstd gzip"
    echo "	reverse_proxy ${upstream} {"
    echo "		header_up Host {host}"
    echo "		header_up X-Real-IP {remote_host}"
    echo "		header_up X-Forwarded-For {remote_host}"
    echo "		header_up X-Forwarded-Proto {scheme}"
    echo "		header_up X-Forwarded-Host {host}"
    echo "		transport http {"
    echo "			versions h1 h2"
    echo "		}"
    echo "	}"
    _site_headers_block
    _site_log_block "${domain}"
    echo "}"
  } > "${conf}"
}

site_add() {
  local domain="" stype="static" upstream="" docroot="" socket="" tls="on" force="no"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -d|--domain) domain="${2:-}"; shift 2 ;;
      -t|--type) stype="${2:-}"; shift 2 ;;
      --upstream|-b|--backend) upstream="${2:-}"; shift 2 ;;
      -r|--root) docroot="${2:-}"; shift 2 ;;
      -s|--socket) socket="${2:-}"; shift 2 ;;
      --no-tls) tls="off"; shift ;;
      --tls) tls="on"; shift ;;
      --force) force="yes"; shift ;;
      *) die "unknown site add option: $1" ;;
    esac
  done
  [[ -n "${domain}" ]] || die "site domain required (-d)"
  require_domain "${domain}" || die "invalid domain: ${domain}"
  case "${stype}" in static|php|proxy) ;; *) die "type must be static|php|proxy" ;; esac

  local conf
  conf="$(site_conf_path "${domain}")"
  if [[ -f "${conf}" && "${force}" != "yes" ]]; then
    die "site exists: ${domain} (use --force)"
  fi

  if [[ -z "${docroot}" ]]; then
    docroot="$(site_docroot "${domain}")"
  fi

  ensure_base_dirs
  case "${stype}" in
    static)
      site_write_static "${domain}" "${docroot}" "${tls}"
      sites_index_upsert "${domain}" "static" "-" "${docroot}" "${tls}" "${conf}"
      ;;
    php)
      if [[ -z "${socket}" ]]; then
        if declare -F php_detect_socket >/dev/null 2>&1; then
          socket="$(php_detect_socket)"
        else
          socket="unix//run/php/php-fpm.sock"
        fi
      fi
      site_write_php "${domain}" "${docroot}" "${socket}" "${tls}"
      sites_index_upsert "${domain}" "php" "${socket}" "${docroot}" "${tls}" "${conf}"
      ;;
    proxy)
      [[ -n "${upstream}" ]] || die "proxy site requires --upstream http://127.0.0.1:8080"
      [[ "${upstream}" == http://* || "${upstream}" == https://* ]] || upstream="http://${upstream}"
      site_write_proxy "${domain}" "${upstream}" "${tls}"
      sites_index_upsert "${domain}" "proxy" "${upstream}" "-" "${tls}" "${conf}"
      ;;
  esac
  web_reload
  info "site ready: ${domain} (${stype})"
}

site_list() {
  sites_index_touch
  if [[ ! -s "${SITES_INDEX}" ]]; then
    echo "(no sites recorded)"
    return 0
  fi
  printf '%s\n' "DOMAIN	TYPE	DETAIL	DOCROOT	TLS	CONFIG"
  cat "${SITES_INDEX}"
}

site_show() {
  local domain="${1:-}"
  [[ -n "${domain}" ]] || die "usage: lckit site show <domain>"
  local conf
  conf="$(site_conf_path "${domain}")"
  [[ -f "${conf}" ]] || die "site not found: ${domain}"
  cat "${conf}"
}

site_rm() {
  local domain="${1:-}"
  [[ -n "${domain}" ]] || die "usage: lckit site rm <domain>"
  local conf
  conf="$(site_conf_path "${domain}")"
  rm -f "${conf}"
  sites_index_drop "${domain}"
  web_reload
  info "site removed: ${domain} (files under $(site_docroot "${domain}") kept)"
}

site_usage() {
  cat <<'EOF'
Usage: lckit site <add|list|show|rm> ...

  lckit site add -d <domain> -t static|php|proxy [options]
    -d, --domain DOMAIN
    -t, --type static|php|proxy
    --upstream URL          (proxy) e.g. http://127.0.0.1:8080
    -r, --root PATH         (static/php) default /data/web/<domain>
    -s, --socket PATH       (php) FastCGI socket
    --tls | --no-tls
    --force
  lckit site list
  lckit site show <domain>
  lckit site rm <domain>

Repository: https://github.com/houseme/lckit
EOF
}

cmd_site() {
  local sub="${1:-}"
  shift || true
  case "${sub}" in
    add) need_root; site_add "$@" ;;
    list|ls) site_list "$@" ;;
    show) site_show "$@" ;;
    rm|del) need_root; site_rm "$@" ;;
    ""|help|-h|--help) site_usage ;;
    *) die "unknown site subcommand: ${sub}" ;;
  esac
}
