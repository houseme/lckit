# lckit site — Virtual hosts

[← Back to docs home](../README.md) · [中文](../zh/site.md)

Manage static / PHP / reverse-proxy sites. Config files live in `/etc/caddy/sites/<domain>.caddy`.

## Subcommands

```bash
lckit site add -d <domain> -t static|php|proxy [options]
lckit site list
lckit site show <domain>
lckit site rm  <domain>
```

## site add options

| Option | Description |
|--------|-------------|
| `-d, --domain` | Domain (required) |
| `-t, --type` | `static` (default) / `php` / `proxy` |
| `--upstream` | Proxy upstream, e.g. `http://127.0.0.1:8080` |
| `-r, --root` | Document root, default `/data/web/<domain>` |
| `-s, --socket` | PHP FastCGI socket (auto-detected) |
| `--tls` / `--no-tls` | Automatic HTTPS / HTTP only |
| `--force` | Overwrite existing site |

## Examples

```bash
# Static site with custom directory
sudo lckit site add -d demo.example.com -t static -r /data/rustfs/demo.example.com

# PHP
sudo lckit site add -d blog.example.com -t php

# Reverse proxy to Go/Rust
sudo lckit site add -d api.example.com -t proxy --upstream http://127.0.0.1:8080

# Intranet, no TLS
sudo lckit site add -d panel.lan -t proxy --upstream http://127.0.0.1:8443 --no-tls
```

## Notes

- WebSockets work automatically through Caddy `reverse_proxy`
- Proxy sites inject `X-Real-IP` / `X-Forwarded-For` / `X-Forwarded-Proto`
- Missing docroots are created; static/php get a placeholder index

## Troubleshooting

```bash
lckit site show <domain>
systemctl restart caddy
journalctl -u caddy -n 50 --no-pager
caddy validate --config /etc/caddy/Caddyfile
```
