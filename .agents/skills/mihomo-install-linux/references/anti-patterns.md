# 反模式与 FAQ

## 反模式（Anti-Patterns）

| # | 错误做法 | 正确做法 |
|---|----------|----------|
| 1 | 直接编辑正在运行的二进制文件所在目录 | 先停止服务，替换二进制，再启动 |
| 2 | 忘记开放防火墙端口 | 如需 `allow-lan: true`，执行 `ufw allow 7897/tcp` |
| 3 | 使用 root 运行 systemd user 服务 | 始终使用 `systemctl --user`，不要加 `sudo` |
| 4 | 订阅地址明文写在公共仓库 | 使用环境变量或私有文件存储 token |
| 5 | 不校验配置直接重启 | 先 `mihomo -d ~/.config/mihomo -t` 校验 |
| 6 | 同时运行多个 mihomo 实例 | 启动前检查 `pgrep mihomo`，避免端口冲突 |
| 7 | 忽略日志中的 WARN/ERROR | 定期检查 `journalctl --user -u mihomo` |
| 8 | 使用已废弃的配置字段 | 参考官方文档 `https://wiki.metacubex.one/` |
| 9 | 将 mixed-port 暴露到公网 | `allow-lan: true` 时务必设置防火墙规则，仅允许可信 IP |
| 10 | 在已有代理的环境下直接下载 | 先取消代理环境变量 `unset http_proxy https_proxy all_proxy` |
| 11 | 订阅 token 硬编码在配置中 | 使用 `env://SUBSCRIBE_TOKEN` 引用环境变量 |
| 12 | 不设置 API secret | 生产环境必须设置 `secret`，防止未授权访问 |
| 13 | 将所有流量走代理 | 使用 `GEOIP,CN,DIRECT` 让国内流量直连 |
| 14 | 使用默认 DNS 设置 | 配置 DoH 防止 DNS 污染 |
| 15 | 忽略 GeoIP 数据库更新 | 启用 `geo-auto-update` 保持规则准确 |
| 16 | 在 config.yaml 内联数百条规则 | 使用 `rule-providers` 外部规则集，减少启动时间 |
| 17 | 频繁手动更新订阅（每分钟） | 设置合理 `interval`（≥3600），避免被机场封禁 |

## FAQ

### Q1: 如何卸载 Mihomo？

参考 [installation.md](installation.md) 中的「卸载流程」章节，或使用一键卸载脚本。

### Q2: 如何更新到最新版本？

```bash
# 方法一：使用一键安装脚本（自动备份和回退）
bash install-mihomo.sh

# 方法二：手动更新
systemctl --user stop mihomo
# 下载新版替换 ~/bin/mihomo
systemctl --user start mihomo
```

### Q3: 如何查看实时日志？

```bash
journalctl --user -u mihomo -f
```

### Q4: 如何切换配置？

```bash
# 方法一：热重载（推荐）
bash reload-config.sh

# 方法二：修改 config.yaml 后重启
systemctl --user restart mihomo
```

### Q5: 如何更新订阅？

订阅会根据 `interval` 自动更新。手动触发：

```bash
# 通过 API 触发
curl -X PUT http://127.0.0.1:9090/providers/proxies/my-airplane
```

### Q6: 国内服务器下载慢怎么办？

```bash
# 设置镜像环境变量后运行安装脚本
export MIHOMO_MIRROR=https://ghproxy.com/https://github.com
bash install-mihomo.sh
```

### Q7: 如何设置代理环境变量？

```bash
# 临时设置
export https_proxy=http://127.0.0.1:7897
export http_proxy=http://127.0.0.1:7897
export all_proxy=socks5://127.0.0.1:7897

# 永久设置（写入 ~/.bashrc）
echo 'export https_proxy=http://127.0.0.1:7897' >> ~/.bashrc
```

### Q8: 如何限制 mihomo 资源占用？

在 systemd service 文件中添加：

```ini
[Service]
MemoryMax=256M
CPUQuota=50%
```

### Q9: TUN 模式有什么用？

TUN 模式通过虚拟网卡接管系统所有流量，解决部分应用不走代理的问题（如游戏、UDP 流量、部分桌面应用）。详见 [configuration.md](configuration.md) 中的 TUN 模式配置章节。

### Q10: fake-ip 模式有什么用？

fake-ip 模式将域名解析为虚假 IP（198.18.0.0/15），由 mihomo 在转发时再解析真实 IP，解决 DNS 污染问题。详见 [configuration.md](configuration.md) 中的 DNS 高级设置章节。

### Q11: 多订阅源如何负载均衡？

通过配置多个 `proxy-providers` 和不同类型的 `proxy-groups`（url-test / load-balance / fallback）实现。详见 [configuration.md](configuration.md) 中的多订阅源负载均衡章节。

### Q12: 如何备份配置？

```bash
# 备份整个配置目录
tar czf mihomo-backup-$(date +%Y%m%d).tar.gz ~/.config/mihomo

# 恢复
tar xzf mihomo-backup-*.tar.gz -C ~/
```

