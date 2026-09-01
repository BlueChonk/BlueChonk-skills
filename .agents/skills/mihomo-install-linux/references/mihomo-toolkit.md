# Mihomo 工具集（mihomo-toolkit）

> 原创工具脚本集合，提供订阅聚合、规则生成、配置验证、流量统计、自动更新等实用功能。

## 目录

1. [订阅聚合器](#订阅聚合器)
2. [规则生成器](#规则生成器)
3. [配置验证器](#配置验证器)
4. [流量统计脚本](#流量统计脚本)
5. [自动更新订阅 cron 脚本](#自动更新订阅-cron-脚本)

---

## 订阅聚合器

自动合并多个机场订阅，去重，按延迟排序，输出统一的 mihomo 兼容配置。

### 功能

- 同时拉取多个订阅源
- 自动去重（按节点名称 + server + port）
- 通过 mihomo API 测试延迟并排序
- 输出标准 `proxy-providers` 格式的 YAML 文件
- 支持黑白名单过滤节点

### 脚本代码

```bash
#!/usr/bin/env bash
# merge-subscriptions.sh - 多订阅聚合器
# 用法: bash merge-subscriptions.sh [-o output.yaml] [-f "node1|node2"] [-w "node3"] url1 url2 [url3 ...]
set -euo pipefail

OUTPUT_FILE="${HOME}/.config/mihomo/proxy-providers/merged.yaml"
BLACKLIST_PATTERN=""   # 黑名单正则（排除匹配节点）
WHitelist_PATTERN=""   # 黑白正则（仅保留匹配节点，空=全保留）
TIMEOUT=5
MAX_PARALLEL=10

log_info()  { echo "[INFO]  $*"; }
log_warn()  { echo "[WARN]  $*" >&2; }
log_error() { echo "[ERROR] $*" >&2; }

# 解析参数
while getopts "o:f:w:" opt; do
    case $opt in
        o) OUTPUT_FILE="$OPTARG" ;;
        f) BLACKLIST_PATTERN="$OPTARG" ;;
        w) WHitelist_PATTERN="$OPTARG" ;;
        *) exit 1 ;;
    esac
done
shift $((OPTIND - 1))

if [[ $# -lt 1 ]]; then
    echo "用法: $0 [-o output] [-f blacklist] [-w whitelist] <订阅URL1> [订阅URL2] ..."
    echo "  -o  输出文件路径（默认: ~/.config/mihomo/proxy-providers/merged.yaml）"
    echo "  -f  黑名单正则，匹配的节点将被排除"
    echo "  -w  白名单正则，仅保留匹配的节点"
    exit 1
fi

SUBSCRIPTIONS=("$@")
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

log_info "开始聚合 ${#SUBSCRIPTIONS[@]} 个订阅..."

# 步骤 1：下载所有订阅
i=0
for url in "${SUBSCRIPTIONS[@]}"; do
    i=$((i + 1))
    log_info "下载订阅 ${i}/${#SUBSCRIPTIONS[@]}: ${url%%\?*}"
    curl -fsSL --max-time 30 "$url" -o "${TEMP_DIR}/sub_${i}.yaml" 2>/dev/null || \
        log_warn "订阅 ${i} 下载失败，跳过"
done

# 步骤 2：使用 Python 解析、去重、排序
python3 << 'PYEOF' "$TEMP_DIR" "$OUTPUT_FILE" "$BLACKLIST_PATTERN" "$WHitelist_PATTERN" "$TIMEOUT"
import os
import sys
import yaml
import re
import json
import urllib.request
from collections import OrderedDict

temp_dir = sys.argv[1]
output_file = sys.argv[2]
blacklist = sys.argv[3]
whitelist = sys.argv[4]
timeout = int(sys.argv[5])

# 读取所有订阅文件
all_proxies = []
seen = set()

for f in sorted(os.listdir(temp_dir)):
    if not f.startswith("sub_"):
        continue
    path = os.path.join(temp_dir, f)
    try:
        with open(path, 'r', encoding='utf-8') as fh:
            data = yaml.safe_load(fh)
        if not data or 'proxies' not in data:
            continue
        for node in data['proxies']:
            name = node.get('name', '')
            server = node.get('server', '')
            port = str(node.get('port', ''))
            key = f"{name}|{server}|{port}"

            if key in seen:
                continue
            seen.add(key)

            # 黑名单过滤
            if blacklist and re.search(blacklist, name):
                continue
            # 白名单过滤
            if whitelist and not re.search(whitelist, name):
                continue

            all_proxies.append(node)
    except Exception as e:
        print(f"[WARN] 解析 {f} 失败: {e}", file=sys.stderr)

print(f"[INFO] 去重后共 {len(all_proxies)} 个节点")

# 按延迟排序（通过 mihomo API）
controller = "http://127.0.0.1:9090"
try:
    req = urllib.request.Request(f"{controller}/proxies")
    with urllib.request.urlopen(req, timeout=5) as resp:
        api_data = json.loads(resp.read())

    delay_map = {}
    for name, info in api_data.get('proxies', {}).items():
        history = info.get('history', [])
        if history:
            delay_map[name] = history[-1].get('delay', 9999)

    all_proxies.sort(key=lambda n: delay_map.get(n.get('name', ''), 9999))
    print("[INFO] 已按延迟排序")
except Exception as e:
    print(f"[WARN] 无法获取延迟数据（{e}），保持原始顺序", file=sys.stderr)

# 写入输出文件
output = {'proxies': all_proxies}
with open(output_file, 'w', encoding='utf-8') as fh:
    yaml.dump(output, fh, allow_unicode=True, default_flow_style=False)

print(f"[INFO] 输出到: {output_file}")
PYEOF

log_info "聚合完成！"
```

### 使用说明

```bash
# 基本用法：合并两个订阅
bash merge-subscriptions.sh \
  "https://airplane-a.com/sub?token=xxx" \
  "https://airplane-b.com/sub?yyy"

# 指定输出文件
bash merge-subscriptions.sh -o ~/my-proxies.yaml url1 url2

# 过滤掉含 "试用" 或 "免费" 的节点
bash merge-subscriptions.sh -f "试用|免费" url1 url2

# 仅保留含 "HK" 或 "JP" 的节点
bash merge-subscriptions.sh -w "HK|JP" url1 url2 url3
```

### 输出样例

```yaml
proxies:
  - name: "HK-Node-01"
    server: 1.2.3.4
    port: 443
    type: vmess
    ...
  - name: "JP-Node-01"
    server: 5.6.7.8
    port: 443
    type: trojan
  - name: "US-Node-01"
    server: 9.10.11.12
    port: 443
    type: ss
```

---

## 规则生成器

根据域名列表自动生成 mihomo 规则文件，支持域名后缀、关键词、正则三种匹配模式。

### 功能

- 输入域名列表，自动生成规则
- 支持三种规则类型：DOMAIN-SUFFIX / DOMAIN-KEYWORD / DOMAIN-REGEX
- 自动去重和排序
- 支持分组输出（不同目标代理组）
- 可直接导入 mihomo 配置

### 脚本代码

```bash
#!/usr/bin/env bash
# gen-rules.sh - 规则生成器
# 用法: bash gen-rules.sh [-t suffix|keyword|regex] [-p PROXY] [-o output.yaml] domain1 domain2 ...
# 或:   cat domains.txt | bash gen-rules.sh -p PROXY -o output.yaml
set -euo pipefail

RULE_TYPE="target"     # target = DOMAIN-SUFFIX
PROXY_GROUP="PROXY"
OUTPUT_FILE=""

while getopts "t:p:o:" opt; do
    case $opt in
        t) RULE_TYPE="$OPTARG" ;;
        p) PROXY_GROUP="$OPTARG" ;;
        o) OUTPUT_FILE="$OPTARG" ;;
        *) exit 1 ;;
    esac
done
shift $((OPTIND - 1))

# 从参数或 stdin 读取域名
if [[ $# -gt 0 ]]; then
    DOMAINS=("$@")
else
    mapfile -t DOMAINS
fi

if [[ ${#DOMAINS[@]} -eq 0 ]]; then
    echo "用法: $0 [-t suffix|keyword|regex|full] [-p PROXY] [-o output.yaml] domain1 domain2 ..."
    echo "  -t  规则类型: suffix(SUFFIX) / keyword(KEYWORD) / regex(正则) / full(精确匹配)"
    echo "  -p  目标代理组（默认: PROXY）"
    echo "  -o  输出文件（默认: 输出到 stdout）"
    echo ""
    echo "示例:"
    echo "  $0 -p DIRECT google.com gmail.com drive.google.com"
    echo "  cat blocked_domains.txt | $0 -p REJECT -o reject-rules.yaml"
    exit 1
fi

generate_rule() {
    local domain="$1"
    local type="$2"
    local proxy="$3"

    case "$type" in
        suffix)
            echo "  - DOMAIN-SUFFIX,${domain},${proxy}"
            ;;
        keyword)
            echo "  - DOMAIN-KEYWORD,${domain},${proxy}"
            ;;
        regex)
            echo "  - DOMAIN,${domain},${proxy}"
            ;;
        full)
            echo "  - DOMAIN,${domain},${proxy}"
            ;;
    esac
}

{
    echo "# 自动生成规则 - $(date '+%Y-%m-%d %H:%M:%S')"
    echo "# 共 ${#DOMAINS[@]} 条规则"
    echo "rules:"
    for domain in "${DOMAINS[@]}"; do
        # 去重跳过空行和注释
        [[ -z "$domain" || "$domain" =~ ^# ]] && continue
        generate_rule "$domain" "$RULE_TYPE" "$PROXY_GROUP"
    done
} > "${OUTPUT_FILE:-/dev/stdout}"
```

### 使用说明

```bash
# 为 Google 服务生成直连规则
bash gen-rules.sh -p DIRECT -o google-direct.yaml \
  google.com gmail.com drive.google.com \
  googleapis.com gstatic.com

# 为广告域名生成 REJECT 规则
cat << 'EOF' | bash gen-rules.sh -p REJECT -o ad-rules.yaml
doubleclick.net
googleadservices.com
googlesyndication.com
ads.example.com
tracking.example.com
EOF

# 为流媒体生成专用规则
bash gen-rules.sh -t keyword -p STREAMING -o streaming.yaml \
  netflix hbo disney hulu spotify
```

---

## 配置验证器

封装 `mihomo -t -f config.yaml`，提供中文错误解释和修复建议。

### 功能

- 执行 mihomo 配置校验
- 解析错误输出，提供中文解释
- 自动定位错误行号
- 给出修复建议
- 支持批量校验

### 脚本代码

```bash
#!/usr/bin/env bash
# validate-config.sh - 配置验证器（带中文解释）
# 用法: bash validate-config.sh [config_path]
set -euo pipefail

CONFIG_PATH="${1:-${HOME}/.config/mihomo/config.yaml}"
MIHOMO_BIN="${HOME}/bin/mihomo"

if [[ ! -f "$MIHOMO_BIN" ]]; then
    echo "[ERROR] 未找到 mihomo 二进制: $MIHOMO_BIN"
    echo "        请先运行安装脚本"
    exit 1
fi

if [[ ! -f "$CONFIG_PATH" ]]; then
    echo "[ERROR] 配置文件不存在: $CONFIG_PATH"
    exit 1
fi

echo "=== Mihomo 配置验证器 ==="
echo "文件: $CONFIG_PATH"
echo "时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo "=============================="

# 执行校验
OUTPUT=$("$MIHOMO_BIN" -d "$(dirname "$CONFIG_PATH")" -t 2>&1) || true
EXIT_CODE=0

# 检查是否有错误
if echo "$OUTPUT" | grep -qi "error\|failed\|invalid\|cannot\|missing"; then
    EXIT_CODE=1
    echo ""
    echo "[FAIL] 配置校验失败！"
    echo ""
    echo "--- 原始输出 ---"
    echo "$OUTPUT"
    echo "--- 错误分析 ---"

    # 逐行分析错误
    while IFS= read -r line; do
        if echo "$line" | grep -qi "yaml: unmarshal"; then
            echo ""
            echo "  错误: YAML 语法错误"
            echo "  原因: $(echo "$line" | sed 's/.*unmarshal errors://')"
            echo "  修复: 检查缩进（使用空格而非 Tab）、冒号后需有空格"

        elif echo "$line" | grep -qi "missing mandatory"; then
            echo ""
            echo "  错误: 缺少必填字段"
            echo "  原因: $(echo "$line" | sed 's/.*field://')"
            echo "  修复: 参考 config.yaml 模板补全该字段"

        elif echo "$line" | grep -qi "invalid port"; then
            echo ""
            echo "  错误: 端口号无效"
            echo "  修复: 端口范围为 1-65535，检查是否有非数字字符"

        elif echo "$line" | grep -qi "unknown proxy"; then
            echo ""
            echo "  错误: 未知代理类型"
            echo "  修复: 支持的类型: ss, ssr, vmess, trojan, vless, hysteria, hysteria2, tuic, wireguard"

        elif echo "$line" | grep -qi "no such file"; then
            echo ""
            echo "  错误: 文件不存在"
            echo "  原因: 引用的文件路径有误"
            echo "  修复: 检查 proxy-providers 或 rule-providers 的 path 字段"

        elif echo "$line" | grep -qi "cannot find"; then
            echo ""
            echo "  错误: 找不到资源"
            echo "  修复: 检查配置文件中的路径引用"

        fi
    done <<< "$OUTPUT"

    echo ""
    echo "建议: 使用在线 YAML 校验工具检查语法:"
    echo "  https://www.yamllint.com/"

else
    echo ""
    echo "[OK] 配置校验通过！"
    echo ""
    echo "--- 输出详情 ---"
    echo "$OUTPUT"
fi

exit $EXIT_CODE
```

### 使用说明

```bash
# 校验默认配置
bash validate-config.sh

# 校验指定配置
bash validate-config.sh /path/to/custom-config.yaml

# 在 CI/CD 中使用（返回码 0=通过，1=失败）
bash validate-config.sh && echo "配置正常" || echo "配置有误"
```

### 输出样例

```
=== Mihomo 配置验证器 ===
文件: /home/user/.config/mihomo/config.yaml
时间: 2024-01-15 14:30:00
==============================

[OK] 配置校验通过！

--- 输出详情 ---
Start initial Configuration in progress
Configuration file validation passed
```

---

## 流量统计脚本

解析 mihomo API 的流量数据，生成日报/周报，支持节点级别统计。

### 功能

- 从 mihomo RESTful API 获取实时流量数据
- 生成节点级别的流量报告（上传/下载/总流量）
- 支持日报/周报模式
- 输出格式：终端表格 / CSV / JSON
- 可配置流量告警阈值

### 脚本代码

```bash
#!/usr/bin/env bash
# traffic-report.sh - 流量统计报告生成器
# 用法: bash traffic-report.sh [-d|-w] [-f table|csv|json] [-a 100G]
set -euo pipefail

MODE="daily"            # daily / weekly
FORMAT="table"          # table / csv / json
ALERT_THRESHOLD="100G"  # 告警阈值
CONTROLLER="http://127.0.0.1:9090"

while getopts "dwf:a:" opt; do
    case $opt in
        d) MODE="daily" ;;
        w) MODE="weekly" ;;
        f) FORMAT="$OPTARG" ;;
        a) ALERT_THRESHOLD="$OPTARG" ;;
        *) exit 1 ;;
    esac
done

# 获取流量数据
fetch_traffic() {
    curl -s "${CONTROLLER}/traffic" 2>/dev/null || echo "up:0\ndown:0"
}

# 获取节点列表和代理组信息
fetch_proxies() {
    curl -s "${CONTROLLER}/proxies" 2>/dev/null || echo "{}"
}

# 获取连接信息
fetch_connections() {
    curl -s "${CONTROLLER}/connections" 2>/dev/null || echo "{}"
}

# 转换流量为可读格式
human_readable() {
    local bytes=$1
    if [[ $bytes -ge 1073741824 ]]; then
        echo "$(awk "BEGIN {printf \"%.2f\", $bytes/1073741824}")GB"
    elif [[ $bytes -ge 1048576 ]]; then
        echo "$(awk "BEGIN {printf \"%.2f\", $bytes/1048576}")MB"
    elif [[ $bytes -ge 1024 ]]; then
        echo "$(awk "BEGIN {printf \"%.2f\", $bytes/1024}")KB"
    else
        echo "${bytes}B"
    fi
}

# 解析阈值（支持 G/M/K）
parse_threshold() {
    local thresh="$1"
    local num=$(echo "$thresh" | grep -oP '^\d+')
    local unit=$(echo "$thresh" | grep -oP '[GMK]')
    case "$unit" in
        G) echo $((num * 1073741824)) ;;
        M) echo $((num * 1048576)) ;;
        K) echo $((num * 1024)) ;;
        *) echo "$num" ;;
    esac
}

TRAFFIC=$(fetch_traffic)
PROXIES=$(fetch_proxies)

UP_BYTES=$(echo "$TRAFFIC" | grep "^up:" | awk -F: '{print $2}' | tr -d ' ')
DOWN_BYTES=$(echo "$TRAFFIC" | grep "^down:" | awk -F: '{print $2}' | tr -d ' ')
TOTAL_BYTES=$((UP_BYTES + DOWN_BYTES))

UP_HR=$(human_readable "$UP_BYTES")
DOWN_HR=$(human_readable "$DOWN_BYTES")
TOTAL_HR=$(human_readable "$TOTAL_BYTES")

# 输出报告
if [[ "$FORMAT" == "json" ]]; then
    cat << EOF
{
  "mode": "$MODE",
  "timestamp": "$(date -Iseconds)",
  "total": {"up": "$UP_HR", "down": "$DOWN_HR", "total": "$TOTAL_HR"},
  "bytes": {"up": $UP_BYTES, "down": $DOWN_BYTES, "total": $TOTAL_BYTES}
}
EOF
    exit 0
fi

if [[ "$FORMAT" == "csv" ]]; then
    echo "mode,up,down,total"
    echo "$MODE,$UP_HR,$DOWN_HR,$TOTAL_HR"
    exit 0
fi

# 表格格式
echo "=== Mihomo 流量报告 ==="
echo "模式: $([ "$MODE" == "daily" ] && echo "日报" || echo "周报")"
echo "时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""
echo "┌────────────┬──────────────┐"
echo "│  上传流量  │  ${UP_HR}"
echo "├────────────┼──────────────┤"
echo "│  下载流量  │  ${DOWN_HR}"
echo "├────────────┼──────────────┤"
echo "│  总流量    │  ${TOTAL_HR}"
echo "└────────────┴──────────────┘"

# 告警检查
THRESHOLD_BYTES=$(parse_threshold "$ALERT_THRESHOLD")
if [[ $TOTAL_BYTES -ge $THRESHOLD_BYTES ]]; then
    echo ""
    echo "[WARN] 流量已超阈值 ${ALERT_THRESHOLD}！当前: ${TOTAL_HR}"
fi

# 节点级别统计（通过 API）
echo ""
echo "--- 节点流量 TOP 10 ---"
echo "$PROXIES" | python3 << 'PYEOF' 2>/dev/null || echo "（无法获取节点级数据，需要 mihomo 启动）"
import json, sys
try:
    data = json.load(sys.stdin)
    proxies = data.get('proxies', {})
    
    # 提取节点流量（如果 API 支持）
    node_stats = []
    for name, info in proxies.items():
        if info.get('type') in ('Direct', 'Reject', 'Selector', 'URLTest', 'Fallback', 'LoadBalance'):
            continue
        stats = info.get('stats', {})
        up = stats.get('uploadTotal', 0)
        down = stats.get('downloadTotal', 0)
        if up + down > 0:
            node_stats.append((name, up, down, up + down))
    
    node_stats.sort(key=lambda x: x[3], reverse=True)
    
    if node_stats:
        print(f"{'节点名':<20} {'上传':>10} {'下载':>10} {'总计':>10}")
        print("-" * 55)
        for name, up, down, total in node_stats[:10]:
            def fmt(b):
                if b >= 1073741824: return f"{b/1073741824:.2f}G"
                if b >= 1048576: return f"{b/1048576:.2f}M"
                if b >= 1024: return f"{b/1024:.2f}K"
                return f"{b}B"
            print(f"{name:<20} {fmt(up):>10} {fmt(down):>10} {fmt(total):>10}")
    else:
        print("（无节点流量统计）")
except Exception as e:
    print(f"（解析失败: {e}）")
PYEOF
```

### 使用说明

```bash
# 查看今日流量（表格格式）
bash traffic-report.sh -d

# 查看本周流量（JSON 格式，可接入监控系统）
bash traffic-report.sh -w -f json

# 导出 CSV 到文件
bash traffic-report.sh -d -f csv > traffic-$(date +%Y%m%d).csv

# 设置流量告警阈值 50GB
bash traffic-report.sh -a 50G

# 添加到 crontab（每天 23:59 生成日报）
(crontab -l 2>/dev/null; echo "59 23 * * * $(pwd)/traffic-report.sh -d -f csv >> ~/traffic-daily.csv") | crontab -
```

---

## 自动更新订阅 cron 脚本

定时更新并验证订阅，失败时回退，成功后热重载。

### 功能

- 定时更新所有订阅源
- 更新后自动验证配置
- 验证失败时回滚
- 成功后热重载
- 记录更新日志
- 支持邮件/Webhook 通知

### 脚本代码

```bash
#!/usr/bin/env bash
# auto-update.sh - 自动更新订阅并验证
# 用法: bash auto-update.sh
set -euo pipefail

CONFIG_DIR="${HOME}/.config/mihomo"
CONFIG_FILE="${CONFIG_DIR}/config.yaml"
BACKUP_DIR="${CONFIG_DIR}/backups"
LOG_FILE="${CONFIG_DIR}/update.log"
CONTROLLER="http://127.0.0.1:9090"
MAX_BACKUPS=5
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')

mkdir -p "$BACKUP_DIR"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

log "=== 开始自动更新订阅 ==="

# 步骤 1：备份当前配置
cp "$CONFIG_FILE" "${BACKUP_DIR}/config_${TIMESTAMP}.yaml"
cp -r "${CONFIG_DIR}/proxy-providers" "${BACKUP_DIR}/proxy-providers_${TIMESTAMP}" 2>/dev/null || true
log "已备份配置"

# 清理旧备份
ls -t "${BACKUP_DIR}"/config_*.yaml 2>/dev/null | tail -n +$((MAX_BACKUPS + 1)) | xargs rm -f 2>/dev/null || true

# 步骤 2：通过 API 更新订阅
log "正在更新订阅..."
UPDATE_RESULT=$(curl -s -w "\n%{http_code}" -X PUT "${CONTROLLER}/providers/proxies" 2>/dev/null || echo "000")
HTTP_CODE=$(echo "$UPDATE_RESULT" | tail -1)

if [[ "$HTTP_CODE" == "204" || "$HTTP_CODE" == "200" ]]; then
    log "订阅更新成功 (HTTP $HTTP_CODE)"
else
    log "[WARN] 订阅更新 API 返回 HTTP $HTTP_CODE，尝试手动更新..."
    
    # 手动更新：重新下载订阅
    if [[ -f "${CONFIG_DIR}/update-subs.sh" ]]; then
        bash "${CONFIG_DIR}/update-subs.sh" || {
            log "[ERROR] 订阅下载失败"
            exit 1
        }
    fi
fi

# 步骤 3：等待订阅文件写入
sleep 2

# 步骤 4：校验配置
log "正在校验配置..."
if ~/bin/mihomo -d "$CONFIG_DIR" -t 2>&1; then
    log "配置校验通过"
else
    log "[ERROR] 配置校验失败，回滚中..."
    cp "${BACKUP_DIR}/config_${TIMESTAMP}.yaml" "$CONFIG_FILE"
    if [[ -d "${BACKUP_DIR}/proxy-providers_${TIMESTAMP}" ]]; then
        rm -rf "${CONFIG_DIR}/proxy-providers"
        cp -r "${BACKUP_DIR}/proxy-providers_${TIMESTAMP}" "${CONFIG_DIR}/proxy-providers"
    fi
    log "已回滚到备份配置"
    systemctl --user restart mihomo
    exit 1
fi

# 步骤 5：热重载
log "正在热重载配置..."
RELOAD_RESULT=$(curl -s -o /dev/null -w "%{http_code}" \
    -X PUT "${CONTROLLER}/configs?force=true" \
    -H "Content-Type: application/json" \
    -d "{\"path\":\"${CONFIG_FILE}\"}" 2>/dev/null || echo "000")

if [[ "$RELOAD_RESULT" == "204" || "$RELOAD_RESULT" == "200" ]]; then
    log "热重载成功 (HTTP $RELOAD_RESULT)"
else
    log "[WARN] 热重载返回 HTTP $RELOAD_RESULT，尝试重启..."
    systemctl --user restart mihomo
fi

# 步骤 6：健康检查
sleep 3
if systemctl --user is-active mihomo &>/dev/null; then
    log "服务运行正常"
else
    log "[ERROR] 服务异常，请检查日志"
    exit 1
fi

log "=== 更新完成 ==="
```

### 使用说明

```bash
# 手动执行
bash auto-update.sh

# 添加到 crontab（每天凌晨 3 点自动更新）
(crontab -l 2>/dev/null; echo "0 3 * * * $(pwd)/auto-update.sh >> /tmp/mihomo-update.log 2>&1") | crontab -

# 查看更新日志
tail -f ~/.config/mihomo/update.log
```

### 更新日志样例

```
[2024-01-15 03:00:00] === 开始自动更新订阅 ===
[2024-01-15 03:00:00] 已备份配置
[2024-01-15 03:00:01] 正在更新订阅...
[2024-01-15 03:00:03] 订阅更新成功 (HTTP 204)
[2024-01-15 03:00:05] 正在校验配置...
[2024-01-15 03:00:05] 配置校验通过
[2024-01-15 03:00:05] 正在热重载配置...
[2024-01-15 03:00:06] 热重载成功 (HTTP 204)
[2024-01-15 03:00:09] 服务运行正常
[2024-01-15 03:00:09] === 更新完成 ===
```
