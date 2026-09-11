# lckit php — PHP-FPM install & status

[← Back to docs home](README.md) · [中文](../zh/php.md)

## Subcommands

```bash
sudo lckit php install [--version 8.4]
sudo lckit php install 8.3
lckit php status
lckit php ext ...    # extensions, see php-ext.md
```

## Notes

- Debian/Ubuntu: sury / ondrej PPA  
- RHEL: Remi module  
- Configures FPM pool user (prefers `caddy`), socket path, opcache, baseline hardening  
- State file: `/var/lib/lckit/php.env`

On Ubuntu the live socket is usually `/run/php/phpX.Y-fpm.sock` (auto-detected).

## Examples

```bash
sudo lckit php install --version 8.4
lckit php status

sudo lckit site add -d blog.example.com -t php -r /data/web/blog.example.com
```

## Extensions

```bash
sudo lckit php ext install common
sudo lckit php ext install redis imagick memcached swoole
```

See [php-ext.md](php-ext.md).

## Troubleshooting

```bash
lckit php status
systemctl status php8.4-fpm
php-fpm8.4 -t
ls -la /run/php/
```
