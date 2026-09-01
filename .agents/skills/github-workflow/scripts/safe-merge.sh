#!/bin/bash
# safe-merge.sh - 安全合并检查
# 使用方式: bash scripts/safe-merge.sh <target-branch>
# 退出码:
#   0 = 安全可合并
#   1 = 参数缺失
#   2 = 不在 Git 仓库中
#   3 = 目标分支不存在
#   4 = 当前分支与目标分支相同
#   5 = 存在未提交的改动
#   6 = 本地分支与远程不同步
#   7 = 检测到合并冲突
#   8 = CI 状态异常或正在运行
#   9 = 网络超时（git fetch 失败）
#
# 检查项:
#   1. 无未提交改动
#   2. 目标分支已同步
#   3. 无合并冲突
#   4. CI 状态通过（需 gh CLI）

set -euo pipefail

# 超时时间（秒）
FETCH_TIMEOUT=30
GH_TIMEOUT=15
# 重试次数
MAX_RETRIES=3
RETRY_DELAY=2

# 带重试和超时的 git fetch
git_fetch_with_retry() {
    local branch=$1
    local attempt=1
    while [[ $attempt -le $MAX_RETRIES ]]; do
        if timeout "$FETCH_TIMEOUT" git fetch origin "$branch" 2>/dev/null; then
            return 0
        fi
        if [[ $attempt -lt $MAX_RETRIES ]]; then
            sleep "$RETRY_DELAY"
        fi
        ((attempt++))
    done
    return 1
}

# 带超时的 gh CLI 调用
gh_with_timeout() {
    timeout "$GH_TIMEOUT" gh "$@" 2>/dev/null
}

# 参数校验
if [[ $# -lt 1 ]]; then
    echo "ERROR: 请提供目标分支名"
    echo "使用方式: $0 <target-branch>"
    echo "示例: $0 main"
    exit 1
fi

TARGET_BRANCH=$1

# 检查是否在 git 仓库中
GIT_DIR=$(timeout 10 git rev-parse --git-dir 2>/dev/null) || {
    echo "ERROR: 未找到 Git 仓库，请在 Git 仓库根目录执行"
    exit 2
}

CURRENT_BRANCH=$(timeout 10 git symbolic-ref --short HEAD 2>/dev/null) || {
    echo "ERROR: 无法获取当前分支名"
    exit 2
}

if [[ "$CURRENT_BRANCH" == "$TARGET_BRANCH" ]]; then
    echo "ERROR: 当前分支与目标分支相同，无需合并"
    exit 4
fi

# 检查目标分支是否存在
if ! git rev-parse --verify "$TARGET_BRANCH" >/dev/null 2>&1; then
    echo "ERROR: 目标分支 '$TARGET_BRANCH' 不存在"
    echo "  可用分支:"
    git branch -a --list "*$TARGET_BRANCH*" 2>/dev/null | head -5 || echo "    (无匹配分支)"
    exit 3
fi

echo "=== 安全合并检查 ==="
echo "当前分支: $CURRENT_BRANCH"
echo "目标分支: $TARGET_BRANCH"
echo ""

# 检查 1: 是否有未提交的改动
if ! git diff-index --quiet HEAD --; then
    echo "WARNING: 存在未提交的改动，请先提交或 stash"
    echo "  运行: git status"
    echo "  或:   git stash -m \"临时保存\""
    exit 5
fi
echo "[PASS] 无未提交改动"

# 检查 2: 目标分支是否最新（带重试）
echo ""
echo "=== 同步检查 ==="
if ! git_fetch_with_retry "$TARGET_BRANCH"; then
    echo "ERROR: 无法同步远程分支（网络超时或远程不可达）"
    echo "  已重试 $MAX_RETRIES 次，每次超时 ${FETCH_TIMEOUT}s"
    echo "  请检查网络连接后重试"
    exit 9
fi

LOCAL_TARGET=$(git rev-parse "$TARGET_BRANCH" 2>/dev/null || echo "")
REMOTE_TARGET=$(git rev-parse "origin/$TARGET_BRANCH" 2>/dev/null || echo "")

if [[ -n "$REMOTE_TARGET" && "$LOCAL_TARGET" != "$REMOTE_TARGET" ]]; then
    echo "WARNING: 本地 '$TARGET_BRANCH' 与远程不同步"
    echo "  运行: git pull origin $TARGET_BRANCH"
    exit 6
fi
echo "[PASS] 目标分支已同步"

# 检查 3: 合并冲突预检
echo ""
echo "=== 冲突预检 ==="
MERGE_TEST_OUTPUT=""
if MERGE_TEST_OUTPUT=$(git merge --no-commit --no-ff "$TARGET_BRANCH" 2>&1); then
    echo "[PASS] 无合并冲突"
    git merge --abort 2>/dev/null || true
else
    echo "ERROR: 检测到合并冲突，请先解决冲突"
    echo ""
    echo "冲突文件:"
    echo "$MERGE_TEST_OUTPUT" | grep -i "CONFLICT" | head -10 || true
    echo ""
    echo "  运行: git merge $TARGET_BRANCH  # 手动解决冲突"
    git merge --abort 2>/dev/null || true
    exit 7
fi

# 检查 4: CI 状态（通过 gh CLI，带超时）
echo ""
echo "=== CI 状态检查 ==="
if command -v gh >/dev/null 2>&1; then
    CI_STATUS=$(gh_with_timeout run list --branch="$CURRENT_BRANCH" --limit=1 --json status,conclusion 2>/dev/null || echo "[]")
    if [[ "$CI_STATUS" == "[]" ]]; then
        echo "[SKIP] 未找到 CI 记录（gh CLI 可能未配置或无 CI 工作流）"
    else
        STATUS=$(echo "$CI_STATUS" | jq -r '.[0].status // "unknown"' 2>/dev/null || echo "unknown")
        CONCLUSION=$(echo "$CI_STATUS" | jq -r '.[0].conclusion // "unknown"' 2>/dev/null || echo "unknown")

        if [[ "$STATUS" == "completed" && "$CONCLUSION" == "success" ]]; then
            echo "[PASS] CI 检查通过"
        elif [[ "$STATUS" == "in_progress" || "$STATUS" == "queued" ]]; then
            echo "WARNING: CI 仍在运行中（status=$STATUS），请等待完成后再合并"
            echo "  查看 CI 状态: gh run list --branch=$CURRENT_BRANCH"
            exit 8
        else
            echo "WARNING: CI 状态异常 (status=$STATUS, conclusion=$CONCLUSION)"
            echo "  请检查 CI 日志后再决定是否合并"
            echo "  查看 CI 日志: gh run list --branch=$CURRENT_BRANCH"
            exit 8
        fi
    fi
else
    echo "[SKIP] gh CLI 不可用，跳过 CI 状态检查"
fi

echo ""
echo "=== 检查通过，可以安全合并 ==="
echo "执行合并命令："
echo "  git checkout $TARGET_BRANCH && git merge $CURRENT_BRANCH"
exit 0
