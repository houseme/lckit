# lckit php ext — PHP extensions

Install common PHP extensions (redis, opcache, imagick, swoole, …).

## Subcommands

```bash
sudo lckit php ext install <names...>
sudo lckit php ext install common
sudo lckit php ext install full
lckit php ext list
lckit php ext status
```

## Presets

| Preset | Contents |
|--------|----------|
| `common` | opcache, gd, mbstring, xml, curl, intl, zip, bcmath, exif, fileinfo, sqlite3 |
| `full` | common + redis, memcached, imagick, imap, ldap, bz2, sodium, mysql, pgsql |

## Supported names (excerpt)

`opcache` `gd` `mbstring` `xml` `curl` `intl` `zip` `bcmath` `exif` `fileinfo`  
`redis` `memcached` `imagick` `swoole` `apcu` `igbinary` `msgpack` `mongodb`  
`imap` `ldap` `bz2` `sodium` `mysql` `pgsql` `sqlite3`  
`ioncube` `sourceguardian` (commercial loaders, best-effort download)

**Not supported** (obsolete PHP 5 era): `xcache` `eaccelerator` — skipped with a warning.

## Examples

```bash
sudo lckit php ext install redis opcache imagick memcached swoole
sudo lckit php ext install full
sudo lckit php ext install ioncube
lckit php ext status
```

## Notes

- Already-loaded extensions are skipped  
- `fileinfo` / `iconv` / `pdo` are often bundled with PHP  
- PHP-FPM is restarted after install  
- ionCube / SourceGuardian need a loader matching your PHP version  

## Verify

```bash
php -m | grep -E 'redis|imagick|swoole|Zend OPcache'
lckit php ext status
```
