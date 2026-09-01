# 配置指南

## 配置文件结构

主配置文件位于 `~/.config/mihomo/config.yaml`，完整模板见 [config.yaml](../references/config.yaml)。

### 创建配置目录

```bash
mkdir -p ~/.config/mihomo/proxy-providers
```

## 基础配置

### 核心设置

```yaml
# ===== 基础设置 =====
# 混合端口（HTTP + SOCKS5 合一）
mixed-port: 7897
# 是否允许局域网连接（生产环境建议 false）
allow-lan: false
# 路由模式: rule / global / direct
mode: rule
# 日志级别: silent / error / warning / info / debug
log-level: info

# ===== 控制面板 =====
# RESTful API 地址（用于 Dashboard 和热重载）
external-controller: 127.0.0.1:9090
# Dashboard UI 目录（需单独下载 metacubexd）
external-ui: ui
# API 密钥（生产环境必须设置）
secret: ""

# ===== GeoIP 设置 =====
geodata-mode: false
geo-auto-update: false
geo-update-interval: 24
```

### 配置校验

```bash
# 检查配置文件语法
~/bin/mihomo -d ~/.config/mihomo -t
```

输出样例：
```
[2024-01-15 10:30:00] [Info] Start initial configuration in progress
[2024-01-15 10:30:00] [Info] Configuration loaded successfully
```

## 配置热重载

修改配置后无需重启服务，通过 API 热重载：

```bash
#!/usr/bin/env bash
# reload-config.sh - 热重载 Mihomo 配置
set -euo pipefail

CONTROLLER="127.0.0.1:9090"
CONFIG_DIR="${HOME}/.config/mihomo"

# 先校验配置
if ! ~/bin/mihomo -d "$CONFIG_DIR" -t; then
    echo "[ERROR] 配置校验失败，拒绝重载"
    exit 1
fi

# 通过 API 热重载
if curl -s -X PUT "http://${CONTROLLER}/configs?force=true" \
    -H "Content-Type: application/json" \
    -d "{\"path\":\"${CONFIG_DIR}/config.yaml\"}"; then
    echo "[INFO] 配置热重载成功"
else
    echo "[ERROR] 热重载失败，检查 API 是否可达"
    exit 1
fi
```

## TUN 模式配置

TUN 模式通过虚拟网卡接管系统所有流量，解决部分应用不走代理的问题（如游戏、UDP 流量）。

### 前置条件

- Linux 内核 ≥ 4.9（TUN/TAP 支持）
- root 权限或 `CAP_NET_ADMIN` 能力

### 配置方法

在 `config.yaml` 中添加 `tun` 段：

```yaml
# ===== TUN 模式 =====
tun:
  enable: true
  stack: system  # system / gvisor / mixed
  # system: 内核级 TUN，性能最好，但部分系统不支持
  # gvisor: 用户态网络栈，兼容性好，性能略差
  # mixed: 两者结合，自动回退
  auto-route: true           # 自动设置路由规则
  auto-detect-interface: true # 自动检测出口接口
  strict-route: false        # 是否启用严格路由（建议 false）
  # 需要走 TUN 的地址段（可选）
  routes:
    - 0.0.0.0/1
    - 128.0.0.0/1
  # 排除地址段（不走 TUN）
  exclude-routes:
    - 192.168.0.0/16
    - 10.0.0.0/8
    - 172.16.0.0/12
  # DNS 劫持（将 DNS 请求劫持到 TUN 接口）
  enable-dns-hijack: true
  # 独立 DNS 配置（可选）
  # dns-hijack:
  #   - any:53
  #   - tcp://any:53
```

### TUN 模式注意事项

1. **与 DNS 配置冲突**：启用 TUN 后，`dns` 段中的 `nameserver` 会接管系统 DNS
2. **路由环路**：确保 `exclude-routes` 包含本地网络段，否则可能导致路由环路
3. **性能**：`stack: system` 性能最佳，但需要内核支持；`stack: gvisor` 兼容性最好
4. **防火墙**：TUN 模式下需要确保防火墙允许 TUN 接口流量

