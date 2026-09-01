# 安装与卸载

## 一键安装脚本

以下脚本包含架构自动检测、国内镜像优先下载、超时重试、配置校验：

```bash
#!/usr/bin/env bash
set -euo pipefail

# ==================== 配置项 ====================
MIHOMO_DIR="${HOME}/.config/mihomo"
BIN_DIR="${HOME}/bin"
SERVICE_NAME="mihomo"
# 国内镜像加速（默认优先使用，失败后回退 GitHub 官方）
MIRROR_BASE="${MIHOMO_MIRROR:-https://ghproxy.com/https://github.com}"
# 下载超时（秒）
DOWNLOAD_TIMEOUT=30
MAX_RETRIES=3
# ==============================================

log_info()  { echo "[INFO]  $*"; }
log_warn()  { echo "[WARN]  $*" >&2; }
log_error() { echo "[ERROR] $*" >&2; }

# 检测架构
detect_arch() {
    local arch
    arch="$(uname -m)"
    case "$arch" in
        x86_64)  echo "amd64" ;;
        aarch64) echo "arm64" ;;
        armv7l|armv6l) echo "arm" ;;
        *)       log_error "不支持的架构: $arch"; return 1 ;;
    esac
}

# 获取最新版本号（带重试和镜像回退）
get_latest_version() {
    local api_url="https://api.github.com/repos/MetaCubeX/mihomo/releases/latest"
    local mirror_api="https://ghproxy.com/https://api.github.com/repos/MetaCubeX/mihomo/releases/latest"
    local version=""

    # 优先尝试 GitHub API
    for ((i=1; i<=MAX_RETRIES; i++)); do
        version="$(curl -s --max-time "$DOWNLOAD_TIMEOUT" "$api_url" 2>/dev/null | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')" && break
        log_warn "获取版本号失败（第 ${i}/${MAX_RETRIES} 次），重试中..."
        sleep 2
    done

    # 回退到镜像
    if [[ -z "$version" ]]; then
        log_warn "GitHub API 不可用，尝试镜像..."
        version="$(curl -s --max-time "$DOWNLOAD_TIMEOUT" "$mirror_api" 2>/dev/null | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')"
    fi

    if [[ -z "$version" ]]; then
        log_error "无法获取最新版本号，请检查网络连接"
        return 1
    fi

    echo "$version"
}

# 下载文件（国内镜像优先，失败后回退 GitHub）
download_with_retry() {
    local url="$1"
    local output="$2"
    local filename="${url##*/}"
    local success=false

    # 优先使用国内镜像
    if [[ -n "${MIRROR_BASE:-}" ]]; then
        local mirror_url="${MIRROR_BASE}/${filename}"
        log_info "尝试国内镜像: $mirror_url"
        for ((i=1; i<=MAX_RETRIES; i++)); do
            if curl -fsSL --max-time "$DOWNLOAD_TIMEOUT" -o "$output" "$mirror_url" 2>/dev/null; then
                success=true
                break
            fi
            log_warn "镜像下载失败（第 ${i}/${MAX_RETRIES} 次），重试中..."
            sleep 2
        done
    fi

    # 镜像失败，回退 GitHub 官方
    if [[ "$success" == "false" ]]; then
        log_info "回退到 GitHub 官方: $url"
        for ((i=1; i<=MAX_RETRIES; i++)); do
            if curl -fsSL --max-time "$DOWNLOAD_TIMEOUT" -o "$output" "$url" 2>/dev/null; then
                success=true
                break
            fi
            log_warn "下载失败（第 ${i}/${MAX_RETRIES} 次），重试中..."
            sleep 2
        done
    fi

    if [[ "$success" == "false" ]]; then
        log_error "下载失败: $url"
        return 1
    fi
}

# 主流程
main() {
    log_info "开始安装 Mihomo..."

    local arch version gz_path binary_path
    arch="$(detect_arch)"
    log_info "检测到架构: $(uname -m) → $arch"

    version="$(get_latest_version)"
    log_info "最新版本: $version"

    # 创建目录
    mkdir -p "$MIHOMO_DIR/proxy-providers" "$BIN_DIR"

    # 下载
    local download_url="https://github.com/MetaCubeX/mihomo/releases/download/${version}/mihomo-linux-${arch}-${version}.gz"
    gz_path="/tmp/mihomo-${version}.gz"
    binary_path="${BIN_DIR}/mihomo"

    download_with_retry "$download_url" "$gz_path"

    # 解压
    gunzip -f "$gz_path"
    chmod +x "/tmp/mihomo-${version}"

    # 备份旧版本
    if [[ -f "$binary_path" ]]; then
        cp "$binary_path" "${binary_path}.bak"
        log_info "已备份旧版本到 ${binary_path}.bak"
    fi

    mv "/tmp/mihomo-${version}" "$binary_path"

    # 验证
    if "$binary_path" -v; then
        log_info "安装成功！"
    else
        log_error "安装失败，二进制无法执行"
        if [[ -f "${binary_path}.bak" ]]; then
            log_info "正在恢复备份..."
            mv "${binary_path}.bak" "$binary_path"
        fi
        return 1
    fi

    # 清理备份
    rm -f "${binary_path}.bak"
}

main "$@"
```

### 安装输出样例

```
[INFO]  开始安装 Mihomo...
[INFO]  检测到架构: x86_64 → amd64
[INFO]  最新版本: v1.18.10
[INFO]  尝试国内镜像: https://ghproxy.com/https://github.com/mihomo-linux-amd64-v1.18.10.gz
[INFO]  已备份旧版本到 /home/user/bin/mihomo.bak
mihomo v1.18.10 linux amd64
[INFO]  安装成功！
```

