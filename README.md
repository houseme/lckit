# LCKit

**LCKit** (Linux + Caddy Kit) is a modular Bash toolkit: [Caddy](https://caddyserver.com) as reverse proxy / TLS / static front-end, optional MariaDB, PHP-FPM, and PostgreSQL 18, plus app-unit management for Go/Rust/any HTTP backend, and China public mirrors.

- **License**: Apache License 2.0
- **Implementation note**: Independent implementation. Product ideas only; **not** derived from GPL sources.
- **CLI**: `lckit`

Chinese docs: [README_CN.md](README_CN.md) · Guides: [docs/](docs/README.md)

## Features

| Capability | Command |
|------------|---------|
| Interactive stack setup | `lckit setup` |
| Install MariaDB / PostgreSQL **after** setup | `lckit db install mariadb\|postgresql` |
| Install PHP-FPM **after** setup | `lckit php install` |
| PHP extensions | `lckit php ext install ...` |
| Sites (static / php / proxy) | `lckit site add\|list\|show\|rm` |
| Backend systemd units | `lckit app add\|list\|rm\|start\|stop\|restart\|status` |
| Package mirrors | `lckit mirror show\|set\|apply\|list` |
| Environment health check | `lckit doctor` |

After installing Caddy, a default static welcome site is created at `/data/web/default`.

## Supported systems

- Enterprise Linux 8 / 9 / 10
- Debian 11 / 12 / 13
- Ubuntu 22.04 / 24.04

Requires root and internet access.

## Install

```bash
git clone https://github.com/houseme/lckit-apache.git
cd lckit-apache
chmod +x lckit
sudo ./lckit setup
```

The CLI is installed to `/usr/local/bin/lckit`.

## Add databases / PHP later

You can skip DB/PHP during first setup:

```bash
sudo lckit db install mariadb
sudo lckit db install postgresql
sudo lckit php install --version 8.4
sudo lckit php ext install common redis imagick

lckit db status
lckit php status
lckit doctor
```

- Omit `--password` to generate a strong random secret under `/var/lib/lckit/secrets/` (`0700`/`0600`)
- Databases listen on `127.0.0.1` only
- Basic memory-based tuning for MariaDB / PostgreSQL / PHP-FPM / opcache

## Quick start

```bash
# Static site (custom docroot)
sudo lckit site add -d example.com -t static -r /data/web/example.com

# Go / Rust reverse proxy
sudo lckit app  add --name api --bin /opt/api/api --port 8080 --workdir /opt/api
sudo lckit site add -d api.example.com -t proxy --upstream http://127.0.0.1:8080

# PHP site
sudo lckit site add -d blog.example.com -t php

# China mirror
sudo lckit mirror set tuna
```

## Repository layout

```
lckit-apache/
├── lckit                 # CLI entry
├── lib/                  # modules
├── share/default-site/   # default static page
├── docs/                 # bilingual usage guides
├── README.md             # this file (English)
├── README_CN.md          # Chinese README
└── LICENSE               # Apache-2.0
```

## Design note (GPL relationship)

This repository reimplements install/management flows from scratch. Module layout, paths, index formats, and command semantics are independently designed. Product goals (Caddy reverse-proxy stack, optional databases, mirror switching) are ideas, not copyrightable expression. Code is released under Apache-2.0.

Do **not** copy GPL-licensed third-party installer sources into this repository.

## Thanks

Thanks to the broader open-source ecosystem — Caddy, MariaDB, PostgreSQL, PHP, and community “web stack installer” ideas.

## License

```
Copyright 2026 LCKit contributors

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```