### TUN 模式验证

```bash
# 检查 TUN 接口是否存在
ip addr show | grep tun

# 检查路由表
ip route show table all | grep tun

# 测试 UDP 代理（TUN 模式下 UDP 也会走代理）
curl -x socks5://127.0.0.1:7897 https://www.gstatic.com/generate_204
```

## DNS 高级设置

### fake-ip 模式

fake-ip 模式将域名解析为虚假 IP（198.18.0.0/15），由 mihomo 在转发时再解析真实 IP，解决 DNS 污染问题：

```yaml
# ===== DNS 配置 =====
dns:
  enable: true
  listen: 0.0.0.0:53
  # fake-ip 模式
  fake-ip-range: 198.18.0.1/16
  fake-ip-filter:
    # 以下域名不使用 fake-ip，直接解析
    - "+.lan"
    - "+.local"
    - "+.example.com"
  # 上游 DNS 服务器
  nameserver:
    - https://doh.pub/dns-query        # 腾讯 DoH
    - https://dns.alidns.com/dns-query # 阿里 DoH
  fallback:
    - https://1.1.1.1/dns-query        # Cloudflare DoH
    - https://8.8.8.8/dns-query        # Google DoH
  # 域名分流规则
  nameserver-policy:
    "+.cn": "https://dns.alidns.com/dns-query"  # 国内域名走阿里 DNS
    "+.push.apple.com": "https://doh.pub/dns-query"
```

### DNS over HTTPS (DoH)

```yaml
dns:
  enable: true
  listen: 0.0.0.0:53
  # 所有上游使用 DoH
  nameserver:
    - https://doh.pub/dns-query
    - https://dns.alidns.com/dns-query
  # 预解析（加速首次访问）
  prefetch: true
  # 使用系统 hosts 文件
  use-hosts: true
```

### DNS 配置注意事项

1. **端口冲突**：`listen: 0.0.0.0:53` 可能与系统 `systemd-resolved` 冲突，需先停止：
   ```bash
   sudo systemctl stop systemd-resolved
   sudo systemctl disable systemd-resolved
   ```
2. **fake-ip 与 TUN**：TUN 模式下 fake-ip 效果最佳，非 TUN 模式下部分应用可能不兼容
3. **fallback 机制**：当 `nameserver` 全部不可用时，自动使用 `fallback` 服务器

## 多订阅源负载均衡

当有多个机场订阅时，可以配置负载均衡策略：

### 订阅源定义

```yaml
proxy-providers:
  # 机场 A
  airplane-a:
    type: http
    url: "https://airplane-a.com/sub?token=token-a"
    interval: 3600
    path: ./proxy-providers/airplane-a.yaml
    health-check:
      enable: true
      interval: 600
      url: http://www.gstatic.com/generate_204

  # 机场 B
  airplane-b:
    type: http
    url: "https://airplane-b.com/sub?token=token-b"
    interval: 3600
    path: ./proxy-providers/airplane-b.yaml
    health-check:
      enable: true
      interval: 600
      url: http://www.gstatic.com/generate_204

  # 免费订阅（稳定性差，作为备用）
  free-sub:
    type: http
    url: "https://free-sub.example.com/sub"
    interval: 7200
    path: ./proxy-providers/free-sub.yaml
    health-check:
      enable: true
      interval: 1200
      url: http://www.gstatic.com/generate_204
```

### 负载均衡策略

