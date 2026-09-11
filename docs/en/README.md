# LCKit Docs

**English** · [中文](../zh/README.md)

Complete English handbook for **LCKit** (Linux + Caddy Kit).  
Repository: [https://github.com/houseme/lckit](https://github.com/houseme/lckit) · License: Apache-2.0

---

## Overview

LCKit is a modular Bash toolkit:

- **Caddy** as reverse proxy / TLS / static front-end
- Optional **MariaDB**, **PostgreSQL 18**, **PHP-FPM**
- Backend **systemd** units for Go / Rust / any HTTP binary
- **China public mirrors** (TUNA / Aliyun / USTC)
- CLI: `lckit` (installed to `/usr/local/bin/lckit`)

Supported OS: Enterprise Linux 8–10, Debian 11–13, Ubuntu 22.04 / 24.04 (root + internet).

---

## Commands

| Command | Description | Guide |
|---------|-------------|-------|
| `lckit setup` | Interactive stack install | [setup](setup.md) |
| `lckit site` | static / php / proxy vhosts | [site](site.md) |
| `lckit app` | Backend systemd units | [app](app.md) |
| `lckit db` | MariaDB & PostgreSQL | [db](db.md) |
| `lckit php` | PHP-FPM | [php](php.md) |
| `lckit php ext` | PHP extensions | [php ext](php-ext.md) |
| `lckit mirror` | Package mirrors | [mirror](mirror.md) |
| `lckit doctor` | Health check | [doctor](doctor.md) |

Longer notes on sites/apps: [../sites.md](../sites.md)

---

## Install

```bash
git clone https://github.com/houseme/lckit.git
cd lckit
chmod +x lckit
sudo ./lckit setup
```

After setup:

```bash
lckit doctor
lckit help
```

---

## Add databases / PHP later

You can skip DB/PHP during first `setup`:

```bash
sudo lckit db install mariadb
sudo lckit db install mariadb --series 11.8 --password 'Your.Strong.Pass'
sudo lckit db install postgresql

sudo lckit php install --version 8.4
sudo lckit php ext install common redis imagick memcached swoole

lckit db status
lckit php status
```

- Omit `--password` → strong random secret under `/var/lib/lckit/secrets/` (`0700`/`0600`)
- Databases listen on **127.0.0.1** only

---

## Common flows

### Reverse proxy only (Caddy + Go/Rust)

```bash
sudo lckit setup
sudo lckit app  add --name api --bin /opt/api/api --port 8080 --workdir /opt/api
sudo lckit site add -d api.example.com -t proxy --upstream http://127.0.0.1:8080
```

### Static site with custom document root

```bash
sudo lckit site add -d demo.example.com -t static -r /data/rustfs/demo.example.com
```

Default root if `-r` is omitted: `/data/web/<domain>`.

### PHP site

```bash
sudo lckit php install --version 8.4
sudo lckit site add -d blog.example.com -t php
```

### Intranet without TLS

```bash
sudo lckit site add -d panel.lan -t proxy --upstream http://127.0.0.1:8443 --no-tls
```

### China mirrors

```bash
lckit mirror show
sudo lckit mirror set tuna
sudo lckit mirror apply
```

Profiles: `official` | `tuna` | `aliyun` | `ustc`

---

## Site types

| Type | Use | Key flags |
|------|-----|-----------|
| `static` | HTML / frontend build | `-r/--root` |
| `php` | PHP-FPM | `-s/--socket` (auto) |
| `proxy` | Go/Rust/any HTTP | `--upstream http://127.0.0.1:8080` |

```bash
lckit site add -d <domain> -t static|php|proxy [options]
lckit site list
lckit site show <domain>
lckit site rm  <domain>
```

WebSocket works automatically via Caddy `reverse_proxy`.  
Proxy injects `X-Real-IP`, `X-Forwarded-For`, `X-Forwarded-Proto`, `X-Forwarded-Host`.

---

## App units

```bash
lckit app add --name api --bin /opt/api/api --port 8080 \
  --workdir /opt/api --user root --env RUST_LOG=info

# binary listens via env only
lckit app add --name api --bin /opt/api/api --no-port-arg \
  --port 8080 --env PORT=8080

lckit app list
lckit app status api
lckit app restart api
lckit app rm api
```

Unit file: `/etc/systemd/system/lckit-app-<name>.service`  
Index: `/var/lib/lckit/apps.tsv`

Prefer binding backends to `127.0.0.1`; expose only Caddy 80/443.

---

## PHP extensions

```bash
sudo lckit php ext install common
sudo lckit php ext install full
sudo lckit php ext install redis opcache imagick memcached swoole imap ldap bz2 sodium
sudo lckit php ext install ioncube          # best-effort commercial loader
sudo lckit php ext install sourceguardian   # best-effort
lckit php ext list
lckit php ext status
```

| Preset | Includes |
|--------|----------|
| `common` | opcache, gd, mbstring, xml, curl, intl, zip, bcmath, exif, fileinfo, sqlite3 |
| `full` | common + redis, memcached, imagick, imap, ldap, bz2, sodium, mysql, pgsql |

Obsolete (PHP 5) `xcache` / `eaccelerator` are skipped with a warning.

---

## Important paths

| Item | Path |
|------|------|
| CLI | `/usr/local/bin/lckit` |
| State / indexes | `/var/lib/lckit/` |
| Secrets | `/var/lib/lckit/secrets/` |
| PHP state | `/var/lib/lckit/php.env` |
| Default web root | `/data/web/default` |
| Caddy main config | `/etc/caddy/Caddyfile` |
| Site configs | `/etc/caddy/sites/*.caddy` |
| App units | `/etc/systemd/system/lckit-app-*.service` |
| Mirror config | `/etc/lckit/mirror.conf` |
| Install log | `/var/log/lckit.log` |

---

## Troubleshooting

```bash
lckit doctor
lckit site list
lckit app list
lckit php status
lckit db status

systemctl status caddy
systemctl status php8.4-fpm
journalctl -u caddy -n 50 --no-pager
caddy validate --config /etc/caddy/Caddyfile
ss -tlnp
```

| Symptom | Check |
|---------|--------|
| Site 502 | Upstream port listening? `lckit app status <name>` |
| PHP 502 | FPM socket under `/run/php/`; `lckit php status` |
| HTTPS fail | DNS, port 80, or use `--no-tls` for intranet |
| DB auth | `sudo cat /var/lib/lckit/secrets/<name>` |

---

## Language / 语言

- 中文首页：[../zh/README.md](../zh/README.md)
- Repository: [https://github.com/houseme/lckit](https://github.com/houseme/lckit)
