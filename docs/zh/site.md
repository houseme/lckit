# lckit site — 虚拟主机

[← 返回文档首页](README.md) · [English](../en/site.md)

管理静态 / PHP / 反向代理站点。配置写入 `/etc/caddy/sites/<域名>.caddy`。

## 子命令

```bash
lckit site add -d <域名> -t static|php|proxy [选项]
lckit site list
lckit site show <域名>
lckit site rm  <域名>
```

## site add 选项

| 选项 | 说明 |
|------|------|
| `-d, --domain` | 域名（必填） |
| `-t, --type` | `static`（默认）/ `php` / `proxy` |
| `--upstream` | proxy 上游，如 `http://127.0.0.1:8080` |
| `-r, --root` | 站点目录，默认 `/data/web/<域名>` |
| `-s, --socket` | php FastCGI socket（默认自动探测） |
| `--tls` / `--no-tls` | 自动 HTTPS / 仅 HTTP |
| `--force` | 覆盖已有配置 |

## 示例

```bash
# 静态站 + 自定义目录
sudo lckit site add -d demo.example.com -t static -r /data/rustfs/demo.example.com

# PHP
sudo lckit site add -d blog.example.com -t php

# 反向代理 Go/Rust
sudo lckit site add -d api.example.com -t proxy --upstream http://127.0.0.1:8080

# 内网无证书
sudo lckit site add -d panel.lan -t proxy --upstream http://127.0.0.1:8443 --no-tls
```

## 说明

- WebSocket 由 Caddy `reverse_proxy` 自动处理  
- proxy 会注入 `X-Real-IP` / `X-Forwarded-For` / `X-Forwarded-Proto` 等头  
- 文档根若不存在会自动创建；static/php 会写入占位首页  

## 排障

```bash
lckit site show <域名>
systemctl restart caddy
journalctl -u caddy -n 50 --no-pager
caddy validate --config /etc/caddy/Caddyfile
```
