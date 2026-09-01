---
name: "pm2-service-manager"
description: "Manage any background service with PM2. Covers process guard, crash auto-restart, log viewing, startup on boot, cluster mode, zero-downtime deployment, performance tuning, and monitoring. Invoke when the user wants to run, manage, or troubleshoot any background service with PM2 (DSH Web, OpenClaw, QQ Bot, or custom services). 典型触发话术：'帮我重启 dsh-web'、'为什么 openclaw 一直崩溃'、'如何查看所有服务的日志'、'帮我设置开机自启'、'PM2 服务掉了怎么办'、'怎么部署一个 Node.js 服务'、'PM2 集群模式怎么配'、'服务内存太高怎么限制'、'零停机更新怎么做'、'帮我监控服务状态'。"
---

# PM2 服务管理

## 能力边界

### 支持的服务类型

| 类型 | 说明 | 示例 |
|------|------|------|
| Node.js 应用 | npm 包、本地 .js/.mjs 脚本 | DSH Web、OpenClaw、QQ Bot |
| Python 脚本 | 指定 python 解释器 | `pm2 start python3 --name myscript -- app.py` |
| 任何可执行文件 | 二进制、shell 脚本、bat | Nginx、Redis、编译后的 Go 程序 |
| 定时任务 | 配合 `cron_restart` 实现 | 每日凌晨重启的服务 |

### 不支持的场景

- Docker 容器内的服务管理（请用 Docker restart policy，见下方 Docker 最佳实践）
- 需要 systemd 深度集成的场景（如依赖 `journalctl` 日志，见下方 systemd 集成方案）
- Windows 服务（Service Control Manager）与 PM2 并存时可能端口冲突
- 不适用于无状态、不需要进程守护的一次性脚本

### 输入输出约束

- **服务名**：仅支持 `[a-zA-Z0-9_-]`，不支持中文和空格
- **日志路径**：默认 `~/.pm2/logs/`，可通过 `error_file` / `out_file` 自定义
- **最大实例数**：受 CPU 核数限制，推荐 `max` 使用全部核心
- **环境变量**：通过 `--env production` 或 `env` 字段注入，不支持交互式输入

---

## 服务配置表

| 服务名 | Windows 启动命令 | Linux 启动命令 |
|--------|-----------------|----------------|
| **dsh-web** | `pm2 start $(where.exe node) --name dsh-web -- $(npm root -g)\@deepseek-ai\dsh\lib\bin.js --profile web --no-open` | `pm2 start "dsh" --name dsh-web -- --profile web --no-open` |
| **openclaw** | `pm2 start "$(npm root -g)\openclaw\openclaw.mjs" --name openclaw -- gateway run` | `pm2 start $(which openclaw) --name openclaw -- gateway start` |
| **dsh-qqbot** | `pm2 start $(where.exe node) --name dsh-qqbot -- $(npm root -g)\@deepseek-ai\dsh\lib\bin.js --profile qqbot` | `pm2 start "dsh --profile qqbot" --name dsh-qqbot` |

---

## 启动服务

### Windows

```powershell
# 以 dsh-web 为例，替换服务名和命令即可
$nodeExe = (where.exe node).Split('\n')[0].Trim()
$binPath = "$(npm root -g)\@deepseek-ai\dsh\lib\bin.js"
pm2 start $nodeExe --name dsh-web -- $binPath --profile web --no-open
```

### Linux

```bash
pm2 start "dsh" --name dsh-web -- --profile web --no-open
```

### 通用任意服务示例

```bash
# Python 服务
pm2 start python3 --name my-api -- app.py

# Nginx
pm2 start nginx --name nginx -x -- -g "daemon off;"

# Redis
pm2 start redis-server --name redis -- /etc/redis/redis.conf

# Go 编译二进制
pm2 start ./myapp --name go-api -- --port 8080

# Shell 脚本
pm2 start ./deploy.sh --name deploy-task --cron "0 3 * * *" --no-autorestart
```

### 验证

```bash
pm2 status
pm2 logs dsh-web --lines 10
```

### pm2 status 预期输出样例

```
┌─────┬────────────┬─────────┬─────────┬─────────┬──────────┬───────┐
│ id  │ name       │ mode    │ ↺       │ status  │ cpu      │ memory│
├─────┼────────────┼─────────┼─────────┼─────────┼──────────┼───────┤
│ 0   │ dsh-web    │ fork    │ 2       │ online  │ 0.8%     │ 65.2mb│
│ 1   │ openclaw   │ fork    │ 0       │ online  │ 1.2%     │ 89.4mb│
│ 2   │ dsh-qqbot  │ fork    │ 5       │ online  │ 0.3%     │ 42.1mb│
└─────┴────────────┴─────────┴─────────┴─────────┴──────────┴───────┘
```

> **↺ 列**：重启次数。如果持续 > 0，说明服务不稳定，需查日志。

### pm2 logs 输出样例

```
[TAILING] Tailing last 15 lines for [dsh-web] process (change the value with --lines option)
C:\Users\Cecilia\.pm2\logs\dsh-web-out.log last 15 lines:
0|dsh-web | 2025-01-15 10:30:00: INFO  DSH Web started on port 3000
0|dsh-web | 2025-01-15 10:30:01: INFO  Connected to gateway
0|dsh-web | 2025-01-15 10:31:23: INFO  Incoming request: GET /api/status
0|dsh-web | 2025-01-15 10:32:45: WARN  High memory usage detected: 412MB

C:\Users\Cecilia\.pm2\logs\dsh-web-error.log last 15 lines:
0|dsh-web | 2025-01-15 10:29:58: ERROR Failed to bind port 3000, retrying...
```

> **说明**：默认同时显示 out log 和 error log，用 `--err` 仅看错误，用 `--out` 仅看输出。

---

## ecosystem.config.js 配置（推荐）

复杂服务推荐使用配置文件管理，可版本化、可复用。

### 基础模板

