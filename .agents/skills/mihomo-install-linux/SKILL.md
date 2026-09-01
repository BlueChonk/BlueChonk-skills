---
name: "mihomo-install-linux"
description: "Download, install and configure Mihomo proxy on Linux. Invoke when the user wants to set up Mihomo proxy, configure subscriptions, or troubleshoot Mihomo service issues. 触发话术：「帮我安装 mihomo」「代理连不上怎么排查」「如何更新订阅」「国内下载太慢怎么办」「配置 TUN 模式」「多订阅负载均衡」「DNS 解析异常」「mihomo 服务挂了」"
---

# Mihomo Linux 安装与配置

> 一站式 Mihomo (MetaCubeX) Linux 部署技能包，涵盖安装、配置、进阶调优、独创工具集与故障排查。

## 快速开始

### 一键部署（从安装到验证）

以下单行命令完成从下载到服务启动的全流程：

```bash
# 完整一键部署（国内服务器推荐）
# 1. 下载安装脚本（完整脚本见 references/installation.md）
export MIHOMO_MIRROR=https://ghproxy.com/https://github.com
# 2. 执行安装（脚本会自动检测架构、下载二进制、校验配置）
bash install-mihomo.sh
# 3. 创建配置目录
mkdir -p ~/.config/mihomo/proxy-providers ~/.config/systemd/user
# 4. 写入 systemd 服务
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
LimitNOFILE=65535
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=default.target
EOF
# 5. 启动服务
systemctl --user daemon-reload
systemctl --user enable --now mihomo
systemctl --user status mihomo
echo "部署完成！代理地址: http://127.0.0.1:7897"
```

> **说明**：`install-mihomo.sh` 完整脚本见 [references/installation.md](references/installation.md)，可复制到本地后执行。

### 分步部署

```bash
# 1. 下载安装脚本（国内服务器优先使用镜像）
export MIHOMO_MIRROR=https://ghproxy.com/https://github.com
bash install-mihomo.sh

# 2. 创建配置目录
mkdir -p ~/.config/mihomo/proxy-providers

# 3. 写入配置文件（详见 references/configuration.md）
cp references/config.yaml ~/.config/mihomo/config.yaml
# 编辑订阅地址
vim ~/.config/mihomo/config.yaml

# 4. 校验配置
~/bin/mihomo -d ~/.config/mihomo -t

# 5. 创建 systemd 服务并启动
systemctl --user enable --now mihomo
systemctl --user status mihomo
```

### 部署验证

```bash
# 验证服务状态
systemctl --user is-active mihomo

# 验证代理连通
curl -x http://127.0.0.1:7897 https://www.gstatic.com/generate_204 -w "\nHTTP Code: %{http_code}\n"

# 验证出口 IP
curl -x http://127.0.0.1:7897 https://ipinfo.io
```

### 部署输出样例

```
[INFO]  开始安装 Mihomo...
[INFO]  检测到架构: x86_64 → amd64
[INFO]  最新版本: v1.18.10
[INFO]  尝试国内镜像: https://ghproxy.com/https://github.com/mihomo-linux-amd64-v1.18.10.gz
mihomo v1.18.10 linux amd64
[INFO]  安装成功！
● mihomo.service - Mihomo Meta Proxy Service
     Loaded: loaded (/home/user/.config/systemd/user/mihomo.service; enabled)
     Active: active (running) since Mon 2024-01-15 10:30:00 CST; 2s ago
部署完成！代理地址: http://127.0.0.1:7897
```

## 平台与依赖

### 支持的架构

| 架构 | 标识 | 说明 |
|------|------|------|
| x86_64 | `amd64` | 主流服务器和桌面 |
| ARM 64-bit | `arm64` / `aarch64` | 树莓派 4/5、ARM 服务器 |
| ARM 32-bit | `arm` | 旧版树莓派（兼容性有限） |

### 依赖要求

| 依赖 | 用途 | 是否必需 |
|------|------|----------|
| `curl` 或 `wget` | 下载二进制和订阅 | 二选一，必需 |
| `gunzip` | 解压 `.gz` 包 | 必需 |
| `systemd` | 服务管理 | 必需（不支持非 systemd 发行版） |
| `jq`（可选） | 解析 GitHub API 版本号 | 推荐 |
| `python3`（可选） | 运行工具集脚本 | 推荐（流量统计、订阅聚合） |

### 不支持的场景

