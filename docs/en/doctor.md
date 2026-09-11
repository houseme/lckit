# lckit doctor — Environment health check

Prints a summary of host, mirror, services, components, sites, and apps.

## Usage

```bash
lckit doctor
# equivalent
lckit status
```

## What it shows

- LCKit version, OS, mirror profile  
- Key paths (webroot / sites / secrets)  
- Service state: caddy, mariadb, postgresql, php-fpm, `lckit-app-*`  
- `db status` / `php status`  
- Site list and backend app list  

## Example

```bash
lckit doctor
```

Useful after deploy or when filing an issue.
