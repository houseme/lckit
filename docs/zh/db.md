# lckit db — 数据库安装与状态

在 **setup 之后** 安装 MariaDB 或 PostgreSQL，或查看状态。

## 子命令

```bash
sudo lckit db install mariadb [--series 11.4] [--password SECRET]
sudo lckit db install postgresql [--password SECRET]
lckit db status
lckit db help
```

## 说明

- 省略 `--password` 时生成随机强密码，写入 `/var/lib/lckit/secrets/`（目录 `0700`，文件 `0600`）
  - MariaDB: `mariadb_root`
  - PostgreSQL: `postgresql_postgres`
- 仅监听 **127.0.0.1**
- 按机器内存做基础调优（buffer pool / shared_buffers 等）

## 示例

```bash
sudo lckit db install mariadb
sudo lckit db install mariadb --series 11.8 --password 'Your.Strong.Pass'
sudo lckit db install postgresql

# 读取密码
sudo cat /var/lib/lckit/secrets/mariadb_root
sudo cat /var/lib/lckit/secrets/postgresql_postgres

# 连接
mariadb -uroot -p"$(sudo cat /var/lib/lckit/secrets/mariadb_root)"
sudo -u postgres psql
```

## 状态

```bash
lckit db status
lckit doctor
systemctl status mariadb
systemctl status postgresql
```
