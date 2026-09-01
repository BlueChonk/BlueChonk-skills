---
name: "github-ops"
description: "GitHub operations using gh CLI. Covers repo management, Issues, Pull Requests, Actions, Releases, and authentication. Invoke when the user needs to interact with GitHub. 触发示例：创建仓库、提交 PR、查看 CI 状态、创建 release、批量处理 issue、查看 workflow 日志、fork 同步、管理 branch protection 等所有基于 GitHub 的操作。"
---

# GitHub 操作指南（gh CLI）

> 尽量全部使用 `gh` 命令，而非手动操作网页或调用原始 API。
> `gh` 无法满足时，用 `gh api` 调用 REST API，**不要手动构造 curl 请求**。

---

## 一、能力边界

### 支持的功能

| 类别 | 覆盖范围 |
|------|---------|
| 认证 | `gh auth` 管理多账户、token 切换、SSH/HTTPS 配置 |
| 仓库 | 创建、克隆、fork、archive、查看、设置可见性 |
| Issues | 创建、列出、查看、关闭、重新打开、标签/指派管理 |
| Pull Requests | 创建、查看、diff、review、合并（merge/squash/rebase）、草稿 PR |
| Actions | 查看运行日志、重新运行、取消运行、列出 workflow |
| Releases | 创建、上传资源、自动生成 release notes、删除 |
| API | `gh api` 调用任意 GitHub REST/GraphQL 端点 |
| Gist | 创建、列出、查看、编辑、删除 |
| SSH Key | 添加、列出、删除 SSH 密钥 |

### 不支持 / 受限场景

| 场景 | 说明 | 替代方案 |
|------|------|---------|
| GitHub Enterprise 特殊配置 | 部分 GHE 实例有自定义 API 路径 | 使用 `gh auth login --hostname` 指定主机名 |
| 仓库删除 | `gh` 不支持删除仓库 | 通过浏览器或 `gh api -X DELETE repos/owner/repo` |
| Branch Protection 管理 | `gh` 支持有限 | 使用 `gh api` 调用 protection API |
| 组织级设置 | 大部分组织设置不在 `gh` 范围内 | 浏览器操作或 `gh api` |
| 大型文件上传（>2GB） | `gh release upload` 有大小限制 | 分片上传或使用 Git LFS |

### 输入输出约束

- `gh` 命令输出默认 JSON 格式可通过 `--jq` 过滤，或通过 `--template` 指定 Go 模板
- `gh api` 返回 JSON，可用 `jq` 处理
- 所有命令支持 `--help` 查看完整参数
- 分页：`gh` 默认返回 30 条，可用 `--limit` 调整（最大 100）

---

## 二、前置检查

### 2.1 认证状态检查

```bash
# 检查登录状态（每次操作前必做）
gh auth status

# 预期输出：
# github.com
#   ✓ Logged into github.com as BlueChonk (oauth_token)
#   ✓ Git operations for github.com configured to use https protocol.
#   ✓ Token: gho_************************************
```

### 2.2 认证失败处理

```bash
# 未登录时
gh auth login

# 选择交互流程：
# ? What account do you want to log into? GitHub.com
# ? What is your preferred protocol for Git operations? HTTPS
# ? Authenticate Git with your GitHub credentials? Yes
# ? How would you like to authenticate? Login with a web browser

# 多账户切换
gh auth switch

# 查看所有已登录账户
gh auth list

# 登出
gh auth logout --hostname github.com
```

### 2.3 网络连通性检查

```bash
# 测试 GitHub API 连通性
gh api zen
# 预期输出：随机一句禅语（如 "Keep it logically awesome."）

# 测试仓库访问权限
gh repo view owner/repo --json name,description
```

### 2.4 国内网络问题

```bash
# 方案一：设置 HTTP 代理
export HTTPS_PROXY=http://127.0.0.1:7890
export HTTP_PROXY=http://127.0.0.1:7890

# 方案二：使用 ghproxy 加速 release 下载
# 将 https://github.com 替换为 https://ghproxy.com/https://github.com
# 仅适用于下载场景，不适用于 gh CLI 操作

# 方案三：配置 git 代理
git config --global http.proxy http://127.0.0.1:7890
git config --global https.proxy http://127.0.0.1:7890

# 方案四：取消代理
git config --global --unset http.proxy
git config --global --unset https.proxy
```

