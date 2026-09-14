# LCKit Caddy web front-end
# SPDX-License-Identifier: Apache-2.0
# Repository: https://github.com/houseme/lckit

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

# Default welcome page: prefer GitHub raw download; else local file; else base64 payload.
: "${LCKIT_DEFAULT_INDEX_URL:=https://raw.githubusercontent.com/houseme/lckit/main/share/default-site/index.html}"

# base64 of share/default-site/index.html (offline fallback)
# shellcheck disable=SC2034
LCKIT_DEFAULT_INDEX_B64="PCFET0NUWVBFIGh0bWw+CjxodG1sIGxhbmc9InpoLUNOIj4KPGhlYWQ+CiAgPG1ldGEgY2hhcnNldD0idXRmLTgiPgogIDxtZXRhIG5hbWU9InZpZXdwb3J0IiBjb250ZW50PSJ3aWR0aD1kZXZpY2Utd2lkdGgsIGluaXRpYWwtc2NhbGU9MSI+CiAgPHRpdGxlPkxDS2l0IMK3IExpbnV4ICsgQ2FkZHkgS2l0PC90aXRsZT4KICA8c3R5bGU+CiAgICA6cm9vdCB7CiAgICAgIC0tYmc6ICMwNzBiMTQ7CiAgICAgIC0tcGFuZWw6ICMxMDE4Mjc7CiAgICAgIC0taW5rOiAjZWRmMmY3OwogICAgICAtLW11dGVkOiAjOGI5YmI0OwogICAgICAtLWxpbmU6IHJnYmEoMjU1LDI1NSwyNTUsLjA4KTsKICAgICAgLS1ibHVlOiAjNGVhMWZmOwogICAgICAtLWdyZWVuOiAjMzRkMzk5OwogICAgfQogICAgKiB7IGJveC1zaXppbmc6IGJvcmRlci1ib3g7IH0KICAgIGJvZHkgewogICAgICBtYXJnaW46IDA7CiAgICAgIG1pbi1oZWlnaHQ6IDEwMHZoOwogICAgICBjb2xvcjogdmFyKC0taW5rKTsKICAgICAgZm9udC1mYW1pbHk6IHVpLXNhbnMtc2VyaWYsIHN5c3RlbS11aSwgLWFwcGxlLXN5c3RlbSwgIlNlZ29lIFVJIiwgUm9ib3RvLCAiUGluZ0ZhbmcgU0MiLCAiTWljcm9zb2Z0IFlhSGVpIiwgc2Fucy1zZXJpZjsKICAgICAgYmFja2dyb3VuZDoKICAgICAgICByYWRpYWwtZ3JhZGllbnQoOTAwcHggNDgwcHggYXQgMCUgMCUsIHJnYmEoNzgsMTYxLDI1NSwuMTYpLCB0cmFuc3BhcmVudCA1NSUpLAogICAgICAgIHJhZGlhbC1ncmFkaWVudCg3MDBweCA0MjBweCBhdCAxMDAlIDEwJSwgcmdiYSg1MiwyMTEsMTUzLC4xMCksIHRyYW5zcGFyZW50IDUwJSksCiAgICAgICAgdmFyKC0tYmcpOwogICAgICBkaXNwbGF5OiBncmlkOwogICAgICBwbGFjZS1pdGVtczogY2VudGVyOwogICAgICBwYWRkaW5nOiAyOHB4IDE2cHg7CiAgICB9CiAgICAuc2hlbGwgewogICAgICB3aWR0aDogbWluKDc0MHB4LCAxMDAlKTsKICAgICAgYmFja2dyb3VuZDogdmFyKC0tcGFuZWwpOwogICAgICBib3JkZXI6IDFweCBzb2xpZCB2YXIoLS1saW5lKTsKICAgICAgYm9yZGVyLXJhZGl1czogMThweDsKICAgICAgcGFkZGluZzogMzRweCAzMHB4IDI2cHg7CiAgICAgIGJveC1zaGFkb3c6IDAgMjRweCA3MHB4IHJnYmEoMCwwLDAsLjQpOwogICAgfQogICAgLnBpbGwgewogICAgICBkaXNwbGF5OiBpbmxpbmUtZmxleDsKICAgICAgZ2FwOiA4cHg7CiAgICAgIGFsaWduLWl0ZW1zOiBjZW50ZXI7CiAgICAgIGZvbnQtc2l6ZTogMTJweDsKICAgICAgdGV4dC10cmFuc2Zvcm06IHVwcGVyY2FzZTsKICAgICAgbGV0dGVyLXNwYWNpbmc6IC4wNWVtOwogICAgICBjb2xvcjogdmFyKC0tZ3JlZW4pOwogICAgICBiYWNrZ3JvdW5kOiByZ2JhKDUyLDIxMSwxNTMsLjEyKTsKICAgICAgYm9yZGVyOiAxcHggc29saWQgcmdiYSg1MiwyMTEsMTUzLC4yOCk7CiAgICAgIGJvcmRlci1yYWRpdXM6IDk5OXB4OwogICAgICBwYWRkaW5nOiA0cHggMTBweDsKICAgICAgbWFyZ2luLWJvdHRvbTogMTZweDsKICAgIH0KICAgIC5waWxsIGkgewogICAgICB3aWR0aDogOHB4OyBoZWlnaHQ6IDhweDsgYm9yZGVyLXJhZGl1czogNTAlOwogICAgICBiYWNrZ3JvdW5kOiB2YXIoLS1ncmVlbik7CiAgICAgIGRpc3BsYXk6IGlubGluZS1ibG9jazsKICAgIH0KICAgIGgxIHsgbWFyZ2luOiAwIDAgOHB4OyBmb250LXNpemU6IDMwcHg7IGxldHRlci1zcGFjaW5nOiAtLjAyZW07IH0KICAgIC5sZWFkIHsgbWFyZ2luOiAwIDAgMjJweDsgY29sb3I6IHZhcigtLW11dGVkKTsgbGluZS1oZWlnaHQ6IDEuNjU7IH0KICAgIC5ncmlkIHsgZGlzcGxheTogZ3JpZDsgZ2FwOiAxMnB4OyB9CiAgICBAbWVkaWEgKG1pbi13aWR0aDogNjQwcHgpIHsgLmdyaWQgeyBncmlkLXRlbXBsYXRlLWNvbHVtbnM6IDFmciAxZnI7IH0gfQogICAgLmNhcmQgewogICAgICBib3JkZXI6IDFweCBzb2xpZCB2YXIoLS1saW5lKTsKICAgICAgYm9yZGVyLXJhZGl1czogMTJweDsKICAgICAgcGFkZGluZzogMTRweDsKICAgICAgYmFja2dyb3VuZDogcmdiYSgyNTUsMjU1LDI1NSwuMDIpOwogICAgfQogICAgLmNhcmQgaDIgeyBtYXJnaW46IDAgMCA2cHg7IGZvbnQtc2l6ZTogMTRweDsgfQogICAgLmNhcmQgcCB7IG1hcmdpbjogMDsgY29sb3I6IHZhcigtLW11dGVkKTsgZm9udC1zaXplOiAxM3B4OyBsaW5lLWhlaWdodDogMS41OyB9CiAgICAuY21kIHsKICAgICAgZGlzcGxheTogYmxvY2s7CiAgICAgIG1hcmdpbi10b3A6IDEwcHg7CiAgICAgIGZvbnQtZmFtaWx5OiB1aS1tb25vc3BhY2UsIFNGTW9uby1SZWd1bGFyLCBNZW5sbywgQ29uc29sYXMsIG1vbm9zcGFjZTsKICAgICAgZm9udC1zaXplOiAxMnB4OwogICAgICBjb2xvcjogIzllY2JmZjsKICAgICAgYmFja2dyb3VuZDogIzA4MGQxNjsKICAgICAgYm9yZGVyOiAxcHggc29saWQgdmFyKC0tbGluZSk7CiAgICAgIGJvcmRlci1yYWRpdXM6IDhweDsKICAgICAgcGFkZGluZzogOHB4IDEwcHg7CiAgICAgIG92ZXJmbG93LXg6IGF1dG87CiAgICAgIHdoaXRlLXNwYWNlOiBub3dyYXA7CiAgICB9CiAgICBmb290ZXIgewogICAgICBtYXJnaW4tdG9wOiAyMHB4OwogICAgICBwYWRkaW5nLXRvcDogMTRweDsKICAgICAgYm9yZGVyLXRvcDogMXB4IHNvbGlkIHZhcigtLWxpbmUpOwogICAgICBjb2xvcjogdmFyKC0tbXV0ZWQpOwogICAgICBmb250LXNpemU6IDEycHg7CiAgICAgIGRpc3BsYXk6IGZsZXg7CiAgICAgIGp1c3RpZnktY29udGVudDogc3BhY2UtYmV0d2VlbjsKICAgICAgZ2FwOiAxMHB4OwogICAgICBmbGV4LXdyYXA6IHdyYXA7CiAgICB9CiAgPC9zdHlsZT4KPC9oZWFkPgo8Ym9keT4KICA8bWFpbiBjbGFzcz0ic2hlbGwiPgogICAgPGRpdiBjbGFzcz0icGlsbCI+PGk+PC9pPiBDYWRkeSBvbmxpbmU8L2Rpdj4KICAgIDxoMT5MQ0tpdCDpu5jorqTnq5nngrk8L2gxPgogICAgPHAgY2xhc3M9ImxlYWQiPgogICAgICBMaW51eCArIENhZGR5IEtpdCDlt7Lpg6jnvbLjgILmraTpobXpnaLmmK/lronoo4XlkI7nmoTpnZnmgIHpu5jorqTnq5nvvIzlj6/nu6fnu63liJvlu7rkuJrliqHnq5nngrnmiJblj43lkJHku6PnkIbjgIIKICAgIDwvcD4KICAgIDxkaXYgY2xhc3M9ImdyaWQiPgogICAgICA8c2VjdGlvbiBjbGFzcz0iY2FyZCI+CiAgICAgICAgPGgyPumdmeaAgeermeeCuTwvaDI+CiAgICAgICAgPHA+5omY566h5YmN56uv5p6E5bu65Lqn54mp5oiW57qvIEhUTUzjgII8L3A+CiAgICAgICAgPGNvZGUgY2xhc3M9ImNtZCI+bGNraXQgc2l0ZSBhZGQgLWQgZXhhbXBsZS5jb20gLXQgc3RhdGljPC9jb2RlPgogICAgICA8L3NlY3Rpb24+CiAgICAgIDxzZWN0aW9uIGNsYXNzPSJjYXJkIj4KICAgICAgICA8aDI+SFRUUCDlj43lkJHku6PnkIY8L2gyPgogICAgICAgIDxwPuWvueaOpSBHbyAvIFJ1c3QgLyDku7vmhI/mnKzmnLogSFRUUCDmnI3liqHvvIxXZWJTb2NrZXQg6Ieq5Yqo5Y+v55So44CCPC9wPgogICAgICAgIDxjb2RlIGNsYXNzPSJjbWQiPmxja2l0IHNpdGUgYWRkIC1kIGFwaS5leGFtcGxlLmNvbSAtdCBwcm94eSAtLXVwc3RyZWFtIGh0dHA6Ly8xMjcuMC4wLjE6ODA4MDwvY29kZT4KICAgICAgPC9zZWN0aW9uPgogICAgICA8c2VjdGlvbiBjbGFzcz0iY2FyZCI+CiAgICAgICAgPGgyPuW6lOeUqCBzeXN0ZW1kPC9oMj4KICAgICAgICA8cD7miorkuozov5vliLbms6jlhozkuLrmnI3liqHljZXlhYPjgII8L3A+CiAgICAgICAgPGNvZGUgY2xhc3M9ImNtZCI+bGNraXQgYXBwIGFkZCAtLW5hbWUgYXBpIC0tYmluIC9vcHQvYXBpL2FwaSAtLXBvcnQgODA4MDwvY29kZT4KICAgICAgPC9zZWN0aW9uPgogICAgICA8c2VjdGlvbiBjbGFzcz0iY2FyZCI+CiAgICAgICAgPGgyPumVnOWDj+a6kDwvaDI+CiAgICAgICAgPHA+b2ZmaWNpYWwgLyB0dW5hIC8gYWxpeXVuIC8gdXN0Y++8jOmaj+aXtuWIh+aNouOAgjwvcD4KICAgICAgICA8Y29kZSBjbGFzcz0iY21kIj5sY2tpdCBtaXJyb3Igc2V0IHR1bmE8L2NvZGU+CiAgICAgIDwvc2VjdGlvbj4KICAgIDwvZGl2PgogICAgPGZvb3Rlcj4KICAgICAgPHNwYW4+5qC555uu5b2VIC9kYXRhL3dlYi9kZWZhdWx0PC9zcGFuPgogICAgICA8c3Bhbj5sY2tpdCBkb2N0b3IgwrcgQXBhY2hlLTIuMDwvc3Bhbj4KICAgIDwvZm9vdGVyPgogIDwvbWFpbj4KPC9ib2R5Pgo8L2h0bWw+Cg=="