```yaml
proxy-groups:
  # 策略 1：自动选择（所有订阅中延迟最低）
  - name: "AUTO"
    type: url-test
    use:
      - airplane-a
      - airplane-b
      - free-sub
    url: "http://www.gstatic.com/generate_204"
    interval: 300
    # 容差：延迟差异在 50ms 内不切换
    tolerance: 50

  # 策略 2：负载均衡（按权重分配流量）
  - name: "LOAD-BALANCE"
    type: load-balance
    use:
      - airplane-a
      - airplane-b
    url: "http://www.gstatic.com/generate_204"
    interval: 300
    # 算法: round-robin / consistent-hashing / random
    strategy: consistent-hashing

  # 策略 3：故障转移（主订阅挂了自动切备用）
  - name: "FALLBACK"
    type: fallback
    use:
      - airplane-a
      - airplane-b
      - free-sub
    url: "http://www.gstatic.com/generate_204"
    interval: 300

  # 策略 4：手动选择（用户自行选择订阅）
  - name: "SELECT"
    type: select
    use:
      - airplane-a
      - airplane-b
      - free-sub

  # 策略 5：国内网站直连 + 国外走代理
  - name: "PROXY"
    type: select
    use:
      - AUTO
      - airplane-a
      - airplane-b
```

### 路由规则（配合多订阅）

```yaml
rules:
  # 国内直连
  - GEOIP,CN,DIRECT
  # 机场 A 专用规则（如流媒体走机场 A）
  - DOMAIN-SUFFIX,netflix.com,airplane-a
  - DOMAIN-SUFFIX,hbomax.com,airplane-a
  # 机场 B 专用规则（如学术资源走机场 B）
  - DOMAIN-SUFFIX,sci-hub.se,airplane-b
  # 默认走自动选择
  - MATCH,AUTO
```

## 规则分片策略

当规则数量庞大时（如使用外部规则集），直接加载会导致启动缓慢。通过规则分片优化：

### 方法 1：使用 rule-providers

```yaml
rule-providers:
  # 国内直连规则
  direct-rules:
    type: http
    behavior: classical
    url: "https://cdn.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/direct.txt"
    path: ./rule-providers/direct.yaml
    interval: 86400

  # 代理规则
  proxy-rules:
    type: http
    behavior: classical
    url: "https://cdn.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/proxy.txt"
    path: ./rule-providers/proxy.yaml
    interval: 86400

  # 广告屏蔽
  ad-rules:
    type: http
    behavior: classical
    url: "https://cdn.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/reject.txt"
    path: ./rule-providers/reject.yaml
    interval: 86400

  # GFW 列表
  gfw:
    type: http
    behavior: domain
    url: "https://cdn.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/gfw.txt"
    path: ./rule-providers/gfw.yaml
    interval: 86400

rules:
  # 按优先级依次匹配
  - RULE-SET,ad-rules,REJECT
  - RULE-SET,direct-rules,DIRECT
  - RULE-SET,gfw,PROXY
  - RULE-SET,proxy-rules,PROXY
  - GEOIP,CN,DIRECT
  - MATCH,PROXY
```

### 方法 2：按域名后缀分片

```yaml
rules:
  # 流媒体
  - DOMAIN-SUFFIX,netflix.com,STREAMING
  - DOMAIN-SUFFIX,hbomax.com,STREAMING
  - DOMAIN-SUFFIX,disneyplus.com,STREAMING

  # 开发者
  - DOMAIN-SUFFIX,github.com,DEV
  - DOMAIN-SUFFIX,stackoverflow.com,DEV
  - DOMAIN-SUFFIX,docker.com,DEV

  # 社交媒体
  - DOMAIN-SUFFIX,twitter.com,SOCIAL
  - DOMAIN-SUFFIX,youtube.com,SOCIAL
  - DOMAIN-SUFFIX,reddit.com,SOCIAL

  # 默认
  - MATCH,PROXY
```

## 与国内机场订阅的特殊适配

国内机场订阅常见格式与适配方法：

### 订阅格式识别

| 格式 | 说明 | 适配方式 |
|------|------|----------|
| Clash 订阅 | YAML 格式，mihomo 原生支持 | 直接使用 `type: http` |
| V2Ray 订阅 | Base64 编码的 vmess:// 链接 | mihomo 自动识别 |
| SSR 订阅 | ssr:// 格式 | mihomo 自动识别 |
| 单节点订阅 | 单个 vmess:// 或 ss:// 链接 | mihomo 自动识别 |
| 带 `flag=true` 的订阅 | 返回带国旗标识的节点 | mihomo 自动处理 |

