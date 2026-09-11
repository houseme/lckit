# LCKit Docs

> **Language / 语言:** [English](#english) · [中文](#中文)

Usage guides for every `lckit` command.  
LCKit 全部命令的使用说明。按语言切换后阅读对应章节。

---

<a id="english"></a>
# English

Welcome to **LCKit** documentation (Linux + Caddy Kit).

- Project README: [../README.md](../README.md)
- License: Apache-2.0
- CLI entry: `lckit` (installed to `/usr/local/bin/lckit` after `setup`)

## Quick start

```bash
git clone https://github.com/houseme/lckit-apache.git
cd lckit-apache
chmod +x lckit
sudo ./lckit setup

# optional later
sudo lckit db install mariadb
sudo lckit db install postgresql
sudo lckit php install --version 8.4
sudo lckit php ext install common redis imagick

# sites / backends
sudo lckit site add -d example.com -t static
sudo lckit app  add --name api --bin /opt/api/api --port 8080
sudo lckit site add -d api.example.com -t proxy --upstream http://127.0.0.1:8080
```

## Command map

| Command | What it does | Guide |
|---------|----------------|-------|
| `lckit setup` | Interactive stack install | [en/setup.md](en/setup.md) |
| `lckit site` | static / php / proxy vhosts | [en/site.md](en/site.md) |
| `lckit app` | Backend systemd units (Go/Rust/any) | [en/app.md](en/app.md) |
| `lckit db` | Install/status MariaDB or PostgreSQL | [en/db.md](en/db.md) |
| `lckit php` | Install/status PHP-FPM | [en/php.md](en/php.md) |
| `lckit php ext` | PHP extensions (redis, imagick, …) | [en/php-ext.md](en/php-ext.md) |
| `lckit mirror` | Official / TUNA / Aliyun / USTC | [en/mirror.md](en/mirror.md) |
| `lckit doctor` | Environment health check | [en/doctor.md](en/doctor.md) |

Chinese versions: [`zh/README.md`](zh/README.md)

## Typical workflows

### 1. Reverse-proxy only (Caddy + Go/Rust)

```bash
sudo lckit setup                 # select Caddy; skip DB/PHP if unused
sudo lckit app  add --name api --bin /opt/api/api --port 8080 --workdir /opt/api
sudo lckit site add -d api.example.com -t proxy --upstream http://127.0.0.1:8080
```

### 2. Static site with custom document root

```bash
sudo lckit site add -d demo.example.com -t static -r /data/rustfs/demo.example.com
```

Default root if `-r` is omitted: `/data/web/<domain>`.

### 3. Full LAMP-like stack (add later)

```bash
sudo lckit setup                 # Caddy first
sudo lckit db install mariadb
sudo lckit php install --version 8.4
sudo lckit php ext install full
sudo lckit site add -d blog.example.com -t php
```

### 4. China mirrors

```bash
sudo lckit mirror set tuna
lckit mirror show
```

## Important paths

| Item | Path |
|------|------|
| CLI | `/usr/local/bin/lckit` |
| State / indexes | `/var/lib/lckit/` |
| Secrets | `/var/lib/lckit/secrets/` (0700/0600) |
| Web root default | `/data/web/default` |
| Caddy main config | `/etc/caddy/Caddyfile` |
| Site configs | `/etc/caddy/sites/*.caddy` |
| App units | `/etc/systemd/system/lckit-app-*.service` |
| Install log | `/var/log/lckit.log` |

## Extra reference

- [sites.md](sites.md) — longer site/app notes (Chinese)

---

<a id="中文"></a>
# 中文

欢迎使用 **LCKit**（Linux + Caddy Kit）文档。

- 项目说明：[../README_CN.md](../README_CN.md)
- 协议：Apache-2.0
- 主命令：`lckit`（`setup` 后位于 `/usr/local/bin/lckit`）

## 快速开始

```bash
git clone https://github.com/houseme/lckit-apache.git
cd lckit-apache
chmod +x lckit
sudo ./lckit setup

# 之后可补装
sudo lckit db install mariadb
sudo lckit db install postgresql
sudo lckit php install --version 8.4
sudo lckit php ext install common redis imagick

# 站点 / 后端
sudo lckit site add -d example.com -t static
sudo lckit app  add --name api --bin /opt/api/api --port 8080
sudo lckit site add -d api.example.com -t proxy --upstream http://127.0.0.1:8080
```

## 命令一览

| 命令 | 作用 | 文档 |
|------|------|------|
| `lckit setup` | 交互安装栈 | [zh/setup.md](zh/setup.md) |
| `lckit site` | static / php / proxy 站点 | [zh/site.md](zh/site.md) |
| `lckit app` | Go/Rust 等后端 systemd 单元 | [zh/app.md](zh/app.md) |
| `lckit db` | 安装/查看 MariaDB、PostgreSQL | [zh/db.md](zh/db.md) |
| `lckit php` | 安装/查看 PHP-FPM | [zh/php.md](zh/php.md) |
| `lckit php ext` | PHP 扩展（redis、imagick 等） | [zh/php-ext.md](zh/php-ext.md) |
| `lckit mirror` | 官方 / 清华 / 阿里云 / 中科大 | [zh/mirror.md](zh/mirror.md) |
| `lckit doctor` | 环境体检 | [zh/doctor.md](zh/doctor.md) |

英文总览：[`en/README.md`](en/README.md)

## 典型场景

### 1. 只做反向代理（Caddy + Go/Rust）

```bash
sudo lckit setup                 # 勾选 Caddy；可跳过 DB/PHP
sudo lckit app  add --name api --bin /opt/api/api --port 8080 --workdir /opt/api
sudo lckit site add -d api.example.com -t proxy --upstream http://127.0.0.1:8080
```

### 2. 静态站 + 自定义目录

```bash
sudo lckit site add -d demo.example.com -t static -r /data/rustfs/demo.example.com
```

不写 `-r` 时默认目录为 `/data/web/<域名>`。

### 3. 完整栈（可后补数据库 / PHP）

```bash
sudo lckit setup
sudo lckit db install mariadb
sudo lckit php install --version 8.4
sudo lckit php ext install full
sudo lckit site add -d blog.example.com -t php
```

### 4. 国内镜像

```bash
sudo lckit mirror set tuna
lckit mirror show
```

## 重要路径

| 项目 | 路径 |
|------|------|
| CLI | `/usr/local/bin/lckit` |
| 状态与索引 | `/var/lib/lckit/` |
| 密码密钥 | `/var/lib/lckit/secrets/`（0700/0600） |
| 默认站点根 | `/data/web/default` |
| Caddy 主配置 | `/etc/caddy/Caddyfile` |
| 站点配置 | `/etc/caddy/sites/*.caddy` |
| 应用 unit | `/etc/systemd/system/lckit-app-*.service` |
| 安装日志 | `/var/log/lckit.log` |

## 补充

- [sites.md](sites.md) — 站点 / 应用补充说明

---

↑ [Back to top / 回到顶部](#lckit-docs)
