# LCKit Docs

**English** · [中文](zh/README.md)

Command handbook for Linux + Caddy Kit.  
Project: [README.md](../README.md)

---

## Commands

| Command | Description |
|---------|-------------|
| [lckit setup](en/setup.md) | Interactive Caddy install; optional DB / PHP |
| [lckit site](en/site.md) | Static, PHP, and reverse-proxy sites |
| [lckit app](en/app.md) | Systemd units for Go / Rust / any binary |
| [lckit db](en/db.md) | Install or inspect MariaDB, PostgreSQL |
| [lckit php](en/php.md) | Install or inspect PHP-FPM |
| [lckit php ext](en/php-ext.md) | PHP extensions (redis, imagick, swoole, …) |
| [lckit mirror](en/mirror.md) | Official / TUNA / Aliyun / USTC mirrors |
| [lckit doctor](en/doctor.md) | Environment health check |

More notes: [sites.md](sites.md)

---

## Install

```bash
git clone https://github.com/houseme/lckit-apache.git
cd lckit-apache
chmod +x lckit
sudo ./lckit setup
```

After setup the CLI is `lckit` (`/usr/local/bin/lckit`).

---

## Common flows

**Reverse proxy only**

```bash
sudo lckit setup
sudo lckit app  add --name api --bin /opt/api/api --port 8080
sudo lckit site add -d api.example.com -t proxy --upstream http://127.0.0.1:8080
```

**Static site (custom root)**

```bash
sudo lckit site add -d demo.example.com -t static -r /data/rustfs/demo.example.com
```

**Add DB and PHP later**

```bash
sudo lckit db  install mariadb
sudo lckit php install --version 8.4
sudo lckit php ext install common redis imagick
sudo lckit site add -d blog.example.com -t php
```

**China mirrors**

```bash
sudo lckit mirror set tuna
```

---

## Paths

| Item | Path |
|------|------|
| CLI | `/usr/local/bin/lckit` |
| State | `/var/lib/lckit/` |
| Secrets | `/var/lib/lckit/secrets/` |
| Site configs | `/etc/caddy/sites/` |
| Default site | `/data/web/default` |
| Log | `/var/log/lckit.log` |

---

## Troubleshooting

```bash
lckit doctor
lckit site list
systemctl status caddy
journalctl -u caddy -n 50 --no-pager
```