- **非 systemd 发行版**：Devuan、Alpine（OpenRC）、Void（runit）等
- **macOS / Windows**：本 skill 仅适用于 Linux
- **rootless 容器**：需要额外配置 `loginctl enable-linger`
- **旧版 Linux 内核**：要求 kernel ≥ 4.9（TUN/TAP 支持）

## 文档索引

| 文件 | 内容 |
|------|------|
| [references/installation.md](references/installation.md) | 一键安装脚本详解、国内镜像加速、更新与卸载流程 |
| [references/configuration.md](references/configuration.md) | 配置指南、配置参数说明表、TUN 模式、DNS 高级设置、多订阅源负载均衡、规则分片策略 |
| [references/troubleshooting.md](references/troubleshooting.md) | 故障排查速查表、常见错误日志对照表、网络诊断流程图、一键诊断脚本 |
| [references/anti-patterns.md](references/anti-patterns.md) | 反模式（17条）、FAQ（20条）、最佳实践检查清单 |
| [references/mihomo-toolkit.md](references/mihomo-toolkit.md) | 独创工具集：订阅聚合器、规则生成器、配置验证器、流量统计、自动更新 cron |
| [references/config.yaml](references/config.yaml) | 完整配置模板（带注释） |

## 常用操作速查

| 操作 | 命令 |
|------|------|
| 启动服务 | `systemctl --user start mihomo` |
| 停止服务 | `systemctl --user stop mihomo` |
| 重启服务 | `systemctl --user restart mihomo` |
| 查看状态 | `systemctl --user status mihomo` |
| 查看日志 | `journalctl --user -u mihomo -f` |
| 配置校验 | `~/bin/mihomo -d ~/.config/mihomo -t` |
| 热重载配置 | `curl -s -X PUT http://127.0.0.1:9090/configs?force=true -H "Content-Type: application/json" -d '{"path":"'$HOME'/.config/mihomo/config.yaml"}'` |
| 更新订阅 | `curl -X PUT http://127.0.0.1:9090/providers/proxies/my-airplane` |
| 开机自启 | `loginctl enable-linger $(whoami) && systemctl --user enable mihomo` |
| 健康检查 | `bash health-check.sh` |
| 流量报告 | `bash traffic-report.sh -d` |
| 一键诊断 | `bash diagnose.sh` |
| 订阅聚合 | `bash merge-subscriptions.sh url1 url2` |
| 配置验证 | `bash validate-config.sh` |

## 输出样例

### mihomo -t 校验通过

```
[2024-01-15 10:30:00] [Info] Start initial configuration in progress
[2024-01-15 10:30:00] [Info] Configuration loaded successfully
```

### 健康检查脚本输出

```
=== Mihomo 健康检查 ===
[OK] 服务运行中
[OK] API 可达
[OK] 代理连通
[OK] DNS 解析正常
=== 检查完成 ===
```

### 订阅聚合后的配置样例

```yaml
proxies:
  - name: "HK-Node-01"
    server: 1.2.3.4
    port: 443
    type: vmess
    uuid: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
    alterId: 0
    cipher: auto
    tls: true
    skip-cert-verify: false
    network: ws
    ws-opts:
      path: "/ws"
      headers:
        Host: hk01.example.com
  - name: "JP-Node-01"
    server: 5.6.7.8
    port: 443
    type: trojan
    password: xxxxxxxx
    sni: jp01.example.com
    skip-cert-verify: false
```

### 流量统计报告输出

```
=== Mihomo 流量报告 ===
模式: 日报
时间: 2024-01-15 23:59:00

┌────────────┬──────────────┐
│  上传流量  │  1.23GB
├────────────┼──────────────┤
│  下载流量  │  8.76GB
├────────────┼──────────────┤
│  总流量    │  9.99GB
└────────────┴──────────────┘

--- 节点流量 TOP 10 ---
节点名                     上传         下载         总计
-------------------------------------------------------
HK-Node-01              512.34MB    3.45GB    3.96GB
JP-Node-01              345.67MB    2.78GB    3.13GB
US-Node-01              123.45MB    1.23GB    1.35GB
```

## 链接

- [官方文档](https://wiki.metacubex.one/)
- [GitHub 仓库](https://github.com/MetaCubeX/mihomo)
- [Dashboard (metacubexd)](https://github.com/metacubex/metacubexd)
- [ghproxy 镜像](https://ghproxy.com/)
