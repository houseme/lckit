# lckit setup — 交互安装

安装 LCKit 栈（Caddy + 可选数据库 / PHP）。

## 用法

```bash
sudo ./lckit setup
# 安装到 PATH 之后
sudo lckit setup
```

## 交互项

1. **镜像源**：official / tuna / aliyun / ustc  
2. **组件**：
   - Caddy（默认 Y）
   - MariaDB（默认 n）
   - PHP-FPM（默认 n）
   - PostgreSQL 18（默认 n）
3. 若选中数据库，会询问版本与密码（可回车生成/使用默认流程）

至少勾选一个组件。

## 做了什么

- 系统准备（基础包、BBR 尽力开启、防火墙放行 80/443）
- 安装所选组件
- Caddy 默认静态站：`/data/web/default`
- 将 CLI 安装到 `/usr/local/bin/lckit`

## 之后还能装

```bash
sudo lckit db install mariadb
sudo lckit db install postgresql
sudo lckit php install --version 8.4
```

详见 [db.md](db.md)、[php.md](php.md)。

## 排障

```bash
lckit doctor
journalctl -u caddy -n 50 --no-pager
```
