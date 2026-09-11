# LCKit

**LCKit**（Linux + Caddy Kit）是一款模块化 Bash 工具：以 [Caddy](https://caddyserver.com) 为反向代理 / TLS / 静态站前端，可选安装 MariaDB、PHP-FPM、PostgreSQL 18，并提供 Go / Rust 等 HTTP 后端的应用单元与站点管理，支持国内公共镜像。

- **协议**：Apache License 2.0  
- **实现声明**：本仓库为**独立实现**，仅借鉴「Linux + Caddy 栈管理」的产品思想，**不**基于 GPL 源码改写。  
- **主命令**：`lckit`

English README: [README.md](README.md) · 使用指南: [docs/README.md](docs/README.md)

## 功能

| 能力 | 命令 |
|------|------|
| 交互安装栈 | `lckit setup` |
| **安装后补装** MariaDB / PostgreSQL | `lckit db install mariadb\|postgresql` |
| **安装后补装** PHP-FPM | `lckit php install` |
| PHP 扩展 | `lckit php ext install ...` |
| 站点（static / php / proxy） | `lckit site add\|list\|show\|rm` |
| 后端应用 systemd 单元 | `lckit app add\|list\|rm\|start\|stop\|restart\|status` |
| 镜像源 | `lckit mirror show\|set\|apply\|list` |
| 环境体检 | `lckit doctor` |

安装 Caddy 后会自动创建默认静态欢迎站：`/data/web/default`。

## 支持系统

- Enterprise Linux 8 / 9 / 10  
- Debian 11 / 12 / 13  
- Ubuntu 22.04 / 24.04  

需要 root 与互联网。

## 安装

```bash
git clone https://github.com/houseme/lckit-apache.git
cd lckit-apache
chmod +x lckit
sudo ./lckit setup
```

安装结束后 CLI 位于 `/usr/local/bin/lckit`。

## 安装后补装数据库 / PHP

```bash
sudo lckit db install mariadb
sudo lckit db install postgresql
sudo lckit php install --version 8.4
sudo lckit php ext install common redis imagick

lckit db status
lckit php status
lckit doctor
```

- 省略 `--password` 时生成随机密码，存放在 `/var/lib/lckit/secrets/`（`0700`/`0600`）
- 数据库仅监听 `127.0.0.1`
- 已对 MariaDB / PostgreSQL / PHP-FPM / opcache 做基础内存调优

## 快速开始

```bash
# 静态站（自定义目录）
sudo lckit site add -d example.com -t static -r /data/web/example.com

# Go / Rust 反向代理
sudo lckit app  add --name api --bin /opt/api/api --port 8080 --workdir /opt/api
sudo lckit site add -d api.example.com -t proxy --upstream http://127.0.0.1:8080

# PHP
sudo lckit site add -d blog.example.com -t php

# 国内镜像
sudo lckit mirror set tuna
```

## 仓库结构

```
lckit-apache/
├── lckit                 # CLI 入口
├── lib/                  # 模块
├── share/default-site/   # Caddy 默认静态页
├── docs/                 # 中英文使用指南
│   ├── zh/  en/
│   └── README.md
├── README.md             # 英文
├── README_CN.md          # 中文
└── LICENSE               # Apache-2.0
```

## 致谢

感谢 Caddy、MariaDB、PostgreSQL、PHP 等开源生态，以及社区中各类 Web 栈一键安装思路的启发。

## License

Apache License 2.0，见 [LICENSE](LICENSE)。
