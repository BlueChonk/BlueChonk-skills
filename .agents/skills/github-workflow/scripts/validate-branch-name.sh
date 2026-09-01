#!/bin/bash
# validate-branch-name.sh - 分支命名规范检查
# 使用方式: bash scripts/validate-branch-name.sh
# 退出码:
#   0 = 通过
#   1 = 不在 Git 仓库中
#   2 = 无法获取分支名（git 锁或异常）
#   3 = 分支名不符合规范
#
# 合法分支名格式:
#   main, dev
#   feat/<name>, fix/<name>, test/<name>
#   release/v<semver>, hotfix/v<semver>

set -euo pipefail

# 超时时间（秒）
TIMEOUT=10
# 重试次数
MAX_RETRIES=3
RETRY_DELAY=1

# 带重试的 git 命令
git_with_retry() {
    local attempt=1
    local output=""
    while [[ $attempt -le $MAX_RETRIES ]]; do
        output=$(timeout "$TIMEOUT" git "$@" 2>/dev/null) && {
            echo "$output"
            return 0
        }
        if [[ $attempt -lt $MAX_RETRIES ]]; then
            sleep "$RETRY_DELAY"
        fi
        ((attempt++))
    done
    return 1
}

# 获取当前分支名（带重试）
BRANCH_NAME=""
for attempt in $(seq 1 $MAX_RETRIES); do
    BRANCH_NAME=$(timeout "$TIMEOUT" git symbolic-ref --short HEAD 2>/dev/null) && break
    if [[ $attempt -lt $MAX_RETRIES ]]; then
        sleep "$RETRY_DELAY"
    fi
done

if [[ -z "$BRANCH_NAME" ]]; then
    # 判断是否在 git 仓库中
    if ! timeout "$TIMEOUT" git rev-parse --git-dir >/dev/null 2>&1; then
        echo "ERROR: 未找到 Git 仓库，请在 Git 仓库根目录执行"
        exit 1
    fi
    echo "ERROR: 无法获取当前分支名（git 仓库可能处于异常状态，如 rebase 冲突中）"
    echo "  提示: 检查 .git/HEAD 文件是否损坏，或尝试 git status"
    exit 2
fi

# 定义合法分支名正则
PATTERN="^(main|dev|feat/[a-z0-9-]+|fix/[a-z0-9-]+|test/[a-z0-9-]+|release/v[0-9]+\.[0-9]+\.[0-9]+|hotfix/v[0-9]+\.[0-9]+\.[0-9]+)$"

if [[ ! $BRANCH_NAME =~ $PATTERN ]]; then
    echo "ERROR: 分支名 '$BRANCH_NAME' 不符合规范"
    echo ""
    echo "合法格式示例："
    echo "  feat/user-auth       （功能开发）"
    echo "  fix/login-redirect   （Bug 修复）"
    echo "  test/payment-flow    （临时测试）"
    echo "  release/v1.2.0       （发布分支）"
    echo "  hotfix/v1.2.1        （紧急修复）"
    exit 3
fi

echo "PASS: 分支名 '$BRANCH_NAME' 符合规范"
exit 0
