# lckit mirror — Package mirrors

[← Back to docs home](../README.md) · [中文](../zh/mirror.md)

Show or switch package-manager mirrors (official / China public mirrors).

## Subcommands

```bash
lckit mirror show
lckit mirror list
sudo lckit mirror set official|tuna|aliyun|ustc
sudo lckit mirror apply
```

## Profiles

| Profile | Description |
|---------|-------------|
| `official` | Upstream public repos (default) |
| `tuna` | Tsinghua TUNA |
| `aliyun` | Aliyun |
| `ustc` | USTC |

## Coverage (`apply` after install)

- Debian/Ubuntu OS sources (skips third-party lists)
- EPEL (RHEL family)
- PGDG apt list
- MariaDB list (TUNA/Aliyun)
- sury PHP (Debian + TUNA)

Caddy remains on official Cloudsmith/COPR.

## Examples

```bash
lckit mirror show
sudo lckit mirror set tuna
sudo lckit mirror apply
```

Config: `/etc/lckit/mirror.conf`  
Backups: `/var/lib/lckit/mirror-backup/`
