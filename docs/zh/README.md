# LCKit 文档

[English](../en/README.md) · **中文**

Linux + Caddy Kit 命令手册。  
仓库：[https://github.com/houseme/lckit](https://github.com/houseme/lckit)

---

## 命令

| 命令 | 说明 |
|------|------|
| [lckit setup](setup.md) | 交互安装 Caddy，可选数据库 / PHP |
| [lckit site](site.md) | 静态站、PHP 站、反向代理 |
| [lckit app](app.md) | Go / Rust 等后端 systemd 服务 |
| [lckit db](db.md) | 安装或查看 MariaDB、PostgreSQL |
| [lckit php](php.md) | 安装或查看 PHP-FPM |
| [lckit php ext](php-ext.md) | PHP 扩展（redis、imagick、swoole 等） |
| [lckit mirror](mirror.md) | 官方 / 清华 / 阿里云 / 中科大 镜像 |
| [lckit doctor](doctor.md) | 环境体检 |

补充说明：[sites.md](../sites.md)

---

## 安装

```bash
git clone https://github.com/houseme/lckit.git
cd lckit
chmod +x lckit
sudo ./lckit setup
```

装完后命令为 `lckit`（`/usr/local/bin/lckit`）。

---

## 常用流程

**只做反向代理**

```bash
sudo lckit setup
sudo lckit app  add --name api --bin /opt/api/api --port 8080
sudo lckit site add -d api.example.com -t proxy --upstream http://127.0.0.1:8080
```

**静态站（自定义目录）**

```bash
sudo lckit site add -d demo.example.com -t static -r /data/rustfs/demo.example.com
```

**后补数据库与 PHP**

```bash
sudo lckit db  install mariadb
sudo lckit php install --version 8.4
sudo lckit php ext install common redis imagick
sudo lckit site add -d blog.example.com -t php
```

**国内镜像**

```bash
sudo lckit mirror set tuna
```

---

## 路径

| 项目 | 路径 |
|------|------|
| CLI | `/usr/local/bin/lckit` |
| 状态 | `/var/lib/lckit/` |
| 密钥 | `/var/lib/lckit/secrets/` |
| 站点配置 | `/etc/caddy/sites/` |
| 默认站点 | `/data/web/default` |
| 日志 | `/var/log/lckit.log` |

---

## 排障

```bash
lckit doctor
lckit site list
systemctl status caddy
journalctl -u caddy -n 50 --no-pager
```
