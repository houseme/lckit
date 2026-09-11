# LCKit site & app 指南

[← 返回文档首页](zh/README.md) · [English](en/README.md)

## 站点类型

| 类型 | 用途 | 关键参数 |
|------|------|----------|
| `static` | 静态文件 | `-r/--root`（默认 `/data/web/<域名>`） |
| `php` | PHP-FPM | `-s/--socket`（默认自动使用安装时的 socket） |
| `proxy` | 反向代理 | `--upstream`（如 `http://127.0.0.1:8080`） |

配置文件：`/etc/caddy/sites/<域名>.caddy`  
主配置：`/etc/caddy/Caddyfile`（import sites）

## site 命令

```bash
lckit site add -d example.com -t static
lckit site add -d example.com -t static -r /var/www/example --force
lckit site add -d blog.example.com -t php
lckit site add -d api.example.com -t proxy --upstream http://127.0.0.1:8080
lckit site add -d nas.lan -t proxy --upstream http://127.0.0.1:9000 --no-tls
lckit site list
lckit site show api.example.com
lckit site rm api.example.com
```

说明：

- 默认启用 Caddy 自动 HTTPS（`--tls`）；内网域名请加 `--no-tls`。
- `proxy` 会注入 `X-Real-IP` / `X-Forwarded-For` / `X-Forwarded-Proto` 等头。
- WebSocket 由 Caddy `reverse_proxy` 自动处理。

## app 命令（Go / Rust 等）

```bash
lckit app add --name api --bin /opt/api/api --port 8080 \
  --workdir /opt/api --user app --env RUST_LOG=info

# 程序自己读环境变量监听端口时：
lckit app add --name api --bin /opt/api/api --no-port-arg \
  --env PORT=8080 --env BIND=127.0.0.1:8080

lckit app list
lckit app status api
lckit app restart api
lckit app rm api
```

生成单元：`/etc/systemd/system/lckit-app-<name>.service`  
索引：`/var/lib/lckit/apps.tsv`

建议后端只监听 `127.0.0.1`，由 Caddy 暴露 80/443。

## 默认静态站

| 项 | 路径 |
|----|------|
| 文档根 | `/data/web/default` |
| 欢迎页 | `/data/web/default/index.html` |
| 站点配置 | `/etc/caddy/sites/00-default.caddy` |

## 排障

```bash
lckit doctor
systemctl status caddy
journalctl -u caddy -n 100 --no-pager
caddy validate --config /etc/caddy/Caddyfile
ss -tlnp
```

| 现象 | 处理 |
|------|------|
| 502 | 检查 `--upstream` 端口是否监听；`lckit app status <name>` |
| HTTPS 失败 | 域名解析 / 防火墙 80；或改 `--no-tls` |
| site 已存在 | `--force` 或先 `lckit site rm` |