---

## 三、命令速查

### 认证

| 场景 | 命令 |
|------|------|
| 查看登录状态 | `gh auth status` |
| 登录 | `gh auth login` |
| 多账户切换 | `gh auth switch` |
| 列出所有账户 | `gh auth list` |
| 刷新 token | `gh auth refresh` |
| 登出 | `gh auth logout` |
| 查看 token 权限 | `gh auth status -t` |

### 仓库

| 场景 | 命令 |
|------|------|
| 查看仓库 | `gh repo view <owner/repo>` |
| 查看仓库（JSON） | `gh repo view <owner/repo> --json name,description,stargazerCount` |
| 列出仓库 | `gh repo list` |
| 列出仓库（限定数量） | `gh repo list --limit 50` |
| 创建仓库 | `gh repo create <name> --public --clone` |
| 创建私有仓库 | `gh repo create <name> --private --clone` |
| 创建并指定描述 | `gh repo create <name> --description "xxx" --public` |
| Fork 仓库 | `gh repo fork <owner/repo>` |
| Fork 并克隆 | `gh repo fork <owner/repo> --clone` |
| 克隆仓库 | `gh repo clone <owner/repo>` |
| 设置默认仓库 | `gh repo set-default <owner/repo>` |

**输出样例**：
```
$ gh repo view BlueChonk/awesome-project
name:	BlueChonk/awesome-project
description:	一个很棒的项目
--
Stars:    42
Forks:    5
Issues:   3
```

### Issues

| 场景 | 命令 |
|------|------|
| 列出（开放） | `gh issue list --state open` |
| 列出（已关闭） | `gh issue list --state closed` |
| 按标签筛选 | `gh issue list --label "bug"` |
| 按指派筛选 | `gh issue list --assignee @me` |
| 按作者筛选 | `gh issue list --author @me` |
| 搜索 | `gh issue list --search "crash in:title"` |
| 查看 | `gh issue view <number>` |
| 查看（JSON） | `gh issue view <number> --json title,body,labels,assignees` |
| 创建 | `gh issue create --title "xxx" --label "bug" --body "..."` |
| 创建（指定指派） | `gh issue create --title "xxx" --assignee @me` |
| 创建（指定里程碑） | `gh issue create --title "xxx" --milestone "v1.0"` |
| 关闭 | `gh issue close <number>` |
| 关闭并评论 | `gh issue close <number> --comment "已修复"` |
| 重新打开 | `gh issue reopen <number>` |
| 添加标签 | `gh issue edit <number> --add-label "bug"` |
| 移除标签 | `gh issue edit <number> --remove-label "bug"` |
| 编辑标题 | `gh issue edit <number> --title "新标题"` |

**输出样例**：
```
$ gh issue list --state open --label "bug"
#123	bug: 登录页面崩溃		opened 2 hours ago
#124	bug: 数据不同步		opened 5 hours ago
```

### Pull Requests

| 场景 | 命令 |
|------|------|
| 列出（开放） | `gh pr list` |
| 列出（已合并） | `gh pr list --state merged` |
| 列出（已关闭） | `gh pr list --state closed` |
| 按分支筛选 | `gh pr list --head feature-branch` |
| 按标签筛选 | `gh pr list --label "enhancement"` |
| 查看 | `gh pr view <number>` |
| 查看（JSON） | `gh pr view <number> --json title,body,state,mergeable` |
| 查看差异 | `gh pr diff <number>` |
| 查看文件列表 | `gh pr diff <number> --name-only` |
| 检查状态 | `gh pr checks <number>` |
| 创建 | `gh pr create --title "feat: xxx" --body "..."` |
| 创建（指定分支） | `gh pr create --base main --head feature --title "feat: xxx"` |
| 创建草稿 | `gh pr create --draft --title "WIP: xxx"` |
| 创建并指定 reviewer | `gh pr create --reviewer user1,user2` |
| 标记为可合并 | `gh pr ready <number>` |
| 合并（merge） | `gh pr merge <number> --merge` |
| 合并（squash） | `gh pr merge <number> --squash` |
| 合并（rebase） | `gh pr merge <number> --rebase` |
| 合并并删除分支 | `gh pr merge <number> --merge --delete-branch` |
| 合并（自动） | `gh pr merge <number> --auto --squash` |
| Approve | `gh pr review <number> --approve` |
| Request Changes | `gh pr review <number> --request-changes --body "需要修改"` |
| 评论 | `gh pr review <number> --comment --body "LGTM"` |
| 查看评论 | `gh pr review <number> --json body,author,state` |