### 订阅转换

部分机场只提供 Shadowsocks 订阅，需要转换为 Clash 格式：

```bash
# 使用在线转换服务
# 将订阅地址拼接到转换服务 URL 后
SUB_URL="https://airplane.com/sub?token=xxx"
CONVERTED_URL="https://sub-web.netlify.app/sub?target=clash&url=${SUB_URL}&insert=false&config=https://raw.githubusercontent.com/ACL4SSR/ACL4SSR/master/Clash/config/ACL4SSR_Online.ini"

# 在 proxy-providers 中使用转换后的地址
```

### 国内机场常见问题

1. **订阅返回 403**：检查 token 是否过期，或机场是否限制了 IP
2. **节点名称乱码**：部分机场使用 Base64 编码节点名，mihomo 会自动解码
3. **节点延迟异常**：国内机场节点延迟测试可能不准确，建议关闭 `health-check` 或调整 `url` 为国内测速地址
4. **订阅更新频率**：部分机场限制订阅更新频率（如每小时 1 次），设置 `interval` 时注意不要过短

### 推荐配置（国内机场）

```yaml
proxy-providers:
  my-airplane:
    type: http
    url: "https://your-airplane.com/sub?token=your-token"
    interval: 3600
    path: ./proxy-providers/my-airplane.yaml
    health-check:
      enable: true
      interval: 600
      # 使用国内测速地址（更准确）
      url: http://www.gstatic.cn/generate_204
      # 或使用机场自带的测速
      # url: http://connectivitycheck.platform.hicloud.com/generate_204

## 配置参数说明表

以下为 mihomo 核心配置参数的完整说明：

### 基础参数

| 参数名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `mixed-port` | int | 0 | 混合端口（HTTP + SOCKS5），0=禁用 |
| `port` | int | 0 | HTTP 代理端口（与 socks-port 二选一） |
| `socks-port` | int | 0 | SOCKS5 代理端口 |
| `redir-port` | int | 0 | 流量重定向端口（Linux/macOS） |
| `tproxy-port` | int | 0 | TProxy 端口（Linux） |
| `allow-lan` | bool | false | 是否允许局域网连接 |
| `bind-address` | string | "*" | 绑定地址，"*"=所有接口 |
| `mode` | string | rule | 运行模式：rule / global / direct |
| `log-level` | string | info | 日志级别：silent / error / warning / info / debug |
| `ipv6` | bool | false | 是否启用 IPv6 |

### 控制器参数

| 参数名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `external-controller` | string | - | RESTful API 地址，如 `127.0.0.1:9090` |
| `external-controller-tls` | string | - | TLS RESTful API 地址 |
| `external-ui` | string | - | Dashboard UI 目录名 |
| `secret` | string | - | API 认证密钥 |
| `external-controller-cors` | object | - | CORS 配置 |
| `external-controller-cors-allow-origins` | list | - | 允许的 Origin 列表 |

### GeoIP 参数

| 参数名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `geodata-mode` | bool | false | 使用 GeoIP 而非 MMDB |
| `geo-auto-update` | bool | false | 自动更新 GeoIP 数据库 |
| `geo-update-interval` | int | 24 | 更新间隔（小时） |
| `geox-url` | object | - | GeoIP/GeoSite/MMDB 自定义下载地址 |

### DNS 参数

| 参数名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `dns.enable` | bool | false | 是否启用内置 DNS 服务器 |
| `dns.listen` | string | - | DNS 监听地址，如 `0.0.0.0:53` |
| `dns.fake-ip-range` | string | - | fake-ip 网段，如 `198.18.0.1/16` |
| `dns.fake-ip-filter` | list | - | 不使用 fake-ip 的域名列表 |
| `dns.nameserver` | list | - | 主要 DNS 服务器列表 |
| `dns.fallback` | list | - | 回退 DNS 服务器列表 |
| `dns.nameserver-policy` | object | - | 域名分流 DNS 策略 |
| `dns.prefer-h3` | bool | false | DoH 优先使用 HTTP/3 |
| `dns.use-hosts` | bool | true | 是否使用系统 hosts 文件 |
| `dns.enable-dns-hijack` | bool | false | 是否劫持所有 DNS 请求到 TUN |

### TUN 参数

| 参数名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `tun.enable` | bool | false | 是否启用 TUN 模式 |
| `tun.stack` | string | system | 网络栈：system / gvisor / mixed |
| `tun.auto-route` | bool | true | 自动设置路由规则 |
| `tun.auto-detect-interface` | bool | true | 自动检测出口网卡 |
| `tun.strict-route` | bool | false | 严格路由（防止本地流量走 TUN） |
| `tun.mtu` | int | 9000 | TUN 接口 MTU |
| `tun.routes` | list | - | 强制走 TUN 的地址段 |
| `tun.exclude-routes` | list | - | 不走 TUN 的地址段 |
| `tun.endpoint-independent-nat` | bool | false | 独立端口 NAT |
| `tun.enable-dns-hijack` | bool | false | 劫持 DNS 到 TUN 接口 |

### 代理组参数

| 参数名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `type` | string | - | 类型：select / url-test / fallback / load-balance / relay |
| `proxies` | list | - | 节点名称列表 |
| `use` | list | - | 引用的 proxy-providers 名称 |
| `url` | string | - | 延迟测试 URL |
| `interval` | int | 300 | 延迟测试间隔（秒） |
| `tolerance` | int | 50 | 延迟容差（ms），差异内不切换 |
| `strategy` | string | consistent-hashing | 负载均衡算法：round-robin / consistent-hashing / random |
| `lazy` | bool | true | 懒加载（仅在使用时测试） |
| `disable-udp` | bool | false | 禁用 UDP |
| `filter` | string | - | 节点名过滤正则 |
| `exclude-filter` | string | - | 节点名排除正则 |

### 订阅源参数

| 参数名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `type` | string | http | 类型：http / file |
| `url` | string | - | 订阅 URL |
| `interval` | int | 3600 | 更新间隔（秒） |
| `path` | string | - | 本地存储路径 |
| `health-check.enable` | bool | false | 是否启用健康检查 |
| `health-check.interval` | int | 600 | 健康检查间隔（秒） |
| `health-check.url` | string | - | 健康检查 URL |
| `health-check.lazy` | bool | true | 懒加载 |
| `override.additional-prefix` | string | - | 节点名前缀 |
| `override.additional-suffix` | string | - | 节点名后缀 |
| `override.proxy-name-separator` | string | - | 节点名分隔符 |

## 高级 DNS 配置模板

### 完整 fake-ip + DoH + 域名分流

```yaml
dns:
  enable: true
  listen: 0.0.0.0:53
  ipv6: false

  # fake-ip 配置
  fake-ip-range: 198.18.0.1/16
  fake-ip-filter:
    # 不使用 fake-ip 的域名（直接解析）
    - "+.lan"
    - "+.local"
    - "+.example.com"
    # 运营商域名
    - "+.10086.cn"
    - "+.10010.cn"
    # 国内视频
    - "+.iqiyi.com"
    - "+.youku.com"
    - "+.bilibili.com"

  # 主要 DNS（国内域名）
  nameserver:
    - https://doh.pub/dns-query          # 腾讯 DoH
    - https://dns.alidns.com/dns-query   # 阿里 DoH
    - https://doh.360.cn/dns-query       # 360 DoH

  # 回退 DNS（国外域名）
  fallback:
    - https://1.1.1.1/dns-query          # Cloudflare DoH
    - https://8.8.8.8/dns-query          # Google DoH
    - https://doh.opendns.com/dns-query  # OpenDNS DoH

  # 域名分流策略
  nameserver-policy:
    # 国内域名走国内 DNS
    "+.cn": "https://dns.alidns.com/dns-query"
    "geosite:cn": "https://dns.alidns.com/dns-query"
    # Apple 服务走腾讯 DNS
    "+.push.apple.com": "https://doh.pub/dns-query"
    "+.apple.com": "https://doh.pub/dns-query"
    # 默认走 fallback
    "geosite:geolocation-!cn": "https://1.1.1.1/dns-query"

  # 性能优化
  prefer-h3: false
  use-hosts: true
  enable-dns-hijack: true
