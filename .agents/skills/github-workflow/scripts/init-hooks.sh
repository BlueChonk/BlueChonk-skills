#!/bin/bash
# init-hooks.sh - 一键安装 Git hooks
# 使用方式: bash scripts/init-hooks.sh
# 退出码:
#   0 = 安装成功
#   1 = 未找到 Git 仓库
#   2 = hooks 目录不可写
#   3 = 脚本文件不存在或复制失败
#
# 自动将 3 个验证脚本安装到 .git/hooks/ 目录:
#   pre-push         → validate-branch-name.sh (分支命名规范检查)
#   commit-msg       → validate-commit-msg.sh (commit message 格式校验)
#   pre-merge-commit → safe-merge.sh (安全合并检查)

set -euo pipefail

# 超时时间（秒）
TIMEOUT=10
# 重试次数
MAX_RETRIES=3
RETRY_DELAY=1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 检查是否在 git 仓库中（带重试）
GIT_ROOT=""
for attempt in $(seq 1 $MAX_RETRIES); do
    GIT_ROOT=$(timeout "$TIMEOUT" git rev-parse --show-toplevel 2>/dev/null) && break
    if [[ $attempt -lt $MAX_RETRIES ]]; then
        sleep "$RETRY_DELAY"
    fi
done

if [[ -z "$GIT_ROOT" ]]; then
    echo "ERROR: 未找到 Git 仓库，请在 Git 仓库根目录执行"
    exit 1
fi

HOOKS_DIR="$GIT_ROOT/.git/hooks"

# 检查 hooks 目录是否可写
if [[ ! -d "$HOOKS_DIR" ]]; then
    mkdir -p "$HOOKS_DIR" 2>/dev/null || {
        echo "ERROR: 无法创建 hooks 目录: $HOOKS_DIR"
        exit 2
    }
fi

if [[ ! -w "$HOOKS_DIR" ]]; then
    echo "ERROR: hooks 目录不可写: $HOOKS_DIR"
    echo "  请检查目录权限"
    exit 2
fi

echo "=== Git Hooks 一键安装 ==="
echo "仓库路径: $GIT_ROOT"
echo "Hooks 目录: $HOOKS_DIR"
echo ""

# 验证脚本文件存在
for script in validate-branch-name.sh validate-commit-msg.sh; do
    if [[ ! -f "$SCRIPT_DIR/$script" ]]; then
        echo "ERROR: 脚本文件不存在: $SCRIPT_DIR/$script"
        exit 3
    fi
done

# 创建 pre-push hook（带重试写入）
INSTALL_OK=false
for attempt in $(seq 1 $MAX_RETRIES); do
    cat > "$HOOKS_DIR/pre-push" << 'HOOK'
#!/bin/bash
# pre-push hook - 分支命名规范检查
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../scripts" && pwd)"
bash "$SCRIPT_DIR/validate-branch-name.sh"
HOOK
    chmod +x "$HOOKS_DIR/pre-push" 2>/dev/null && {
        INSTALL_OK=true
        break
    }
    if [[ $attempt -lt $MAX_RETRIES ]]; then
        sleep "$RETRY_DELAY"
    fi
done

if [[ "$INSTALL_OK" == "false" ]]; then
    echo "ERROR: 无法写入 pre-push hook（已重试 $MAX_RETRIES 次）"
    exit 3
fi
echo "[OK] pre-push hook 已安装（分支命名规范检查）"

# 创建 commit-msg hook
INSTALL_OK=false
for attempt in $(seq 1 $MAX_RETRIES); do
    cat > "$HOOKS_DIR/commit-msg" << 'HOOK'
#!/bin/bash
# commit-msg hook - commit message 格式校验
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../scripts" && pwd)"
bash "$SCRIPT_DIR/validate-commit-msg.sh" "$1"
HOOK
    chmod +x "$HOOKS_DIR/commit-msg" 2>/dev/null && {
        INSTALL_OK=true
        break
    }
    if [[ $attempt -lt $MAX_RETRIES ]]; then
        sleep "$RETRY_DELAY"
    fi
done

if [[ "$INSTALL_OK" == "false" ]]; then
    echo "ERROR: 无法写入 commit-msg hook（已重试 $MAX_RETRIES 次）"
    exit 3
fi
echo "[OK] commit-msg hook 已安装（commit message 格式校验）"

# 创建 pre-merge-commit hook
INSTALL_OK=false
for attempt in $(seq 1 $MAX_RETRIES); do
    cat > "$HOOKS_DIR/pre-merge-commit" << 'HOOK'
#!/bin/bash
# pre-merge-commit hook - 安全合并检查（检查未解决冲突）
if git diff --name-only --diff-filter=U | grep -q .; then
    echo "ERROR: 存在未解决的合并冲突，请先解决冲突"
    exit 1
fi
echo "PASS: 合并冲突检查通过"
HOOK
    chmod +x "$HOOKS_DIR/pre-merge-commit" 2>/dev/null && {
        INSTALL_OK=true
        break
    }
    if [[ $attempt -lt $MAX_RETRIES ]]; then
        sleep "$RETRY_DELAY"
    fi
done

if [[ "$INSTALL_OK" == "false" ]]; then
    echo "ERROR: 无法写入 pre-merge-commit hook（已重试 $MAX_RETRIES 次）"
    exit 3
fi
echo "[OK] pre-merge-commit hook 已安装（安全合并检查）"

echo ""
echo "=== 安装完成 ==="
echo "已安装 3 个 Git hooks："
echo "  pre-push         → 分支命名规范检查"
echo "  commit-msg       → commit message 格式校验"
echo "  pre-merge-commit → 安全合并检查"
echo ""
echo "如需卸载，删除 .git/hooks/ 下对应文件即可"
echo ""
echo "单独运行验证脚本："
echo "  bash $SCRIPT_DIR/validate-branch-name.sh"
echo "  bash $SCRIPT_DIR/validate-commit-msg.sh .git/COMMIT_EDITMSG"
echo "  bash $SCRIPT_DIR/safe-merge.sh main"
exit 0