**输出样例**：
```
$ gh pr view 42
feat: 添加用户登录功能
Open • BlueChonk wants to merge 3 commits into main from feature/login

## 变更内容
- 添加登录表单
- 添加 JWT 验证
- 添加单元测试

Reviewers: @reviewer1 (Approved)
Checks: 5 success, 0 failed
```

### Actions

| 场景 | 命令 |
|------|------|
| 列出运行 | `gh run list` |
| 列出指定 workflow | `gh run list --workflow=ci.yml` |
| 列出指定分支 | `gh run list --branch main` |
| 列出指定状态 | `gh run list --status failure` |
| 查看运行 | `gh run view <id>` |
| 查看失败日志 | `gh run view <id> --log-failed` |
| 查看指定 job | `gh run view <id> --job=<job_id>` |
| 查看 workflow 文件 | `gh run view <id> --json workflowName` |
| 重新运行 | `gh run rerun <id>` |
| 重新运行（仅失败 job） | `gh run rerun <id> --failed` |
| 取消运行 | `gh run cancel <id>` |
| 列出 workflow | `gh workflow list` |
| 启用 workflow | `gh workflow enable <workflow_id>` |
| 禁用 workflow | `gh workflow disable <workflow_id>` |
| 手动触发 | `gh workflow run <workflow.yml> --ref main` |
| 手动触发（带参数） | `gh workflow run deploy.yml -f env=production` |

**输出样例**：
```
$ gh run list --workflow=ci.yml
STATUS  TITLE           WORKFLOW  BRANCH  ID      ELAPSED
✓       fix: bug修复    ci.yml    main    12345   2m30s
✗       feat: 新功能    ci.yml    feature 12344   1m45s
```

### Releases

| 场景 | 命令 |
|------|------|
| 列出 | `gh release list` |
| 列出（含草稿） | `gh release list --exclude-drafts=false` |
| 查看 | `gh release view v1.0.0` |
| 查看（JSON） | `gh release view v1.0.0 --json name,tagName,body` |
| 创建 | `gh release create v1.0.0 --title "v1.0.0" --notes "..."` |
| 自动生成说明 | `gh release create v1.0.0 --generate-notes` |
| 创建草稿 | `gh release create v1.0.0 --draft` |
| 创建预发布 | `gh release create v1.0.0 --prerelease` |
| 上传资源 | `gh release upload v1.0.0 ./build/*` |
| 删除 | `gh release delete v1.0.0` |
| 删除（同时删除 tag） | `gh release delete v1.0.0 --cleanup-tag` |
| 下载资源 | `gh release download v1.0.0` |
| 下载指定文件 | `gh release download v1.0.0 --pattern "*.zip"` |

**输出样例**：
```
$ gh release list
TITLE    TYPE    TAG NAME  PUBLISHED
v1.0.0   Latest  v1.0.0    about 1 day ago
v0.9.0           v0.9.0    about 1 month ago
```

### Gist

| 场景 | 命令 |
|------|------|
| 创建 | `gh gist create ./file.txt --desc "描述"` |
| 创建（公开） | `gh gist create ./file.txt --public` |
| 列出 | `gh gist list` |
| 查看 | `gh gist view <id>` |
| 编辑 | `gh gist edit <id> --add-file new.txt` |
| 删除 | `gh gist delete <id>` |

---

## 四、组合工作流

### 4.1 一键初始化仓库并推送