```

### 纯 DoH 模式（无 fake-ip）

```yaml
dns:
  enable: true
  listen: 0.0.0.0:53
  nameserver:
    - https://doh.pub/dns-query
    - https://dns.alidns.com/dns-query
  fallback:
    - https://1.1.1.1/dns-query
  nameserver-policy:
    "+.cn": "https://dns.alidns.com/dns-query"
  prefetch: true
  use-hosts: true
```

## TUN 模式完整配置

### system 栈（推荐，性能最佳）

```yaml
tun:
  enable: true
  stack: system
  auto-route: true
  auto-detect-interface: true
  strict-route: false
  mtu: 9000
  enable-dns-hijack: true
  dns-hijack:
    - any:53
    - tcp://any:53
  routes:
    - 0.0.0.0/1
    - 128.0.0.0/1
  exclude-routes:
    - 192.168.0.0/16
    - 10.0.0.0/8
    - 172.16.0.0/12
    - 100.64.0.0/10
```

### gvisor 栈（兼容性最佳）

```yaml
tun:
  enable: true
  stack: gvisor
  auto-route: true
  auto-detect-interface: true
  strict-route: false
  mtu: 9000
  enable-dns-hijack: true
  endpoint-independent-nat: true
  exclude-routes:
    - 192.168.0.0/16
    - 10.0.0.0/8
    - 172.16.0.0/12
