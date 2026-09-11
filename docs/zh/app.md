# lckit app — 后端应用单元

[← 返回文档首页](README.md) · [English](../en/app.md)

把 Go / Rust / 任意 HTTP 二进制注册为 systemd 服务，配合 `site add -t proxy` 使用。

## 子命令

```bash
lckit app add --name <名称> --bin <路径> [--port 8080] [选项]
lckit app list
lckit app rm <名称>
lckit app start|stop|restart|status <名称>
```

单元文件：`/etc/systemd/system/lckit-app-<名称>.service`  
索引：`/var/lib/lckit/apps.tsv`

## app add 选项

| 选项 | 说明 |
|------|------|
| `--name` | 服务名（必填，字母数字 `._-`） |
| `--bin` | 二进制绝对路径（必填） |
| `--port` | 监听端口，默认 8080 |
| `--workdir` | 工作目录，默认二进制所在目录 |
| `--user` | 运行用户，默认 root |
| `--args "..."` | 追加命令行参数 |
| `--env K=V` | 环境变量（可重复） |
| `--no-port-arg` | 不追加 `--port <port>`（程序用环境变量监听时） |
| `--description` | unit 描述 |
| `--force` | 覆盖已有 unit |

默认会在命令行追加 `--port <port>`（许多 Go/Rust CLI 支持）。

## 示例

```bash
sudo lckit app add --name api --bin /opt/api/api --port 8080 --workdir /opt/api

# 用环境变量监听
sudo lckit app add --name api --bin /opt/api/api --no-port-arg \
  --port 8080 --env PORT=8080 --env RUST_LOG=info

# 反代
sudo lckit site add -d api.example.com -t proxy --upstream http://127.0.0.1:8080
```

## 建议

后端只监听 `127.0.0.1`，公网仅开放 Caddy 的 80/443。

## 排障

```bash
lckit app status <名称>
journalctl -u lckit-app-<名称> -n 50 --no-pager
ss -tlnp | grep <端口>
```