web_fetch_default_index() {
  local dest="$1"
  mkdir -p "$(dirname "${dest}")"
  # 1) GitHub raw
  if have curl && curl -fsSL --connect-timeout 8 --max-time 20 \
      -o "${dest}" "${LCKIT_DEFAULT_INDEX_URL}" 2>/dev/null; then
    if [[ -s "${dest}" ]] && grep -q '<html' "${dest}" 2>/dev/null; then
      info "default index downloaded from GitHub"
      return 0
    fi
  fi
  # 2) local share asset
  local src
  for src in \
    "${LCKIT_HOME}/share/default-site/index.html" \
    /usr/local/share/lckit/index.html; do
    if [[ -f "${src}" ]]; then
      cp -f "${src}" "${dest}"
      info "default index copied from local share"
      return 0
    fi
  done
  # 3) embedded base64
  if [[ -n "${LCKIT_DEFAULT_INDEX_B64:-}" ]]; then
    if base64 --decode <<<"${LCKIT_DEFAULT_INDEX_B64}" > "${dest}" 2>/dev/null \
      || base64 -d <<<"${LCKIT_DEFAULT_INDEX_B64}" > "${dest}" 2>/dev/null; then
      info "default index decoded from embedded base64"
      return 0
    fi
  fi
  return 1
}

web_write_default_site() {
  ensure_base_dirs
  mkdir -p "${WEB_DEFAULT}"
  if ! web_fetch_default_index "${WEB_DEFAULT}/index.html"; then
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