```javascript
// ecosystem.config.js
module.exports = {
  apps: [
    {
      name: 'dsh-web',
      script: 'node',
      args: 'bin.js --profile web --no-open',
      cwd: `${process.env.USERPROFILE || process.env.HOME}/AppData/Roaming/npm/node_modules/@deepseek-ai/dsh/lib`,
      interpreter: 'none',
      instances: 1,
      autorestart: true,
      watch: false,
      max_memory_restart: '512M',
      env: {
        NODE_ENV: 'production',
      },
      error_file: './logs/dsh-web-error.log',
      out_file: './logs/dsh-web-out.log',
      log_date_format: 'YYYY-MM-DD HH:mm:ss Z',
      merge_logs: true,
    },
    {
      name: 'openclaw',
      script: 'openclaw.mjs',
      args: 'gateway run',
      cwd: `${process.env.USERPROFILE || process.env.HOME}/AppData/Roaming/npm/node_modules/openclaw`,
      interpreter: 'node',
      instances: 1,
      autorestart: true,
      max_memory_restart: '1G',
      env: {
        NODE_ENV: 'production',
      },
      error_file: './logs/openclaw-error.log',
      out_file: './logs/openclaw-out.log',
    },
  ],
};
```

### 使用配置文件

```bash
# 启动所有服务
pm2 start ecosystem.config.js

# 仅启动指定服务
pm2 start ecosystem.config.js --only dsh-web

# 重载配置（零停机）
pm2 reload ecosystem.config.js
```

### 多实例部署（Cluster 模式）— 完整指南

Cluster 模式利用多核 CPU，PM2 会自动分配端口和负载均衡。

```javascript
{
  name: 'api-server',
  script: 'server.js',
  instances: 'max',        // 按 CPU 核数自动扩展（或填具体数字如 4）
  exec_mode: 'cluster',    // 启用 cluster 模式
  max_memory_restart: '300M',
  // 优雅关闭：等待现有连接关闭后再重启
  kill_timeout: 5000,
  listen_timeout: 3000,
  // 滚动更新：逐个重启，保证始终有实例在运行
  wait_ready: true,
  env_production: {
    NODE_ENV: 'production',
    PORT: 3000,
  },
}
```

```bash
# 启动并指定环境
pm2 start ecosystem.config.js --env production

# 动态调整实例数（不中断服务）
pm2 scale api-server 4

# 查看 cluster 各实例状态
pm2 status
# 输出中 mode 列显示 "cluster"，id 列显示 0, 1, 2, 3...
```

> **Cluster 模式注意事项**：
> - 应用必须无状态（session 存 Redis/DB，不存内存）
> - 端口由 PM2 自动分配，应用只需读取 `process.env.PORT`
> - `instances: 'max'` 在 8 核机器上会启动 8 个实例

---

## 零停机部署方案（滚动更新）

### 方案一：pm2 reload（推荐）

```bash
# 修改代码后，逐个重启实例，保证始终有实例在运行
pm2 reload ecosystem.config.js

# 仅重载指定服务
pm2 reload <服务名>
```

### 方案二：pm2 reloadLogs（不中断地重载日志）

```bash
# 日志轮转时不中断服务
pm2 reloadLogs
```

### 方案三：手动滚动更新脚本

```bash
#!/bin/bash
# rolling-update.sh — 逐个重启 cluster 实例
INSTANCES=$(pm2 jlist | jq -r '.[] | select(.name=="api-server") | .pm_id')
for id in $INSTANCES; do
    echo "重启实例 $id..."
    pm2 restart $id
    sleep 3  # 等待实例就绪
done
echo "滚动更新完成"
```

### 方案四：CI/CD 集成

```yaml
# GitHub Actions 示例
- name: Deploy with zero downtime
  run: |
    ssh user@server "cd /app && git pull && npm ci && pm2 reload ecosystem.config.js"
```

---

## 性能调优指南

### 内存限制策略

```javascript
// 根据服务类型设置合理的内存上限
{
  // 轻量 API 服务
  max_memory_restart: '200M',
}
{
  // 中等 Node.js 应用
  max_memory_restart: '512M',
}
{
  // 内存密集型（如数据处理）
  max_memory_restart: '2G',
}
```

### 实例数优化

| CPU 核数 | 推荐 instances | 说明 |
|----------|---------------|------|
| 2 核 | 2 | 留 1 核给系统 |
| 4 核 | 3-4 | `max` 或 `max-1` |
| 8 核 | 6-8 | 根据内存余量决定 |
| 16 核+ | `max` | 充分利用多核 |

### Node.js 内存调优

```javascript
{
  name: 'api-server',
  script: 'server.js',
  // 限制 Node.js 堆内存（单位：MB）
  node_args: '--max-old-space-size=2048',
  instances: 'max',
  exec_mode: 'cluster',
}
```

### CPU 亲和性（高级）

```bash
# 将 PM2 进程绑定到特定 CPU 核（Linux）
pm2 start app.js --name myapp --affinity 0x3  # 绑定到 CPU 0 和 1
```

---

## 日常操作

| 操作 | 命令 |
|------|------|
| 查看状态 | `pm2 status` |
| 查看日志 | `pm2 logs <服务名>` |
| 查看最近 N 行日志 | `pm2 logs <服务名> --lines 100` |
| 实时跟踪日志 | `pm2 logs <服务名> --lines 0` |
| 仅看错误日志 | `pm2 logs <服务名> --err` |
| 重启 | `pm2 restart <服务名>` |
| 重载（零停机） | `pm2 reload <服务名>` |
| 停止 | `pm2 stop <服务名>` |
| 删除 | `pm2 delete <服务名>` |
| 停止所有 | `pm2 stop all` |
| 重启所有 | `pm2 restart all` |
| 删除所有 | `pm2 delete all` |
| 动态扩缩容 | `pm2 scale <服务名> <数量>` |

---

## PM2 Monit 监控

```bash
# 终端内嵌监控面板（CPU / 内存 / 重启次数）
pm2 monit

# 查看单个服务的详细信息
pm2 describe <服务名>

# 查看进程树
pm2 prettylist
```

### pm2 monit 界面说明