## 国内镜像加速

国内服务器默认优先使用 ghproxy 镜像下载。如果镜像不可用，自动回退到 GitHub 官方。

```bash
# 使用默认镜像（ghproxy）
export MIHOMO_MIRROR=https://ghproxy.com/https://github.com
bash install-mihomo.sh

# 使用其他镜像
export MIHOMO_MIRROR=https://gh.llkk.cc/https://github.com
bash install-mihomo.sh

# 禁用镜像，强制使用 GitHub 官方
export MIHOMO_MIRROR=
bash install-mihomo.sh
```

### 常用国内镜像列表

| 镜像 | 地址 | 说明 |
|------|------|------|
| ghproxy | `https://ghproxy.com/https://github.com` | 稳定，推荐 |
| gh.llkk.cc | `https://gh.llkk.cc/https://github.com` | 备选 |
| gitclone.com | `https://gitclone.com/github.com` | 速度较快 |

## systemd 服务管理

### 创建服务文件

```bash
mkdir -p ~/.config/systemd/user
cat > ~/.config/systemd/user/mihomo.service << 'EOF'
[Unit]
Description=Mihomo Meta Proxy Service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=%h/bin/mihomo -d %h/.config/mihomo
Restart=on-failure
RestartSec=5
# 文件描述符限制
LimitNOFILE=65535
# 资源限制（可选）
# MemoryMax=256M
# CPUQuota=50%
# 日志输出到 journal
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=default.target
EOF
```

### 启动服务

```bash
systemctl --user daemon-reload
systemctl --user enable mihomo
systemctl --user start mihomo
systemctl --user status mihomo
```

### 常用操作

| 操作 | 命令 |
|------|------|
| 启动 | `systemctl --user start mihomo` |
| 停止 | `systemctl --user stop mihomo` |
| 重启 | `systemctl --user restart mihomo` |
| 查看状态 | `systemctl --user status mihomo` |
| 查看日志 | `journalctl --user -u mihomo -f` |
| 查看最近 50 行日志 | `journalctl --user -u mihomo --no-pager -n 50` |
| 开机自启 | `systemctl --user enable mihomo` |
| 禁用自启 | `systemctl --user disable mihomo` |

## 更新流程

```bash
#!/usr/bin/env bash
# update-mihomo.sh - 安全更新 Mihomo
set -euo pipefail

BIN_PATH="${HOME}/bin/mihomo"
BACKUP_PATH="${BIN_PATH}.bak"

# 1. 停止服务
echo "[INFO] 停止服务..."
systemctl --user stop mihomo

# 2. 备份当前版本
cp "$BIN_PATH" "$BACKUP_PATH"

# 3. 下载新版本（复用一键安装脚本的逻辑）
# ... 下载代码 ...

# 4. 替换并验证
if ~/bin/mihomo -v; then
    echo "[INFO] 更新成功"
    rm -f "$BACKUP_PATH"
else
    echo "[ERROR] 新版本验证失败，回滚..."
    mv "$BACKUP_PATH" "$BIN_PATH"
fi

# 5. 重启服务
systemctl --user start mihomo
echo "[INFO] 服务已重启"
```

## 卸载流程

```bash
#!/usr/bin/env bash
# uninstall-mihomo.sh - 完全卸载 Mihomo
set -euo pipefail

read -p "确认卸载 Mihomo？配置和数据将被删除 [y/N] " confirm
[[ "$confirm" =~ ^[Yy]$ ]] || { echo "已取消"; exit 0; }

# 停止并禁用服务
systemctl --user stop mihomo 2>/dev/null || true
systemctl --user disable mihomo 2>/dev/null || true

# 删除服务文件
rm -f ~/.config/systemd/user/mihomo.service
systemctl --user daemon-reload

# 删除二进制
rm -f ~/bin/mihomo ~/bin/mihomo.bak

# 删除配置（可选）
read -p "是否删除配置文件？[y/N] " del_conf
if [[ "$del_conf" =~ ^[Yy]$ ]]; then
    rm -rf ~/.config/mihomo
    echo "[INFO] 配置已删除"
fi

echo "[INFO] 卸载完成"
```

## 健康检查脚本

```bash
#!/usr/bin/env bash
# health-check.sh - Mihomo 服务健康检查
set -euo pipefail

CONTROLLER="127.0.0.1:9090"
PROXY_PORT=7897
TIMEOUT=10

check_service() {
    systemctl --user is-active mihomo &>/dev/null
}

check_api() {
    curl -s --max-time "$TIMEOUT" "http://${CONTROLLER}/version" &>/dev/null
}

check_proxy() {
    curl -x "http://127.0.0.1:${PROXY_PORT}" \
         -s --max-time "$TIMEOUT" \
         "https://www.gstatic.com/generate_204" -o /dev/null -w "%{http_code}" \
         | grep -q "204"
}

check_dns() {
    curl -x "http://127.0.0.1:${PROXY_PORT}" \
         -s --max-time "$TIMEOUT" \
         "https://1.1.1.1/dns-query?name=example.com" -o /dev/null
}

echo "=== Mihomo 健康检查 ==="

if check_service; then
    echo "[OK] 服务运行中"
else
    echo "[FAIL] 服务未运行"
    exit 1
fi

if check_api; then
    echo "[OK] API 可达"
else
    echo "[FAIL] API 不可达"
    exit 1
fi

if check_proxy; then
    echo "[OK] 代理连通"
else
    echo "[FAIL] 代理不通"
    exit 1
fi

if check_dns; then
    echo "[OK] DNS 解析正常"
else
    echo "[WARN] DNS 解析异常"
fi

echo "=== 检查完成 ==="
```