### Q13: 如何监控 mihomo 运行状态？

```bash
# 使用健康检查脚本
bash health-check.sh

# 通过 API 获取版本信息
curl -s http://127.0.0.1:9090/version

# 通过 API 获取连接信息
curl -s http://127.0.0.1:9090/connections | python3 -m json.tool
```

### Q14: 订阅地址泄露了怎么办？

1. 立即在机场后台重新生成 token
2. 更新 `config.yaml` 中的订阅地址
3. 热重载配置
4. 检查是否有异常流量（通过 API 查看连接）

### Q15: 如何设置 Dashboard？

```bash
# 下载 metacubexd Dashboard
DASHBOARD_VERSION=$(curl -s https://api.github.com/repos/metacubex/metacubexd/releases/latest | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
curl -fsSL "https://github.com/metacubex/metacubexd/releases/download/${DASHBOARD_VERSION}/gh-pages.tar.gz" -o /tmp/dashboard.tar.gz

# 解压到配置目录
mkdir -p ~/.config/mihomo/ui
tar xzf /tmp/dashboard.tar.gz -C ~/.config/mihomo/ui

# 在 config.yaml 中设置
# external-ui: ui
```

### Q16: 为什么国内网站也走代理？

检查 `config.yaml` 中的 `rules` 部分，确保有以下规则：

```yaml
rules:
  - GEOIP,CN,DIRECT
  - MATCH,PROXY
```

如果使用了外部规则集，确保规则顺序正确（国内直连规则在代理规则之前）。

### Q17: 如何调试规则匹配？

```bash
# 开启 debug 日志
# 在 config.yaml 中设置 log-level: debug

# 查看日志中的规则匹配
journalctl --user -u mihomo -f | grep "match"
```

### Q18: 内存泄漏怎么办？

1. 升级到最新版本（可能已修复）
2. 减少订阅节点数量
3. 在 systemd 服务中设置 `MemoryMax` 限制
4. 定期重启服务（通过 cron 定时任务）

```bash
# 添加定时重启（每天凌晨 4 点）
(crontab -l 2>/dev/null; echo "0 4 * * * systemctl --user restart mihomo") | crontab -
```

### Q19: 节点延迟很高怎么办？

1. 检查测速 URL 是否可达：`curl -x http://127.0.0.1:7897 http://www.gstatic.com/generate_204`
2. 尝试切换 TUN 模式（改善 UDP 路由）
3. 使用 `url-test` 自动选择低延迟节点
4. 在 `proxy-groups` 中设置 `tolerance` 避免频繁切换
5. 检查是否开启了 `strict-route`（可能增加延迟）

### Q20: mihomo 启动很慢怎么办？

1. 减少 `proxy-providers` 中的节点数量
2. 禁用 `geo-auto-update`（首次启动需下载数据库）
3. 使用 `rule-providers` 替代内联规则
4. 检查 DNS 解析是否正常（`dig github.com`）
5. 在 systemd 服务中增加 `TimeoutStartSec=30`

## 最佳实践检查清单

部署前请逐项确认：

### 安全

- [ ] `secret` 字段已设置（非空）
- [ ] `allow-lan` 默认为 `false`，如需开启已配置防火墙
- [ ] 订阅 token 通过环境变量引用，未明文写入配置
- [ ] `external-controller` 绑定 `127.0.0.1`（非 `0.0.0.0`）
- [ ] 已配置防火墙规则（`ufw allow from 192.168.0.0/16 to any port 7897`）

### 稳定性

- [ ] systemd 服务已配置 `Restart=on-failure` 和 `RestartSec=5`
- [ ] `log-level` 非 `debug`（生产环境用 `info` 或 `warning`）
- [ ] `health-check` 已启用，interval ≥ 600
- [ ] 订阅 `interval` ≥ 3600（避免被机场封禁）
- [ ] `LimitNOFILE` 设置为 65535

### 性能

- [ ] 国内流量直连规则 `GEOIP,CN,DIRECT` 已配置
- [ ] DNS 使用 DoH（`https://` 前缀）
- [ ] 未使用内联大量规则（改用 `rule-providers`）
- [ ] `geo-auto-update` 按需开启（关闭可减少启动时间）
- [ ] TUN 模式按需开启（非必要不启用）

### 监控

- [ ] 已配置健康检查脚本，定期执行
- [ ] 已配置日志监控（`journalctl --user -u mihomo -f`）
- [ ] 已配置流量统计脚本（`traffic-report.sh`）
- [ ] 已配置自动更新脚本（`auto-update.sh`）
- [ ] 已配置 linger（`loginctl enable-linger $(whoami)`）

### 备份与恢复

- [ ] 配置目录已纳入版本控制（脱敏后）
- [ ] 定期备份配置（至少每周一次）
- [ ] 更新前自动备份已配置（`auto-update.sh` 内置）
- [ ] 回滚流程已验证（可恢复旧版本）