```
┌──────────────────────────────────────────────────────────────┐
│                        PM2 MONIT                              │
├──────────────────────────────────────────────────────────────┤
│  [Processes]  [Logs]  [Custom Metrics]                        │
│                                                               │
│  ┌─────────────┬───────┬────────┬─────────┐                  │
│  │ Name        │ CPU   │ Memory │ Status  │                  │
│  ├─────────────┼───────┼────────┼─────────┤                  │
│  │ dsh-web     │ 0.8%  │ 65 MB  │ online  │                  │
│  │ openclaw    │ 1.2%  │ 89 MB  │ online  │                  │
│  └─────────────┴───────┴────────┴─────────┘                  │
│                                                               │
│  操作提示：                                                    │
│  ↑/↓ 选择进程  Enter 查看详情  q 退出                         │
│  b 查看日志  m 查看内存  c 查看 CPU                           │
└──────────────────────────────────────────────────────────────┘
```

> **说明**：`pm2 monit` 是终端内的实时仪表盘，按 `q` 退出。适合快速查看资源占用，不适合长期监控。

### pm2 describe 完整输出样例

```
Describing process with id 0 - name dsh-web
┌───────────────────┬──────────────────────────────────────────────┐
│ status            │ online                                       │
│ name              │ dsh-web                                      │
│ restarts          │ 2                                            │
│ uptime            │ 3h                                           │
│ script path       │ C:\...\bin.js                                │
│ script args       │ --profile web --no-open                      │
│ error log path    │ C:\Users\Cecilia\.pm2\logs\dsh-web-error.log │
│ out log path      │ C:\Users\Cecilia\.pm2\logs\dsh-web-out.log   │
│ pid path          │ C:\Users\Cecilia\.pm2\pm2.pid                │
│ interpreter       │ none                                         │
│ interpreter args  │ N/A                                          │
│ script id         │ 0                                            │
│ exit code         │ 0                                            │
│ pid               │ 12345                                        │
│ activity          │ 2025-01-15T10:30:00.000Z                     │
└───────────────────┴──────────────────────────────────────────────┘

┌───────────────────────────┐
│  CWD                      │
│  USER                     │
│  Command                  │
│  Watch & Restart          │
│  Unstable Restarts        │
│  Restart time             │
│  Script type              │
│  Node.js version          │
│  Node.js path             │
│  interpreter              │
│  interpreter args         │
│  exec mode                │
│  node args                │
│  log type                 │
│  output logs              │
│  error logs               │
│  node version             │
│  node supervisor          │
│  versioning               │
│  pid path                 │
│  script id                │
│  exit code                │
│  activity                 │
└───────────────────────────┘
```

---

## 日志管理

### 日志轮转配置

```bash
# 安装日志轮转模块
pm2 install pm2-logrotate

# 配置轮转策略
pm2 set pm2-logrotate:max_size 10M        # 单文件最大 10MB
pm2 set pm2-logrotate:retain 7            # 保留 7 个文件
pm2 set pm2-logrotate:compress true       # 压缩旧日志
pm2 set pm2-logrotate:dateFormat YYYY-MM-DD_HH-mm-ss
pm2 set pm2-logrotate:rotateModule true   # 轮转 PM2 自身日志
pm2 set pm2-logrotate:workerInterval 30   # 检查间隔（秒）
```

### 手动清理日志

```bash
# 清空所有日志
pm2 flush

# 清空指定服务日志
pm2 flush <服务名>
```

### 查看历史日志

```bash
# 日志文件默认位置
# Windows: %USERPROFILE%\.pm2\logs\
# Linux:   ~/.pm2/logs/

# 查看错误日志
cat ~/.pm2/logs/dsh-web-error.log

# 查看完整日志（含时间戳）
cat ~/.pm2/logs/dsh-web-out.log

# 搜索日志内容
grep "ERROR" ~/.pm2/logs/dsh-web-error.log
```

---

## 开机自启

### Windows

```powershell
npm install -g pm2-windows-startup
pm2-startup install
pm2 save
```

### Linux

```bash
pm2 save
pm2 startup
# 打印 sudo 命令，复制执行
```

### 验证自启

```bash
# 检查保存的进程列表
pm2 save --force

# 查看 dump 文件
cat ~/.pm2/dump.pm2

# 模拟重启后恢复
pm2 resurrect
```

---

## PM2 自身升级

```bash
# 查看当前版本
pm2 --version

# 升级 PM2
npm install -g pm2@latest

# 升级后必须重载所有进程
pm2 updatePM2

# 验证升级
pm2 --version
```

> **注意**：`pm2 updatePM2` 会短暂中断服务（约 1-2 秒），请在低峰期执行。

---

## 一键部署脚本

### 新机器初始化脚本

```powershell
# setup-pm2.ps1 — Windows
$ErrorActionPreference = "Stop"

Write-Host "=== PM2 服务初始化 ===" -ForegroundColor Cyan

# 1. 检查 PM2
if (-not (Get-Command pm2 -ErrorAction SilentlyContinue)) {
    Write-Host "安装 PM2..." -ForegroundColor Yellow
    npm install -g pm2
}

# 2. 安装 Windows 启动支持
if (-not (Get-Command pm2-startup -ErrorAction SilentlyContinue)) {
    npm install -g pm2-windows-startup
    pm2-startup install
}

# 3. 安装日志轮转
pm2 install pm2-logrotate
pm2 set pm2-logrotate:max_size 10M
pm2 set pm2-logrotate:retain 7

# 4. 启动服务
$nodeExe = (where.exe node).Split('\n')[0].Trim()
$binPath = "$(npm root -g)\@deepseek-ai\dsh\lib\bin.js"
pm2 start $nodeExe --name dsh-web -- $binPath --profile web --no-open

# 5. 保存
pm2 save

Write-Host "=== 初始化完成 ===" -ForegroundColor Green
pm2 status
```

