# 故障排查

## 速查表

| 现象 | 原因 | 解决方案 |
|------|------|----------|
| 端口被占用 | 其他程序占用了 7897 | `lsof -i :7897` 查找进程，修改 `config.yaml` 中 `mixed-port` |
| 服务无法启动 | 配置语法错误 | `journalctl --user -u mihomo --no-pager -n 50` 查看日志，`mihomo -d ~/.config/mihomo -t` 校验配置 |
| 权限问题 | 二进制无执行权限 | `chmod +x ~/bin/mihomo` |
| 下载超时 | 网络不通或 GitHub 被墙 | 设置 `export MIHOMO_MIRROR=https://ghproxy.com/https://github.com` |
| 订阅更新失败 | 订阅地址错误或 token 过期 | 检查 `proxy-providers` 中的 `url`，手动 `curl -v` 测试 |
| 代理连接超时 | 节点全部不可用 | 检查订阅是否过期，`curl -x http://127.0.0.1:7897 https://ipinfo.io` 测试 |
| DNS 解析失败 | DNS 配置问题 | 检查 `dns` 配置段，尝试 `curl -x socks5://127.0.0.1:7897 https://1.1.1.1/dns-query?name=example.com` |
| 开机不自启 | linger 未启用 | `loginctl enable-linger $(whoami)` |
| 内存占用过高 | 订阅节点过多 | 减少订阅节点数量，或调整 `health-check.interval` |
| TUN 接口创建失败 | 内核不支持或权限不足 | 检查 `uname -r` ≥ 4.9，确保有 root 权限或 `CAP_NET_ADMIN` |
| 热重载无响应 | API 不可达 | 检查 `external-controller` 地址和端口，确认服务正在运行 |
| 配置文件被覆盖 | 外部程序修改 | 使用 `chattr +i ~/.config/mihomo/config.yaml` 加锁（谨慎使用） |

## 日志分析

### 查看实时日志

```bash
journalctl --user -u mihomo -f
```

### 查看最近 N 行日志

```bash
journalctl --user -u mihomo --no-pager -n 50
```

### 按时间范围查看

```bash
# 查看今天的日志
journalctl --user -u mihomo --since today

# 查看最近 1 小时
journalctl --user -u mihomo --since "1 hour ago"

# 查看指定时间段
journalctl --user -u mihomo --since "2024-01-15 10:00:00" --until "2024-01-15 11:00:00"
```

### 常见日志错误

| 日志内容 | 含义 | 处理 |
|----------|------|------|
| `cannot find interface` | 网络接口未找到 | 检查 `tun.auto-detect-interface` 设置 |
| `DNS hijack listen failed` | DNS 端口被占用 | 停止 `systemd-resolved` 或修改 `dns.listen` |
| `provider xxx update failed` | 订阅更新失败 | 检查订阅地址和网络连接 |
| `proxy xxx timeout` | 节点超时 | 节点可能已失效，等待健康检查自动切换 |
| `rule match error` | 规则匹配错误 | 检查 `rules` 语法是否正确 |
| `insufficient permissions` | 权限不足 | 检查二进制权限和 systemd 服务配置 |

## 网络诊断

### 测试代理连通性

```bash
# HTTP 代理测试
curl -x http://127.0.0.1:7897 https://www.gstatic.com/generate_204 -w "\nHTTP Code: %{http_code}\nTime: %{time_total}s\n"

# SOCKS5 代理测试
curl -x socks5://127.0.0.1:7897 https://www.gstatic.com/generate_204 -w "\nHTTP Code: %{http_code}\nTime: %{time_total}s\n"

# 查看出口 IP
curl -x http://127.0.0.1:7897 https://ipinfo.io

# 测试 DNS 解析
curl -x socks5://127.0.0.1:7897 https://1.1.1.1/dns-query?name=example.com
```

### 测试节点延迟

```bash
# 通过 API 查看所有节点
curl -s http://127.0.0.1:9090/proxies | python3 -m json.tool

# 测试指定节点延迟
curl -s -X GET "http://127.0.0.1:9090/proxies/PROXY/delay?timeout=5000&url=http://www.gstatic.com/generate_204"
```

### 检查端口监听