```bash
#!/bin/bash
# 一键创建远程仓库、初始化本地、推送、创建 PR
# 用法: ./init-repo.sh <repo_name> <visibility:public|private>

set -euo pipefail

REPO_NAME="${1:?用法: $0 <repo_name> <visibility>}"
VISIBILITY="${2:-public}"
GITHUB_USER=$(gh api user --jq '.login')

echo "==> 创建远程仓库 ${GITHUB_USER}/${REPO_NAME}..."
gh repo create "${REPO_NAME}" --${VISIBILITY} --clone

cd "${REPO_NAME}"

echo "==> 初始化本地仓库..."
echo "# ${REPO_NAME}" > README.md
cat > .gitignore << 'EOF'
node_modules/
dist/
.env
*.log
EOF

git add .
git commit -m "chore: 初始化仓库"

echo "==> 推送到远程..."
git push -u origin main

echo "==> 完成！仓库地址: https://github.com/${GITHUB_USER}/${REPO_NAME}"
```

### 4.2 完整 PR 工作流

```bash
#!/bin/bash
# 从创建分支到合并 PR 的完整流程
# 用法: ./pr-flow.sh <branch_name> <pr_title>

set -euo pipefail

BRANCH="${1:?用法: $0 <branch_name> <pr_title>}"
TITLE="${2:?用法: $0 <branch_name> <pr_title>}"

# 确保在 main 分支且工作区干净
git checkout main
git pull origin main

# 创建功能分支
git checkout -b "${BRANCH}"

# 开发完成后...
# git add . && git commit -m "feat: xxx"

# 推送分支
git push -u origin "${BRANCH}"

# 创建 PR
gh pr create \
  --title "${TITLE}" \
  --body "## 变更说明\n- \n\n## 测试\n- [ ] 已测试" \
  --base main \
  --head "${BRANCH}"

echo "==> PR 已创建，等待 review..."
```

### 4.3 自动化 Release 流程

```bash
#!/bin/bash
# 自动化 release：打 tag、生成 notes、创建 release
# 用法: ./release.sh <version> [prerelease]

set -euo pipefail

VERSION="${1:?用法: $0 <version> [prerelease]}"
PRERELEASE="${2:-}"

# 确保在 main 分支
git checkout main
git pull origin main

# 参数校验
if [[ ! "${VERSION}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+ ]]; then
  echo "错误: 版本号格式应为 vX.Y.Z"
  exit 1
fi

# 检查 tag 是否已存在
if git rev-parse "${VERSION}" >/dev/null 2>&1; then
  echo "错误: tag ${VERSION} 已存在"
  exit 1
fi

echo "==> 创建 tag ${VERSION}..."
git tag -a "${VERSION}" -m "Release ${VERSION}"

echo "==> 推送 tag..."
git push origin "${VERSION}"

echo "==> 创建 GitHub Release..."
if [ "${PRERELEASE}" = "--prerelease" ]; then
  gh release create "${VERSION}" \
    --title "${VERSION}" \
    --generate-notes \
    --prerelease
else
  gh release create "${VERSION}" \
    --title "${VERSION}" \
    --generate-notes
fi

echo "==> Release ${VERSION} 已发布！"
```

### 4.4 Issue 批量处理

```bash
#!/bin/bash
# 批量关闭已解决的 issue（带评论）
# 用法: ./close-issues.sh <label>

set -euo pipefail

LABEL="${1:?用法: $0 <label>}"

echo "==> 获取标签为 '${LABEL}' 的开放 issue..."
ISSUES=$(gh issue list --state open --label "${LABEL}" --json number --jq '.[].number')

if [ -z "${ISSUES}" ]; then
  echo "没有找到匹配的 issue"
  exit 0
fi

for issue in ${ISSUES}; do
  echo "==> 关闭 issue #${issue}..."
  gh issue close "${issue}" --comment "已自动关闭，标签: ${LABEL}"
done

echo "==> 共关闭 $(echo "${ISSUES}" | wc -w) 个 issue"
```

### 4.5 Fork 同步

```bash
#!/bin/bash
# 同步 fork 仓库的上游变更
# 用法: ./sync-fork.sh [upstream_remote]

set -euo pipefail

UPSTREAM="${1:-upstream}"

# 添加上游远程（如果不存在）
if ! git remote | grep -q "^${UPSTREAM}$"; then
  echo "==> 添加上游远程..."
  # 需要手动指定上游仓库地址
  echo "请运行: git remote add ${UPSTREAM} <上游仓库URL>"
  exit 1
fi

echo "==> 获取上游变更..."
git fetch "${UPSTREAM}"

echo "==> 合并到本地 main..."
git checkout main
git merge "${UPSTREAM}/main"

echo "==> 推送到 fork..."
git push origin main

echo "==> Fork 同步完成！"
```

