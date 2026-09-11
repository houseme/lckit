# lckit doctor — 环境体检

打印主机、镜像、服务、组件、站点与应用的摘要。

## 用法

```bash
lckit doctor
# 等价
lckit status
```

## 输出内容

- LCKit 版本、系统、镜像 profile  
- 关键路径（webroot / sites / secrets）  
- 服务状态：caddy、mariadb、postgresql、php-fpm、`lckit-app-*`  
- `db status` / `php status`  
- 站点列表与后端应用列表  

## 示例

```bash
lckit doctor
```

适合部署后自检或提 issue 时附带输出。
