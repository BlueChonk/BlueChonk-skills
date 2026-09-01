#!/bin/bash
# validate-commit-msg.sh - commit message 格式校验
# 使用方式: bash scripts/validate-commit-msg.sh <commit-msg-file>
# 退出码:
#   0 = 通过
#   1 = 参数缺失
#   2 = 文件不存在或不可读
#   3 = commit message 为空
#   4 = commit message 格式不符合规范
#
# 校验 Conventional Commits 规范:
#   <type>(<scope>): <中文描述>
#   type: feat|fix|docs|style|ref|test|chore|ci|revert

set -euo pipefail

# 超时时间（秒）
TIMEOUT=5
# 重试次数
MAX_RETRIES=3
RETRY_DELAY=1

# 参数校验
if [[ $# -lt 1 ]]; then
    echo "ERROR: 请提供 commit message 文件路径"
    echo "使用方式: $0 <commit-msg-file>"
    exit 1
fi

COMMIT_MSG_FILE=$1

# 带重试的文件读取
CONTENT=""
for attempt in $(seq 1 $MAX_RETRIES); do
    if [[ -f "$COMMIT_MSG_FILE" && -r "$COMMIT_MSG_FILE" ]]; then
        CONTENT=$(timeout "$TIMEOUT" head -n1 "$COMMIT_MSG_FILE" 2>/dev/null) && break
    fi
    if [[ $attempt -lt $MAX_RETRIES ]]; then
        sleep "$RETRY_DELAY"
    fi
done

if [[ -z "$CONTENT" && ! -f "$COMMIT_MSG_FILE" ]]; then
    echo "ERROR: 文件不存在: $COMMIT_MSG_FILE"
    echo "  请确认文件路径正确，或在 git commit 时自动触发"
    exit 2
fi

if [[ -z "$CONTENT" && ! -r "$COMMIT_MSG_FILE" ]]; then
    echo "ERROR: 文件不可读: $COMMIT_MSG_FILE"
    echo "  请检查文件权限"
    exit 2
fi

# 读取第一行（subject）
COMMIT_MSG=$(echo "$CONTENT" | head -n1)

if [[ -z "$COMMIT_MSG" ]]; then
    echo "ERROR: commit message 不能为空"
    exit 3
fi

# 定义 commit message 正则
PATTERN="^(feat|fix|docs|style|ref|test|chore|ci|revert)(\([a-z0-9-]+\))?: .{1,72}$"

if [[ ! $COMMIT_MSG =~ $PATTERN ]]; then
    echo "ERROR: commit message 格式不符合规范"
    echo ""
    echo "当前信息: $COMMIT_MSG"
    echo ""
    echo "正确格式: <type>(<scope>): <中文描述>"
    echo "  type: feat|fix|docs|style|ref|test|chore|ci|revert"
    echo "  scope: 可选，小写字母和连字符"
    echo "  描述: 中文，1-72 字符"
    echo ""
    echo "示例："
    echo "  feat(payment): 添加支付宝支付接口"
    echo "  fix(auth): 修复登录后跳转异常"
    exit 4
fi

echo "PASS: commit message 格式正确"
exit 0