```bash
#!/bin/bash
# setup-pm2.sh — Linux
set -e

echo "=== PM2 服务初始化 ==="

# 1. 检查 PM2
if ! command -v pm2 &> /dev/null; then
    echo "安装 PM2..."
    npm install -g pm2
fi

# 2. 安装日志轮转
pm2 install pm2-logrotate
pm2 set pm2-logrotate:max_size 10M
pm2 set pm2-logrotate:retain 7

# 3. 启动服务
pm2 start "dsh" --name dsh-web -- --profile web --no-open

# 4. 保存并设置自启
pm2 save
pm2 startup

echo "=== 初始化完成 ==="
pm2 status
```

---

## 自动化运维脚本

### 服务健康检查脚本（自动检测异常并重启）

```powershell
# health-check.ps1 — 检查所有 PM2 服务状态，异常时自动重启
$processes = pm2 jlist | ConvertFrom-Json
$hasIssue = $false

foreach ($proc in $processes) {
    $name = $proc.name
    $status = $proc.pm2_env.status
    $restarts = $proc.pm2_env.restart_time
    $cpu = $proc.monit.cpu
    $mem = [math]::Round($proc.monit.memory / 1MB, 1)

    if ($status -ne "online") {
        Write-Host "[FAIL] $name — status: $status, 尝试重启..." -ForegroundColor Red
        pm2 restart $name
        $hasIssue = $true
    } elseif ($restarts -gt 10) {
        Write-Host "[WARN] $name — restarts: $restarts, mem: ${mem}MB, 执行重载..." -ForegroundColor Yellow
        pm2 reload $name
        $hasIssue = $true
    } elseif ($cpu -gt 90) {
        Write-Host "[WARN] $name — CPU: ${cpu}%, mem: ${mem}MB" -ForegroundColor Yellow
    } else {
        Write-Host "[OK]   $name — restarts: $restarts, cpu: ${cpu}%, mem: ${mem}MB" -ForegroundColor Green
    }
}

if ($hasIssue) {
    Write-Host "`n已自动处理异常服务，请持续观察" -ForegroundColor Yellow
    exit 1
} else {
    Write-Host "`n所有服务正常" -ForegroundColor Green
    exit 0
}
```

```bash
#!/bin/bash
# health-check.sh — Linux 版本（含自动重启）
processes=$(pm2 jlist)
has_issue=false

echo "$processes" | jq -c '.[]' | while read proc; do
    name=$(echo "$proc" | jq -r '.name')
    status=$(echo "$proc" | jq -r '.pm2_env.status')
    restarts=$(echo "$proc" | jq -r '.pm2_env.restart_time')
    cpu=$(echo "$proc" | jq -r '.monit.cpu')
    mem=$(echo "$proc" | jq -r '.monit.memory' | awk '{printf "%.1f", $1/1024/1024}')

    if [ "$status" != "online" ]; then
        echo "[FAIL] $name — status: $status, 尝试重启..."
        pm2 restart "$name"
        has_issue=true
    elif [ "$restarts" -gt 10 ]; then
        echo "[WARN] $name — restarts: $restarts, mem: ${mem}MB, 执行重载..."
        pm2 reload "$name"
        has_issue=true
    elif [ "$cpu" -gt 90 ]; then
        echo "[WARN] $name — CPU: ${cpu}%, mem: ${mem}MB"
    else
        echo "[OK]   $name — restarts: $restarts, cpu: ${cpu}%, mem: ${mem}MB"
    fi
done

if $has_issue; then
    echo -e "\n已自动处理异常服务，请持续观察"
    exit 1
else
    echo -e "\n所有服务正常"
    exit 0
fi
```

### 日志清理脚本（按天数或大小清理）

```powershell
# cleanup-logs.ps1 — 清理 PM2 日志
param(
    [int]$MaxAgeDays = 7,
    [double]$MaxSizeMB = 100
)

$logDir = "$env:USERPROFILE\.pm2\logs"
$totalFreed = 0

if (Test-Path $logDir) {
    # 1. 按天数清理
    $cutoff = (Get-Date).AddDays(-$MaxAgeDays)
    $oldFiles = Get-ChildItem $logDir -Filter "*.log" | Where-Object { $_.LastWriteTime -lt $cutoff }
    if ($oldFiles.Count -gt 0) {
        $oldSize = ($oldFiles | Measure-Object -Property Length -Sum).Sum
        $oldFiles | Remove-Item -Force
        $totalFreed += $oldSize
        Write-Host "按天数清理: $($oldFiles.Count) 个文件, $([math]::Round($oldSize / 1MB, 1)) MB" -ForegroundColor Yellow
    }

    # 2. 按大小清理（超过阈值的文件）
    $largeFiles = Get-ChildItem $logDir -Filter "*.log" | Where-Object { $_.Length -gt ($MaxSizeMB * 1MB) }
    if ($largeFiles.Count -gt 0) {
        $largeSize = ($largeFiles | Measure-Object -Property Length -Sum).Sum
        $largeFiles | ForEach-Object {
            $_.FullName
            Clear-Content $_.FullName
        }
        $totalFreed += $largeSize
        Write-Host "按大小清理: $($largeFiles.Count) 个文件, $([math]::Round($largeSize / 1MB, 1)) MB" -ForegroundColor Yellow
    }

    if ($totalFreed -eq 0) {
        Write-Host "无需清理，所有日志文件正常" -ForegroundColor Green
    } else {
        Write-Host "总计释放: $([math]::Round($totalFreed / 1MB, 1)) MB" -ForegroundColor Cyan
    }
} else {
    Write-Host "日志目录不存在: $logDir" -ForegroundColor Red
}

# 同时清空 PM2 内部日志
pm2 flush
Write-Host "PM2 内部日志已清空" -ForegroundColor Green
```

```bash
#!/bin/bash
# cleanup-logs.sh — Linux 版本
LOG_DIR="$HOME/.pm2/logs"
MAX_AGE_DAYS=${1:-7}
MAX_SIZE_MB=${2:-100}
TOTAL_FREED=0