---

## 五、GitHub Actions 工作流示例

### 5.1 CI 工作流（`.github/workflows/ci.yml`）

```yaml
name: CI

on:
  push:
    branches: [main, dev]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        node-version: [18, 20]
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: ${{ matrix.node-version }}
          cache: 'npm'
      - run: npm ci
      - run: npm test
      - run: npm run build

  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: 'npm'
      - run: npm ci
      - run: npm run lint
```

### 5.2 自动发布工作流（`.github/workflows/release.yml`）

```yaml
name: Release

on:
  push:
    tags:
      - 'v*'

jobs:
  release:
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: 'npm'
      - run: npm ci
      - run: npm run build
      - name: Create Release
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          gh release create ${{ github.ref_name }} \
            --title "${{ github.ref_name }}" \
            --generate-notes \
            ./dist/*
```

### 5.3 自动关闭过期 Issue（`.github/workflows/stale.yml`）

```yaml
name: Close Stale Issues

on:
  schedule:
    - cron: '0 0 * * *'  # 每天 UTC 0:00 运行

jobs:
  stale:
    runs-on: ubuntu-latest
    permissions:
      issues: write
    steps:
      - uses: actions/stale@v9
        with:
          stale-issue-message: '此 issue 因 30 天无活动将被关闭'
          days-before-stale: 30
          days-before-close: 7
```

---

## 六、Issue/PR 模板

### 6.1 创建 Issue 模板

```bash
# 创建模板目录
mkdir -p .github/ISSUE_TEMPLATE

# Bug 报告模板
cat > .github/ISSUE_TEMPLATE/bug_report.md << 'EOF'
---
name: Bug 报告
about: 报告一个问题
title: 'bug: '
labels: bug
assignees: ''
---

**描述问题**
清晰描述 bug 的表现

**复现步骤**
1. 步骤一
2. 步骤二
3. ...

**期望行为**
描述应该发生什么

**环境信息**
- OS: [e.g. Windows 11]
- 版本: [e.g. v1.0.0]

**补充信息**
其他相关信息
EOF

# 功能请求模板
cat > .github/ISSUE_TEMPLATE/feature_request.md << 'EOF'
---
name: 功能请求
about: 提出新功能建议
title: 'feat: '
labels: enhancement
assignees: ''
---

**功能描述**
清晰描述你想要的功能

**使用场景**
描述这个功能会用在什么场景

**替代方案**
描述你目前使用的替代方案
EOF
```

### 6.2 创建 PR 模板

```bash
mkdir -p .github

cat > .github/pull_request_template.md << 'EOF'
## 变更类型

- [ ] Bug 修复
- [ ] 新功能
- [ ] 破坏性变更
- [ ] 文档更新

## 变更说明
<!-- 描述你做了什么 -->

## 测试方式
<!-- 如何验证这些变更 -->

## 检查清单

- [ ] 代码已通过 lint
- [ ] 已添加必要的测试
- [ ] 测试全部通过
- [ ] 已更新相关文档
EOF
```

---

## 七、API 速率限制与重试

### 7.1 速率限制说明

GitHub API 速率限制：
- 认证用户：5000 次/小时
- 未认证：60 次/小时
- `gh` CLI 自动处理大部分限流，但批量操作时仍需注意

### 7.2 查看剩余配额

```bash
# 查看当前速率限制
gh api rate_limit --jq '.resources.core'

# 输出样例：
# {
#   "limit": 5000,
#   "remaining": 4980,
#   "reset": 1700000000,
#   "used": 20
# }

# 查看 GraphQL 配额
gh api rate_limit --jq '.resources.graphql'
```

### 7.3 API 缓存

```bash
# 使用缓存（默认 1 小时）
gh api --cache 1h repos/owner/repo/issues

# 自定义缓存时间
gh api --cache 30m repos/owner/repo/commits

# 强制刷新缓存
gh api --method GET repos/owner/repo/issues -H "If-None-Match:"
```

### 7.4 重试逻辑

