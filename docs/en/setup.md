# lckit setup — Interactive stack setup

[← Back to docs home](README.md) · [中文](../zh/setup.md)

Installs the LCKit stack (Caddy + optional databases / PHP).

## Usage

```bash
sudo ./lckit setup
# after CLI is on PATH
sudo lckit setup
```

## Prompts

1. **Mirror**: official / tuna / aliyun / ustc  
2. **Components**:
   - Caddy (default Y)
   - MariaDB (default n)
   - PHP-FPM (default n)
   - PostgreSQL 18 (default n)
3. Version/password questions when a database is selected

Select at least one component.

## What it does

- System prep (base packages, best-effort BBR, open 80/443)
- Installs selected components
- Default Caddy static site: `/data/web/default`
- Installs CLI to `/usr/local/bin/lckit`

## Install later

```bash
sudo lckit db install mariadb
sudo lckit db install postgresql
sudo lckit php install --version 8.4
```

See [db.md](db.md) and [php.md](php.md).

## Troubleshooting

```bash
lckit doctor
journalctl -u caddy -n 50 --no-pager
```