if [ -d "$LOG_DIR" ]; then
    # 1. 按天数清理
    OLD_COUNT=$(find "$LOG_DIR" -name "*.log" -mtime +$MAX_AGE_DAYS | wc -l)
    if [ "$OLD_COUNT" -gt 0 ]; then
        OLD_SIZE=$(find "$LOG_DIR" -name "*.log" -mtime +$MAX_AGE_DAYS -exec du -cb {} + | tail -1 | awk '{print $1}')
        find "$LOG_DIR" -name "*.log" -mtime +$MAX_AGE_DAYS -delete
        TOTAL_FREED=$((TOTAL_FREED + OLD_SIZE))
        echo "按天数清理: ${OLD_COUNT} 个文件, $(echo "scale=1; $OLD_SIZE/1024/1024" | bc) MB"
    fi

    # 2. 按大小清理
    find "$LOG_DIR" -name "*.log" -size +${MAX_SIZE_MB}M | while read f; do
        SIZE=$(du -b "$f" | awk '{print $1}')
        > "$f"
        TOTAL_FREED=$((TOTAL_FREED + SIZE))
        echo "按大小清理: $f ($(echo "scale=1; $SIZE/1024/1024" | bc) MB)"
    done

    if [ "$TOTAL_FREED" -eq 0 ]; then
        echo "无需清理，所有日志文件正常"
    else
        echo "总计释放: $(echo "scale=1; $TOTAL_FREED/1024/1024" | bc) MB"
    fi
else
    echo "日志目录不存在: $LOG_DIR"
fi

# 清空 PM2 内部日志
pm2 flush
echo "PM2 内部日志已清空"
```

### 备份恢复脚本（自动备份 ecosystem 配置）

```powershell
# backup-pm2.ps1 — 自动备份 PM2 配置和 dump 文件
$backupDir = "$env:USERPROFILE\pm2-backups"
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupPath = Join-Path $backupDir $timestamp

if (-not (Test-Path $backupDir)) {
    New-Item -ItemType Directory -Path $backupDir | Out-Null
}

New-Item -ItemType Directory -Path $backupPath | Out-Null

# 1. 保存当前状态
pm2 save --force

# 2. 备份 dump 文件
$dumpFile = "$env:USERPROFILE\.pm2\dump.pm2"
if (Test-Path $dumpFile) {
    Copy-Item $dumpFile (Join-Path $backupPath "dump.pm2")
}

# 3. 备份 ecosystem.config.js（如果存在）
$ecosystemFile = "ecosystem.config.js"
if (Test-Path $ecosystemFile) {
    Copy-Item $ecosystemFile (Join-Path $backupPath "ecosystem.config.js")
}

# 4. 备份 PM2 配置
$pm2ConfigFile = "$env:USERPROFILE\.pm2\conf.js"
if (Test-Path $pm2ConfigFile) {
    Copy-Item $pm2ConfigFile (Join-Path $backupPath "conf.js")
}

# 5. 导出当前进程列表
pm2 jlist | Out-File (Join-Path $backupPath "processes.json")

# 6. 清理超过 30 天的备份
$cutoff = (Get-Date).AddDays(-30)
Get-ChildItem $backupDir | Where-Object { $_.LastWriteTime -lt $cutoff } | Remove-Item -Recurse -Force

Write-Host "备份完成: $backupPath" -ForegroundColor Green
Write-Host "备份内容: dump.pm2, ecosystem.config.js, conf.js, processes.json"
```

```bash
#!/bin/bash
# backup-pm2.sh — Linux 版本
BACKUP_DIR="$HOME/pm2-backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_PATH="$BACKUP_DIR/$TIMESTAMP"

mkdir -p "$BACKUP_DIR"
mkdir -p "$BACKUP_PATH"

# 1. 保存当前状态
pm2 save --force

# 2. 备份 dump 文件
[ -f "$HOME/.pm2/dump.pm2" ] && cp "$HOME/.pm2/dump.pm2" "$BACKUP_PATH/"

# 3. 备份 ecosystem.config.js
[ -f "ecosystem.config.js" ] && cp "ecosystem.config.js" "$BACKUP_PATH/"

# 4. 备份 PM2 配置
[ -f "$HOME/.pm2/conf.js" ] && cp "$HOME/.pm2/conf.js" "$BACKUP_PATH/"

# 5. 导出当前进程列表
pm2 jlist > "$BACKUP_PATH/processes.json"

# 6. 清理超过 30 天的备份
find "$BACKUP_DIR" -maxdepth 1 -type d -mtime +30 -exec rm -rf {} \;

echo "备份完成: $BACKUP_PATH"
echo "备份内容: dump.pm2, ecosystem.config.js, conf.js, processes.json"
```

```powershell
# restore-pm2.ps1 — 从备份恢复 PM2 配置
param(
    [Parameter(Mandatory=$true)]
    [string]$BackupPath
)

if (-not (Test-Path $BackupPath)) {
    Write-Host "备份路径不存在: $BackupPath" -ForegroundColor Red
    exit 1
}

# 1. 停止所有现有服务
pm2 stop all

# 2. 恢复 dump 文件
$dumpFile = Join-Path $BackupPath "dump.pm2"
if (Test-Path $dumpFile) {
    Copy-Item $dumpFile "$env:USERPROFILE\.pm2\dump.pm2" -Force
    pm2 resurrect
    Write-Host "已从 dump 文件恢复服务" -ForegroundColor Green
}

# 3. 恢复 ecosystem.config.js
$ecoFile = Join-Path $BackupPath "ecosystem.config.js"
if (Test-Path $ecoFile) {
    Copy-Item $ecoFile ".\ecosystem.config.js" -Force
    Write-Host "已恢复 ecosystem.config.js" -ForegroundColor Green
}

# 4. 恢复 PM2 配置
$confFile = Join-Path $BackupPath "conf.js"
if (Test-Path $confFile) {
    Copy-Item $confFile "$env:USERPROFILE\.pm2\conf.js" -Force
    Write-Host "已恢复 PM2 配置" -ForegroundColor Green
}

pm2 status
Write-Host "恢复完成" -ForegroundColor Cyan
```

### 监控告警脚本（CPU/内存超限通知）

```powershell
# monitor-alert.ps1 — CPU/内存超限告警
param(
    [int]$CpuThreshold = 80,
    [int]$MemThresholdMB = 1024,
    [string]$WebhookUrl = ""  # 企业微信/钉钉 webhook
)