```bash
# gh 内置重试：网络错误自动重试 3 次
# 自定义重试脚本：

#!/bin/bash
# 带重试的 gh api 调用
# 用法: ./retry-api.sh <api_path> [max_retries]

API_PATH="${1:?用法: $0 <api_path>}"
MAX_RETRIES="${2:-3}"
RETRY_DELAY=5

for i in $(seq 1 "${MAX_RETRIES}"); do
  echo "==> 尝试 ${i}/${MAX_RETRIES}..."
  if gh api "${API_PATH}" 2>/dev/null; then
    echo "==> 成功！"
    exit 0
  fi
  echo "==> 失败，${RETRY_DELAY}秒后重试..."
  sleep "${RETRY_DELAY}"
done

echo "==> 达到最大重试次数，操作失败"
exit 1
```

### 7.5 jq 错误处理

```bash
# 安全的 jq 解析（字段不存在时返回 null 而非报错）
gh api repos/owner/repo --jq '.description // "无描述"'

# 检查字段是否存在
gh api repos/owner/repo --jq 'has("description")'

# 批量操作时过滤空值
gh repo list --limit 100 --json name,description \
  | jq -r '.[] | select(.description != null) | .name'
```

---

## 八、错误处理

### 8.1 常见错误与解决方案

| 错误信息 | 原因 | 解决方案 |
|---------|------|---------|
| `gh: command not found` | gh 未安装 | `winget install GitHub.cli` 或 `choco install gh` |
| `HTTP 401: Bad credentials` | token 过期或无效 | `gh auth login` 重新登录 |
| `HTTP 403: Forbidden` | 权限不足 | 检查 token 权限范围，或联系仓库管理员 |
| `HTTP 404: Not Found` | 仓库/资源不存在 | 检查仓库名拼写，确认有访问权限 |
| `HTTP 422: Validation Failed` | 参数校验失败 | 检查参数格式，如 issue 标题不能为空 |
| `Could not resolve host` | 网络问题 | 检查网络连接，配置代理 |
| `connection refused` | 代理或防火墙问题 | 检查代理设置，关闭 VPN 测试 |
| `merge conflicts` | PR 有合并冲突 | 本地解决冲突后重新推送 |
| `Resource not accessible by personal access token` | PAT 权限不足 | 重新生成 token 并勾选所需权限 |
| `To https://github.com/...` `! [rejected]` | 推送被拒绝 | 先 `git pull --rebase` 再推送 |

### 8.2 排查步骤

```bash
# 1. 检查认证状态
gh auth status

# 2. 检查网络连通性
ping github.com
gh api zen

# 3. 检查仓库访问权限
gh repo view owner/repo

# 4. 检查 token 权限范围
gh auth status -t

# 5. 查看详细错误信息（加 --verbose）
gh pr list --verbose

# 6. 检查 git 远程配置
git remote -v

# 7. 检查 git 凭证
git config --global credential.helper
```

### 8.3 Token 权限对照表

| 操作 | 所需权限 |
|------|---------|
| 读取公开仓库 | 无需认证 |
| 读取私有仓库 | `repo` 或 `public_repo` |
| 创建/修改仓库 | `repo` |
| 创建 Issue/PR | `repo` |
| 管理标签/里程碑 | `repo` |
| 创建 Release | `repo` (contents:write) |
| 触发 Actions | `repo` (actions:write) |
| 管理 Gist | `gist` |
| 管理 SSH Key | `admin:public_key` |
| 读取用户信息 | `read:user` |

---

## 九、反模式与 FAQ

### 9.1 反模式（Anti-Patterns）

| 反模式 | 问题 | 正确做法 |
|--------|------|---------|
| 在脚本中硬编码 token | 泄露风险，难以轮换 | 使用 `gh auth` 管理凭证 |
| 忽略 rate limit | 触发限流导致操作失败 | 检查剩余配额，批量操作加延迟 |
| 直接用 curl 调用 API | 需要手动处理认证和分页 | 使用 `gh api` |
| 不检查命令返回值 | 静默失败难以排查 | 脚本中加 `set -euo pipefail` |
| 强制推送到 main | 可能覆盖他人代码 | 使用 `--force-with-lease` |
| 不写 PR 描述 | Review 效率低 | 使用模板填写变更说明 |
| 长期存在的分支 | 合并冲突风险高 | 及时合并或关闭 |
| 不设置 .gitignore | 提交无用文件 | 初始化时添加 .gitignore |
| 在 commit 中提交敏感信息 | 泄露密钥/密码 | 使用环境变量和 .env 文件 |
| 不处理合并冲突就合并 | 代码丢失 | 本地解决冲突后再合并 |