```bash
# 检查混合端口
ss -tlnp | grep 7897

# 检查 API 端口
ss -tlnp | grep 9090

# 检查 DNS 端口（如果启用）
ss -tlnp | grep 53
```

## 配置问题排查

### 配置校验失败

```bash
# 详细校验（显示具体错误）
~/bin/mihomo -d ~/.config/mihomo -t 2>&1
```

常见校验错误：

| 错误信息 | 原因 | 修复 |
|----------|------|------|
| `yaml: unmarshal errors` | YAML 语法错误 | 检查缩进、冒号后空格 |
| `missing mandatory field` | 缺少必填字段 | 参考模板补全 |
| `invalid port number` | 端口号不合法 | 端口范围 1-65535 |
| `unknown proxy type` | 代理类型错误 | 检查 `type` 字段拼写 |

### 配置热重载失败

```bash
# 检查 API 是否可达
curl -s http://127.0.0.1:9090/version

# 检查配置路径是否正确
curl -s -X PUT "http://127.0.0.1:9090/configs?force=true" \
  -H "Content-Type: application/json" \
  -d '{"path":"'$HOME'/.config/mihomo/config.yaml"}'
```

## 性能问题排查

### 内存占用过高

```bash
# 查看进程内存
ps aux | grep mihomo

# 查看详细内存信息
cat /proc/$(pgrep mihomo)/status | grep -i mem
```

解决方案：
1. 减少订阅节点数量
2. 增大 `health-check.interval`（减少检查频率）
3. 在 systemd 服务中添加 `MemoryMax=256M`

### CPU 占用过高

```bash
# 查看进程 CPU
top -p $(pgrep mihomo)
```

解决方案：
1. 减少规则数量（使用 `rule-providers` 替代内联规则）
2. 关闭 `geo-auto-update`
3. 在 systemd 服务中添加 `CPUQuota=50%`

### 网络速度慢

```bash
# 测试直连速度
curl -o /dev/null -s -w "Speed: %{speed_download} bytes/s\n" https://speed.cloudflare.com/__down?bytes=10000000

# 测试代理速度
curl -x http://127.0.0.1:7897 -o /dev/null -s -w "Speed: %{speed_download} bytes/s\n" https://speed.cloudflare.com/__down?bytes=10000000
```

## 系统级排查

### 检查 systemd 服务状态

```bash
# 查看服务状态
systemctl --user status mihomo

# 查看服务是否启用
systemctl --user is-enabled mihomo

# 查看 linger 状态
loginctl show-user $(whoami) | grep Linger
```

### 检查网络环境

```bash
# 检查默认路由
ip route show default

# 检查 DNS 配置
cat /etc/resolv.conf

# 检查防火墙规则
sudo ufw status
sudo iptables -L -n
```

### 检查 TUN 接口

```bash
# 查看 TUN 接口
ip addr show | grep tun

# 查看路由表
ip route show table all | grep tun

# 查看 TUN 接口统计
ip -s link show tun0
```

## 常见错误日志对照表

| 日志关键词 | 原因 | 解决方案 |
|------------|------|----------|
| `cannot find interface` | 网络接口未找到 | 检查 `tun.auto-detect-interface` 设置，或手动指定接口 |
| `DNS hijack listen failed` | DNS 端口被占用 | 停止 `systemd-resolved` 或修改 `dns.listen` |
| `provider xxx update failed` | 订阅更新失败 | 检查订阅地址和网络连接，手动 `curl -v` 测试 |
| `proxy xxx timeout` | 节点超时 | 节点可能已失效，等待健康检查自动切换 |
| `rule match error` | 规则匹配错误 | 检查 `rules` 语法是否正确 |
| `insufficient permissions` | 权限不足 | 检查二进制权限和 systemd 服务配置 |
| `cannot create TUN device` | TUN 设备创建失败 | 检查内核版本 ≥ 4.9，确保有 root 或 `CAP_NET_ADMIN` |
| `connection refused` | 连接被拒绝 | 目标服务不可用或防火墙拦截 |
| `no such host` | DNS 解析失败 | 检查 `dns.nameserver` 配置 |
| `tls handshake timeout` | TLS 握手超时 | 节点可能被墙，尝试切换协议或端口 |
| `buffer overflow` | 缓冲区溢出 | 减少并发连接数或增大 `udp-proxy-buffer` |
| `out of memory` | 内存不足 | 设置 `MemoryMax` 限制或减少节点数量 |
| `too many open files` | 文件描述符不足 | 增大 `LimitNOFILE`（建议 65535） |
| `bind address already in use` | 端口被占用 | `lsof -i :端口号` 查找占用进程 |
| `yaml: unmarshal errors` | YAML 语法错误 | 检查缩进（空格非 Tab）、冒号后空格 |
| `missing mandatory field` | 缺少必填字段 | 参考模板补全配置 |
| `unknown proxy group` | 引用了不存在的代理组 | 检查 `proxy-groups` 中的名称拼写 |
| `circular dependency` | 代理组循环引用 | 检查代理组之间的引用关系 |
| `geoip database not found` | GeoIP 数据库不存在 | 首次启动需联网下载，或手动放置数据库文件 |
| `mmdb size mismatch` | MMDB 文件损坏 | 删除后重新下载 |
| `udp relay disabled` | UDP 中继未启用 | 在配置中启用 `enable-udp` |