$processes = pm2 jlist | ConvertFrom-Json
$alerts = @()

foreach ($proc in $processes) {
    $name = $proc.name
    $cpu = $proc.monit.cpu
    $mem = [math]::Round($proc.monit.memory / 1MB, 0)
    $status = $proc.pm2_env.status

    if ($status -ne "online") {
        $alerts += "[CRITICAL] $name — 服务已下线!"
    }
    if ($cpu -gt $CpuThreshold) {
        $alerts += "[WARN] $name — CPU: ${cpu}% (阈值: ${CpuThreshold}%)"
    }
    if ($mem -gt $MemThresholdMB) {
        $alerts += "[WARN] $name — 内存: ${mem}MB (阈值: ${MemThresholdMB}MB)"
    }
}

if ($alerts.Count -gt 0) {
    $msg = "PM2 监控告警`n" + ($alerts -join "`n")
    Write-Host $msg -ForegroundColor Red

    # 发送 webhook 通知（可选）
    if ($WebhookUrl) {
        $body = @{ content = $msg } | ConvertTo-Json
        try {
            Invoke-RestMethod -Uri $WebhookUrl -Method Post -Body $body -ContentType "application/json"
            Write-Host "告警已发送" -ForegroundColor Green
        } catch {
            Write-Host "告警发送失败: $_" -ForegroundColor Red
        }
    }
    exit 1
} else {
    Write-Host "所有服务指标正常" -ForegroundColor Green
    exit 0
}
```

```bash
#!/bin/bash
# monitor-alert.sh — Linux 版本
CPU_THRESHOLD=${1:-80}
MEM_THRESHOLD_MB=${2:-1024}
WEBHOOK_URL=${3:-""}
ALERTS=()

while read proc; do
    name=$(echo "$proc" | jq -r '.name')
    cpu=$(echo "$proc" | jq -r '.monit.cpu')
    mem=$(echo "$proc" | jq -r '.monit.memory' | awk '{printf "%.0f", $1/1024/1024}')
    status=$(echo "$proc" | jq -r '.pm2_env.status')

    if [ "$status" != "online" ]; then
        ALERTS+=("[CRITICAL] $name — 服务已下线!")
    fi
    if [ "$cpu" -gt "$CPU_THRESHOLD" ]; then
        ALERTS+=("[WARN] $name — CPU: ${cpu}% (阈值: ${CPU_THRESHOLD}%)")
    fi
    if [ "$mem" -gt "$MEM_THRESHOLD_MB" ]; then
        ALERTS+=("[WARN] $name — 内存: ${mem}MB (阈值: ${MEM_THRESHOLD_MB}MB)")
    fi
done < <(pm2 jlist | jq -c '.[]')