```

### mixed 栈（自动回退）

```yaml
tun:
  enable: true
  stack: mixed
  auto-route: true
  auto-detect-interface: true
  strict-route: false
  mtu: 9000
  enable-dns-hijack: true
  dns-hijack:
    - any:53
  exclude-routes:
    - 192.168.0.0/16
    - 10.0.0.0/8
    - 172.16.0.0/12
```

## 多订阅负载均衡完整配置

### url-test（自动选最快）

```yaml
proxy-groups:
  - name: "AUTO"
    type: url-test
    use:
      - airplane-a
      - airplane-b
    url: "http://www.gstatic.com/generate_204"
    interval: 300
    tolerance: 50
    lazy: true
    filter: "^(?!.*(试用|免费|Expired))"
```

### load-balance（负载均衡）

```yaml
proxy-groups:
  - name: "LB"
    type: load-balance
    use:
      - airplane-a
      - airplane-b
    url: "http://www.gstatic.com/generate_204"
    interval: 300
    strategy: consistent-hashing
    lazy: true
```

### fallback（故障转移）

```yaml
proxy-groups:
  - name: "FALLBACK"
    type: fallback
    use:
      - airplane-a
      - airplane-b
      - free-sub
    url: "http://www.gstatic.com/generate_204"
    interval: 300
    lazy: true
```

### 组合策略（推荐）

```yaml
proxy-groups:
  # 手动选择
  - name: "SELECT"
    type: select
    use:
      - AUTO
      - LB
      - FALLBACK
      - airplane-a
      - airplane-b

  # 自动选择
  - name: "AUTO"
    type: url-test
    use:
      - airplane-a
      - airplane-b
    url: "http://www.gstatic.com/generate_204"
    interval: 300
    tolerance: 50

  # 负载均衡
  - name: "LB"
    type: load-balance
    use:
      - airplane-a
      - airplane-b
    url: "http://www.gstatic.com/generate_204"
    interval: 300
    strategy: consistent-hashing

  # 故障转移
  - name: "FALLBACK"
    type: fallback
    use:
      - airplane-a
      - airplane-b
    url: "http://www.gstatic.com/generate_204"
    interval: 300

  # 最终规则
  - name: "PROXY"
    type: select
    use:
      - AUTO
      - LB
      - FALLBACK
      - airplane-a
      - airplane-b

rules:
  - GEOIP,CN,DIRECT
  - MATCH,PROXY
```
