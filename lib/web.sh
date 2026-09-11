# LCKit Caddy web front-end
# SPDX-License-Identifier: Apache-2.0

web_install_caddy() {
  if os_is_rhel; then
    try "dnf install -y 'dnf-command(copr)'"
    try "dnf copr enable -y @caddy/caddy"
    pkg_install caddy
  else
    pkg_install debian-keyring debian-archive-keyring || true
    run "curl -1sLf https://dl.cloudsmith.io/public/caddy/stable/gpg.key | gpg --dearmor --yes -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg"
    run "chmod a+r /usr/share/keyrings/caddy-stable-archive-keyring.gpg"
    mkdir -p /etc/apt/sources.list.d
    curl -1sLf https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt > /etc/apt/sources.list.d/caddy-stable.list
    run "apt-get update"
    run "DEBIAN_FRONTEND=noninteractive apt-get install -y caddy"
  fi
  info "Caddy package installed"
}

web_write_main_config() {
  ensure_base_dirs
  # Keep admin endpoint on localhost so `caddy reload` / systemctl reload works.
  cat > "${CADDY_MAIN}" <<EOF
{
	admin localhost:2019
}
import ${CADDY_SITES}/*.caddy
EOF
  # Caddy user must write access logs
  mkdir -p /var/log/caddy
  if id caddy >/dev/null 2>&1; then
    chown -R caddy:caddy /var/log/caddy 2>/dev/null || true
    chmod 755 /var/log/caddy 2>/dev/null || true
  fi
}

web_write_default_site() {
  ensure_base_dirs
  mkdir -p "${WEB_DEFAULT}"
  if [[ -f "${LCKIT_HOME}/share/default-site/index.html" ]]; then
    cp -f "${LCKIT_HOME}/share/default-site/index.html" "${WEB_DEFAULT}/index.html"
  else
    web_emit_fallback_index
  fi
  if [[ -f "${LCKIT_HOME}/share/default-site/favicon.svg" ]]; then
    cp -f "${LCKIT_HOME}/share/default-site/favicon.svg" "${WEB_DEFAULT}/favicon.svg"
  fi
  if id caddy >/dev/null 2>&1; then
    chown -R caddy:caddy "${WEB_DEFAULT}" 2>/dev/null || true
  fi

  cat > "${CADDY_SITES}/00-default.caddy" <<EOF
:80 {
	encode zstd gzip
	root * ${WEB_DEFAULT}
	file_server {
		index index.html
	}
	header {
		X-Content-Type-Options nosniff
		X-Frame-Options SAMEORIGIN
		Referrer-Policy strict-origin-when-cross-origin
	}
	log {
		output file /var/log/caddy/default-access.log {
			roll_size 32MiB
			roll_keep 3
			roll_keep_for 7d
		}
	}
}
EOF
  info "default static site ready at ${WEB_DEFAULT}"
}

web_emit_fallback_index() {
  cat > "${WEB_DEFAULT}/index.html" <<'HTML'
<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>LCKit is ready</title>
  <style>
    body{margin:0;min-height:100vh;display:grid;place-items:center;background:#0b1220;color:#e8eef7;
      font-family:system-ui,-apple-system,"Segoe UI",Roboto,"PingFang SC",sans-serif}
    main{width:min(680px,92vw);padding:2rem;border:1px solid rgba(255,255,255,.08);border-radius:16px;background:#121a2b}
    h1{margin:0 0 .5rem;font-size:1.75rem}
    p{color:#8b9bb4;line-height:1.6}
    code{font-family:ui-monospace,SFMono-Regular,Menlo,monospace;background:#0a0f18;padding:.15rem .4rem;border-radius:6px;color:#9ecbff}
    ul{line-height:1.9;padding-left:1.1rem}
  </style>
</head>
<body>
  <main>
    <h1>LCKit 已就绪</h1>
    <p>Caddy 默认站点。继续创建业务站点：</p>
    <ul>
      <li>静态：<code>lckit site add -d example.com -t static</code></li>
      <li>反代：<code>lckit site add -d api.example.com -t proxy --upstream http://127.0.0.1:8080</code></li>
      <li>后端：<code>lckit app add --name api --bin /opt/api/api --port 8080</code></li>
    </ul>
  </main>
</body>
</html>
HTML
}

web_reload() {
  # Prefer restart: robust when admin API is unavailable or config just changed.
  try "systemctl restart caddy"
  if ! systemctl is-active --quiet caddy 2>/dev/null; then
    warnl "caddy is not active; check: journalctl -u caddy -n 50"
  fi
}

web_install_and_configure() {
  web_install_caddy
  web_write_main_config
  web_write_default_site
  web_reload
}
