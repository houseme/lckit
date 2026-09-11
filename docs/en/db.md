# lckit db — Database install & status

[← Back to docs home](../README.md) · [中文](../zh/db.md)

Install MariaDB or PostgreSQL **after** `setup`, or inspect status.

## Subcommands

```bash
sudo lckit db install mariadb [--series 11.4] [--password SECRET]
sudo lckit db install postgresql [--password SECRET]
lckit db status
lckit db help
```

## Notes

- If `--password` is omitted, a strong random password is stored under `/var/lib/lckit/secrets/` (`0700`/`0600`)
  - MariaDB: `mariadb_root`
  - PostgreSQL: `postgresql_postgres`
- Services listen on **127.0.0.1** only
- Basic memory-based tuning (buffer pool / shared_buffers, etc.)

## Examples

```bash
sudo lckit db install mariadb
sudo lckit db install mariadb --series 11.8 --password 'Your.Strong.Pass'
sudo lckit db install postgresql

# read secrets
sudo cat /var/lib/lckit/secrets/mariadb_root
sudo cat /var/lib/lckit/secrets/postgresql_postgres

# connect
mariadb -uroot -p"$(sudo cat /var/lib/lckit/secrets/mariadb_root)"
sudo -u postgres psql
```

## Status

```bash
lckit db status
lckit doctor
systemctl status mariadb
systemctl status postgresql
```
