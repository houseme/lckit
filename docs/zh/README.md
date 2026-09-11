# LCKit 文档（中文）

> 语言切换：[English](../en/README.md) · **中文** · [双语总览](../README.md)

**LCKit**（Linux + Caddy Kit）命令文档。  
项目说明见 [../../README_CN.md](../../README_CN.md)。

## 快速开始

```bash
git clone https://github.com/houseme/lckit-apache.git
cd lckit-apache
chmod +x lckit
sudo ./lckit setup
```

## 命令文档

| 命令 | 说明 | 链接 |
|------|------|------|
| `lckit setup` | 交互安装 Caddy / 可选 DB / PHP | [setup.md](setup.md) |
| `lckit site` | 静态 / PHP / 反向代理站点 | [site.md](site.md) |
| `lckit app` | 后端二进制 systemd 管理 | [app.md](app.md) |
| `lckit db` | MariaDB、PostgreSQL 安装与状态 | [db.md](db.md) |
| `lckit php` | PHP-FPM 安装与状态 | [php.md](php.md) |
| `lckit php ext` | PHP 扩展安装 | [php-ext.md](php-ext.md) |
| `lckit mirror` | 软件源镜像切换 | [mirror.md](mirror.md) |
| `lckit doctor` | 环境体检 | [doctor.md](doctor.md) |

补充：[../sites.md](../sites.md)

## 安装顺序建议

1. `lckit setup`（至少装 Caddy）  
2. 需要数据库时：`lckit db install mariadb` / `postgresql`  
3. 需要 PHP 时：`lckit php install` → `lckit php ext install ...`  
4. `lckit site add ...` / `lckit app add ...`  
5. 异常时：`lckit doctor`

## 常用组合

```bash
# 静态站 + 自定义目录
sudo lckit site add -d demo.example.com -t static -r /data/rustfs/demo.example.com

# Go/Rust 反代
sudo lckit app  add --name api --bin /opt/api/api --port 8080
sudo lckit site add -d api.example.com -t proxy --upstream http://127.0.0.1:8080

# PHP + 常用扩展
sudo lckit php install --version 8.4
sudo lckit php ext install common redis imagick
sudo lckit site add -d blog.example.com -t php

# 国内镜像
sudo lckit mirror set tuna
```

## 路径速查

| 项目 | 路径 |
|------|------|
| CLI | `/usr/local/bin/lckit` |
| 状态 | `/var/lib/lckit/` |
| 密钥 | `/var/lib/lckit/secrets/` |
| 站点配置 | `/etc/caddy/sites/` |
| 默认站点 | `/data/web/default` |
| 日志 | `/var/log/lckit.log` |

## 排障入口

```bash
lckit doctor
lckit site list
lckit app list
systemctl status caddy
journalctl -u caddy -n 50 --no-pager
```

协议：Apache-2.0。
