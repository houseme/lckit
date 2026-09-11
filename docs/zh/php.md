# lckit php — PHP-FPM 安装与状态

## 子命令

```bash
sudo lckit php install [--version 8.4]
sudo lckit php install 8.3
lckit php status
lckit php ext ...    # 扩展，见 php-ext.md
```

## 说明

- Debian/Ubuntu：sury / ondrej PPA  
- RHEL：Remi module  
- 会配置 FPM pool 用户（优先 `caddy`）、socket 路径、opcache 与基础安全项  
- 状态文件：`/var/lib/lckit/php.env`

Ubuntu 实际 socket 通常为 `/run/php/phpX.Y-fpm.sock`（自动探测）。

## 示例

```bash
sudo lckit php install --version 8.4
lckit php status

sudo lckit site add -d blog.example.com -t php -r /data/web/blog.example.com
```

## 扩展

```bash
sudo lckit php ext install common
sudo lckit php ext install redis imagick memcached swoole
```

详见 [php-ext.md](php-ext.md)。

## 排障

```bash
lckit php status
systemctl status php8.4-fpm
php-fpm8.4 -t
ls -la /run/php/
```
