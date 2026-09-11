# lckit php ext — PHP 扩展

[← 返回文档首页](README.md) · [English](../en/php-ext.md)

安装常见 PHP 扩展（redis、opcache、imagick、swoole 等）。

## 子命令

```bash
sudo lckit php ext install <名称...>
sudo lckit php ext install common
sudo lckit php ext install full
lckit php ext list
lckit php ext status
```

## 预设包

| 预设 | 内容 |
|------|------|
| `common` | opcache, gd, mbstring, xml, curl, intl, zip, bcmath, exif, fileinfo, sqlite3 |
| `full` | common + redis, memcached, imagick, imap, ldap, bz2, sodium, mysql, pgsql |

## 支持的名称（节选）

`opcache` `gd` `mbstring` `xml` `curl` `intl` `zip` `bcmath` `exif` `fileinfo`  
`redis` `memcached` `imagick` `swoole` `apcu` `igbinary` `msgpack` `mongodb`  
`imap` `ldap` `bz2` `sodium` `mysql` `pgsql` `sqlite3`  
`ioncube` `sourceguardian`（商业 loader，尽力下载）

**不支持**（PHP 5 时代已过时）：`xcache` `eaccelerator` — 会跳过并提示。

## 示例

```bash
sudo lckit php ext install redis opcache imagick memcached swoole
sudo lckit php ext install full
sudo lckit php ext install ioncube
lckit php ext status
```

## 说明

- 已加载的扩展会跳过  
- `fileinfo` / `iconv` / `pdo` 等常随 PHP 自带  
- 安装后会自动 `systemctl restart` PHP-FPM  
- ionCube / SourceGuardian 需对应 PHP 版本的 loader；失败时请按官网手动安装  

## 验证

```bash
php -m | grep -E 'redis|imagick|swoole|Zend OPcache'
lckit php ext status
```