## 网络诊断流程图

```text
代理无法连接？
    │
    ├─ 1. 服务是否运行？
    │   ├─ 否 → systemctl --user start mihomo
    │   └─ 是 ↓
    │
    ├─ 2. API 是否可达？
    │   ├─ curl http://127.0.0.1:9090/version
    │   ├─ 否 → 检查 external-controller 地址和端口
    │   └─ 是 ↓
    │
    ├─ 3. 代理端口是否监听？
    │   ├─ ss -tlnp | grep 7897
    │   ├─ 否 → 检查 mixed-port 是否被占用
    │   └─ 是 ↓
    │
    ├─ 4. 节点是否可用？
    │   ├─ curl -s http://127.0.0.1:9090/proxies | python3 -m json.tool
    │   ├─ 节点全部超时 → 更新订阅或切换节点
    │   └─ 有可用节点 ↓
    │
    ├─ 5. DNS 是否正常？
    │   ├─ curl -x socks5://127.0.0.1:7897 https://1.1.1.1/dns-query?name=example.com
    │   ├─ 否 → 检查 dns 配置，尝试关闭 fake-ip
    │   └─ 是 ↓
    │
    ├─ 6. 出口 IP 是否正确？
    │   ├─ curl -x http://127.0.0.1:7897 https://ipinfo.io
    │   ├─ 显示本地 IP → 规则配置错误，未走代理
    │   └─ 显示代理 IP ↓
    │
    ├─ 7. 规则是否匹配？
    │   ├─ 开启 debug 日志查看规则匹配
    │   ├─ 日志无规则匹配 → 检查 mode 是否为 rule
    │   └─ 规则正常 ↓
    │
    └─ 8. 协议是否正确？
        ├─ 检查节点类型（vmess/trojan/ss）
        └─ 尝试切换协议或端口
```

## 一键诊断脚本