if [ ${#ALERTS[@]} -gt 0 ]; then
    MSG="PM2 监控告警\n$(printf '%s\n' "${ALERTS[@]}")"
    echo -e "$MSG"

    if [ -n "$WEBHOOK_URL" ]; then
        curl -s -X POST -H "Content-Type: application/json" \
            -d "{\"content\":\"$(echo -e "$MSG" | sed 's/"/\\"/g' | tr '\n' ' ')\"}" \
            "$WEBHOOK_URL"
    fi
    exit 1
else
    echo "所有服务指标正常"
    exit 0
fi
```

---

## 与 systemd 集成方案

当需要 PM2 随系统自动启动（不依赖 `pm2 startup`），或需要与 systemd 生态集成时：

### 创建 systemd 服务单元

```ini
# /etc/systemd/system/pm2-user.service
[Unit]
Description=PM2 Process Manager
After=network.target

[Service]
Type=forking
User=%i
ExecStart=/usr/local/bin/pm2 resurrect
ExecReload=/usr/local/bin/pm2 reload all
ExecStop=/usr/local/bin/pm2 kill
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
```

```bash
# 启用并启动
sudo systemctl enable pm2-user
sudo systemctl start pm2-user

# 查看状态
sudo systemctl status pm2-user

# 查看日志
sudo journalctl -u pm2-user -f
```

### PM2 与 systemd 分工建议

| 场景 | 推荐方案 | 原因 |
|------|---------|------|
| 纯 Node.js 服务 | PM2 | 简单、内置日志、自动重启 |
| 需要开机自启 + 日志持久化 | PM2 + systemd | systemd 保证 PM2 自身存活 |
| 非 Node.js 服务（Nginx、Redis） | systemd | 原生支持，无需额外依赖 |
| 混合服务（Node + 数据库） | systemd 统一管理 | 统一日志、依赖管理 |

---

## Docker 内 PM2 最佳实践

### 方案一：PM2 作为容器主进程

```dockerfile
FROM node:20-alpine
RUN npm install -g pm2
WORKDIR /app
COPY package*.json ./
RUN npm ci --production
COPY . .
EXPOSE 3000
CMD ["pm2-runtime", "ecosystem.config.js"]
```

> **关键**：使用 `pm2-runtime` 而非 `pm2 start`，`pm2-runtime` 在前台运行，保持容器存活。

### 方案二：多阶段构建 + PM2

```dockerfile
# 构建阶段
FROM node:20 AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

# 运行阶段
FROM node:20-alpine
RUN npm install -g pm2
WORKDIR /app
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
COPY ecosystem.config.js ./
EXPOSE 3000
CMD ["pm2-runtime", "ecosystem.config.js", "--env", "production"]
```

### Docker Compose 集成

```yaml
version: '3.8'
services:
  api:
    build: .
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production
    restart: unless-stopped
    # 健康检查
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
```

### Docker 内 PM2 注意事项

| 问题 | 解决方案 |
|------|---------|
| 容器退出后 PM2 消失 | 使用 `pm2-runtime` 前台运行 |
| 日志丢失 | 挂载 volume 到 `/root/.pm2/logs` |
| 内存限制 | 在 `docker run` 中设置 `-m`，PM2 的 `max_memory_restart` 应小于容器限制 |
| 无法 `pm2 monit` | Docker 内无终端，改用 `pm2 logs` 或 `pm2 describe` |
| 多容器部署 | 用 Docker Swarm/K8s 替代 PM2 cluster 模式 |

---

## 故障排查

| 现象 | 原因 | 解决 |
|------|------|------|
| `unknown option --profile` / `bad option` | PM2 把参数传给 node.exe | 用 `pm2 start node -- bin.js --profile <name>` |
| SyntaxError: Invalid or unexpected token | PM2 把 .cmd 当脚本执行 | 改用 .mjs 入口：`pm2 start "$(npm root -g)\openclaw\openclaw.mjs" -- gateway run` |
| 端口被占用 | 旧进程未退出 | `pm2 stop <服务名>` 或 `tasklist \| findstr <服务名>` |
| 进程启动后立即退出 | 配置错误或缺少环境变量 | `pm2 logs <服务名>` 查看日志 |
| 开机未自启 | 未执行 `pm2 save` | `pm2 save` 后检查 `~/.pm2/dump.pm2` |
| 内存持续增长 | 内存泄漏 | 设置 `max_memory_restart: '512M'` 自动重启 |
| 日志文件过大 | 未配置轮转 | `pm2 install pm2-logrotate` |
| Cluster 模式端口冲突 | 多实例绑定同一端口 | 使用 `exec_mode: 'cluster'` 让 PM2 自动分配端口 |
| PM2 daemon 崩溃 | 系统资源不足或 dump 文件损坏 | `pm2 kill && pm2 resurrect` |
| 服务反复重启 | 脚本崩溃或 `max_memory_restart` 设置过小 | 查日志 + 调整内存阈值 |

---

## 反模式（Anti-Patterns）

### 不要直接 kill -9 PM2 进程

```bash
# 错误 — 直接杀死 PM2 daemon
kill -9 $(pgrep PM2)

# 正确 — 通过 PM2 命令管理
pm2 stop all
pm2 kill  # 仅在需要完全停止 PM2 时使用
```

> `kill -9` 会导致 dump 文件损坏，开机自启失效。

### 不要忽略日志

```bash
# 错误 — 服务挂了不看日志直接重启
pm2 restart myapp

# 正确 — 先看日志定位问题
pm2 logs myapp --lines 50
# 找到原因后再重启
pm2 restart myapp
```

### 不要在 ecosystem.config.js 中硬编码绝对路径

```javascript
// 错误
cwd: 'C:\\Users\\Cecilia\\projects\\myapp'

// 正确
cwd: `${process.env.USERPROFILE}/projects/myapp`
```

### 不要同时使用 PM2 和 systemd 管理同一服务

会导致进程重复启动、端口冲突、日志混乱。

### 不要在生产环境使用 `watch: true`

文件监听会消耗大量 CPU，且可能导致意外重启。生产环境用 CI/CD 触发 `pm2 reload`。

### 不要在 Cluster 模式下使用有状态的设计

Cluster 模式多实例共享同一端口，请求可能路由到任意实例。Session 必须存 Redis/DB，不能存内存。

### 不要设置过低的 `max_memory_restart`

频繁触发自动重启反而比偶尔 OOM 更影响可用性。建议根据服务实际内存使用量上浮 30%-50%。

---

## FAQ

### 如何查看历史日志？

```bash
# 日志文件位置
# Windows: %USERPROFILE%\.pm2\logs\<服务名>-out.log
# Linux:   ~/.pm2/logs/<服务名>-out.log

# 查看完整历史
cat ~/.pm2/logs/dsh-web-out.log

# 搜索关键词
grep "error" ~/.pm2/logs/dsh-web-error.log

# 查看最近 1000 行
tail -n 1000 ~/.pm2/logs/dsh-web-out.log
```

### 如何重启所有服务？

```bash
pm2 restart all
```

### 如何备份和恢复 PM2 配置？

```bash
# 备份
pm2 save
cp ~/.pm2/dump.pm2 ./pm2-backup-$(date +%Y%m%d).json

# 恢复（新机器）
# 1. 安装 PM2
npm install -g pm2
# 2. 复制 dump 文件到 ~/.pm2/dump.pm2
# 3. 恢复进程
pm2 resurrect
```

### 如何限制服务的内存使用？

```bash
# 命令行方式
pm2 start app.js --name myapp --max-memory-restart 512M

# 配置文件方式
# 在 ecosystem.config.js 中添加 max_memory_restart: '512M'
```

### 如何设置定时重启？

```bash
# 每天凌晨 3 点重启
pm2 start app.js --name myapp --cron-restart "0 3 * * *"

# 配置文件方式
# cron_restart: '0 3 * * *'
```

### 如何查看 PM2 占用的资源？

```bash
pm2 monit          # 交互式面板
pm2 describe <id>  # 单个进程详情
```

### 服务启动后立即退出怎么办？

```bash
# 1. 查看日志
pm2 logs <服务名> --lines 50

# 2. 常见原因：
#    - 端口被占用 → 换端口或 kill 占用进程
#    - 缺少环境变量 → 检查 .env 文件
#    - 脚本路径错误 → 检查 cwd 和 script 配置
#    - 权限不足 → 检查文件权限

# 3. 手动测试脚本能否正常运行
node bin.js --profile web --no-open
```

### 如何卸载 PM2？

```bash
# 1. 停止并删除所有进程
pm2 delete all

# 2. 杀死 PM2 daemon
pm2 kill

# 3. 卸载全局包
npm uninstall -g pm2

# 4. 清理残留文件（可选）
rm -rf ~/.pm2
```

### PM2 vs systemd vs Docker：如何选择？

| 维度 | PM2 | systemd | Docker |
|------|-----|---------|--------|
| **适用场景** | Node.js 进程守护 | 系统服务管理 | 容器化部署 |
| **自动重启** | 内置 `autorestart` | `Restart=on-failure` | `restart: always` |
| **日志管理** | `pm2 logs` + logrotate | `journalctl` | `docker logs` |
| **多实例** | Cluster 模式（自动） | 需手动配置 | 需编排工具 |
| **开机自启** | `pm2 startup` / `pm2 save` | `systemctl enable` | `restart: always` |
| **资源限制** | `max_memory_restart` | `MemoryMax=` / `CPUQuota=` | `-m` / `--cpus` |
| **学习成本** | 低 | 中 | 高 |
| **推荐组合** | 开发环境 / Node.js 服务 | 生产环境 Linux 服务 | 微服务 / CI/CD |

> **推荐组合**：生产环境用 systemd 管理 PM2，PM2 管理 Node.js 服务。即 systemd → PM2 → Node.js 进程。

### 如何实现服务的优雅关闭？

```javascript
// 在 Node.js 应用中监听 SIGINT 信号
process.on('SIGINT', () => {
  console.log('收到 SIGINT，开始优雅关闭...');
  server.close(() => {
    console.log('HTTP 服务器已关闭');
    process.exit(0);
  });
  // 超时强制退出
  setTimeout(() => process.exit(1), 5000);
});
```

```bash
# ecosystem.config.js 中配置
{
  kill_timeout: 5000,    // 等待 5 秒后强制杀死
  listen_timeout: 3000,  // 等待 ready 信号的超时
  wait_ready: true,      // 等待 process.send('ready')
}
```

### 如何监控 PM2 服务的实时性能？

```bash
# 终端实时面板
pm2 monit

# 查看单个进程详细指标
pm2 describe <服务名>

# 导出 JSON 格式（可接入外部监控系统）
pm2 jlist

# 使用 PM2.io 云端监控（需注册）
pm2 link <secret_key> <public_key>
```

### 服务反复重启（restart loop）怎么办？

```bash
# 1. 查看重启次数
pm2 status
# 关注 ↺ 列

# 2. 查看日志定位原因
pm2 logs <服务名> --lines 100

# 3. 常见原因和解决：
#    - 内存超限 → 增大 max_memory_restart
#    - 端口冲突 → 检查端口占用
#    - 脚本崩溃 → 修复代码 bug
#    - 环境变量缺失 → 检查 env 配置

# 4. 临时禁用自动重启（排查时）
pm2 stop <服务名>
# 手动运行脚本测试
node app.js
```

### 如何设置 PM2 的定时任务？

```bash
# 方法 1：cron_restart（在指定时间重启服务）
pm2 start app.js --name myapp --cron-restart "0 3 * * *"

# 方法 2：用 ecosystem.config.js
{
  name: 'scheduled-task',
  script: 'task.js',
  cron_restart: '0 */6 * * *',  # 每 6 小时执行一次
  autorestart: false,            # 不自动重启（一次性任务）
  watch: false,
}

# 方法 3：配合系统 crontab（推荐复杂调度）
# crontab -e
# 0 3 * * * /usr/local/bin/pm2 restart myapp
```

---

## 端到端操作示例

### 示例一：从零部署一个 Node.js 服务并设置监控

```bash
# 1. 创建项目
mkdir my-api && cd my-api
npm init -y
npm install express

# 2. 创建服务入口
cat > server.js << 'EOF'
const express = require('express');
const app = express();
app.get('/health', (req, res) => res.json({ status: 'ok' }));
app.listen(3000, () => console.log('API running on port 3000'));
EOF

# 3. 创建 ecosystem.config.js
cat > ecosystem.config.js << 'EOF'
module.exports = {
  apps: [{
    name: 'my-api',
    script: 'server.js',
    instances: 'max',
    exec_mode: 'cluster',
    max_memory_restart: '300M',
    env: { NODE_ENV: 'production' },
    error_file: './logs/error.log',
    out_file: './logs/out.log',
  }]
};
EOF
mkdir -p logs

# 4. 启动服务
pm2 start ecosystem.config.js

# 5. 设置开机自启
pm2 save
pm2 startup  # Linux

# 6. 安装日志轮转
pm2 install pm2-logrotate
pm2 set pm2-logrotate:max_size 10M
pm2 set pm2-logrotate:retain 7

# 7. 验证
pm2 status
pm2 logs my-api --lines 10
pm2 describe my-api

# 8. 设置定时健康检查（crontab）
# */5 * * * * /path/to/health-check.sh
```

### 示例二：从故障到恢复的完整流程

```bash
# === 场景：用户报告 openclaw 服务不可用 ===

# 第 1 步：检查服务状态
pm2 status
# 发现 openclaw 状态为 "errored" 或 "stopped"

# 第 2 步：查看日志定位原因
pm2 logs openclaw --lines 50
# 发现错误：EADDRINUSE: address already in use :::3000

# 第 3 步：检查端口占用
# Windows:
netstat -ano | findstr :3000
# Linux:
lsof -i :3000

# 第 4 步：杀死占用进程
# Windows:
taskkill /PID <pid> /F
# Linux:
kill -9 <pid>

# 第 5 步：重启服务
pm2 restart openclaw

# 第 6 步：验证恢复
pm2 status
pm2 logs openclaw --lines 5
# 确认状态为 online，日志无报错

# 第 7 步：设置预防措施
# 在 ecosystem.config.js 中添加：
# max_memory_restart: '1G',
# kill_timeout: 5000,

# 第 8 步：保存配置
pm2 save
```

---

## 最佳实践清单

1. **使用 ecosystem.config.js** 管理配置，纳入版本控制
2. **设置 `max_memory_restart`** 防止内存泄漏拖垮系统
3. **安装 pm2-logrotate** 防止日志磁盘爆满
4. **使用 `pm2 reload`** 代替 `pm2 restart` 实现零停机更新
5. **定期执行 `pm2 save`** 确保开机自启不丢失
6. **监控重启次数**：`↺ > 10` 说明服务不稳定，需排查
7. **生产环境禁用 `watch: true`**，用 CI/CD 触发重载
8. **日志路径统一到 `~/.pm2/logs/`**，便于管理和清理
9. **Cluster 模式用于无状态服务**，有状态服务用 fork 模式
10. **配合 systemd 实现双重保障**：systemd 管理 PM2，PM2 管理应用
11. **定期备份 dump 文件**：`pm2 save` + 定期复制 `~/.pm2/dump.pm2`
12. **设置健康检查脚本**：定时运行 `health-check.sh`，异常自动重启
