# lckit mirror — 软件源镜像

查看或切换包管理镜像（官方 / 国内公共镜像）。

## 子命令

```bash
lckit mirror show
lckit mirror list
sudo lckit mirror set official|tuna|aliyun|ustc
sudo lckit mirror apply
```

## Profile

| Profile | 说明 |
|---------|------|
| `official` | 上游公共源（默认） |
| `tuna` | 清华大学 TUNA |
| `aliyun` | 阿里云 |
| `ustc` | 中科大 |

## 覆盖范围（安装后 apply）

- Debian/Ubuntu 系统源（避开第三方 list）
- EPEL（RHEL 系）
- PGDG apt 列表
- MariaDB list（TUNA/阿里云）
- sury PHP（Debian + TUNA）

Caddy 仍使用官方 Cloudsmith/COPR。

## 示例

```bash
lckit mirror show
sudo lckit mirror set tuna
sudo lckit mirror apply
```

配置文件：`/etc/lckit/mirror.conf`  
备份目录：`/var/lib/lckit/mirror-backup/`
