# LCKit Docs (English)

> Language: [English](README.md) · [中文](../zh/README.md) · [Bilingual hub](../README.md)

Command documentation for **LCKit** (Linux + Caddy Kit).  
Project README: [../../README.md](../../README.md).

## Quick start

```bash
git clone https://github.com/houseme/lckit-apache.git
cd lckit-apache
chmod +x lckit
sudo ./lckit setup
```

## Command guides

| Command | Description | Link |
|---------|-------------|------|
| `lckit setup` | Interactive Caddy / optional DB / PHP install | [setup.md](setup.md) |
| `lckit site` | Static / PHP / reverse-proxy sites | [site.md](site.md) |
| `lckit app` | Backend binary systemd units | [app.md](app.md) |
| `lckit db` | MariaDB & PostgreSQL install/status | [db.md](db.md) |
| `lckit php` | PHP-FPM install/status | [php.md](php.md) |
| `lckit php ext` | PHP extensions | [php-ext.md](php-ext.md) |
| `lckit mirror` | Package mirror switching | [mirror.md](mirror.md) |
| `lckit doctor` | Environment health check | [doctor.md](doctor.md) |

Extra notes: [../sites.md](../sites.md)

## Suggested install order

1. `lckit setup` (at least Caddy)  
2. Databases when needed: `lckit db install mariadb` / `postgresql`  
3. PHP when needed: `lckit php install` → `lckit php ext install ...`  
4. `lckit site add ...` / `lckit app add ...`  
5. On issues: `lckit doctor`

## Common recipes

```bash
# Static site with custom docroot
sudo lckit site add -d demo.example.com -t static -r /data/rustfs/demo.example.com

# Go/Rust reverse proxy
sudo lckit app  add --name api --bin /opt/api/api --port 8080
sudo lckit site add -d api.example.com -t proxy --upstream http://127.0.0.1:8080

# PHP + common extensions
sudo lckit php install --version 8.4
sudo lckit php ext install common redis imagick
sudo lckit site add -d blog.example.com -t php

# China mirrors
sudo lckit mirror set tuna
```

## Path cheat sheet

| Item | Path |
|------|------|
| CLI | `/usr/local/bin/lckit` |
| State | `/var/lib/lckit/` |
| Secrets | `/var/lib/lckit/secrets/` |
| Site configs | `/etc/caddy/sites/` |
| Default site | `/data/web/default` |
| Log | `/var/log/lckit.log` |

## Troubleshooting entry points

```bash
lckit doctor
lckit site list
lckit app list
systemctl status caddy
journalctl -u caddy -n 50 --no-pager
```

License: Apache-2.0.