```bash
#!/usr/bin/env bash
# diagnose.sh - 一键网络诊断
set -euo pipefail

CONTROLLER="http://127.0.0.1:9090"
PROXY_PORT=7897
TIMEOUT=10

echo "=== Mihomo 一键诊断 ==="
echo "时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# 1. 服务状态
echo "[1/7] 检查服务状态..."
if systemctl --user is-active mihomo &>/dev/null; then
    echo "  [OK] 服务运行中"
else
    echo "  [FAIL] 服务未运行"
    echo "  修复: systemctl --user start mihomo"
    exit 1
fi

# 2. API 状态
echo "[2/7] 检查 API..."
if curl -s --max-time "$TIMEOUT" "${CONTROLLER}/version" &>/dev/null; then
    VERSION=$(curl -s "${CONTROLLER}/version" | grep -oP '"version":"\K[^"]+')
    echo "  [OK] API 可达 (版本: ${VERSION:-未知})"
else
    echo "  [FAIL] API 不可达"
    echo "  修复: 检查 external-controller 配置"
    exit 1
fi

# 3. 端口监听
echo "[3/7] 检查端口监听..."
if ss -tlnp | grep -q ":${PROXY_PORT}"; then
    echo "  [OK] 混合端口 ${PROXY_PORT} 监听中"
else
    echo "  [FAIL] 端口 ${PROXY_PORT} 未监听"
    echo "  修复: ss -tlnp | grep ${PROXY_PORT} 检查占用"
    exit 1
fi

# 4. 节点状态
echo "[4/7] 检查节点..."
PROXY_INFO=$(curl -s "${CONTROLLER}/proxies" 2>/dev/null || echo "{}")
NODE_COUNT=$(echo "$PROXY_INFO" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    proxies = data.get('proxies', {})
    # 排除内置代理组
    nodes = [k for k, v in proxies.items() if v.get('type') not in ('Direct', 'Reject', 'Selector', 'URLTest', 'Fallback', 'LoadBalance', 'Relay')]
    print(len(nodes))
except: print(0)
" 2>/dev/null || echo "0")

if [[ "$NODE_COUNT" -gt 0 ]]; then
    echo "  [OK] 共 ${NODE_COUNT} 个节点"
else
    echo "  [WARN] 未发现节点，订阅可能未更新"
fi

# 5. DNS 解析
echo "[5/7] 检查 DNS..."
DNS_RESULT=$(curl -x "socks5://127.0.0.1:${PROXY_PORT}" \
    --max-time "$TIMEOUT" \
    "https://1.1.1.1/dns-query?name=example.com" \
    -o /dev/null -w "%{http_code}" 2>/dev/null || echo "000")

if [[ "$DNS_RESULT" == "200" ]]; then
    echo "  [OK] DNS 解析正常"
else
    echo "  [WARN] DNS 异常 (HTTP $DNS_RESULT)"
fi

# 6. 出口 IP
echo "[6/7] 检查出口 IP..."
IP_INFO=$(curl -x "http://127.0.0.1:${PROXY_PORT}" \
    --max-time "$TIMEOUT" \
    "https://ipinfo.io/json" 2>/dev/null || echo "{}")
IP=$(echo "$IP_INFO" | python3 -c "import json,sys; print(json.load(sys.stdin).get('ip','未知'))" 2>/dev/null || echo "未知")
CITY=$(echo "$IP_INFO" | python3 -c "import json,sys; print(json.load(sys.stdin).get('city',''))" 2>/dev/null || echo "")
ISP=$(echo "$IP_INFO" | python3 -c "import json,sys; print(json.load(sys.stdin).get('org',''))" 2>/dev/null || echo "")
echo "  出口 IP: ${IP} (${CITY}, ${ISP})"

# 7. 连通性测试
echo "[7/7] 连通性测试..."
HTTP_CODE=$(curl -x "http://127.0.0.1:${PROXY_PORT}" \
    --max-time "$TIMEOUT" \
    "https://www.gstatic.com/generate_204" \
    -o /dev/null -w "%{http_code}" 2>/dev/null || echo "000")

if [[ "$HTTP_CODE" == "204" ]]; then
    echo "  [OK] 代理连通 (HTTP 204)"
else
    echo "  [FAIL] 代理异常 (HTTP $HTTP_CODE)"
fi

echo ""
echo "=== 诊断完成 ==="
```

### 诊断脚本使用

```bash
# 运行诊断
bash diagnose.sh

# 在 cron 中定时诊断（每天 8:00 发送报告）
(crontab -l 2>/dev/null; echo "0 8 * * * $(pwd)/diagnose.sh >> ~/mihomo-diagnose.log 2>&1") | crontab -
```

### 诊断输出样例

```
=== Mihomo 一键诊断 ===
时间: 2024-01-15 15:30:00

[1/7] 检查服务状态...
  [OK] 服务运行中
[2/7] 检查 API...
  [OK] API 可达 (版本: v1.18.10)
[3/7] 检查端口监听...
  [OK] 混合端口 7897 监听中
[4/7] 检查节点...
  [OK] 共 24 个节点
[5/7] 检查 DNS...
  [OK] DNS 解析正常
[6/7] 检查出口 IP...
  出口 IP: 103.142.xx.xx (Tokyo, AS139659)
[7/7] 连通性测试...
  [OK] 代理连通 (HTTP 204)

=== 诊断完成 ===
```
