# lckit app — Backend application units

Register a Go / Rust / any HTTP binary as a systemd service, then front it with `site add -t proxy`.

## Subcommands

```bash
lckit app add --name <name> --bin <path> [--port 8080] [options]
lckit app list
lckit app rm <name>
lckit app start|stop|restart|status <name>
```

Unit path: `/etc/systemd/system/lckit-app-<name>.service`  
Index: `/var/lib/lckit/apps.tsv`

## app add options

| Option | Description |
|--------|-------------|
| `--name` | Service name (required) |
| `--bin` | Absolute path to binary (required) |
| `--port` | Listen port, default 8080 |
| `--workdir` | Working directory (defaults to binary dir) |
| `--user` | Run-as user, default root |
| `--args "..."` | Extra CLI args |
| `--env K=V` | Environment variable (repeatable) |
| `--no-port-arg` | Do not append `--port <port>` |
| `--description` | Unit description |
| `--force` | Overwrite existing unit |

By default `--port <port>` is appended (common for Go/Rust CLIs).

## Examples

```bash
sudo lckit app add --name api --bin /opt/api/api --port 8080 --workdir /opt/api

# listen via env vars
sudo lckit app add --name api --bin /opt/api/api --no-port-arg \
  --port 8080 --env PORT=8080 --env RUST_LOG=info

# reverse proxy
sudo lckit site add -d api.example.com -t proxy --upstream http://127.0.0.1:8080
```

## Recommendation

Bind backends to `127.0.0.1`; expose only Caddy 80/443 publicly.

## Troubleshooting

```bash
lckit app status <name>
journalctl -u lckit-app-<name> -n 50 --no-pager
ss -tlnp | grep <port>
```