### 9.2 FAQ

**Q: 如何切换 GitHub 账户？**
```bash
# 查看所有已登录账户
gh auth list

# 切换当前活跃账户
gh auth switch

# 为不同项目使用不同账户（按仓库配置）
cd /path/to/repo
gh auth login --hostname github.com
```

**Q: 如何调试 gh api 调用？**
```bash
# 查看实际请求（verbose 模式）
gh api repos/owner/repo -v

# 查看请求头
gh api repos/owner/repo -i

# 使用 --jq 过滤输出
gh api repos/owner/repo/issues --jq '.[].title'

# 使用 --paginate 获取全部结果
gh api repos/owner/repo/issues --paginate
```

**Q: 如何查看剩余 API 配额？**
```bash
gh api rate_limit --jq '.resources.core'
# 输出: {"limit": 5000, "remaining": 4980, "reset": 1700000000}
```

**Q: 如何批量操作多个仓库？**
```bash
# 列出所有仓库并逐个操作
gh repo list --limit 100 --json nameWithOwner --jq '.[].nameWithOwner' \
  | while read repo; do
    echo "处理: ${repo}"
    gh repo view "${repo}" --json stargazerCount
  done
```

**Q: 如何设置默认仓库？**
```bash
# 设置当前目录的默认仓库
gh repo set-default owner/repo

# 之后命令可以省略仓库名
gh issue list  # 自动使用默认仓库
```

**Q: 如何查看 gh 版本和更新？**
```bash
# 查看版本
gh --version

# 更新 gh
gh extension list  # 查看已安装扩展
winget upgrade GitHub.cli  # Windows
brew upgrade gh    # macOS
```

**Q: 如何处理 GraphQL 查询？**
```bash
# 使用 gh api 调用 GraphQL
gh api graphql -f query='
{
  viewer {
    login
    repositories(first: 5) {
      nodes {
        name
      }
    }
  }
}'
```

**Q: 如何创建和管理 gh 扩展？**
```bash
# 安装扩展
gh extension install owner/gh-extension-name

# 列出已安装扩展
gh extension list

# 升级扩展
gh extension upgrade --all
```

---

## 十、最佳实践

### 10.1 命令优先原则

| 场景 | 推荐 | 不推荐 |
|------|------|--------|
| 创建 PR | `gh pr create` | 浏览器手动操作 |
| 查看 CI 状态 | `gh run list` | 打开 GitHub 页面 |
| 创建 Issue | `gh issue create` | 网页表单 |
| 调用 API | `gh api` | `curl -H "Authorization: token ..."` |
| 管理 Release | `gh release create` | 网页上传 |

### 10.2 脚本编写规范

```bash
#!/bin/bash
# 标准脚本头
set -euo pipefail  # 遇错即停、未定义变量报错、管道错误传播

# 参数校验
REPO="${1:?错误: 请指定仓库名}"

# 前置检查
if ! gh auth status >/dev/null 2>&1; then
  echo "错误: gh 未登录，请先运行 gh auth login"
  exit 1
fi

# 操作前确认
echo "将在 ${REPO} 上执行操作，确认？(y/N)"
read -r confirm
if [ "${confirm}" != "y" ]; then
  echo "已取消"
  exit 0
fi

# 执行操作...
```

### 10.3 安全规范

- **永远不要**在脚本、日志、commit 中硬编码 token
- **永远不要**将 `.env` 文件提交到仓库
- **永远不要**使用他人的 token
- **始终使用** `gh auth` 管理凭证
- **始终使用** 最小权限原则配置 token
- **定期轮换** 长期使用的 token

---

## 注意事项

- 需要 token 的操作优先通过 `gh auth` 管理凭证，不硬编码
- 所有 `gh` 命令支持 `--help`，不确定参数时先查询
- 批量操作前先用 `--limit 1` 测试
- 破坏性操作（删除、强制推送）前必须确认
- 国内网络不稳定时优先配置代理而非使用第三方镜像
