---
name: "github-workflow"
description: "GitHub branch management and workflow conventions. Covers main, dev, feat, release, hotfix branches with naming rules, merge strategies, fork collaboration, branch protection, CODEOWNERS, error recovery, and automation scripts. Invoke when creating or managing branches on GitHub. 触发示例：(1) '帮我创建 release 分支'；(2) 'merge conflict 怎么解决'；(3) '如何撤销已推送的 commit'；(4) '帮我配置分支保护规则'；(5) '如何同步 fork 仓库'；(6) '分支命名规范检查'；(7) 'commit message 格式校验'；(8) '设置 husky commitlint'；(9) '多环境分支策略'；(10) '自动生成 changelog'；(11) '一键安装 git hooks'；(12) '帮我配置分支校验'。"
---

# GitHub 分支管理规范

## 目录

- [快速入门（5 分钟上手）](#快速入门5-分钟上手)
- [常见问题快速定位](#常见问题快速定位)
- [Git 工作流决策树](#git-工作流决策树)
- [一、分支体系](#一分支体系)
- [二、关键命令](#二关键命令)
- [三、分支命名规范](#三分支命名规范)
- [四、Commit 规范](#四commit-规范)
- [五、Pull Request 规范](#五pull-request-规范)
- [六、完整操作流程示例](#六完整操作流程示例)
- [七、分支保护规则配置](#七分支保护规则配置)
- [八、CODEOWNERS 配置](#八codeowners-配置)
- [九、错误处理与故障排除](#九错误处理与故障排除)
- [十、反模式与 FAQ](#十反模式与-faq)
- [十一、自动化工具](#十一自动化工具)
- [十二、自动化验证脚本](#十二自动化验证脚本)
- [十三、组合工作流](#十三组合工作流)
- [十四、能力边界](#十四能力边界)
- [十五、注意事项](#十五注意事项)

---

## 快速入门（5 分钟上手）

最常见的 5 个操作，每条命令即可执行：

### 1. 创建功能分支

```bash
git checkout main && git pull && git checkout -b feat/你的功能名
```

### 2. 提交代码

```bash
git add <files>
git commit -m "feat(scope): 中文描述"
```

### 3. 推送到远程

```bash
git push origin feat/你的功能名
```

### 4. 创建 Pull Request

```bash
gh pr create --title "feat(scope): 功能描述" --body "Closes #issue编号"
```

### 5. 合并后清理

```bash
git checkout main && git pull && git push origin --delete feat/你的功能名 && git branch -d feat/你的功能名
```

---

## 常见问题快速定位

| 问题现象 | 对应章节 |
|----------|----------|
| 分支命名不确定是否规范 | [三、分支命名规范](#三分支命名规范) / [十二、自动化验证脚本](#十二自动化验证脚本) |
| commit 信息被拒绝 | [四、Commit 规范](#四commit-规范) / [11.2 Commit Message 格式校验](#112-commit-message-格式校验脚本) |
| push 被拒（non-fast-forward） | [9.2 Push 被拒处理](#92-push-被拒处理) |
| merge conflict 不知道怎么解决 | [9.1 Merge Conflict 解决](#91-merge-conflict-解决) |
| rebase 出错想放弃 | [9.3 Rebase 冲突恢复](#93-rebase-冲突恢复) |
| 误删分支想恢复 | [9.4 误删分支恢复](#94-误删分支恢复) |
| 想撤销已推送的 commit | [9.5 撤销 Commit](#95-撤销-commit) |
| 想合并多个 commit | [9.6 合并多个 Commit（Squash）](#96-合并多个-commitsquash) |
| 如何配置分支保护 | [七、分支保护规则配置](#七分支保护规则配置) |
| 如何配置 CODEOWNERS | [八、CODEOWNERS 配置](#八codeowners-配置) |
| 如何自动生成 changelog | [11.6 自动化 Changelog 生成](#116-自动化-changelog-生成-git-chglog-完整配置) |
| 如何设置 husky + commitlint | [11.4 Git Hooks 自动化方案](#114-git-hooks-自动化方案husky--commitlint-完整配置) |
| 多环境部署怎么管理分支 | [11.5 多环境分支策略](#115-多环境分支策略devstagingprod) |
| 不确定该用哪种分支策略 | [Git 工作流决策树](#git-工作流决策树) |

---

## Git 工作流决策树

根据项目规模和团队大小选择合适的分支策略：

```
你的项目规模？
│
├── 个人项目 / 小团队（1-3 人）
│   └── 推荐：GitHub Flow
│       └── 分支：main + feat/* + fix/*
│       └── 特点：简单、快速、持续交付
│
├── 中型团队（3-10 人）+ 版本化发布
│   └── 推荐：Git Flow（混合策略）
│       └── 分支：main + dev + feat/* + fix/* + release/* + hotfix/*
│       └── 特点：结构清晰、支持并行开发
│
├── 需要多环境验证（dev/staging/prod）
│   └── 推荐：多环境分支策略
│       └── 分支：prod + staging + dev + feat/* + fix/*
│       └── 特点：环境隔离、逐级验证
│
└── 大型团队 / Trunk-Based
    └── 推荐：Trunk-Based Development
    └── 分支：main（主干）+ 短期分支（<1 天生命周期）
    └── 特点：高频集成、CI/CD 驱动
```

**选择建议**：

| 维度 | GitHub Flow | Git Flow | 多环境策略 | Trunk-Based |
|------|-------------|----------|------------|-------------|
| 复杂度 | 低 | 中 | 中 | 高 |
| 发布频率 | 随时 | 版本周期 | 版本周期 | 随时 |
| 团队规模 | 1-5 人 | 3-20 人 | 5-50 人 | 10+ 人 |
| CI/CD 要求 | 基础 | 中等 | 高 | 极高 |
| 适合场景 | SaaS、Web 应用 | 桌面软件、移动端 | 企业级应用 | 大型平台 |

---

## 一、分支体系

| 分支 | 用途 | 规则 |
|------|------|------|
| `main` | 主分支，始终保持可发布 | 禁止直接推送，必须通过 PR 合并 |
| `dev`（可选） | 开发集成分支 | 功能测试通过后合并到 `main`，小型项目可省略 |
| `feat/*` | 功能开发分支 | 从 `main` 创建，开发完成后 PR 合并，合并后删除 |
| `fix/*` | Bug 修复分支 | 从 `main` 创建，修复后 PR 合并 |
| `test/*` | 临时测试分支 | 测试多个 PR 集成，用完即删 |
| `release/*` | 发布分支 | 从 `main` 创建，仅修复 bug 和版本号，发布后合并回 `main` 和 `dev` |
| `hotfix/*` | 紧急修复分支 | 从 `main` 创建，修复后同时合并回 `main` 和 `dev` |

**Fork 协作核心原则**：
- `fork/main` 只做与 `upstream/main` 同步，不放自己的代码
- 所有改动在 `feat/*` / `fix/*` 分支，每个 PR 从干净的 `main` 独立创建
- 多 PR 并行时，若某个 PR 先被合并，其他 PR 需 `rebase main`

**分支策略声明**：
- 本规范基于 **GitHub Flow**（轻量级，适合持续交付）和 **Git Flow**（带 release/hotfix，适合版本化发布）的混合策略
- 小型项目推荐仅用 `main` + `feat/*` + `fix/*`
- 中大型项目推荐完整使用 `main` + `dev` + `feat/*` + `fix/*` + `release/*` + `hotfix/*`

---

## 二、关键命令

### 同步上游（每次开发前）

```bash
git checkout main
git pull upstream main
git push origin main
```

### 创建功能分支并提 PR

```bash
git checkout main
git checkout -b feat/xxx
# ... 写代码 ...
git add <files>
git commit -m "feat(scope): 中文描述"
git push origin feat/xxx
# 然后提 PR：feat/xxx → upstream/main
```

### PR 合并后清理

```bash
git checkout main
git pull upstream main
git push origin main
git push origin --delete feat/xxx
git branch -d feat/xxx
```

### 多 PR 并行：rebase

```bash
git checkout feat/xxx
git rebase main
git push origin feat/xxx --force
```

### Release 分支管理

```bash
# 创建 release 分支
git checkout main
git checkout -b release/v1.2.0
# 仅修复 bug、更新版本号和 changelog
git commit -m "chore(release): bump version to v1.2.0"
git push origin release/v1.2.0

# 发布完成后合并回 main 和 dev
git checkout main
git merge release/v1.2.0
git tag -a v1.2.0 -m "Release v1.2.0"
git push origin main --tags

git checkout dev
git merge release/v1.2.0
git push origin dev

# 删除 release 分支
git push origin --delete release/v1.2.0
git branch -d release/v1.2.0
```

### Hotfix 分支管理

```bash
# 创建 hotfix 分支
git checkout main
git checkout -b hotfix/v1.2.1
# 修复紧急 bug
git commit -m "fix(critical): 修复生产环境崩溃问题"
git push origin hotfix/v1.2.1

# 修复完成后同时合并回 main 和 dev
git checkout main
git merge hotfix/v1.2.1
git tag -a v1.2.1 -m "Hotfix v1.2.1"
git push origin main --tags

git checkout dev
git merge hotfix/v1.2.1
git push origin dev

# 删除 hotfix 分支
git push origin --delete hotfix/v1.2.1
git branch -d hotfix/v1.2.1
```

---

## 三、分支命名规范

- 使用小写字母和连字符（kebab-case）
- 描述简洁明了，一般不超过 3 个单词
- 可附加 issue 编号：`feat/42-add-payment`
- release 分支使用语义化版本：`release/v1.2.0`
- hotfix 分支使用语义化版本：`hotfix/v1.2.1`

---

## 四、Commit 规范

```
<type>(<scope>): <subject>
```

| type | 说明 |
|------|------|
| feat | 新功能 |
| fix | 修复 bug |
| docs | 文档变更 |
| style | 代码格式（不影响功能） |
| ref | 重构 |
| test | 测试 |
| chore | 构建/工具/依赖 |
| ci | CI 配置 |
| revert | 回滚 |

**Commit 信息模板**：

```
<type>(<scope>): <subject>
<空行>
<body>（可选，说明变更原因和细节）
<空行>
<footer>（可选，关联 issue：Closes #42）
```

**示例**：

```
feat(payment): 添加支付宝支付接口

- 集成支付宝 SDK v2.0
- 新增支付回调处理逻辑
- 添加支付超时重试机制

Closes #123
```

---

## 五、Pull Request 规范

- 标题清晰说明变更内容
- 关联相关 Issue：`Closes #42`
- 描述变更原因和影响范围
- 至少一人 review 通过后才能合并
- 合并后删除源分支

---

## 六、完整操作流程示例

### 场景：从零开发一个功能到合并

```bash
# 1. 确保 main 最新
git checkout main
git pull upstream main
git push origin main

# 2. 创建功能分支
git checkout -b feat/user-profile

# 3. 开发并提交
git add src/components/Profile.tsx
git commit -m "feat(profile): 添加用户头像上传功能"
git add src/api/user.ts
git commit -m "feat(api): 添加用户信息更新接口"

# 4. 推送并提 PR
git push origin feat/user-profile
gh pr create --title "feat(profile): 用户资料页功能" --body "添加头像上传和信息编辑功能，Closes #45"

# 5. Review 通过后合并（在 GitHub 上操作）

# 6. 合并后清理
git checkout main
git pull upstream main
git push origin main
git push origin --delete feat/user-profile
git branch -d feat/user-profile
```

### 场景：Fork 协作提 PR

```bash
# 1. Fork 仓库后添加 upstream
git remote add upstream https://github.com/original/repo.git

# 2. 同步 upstream
git checkout main
git pull upstream main
git push origin main

# 3. 创建修复分支
git checkout -b fix/login-redirect

# 4. 修复并提交
git add src/auth.ts
git commit -m "fix(auth): 修复登录后跳转回首页的问题"
git push origin fix/login-redirect

# 5. 提 PR：fork/fix/login-redirect → upstream/main
gh pr create --head fix/login-redirect --base main --title "fix(auth): 修复登录跳转" --body "Closes #67"
```

---

## 七、分支保护规则配置

### 通过 gh CLI 配置分支保护

```bash
# 保护 main 分支：要求 PR、要求 review、禁止强制推送
gh api repos/{owner}/{repo}/branches/main/protection \
  --method PUT \
  --field required_pull_request_reviews='{"required_approving_review_count":1}' \
  --field enforce_admins=true \
  --field required_status_checks='{"strict":true,"contexts":[]}' \
  --field restrictions=null

# 保护 dev 分支（可选）
gh api repos/{owner}/{repo}/branches/dev/protection \
  --method PUT \
  --field required_pull_request_reviews='{"required_approving_review_count":1}' \
  --field enforce_admins=false \
  --field required_status_checks=null \
  --field restrictions=null
```

### 分支保护规则说明

| 规则 | 说明 |
|------|------|
| 要求 PR | 禁止直接 push，必须通过 Pull Request |
| 要求 review | 至少 N 人 approve 后才能合并 |
| 禁止强制推送 | 防止 `--force` 覆盖历史 |
| 要求 CI 通过 | 所有 status check 通过后才能合并 |
| 要求分支最新 | 合并前必须先 rebase/sync 到最新 main |

---

## 八、CODEOWNERS 配置

在仓库根目录创建 `.github/CODEOWNERS` 文件：

```bash
# 默认所有者（所有文件）
* @BlueChonk

# 前端代码
/src/frontend/ @frontend-team

# 后端代码
/src/backend/ @backend-team

# 文档
/docs/ @doc-team @BlueChonk

# CI/CD 配置
/.github/ @devops-team

# 依赖锁文件
/package-lock.json @devops-team
```

CODEOWNERS 会自动为匹配的文件/目录指定 PR reviewer，确保相关领域的负责人参与 review。

---

## 九、错误处理与故障排除

### 9.1 Merge Conflict 解决

```bash
# 场景：合并 main 到 feat 分支时出现冲突
git checkout feat/xxx
git merge main
# CONFLICT (content): Merge conflict in src/app.ts

# 1. 查看冲突文件
git status

# 2. 手动编辑冲突文件，搜索 <<<<<<< HEAD 标记
# 保留需要的代码，删除冲突标记

# 3. 标记冲突已解决
git add src/app.ts
git commit -m "fix: 解决合并冲突"
```

### 9.2 Push 被拒处理

```bash
# 场景：推送被拒，远程有新提交
git push origin feat/xxx
# ! [rejected]        feat/xxx -> feat/xxx (non-fast-forward)

# 1. 先 fetch 远程最新
git fetch origin

# 2. rebase 到最新远程分支
git rebase origin/feat/xxx

# 3. 如果 rebase 有冲突，解决后继续
git add <resolved-files>
git rebase --continue

# 4. 重新推送
git push origin feat/xxx
```

### 9.3 Rebase 冲突恢复

```bash
# 场景：rebase 过程中遇到冲突，想放弃 rebase
git rebase --abort

# 场景：rebase 完成后发现有问题，想撤销
# 1. 查看 reflog 找到 rebase 前的状态
git reflog
# 2. 重置到 rebase 前
git reset --hard HEAD@{N}  # N 为 reflog 中 rebase 前的位置

# 场景：rebase 时跳过某个有问题的 commit
git rebase --skip

# 场景：rebase 时暂停并修改某个 commit
git rebase -i HEAD~3
# 将需要修改的 commit 前的 pick 改为 edit
# rebase 会停在该 commit，修改后执行：
git add <files>
git commit --amend
git rebase --continue
```

### 9.4 误删分支恢复

```bash
# 场景：误删了本地分支
# 1. 查看 reflog 找到分支最后的 commit
git reflog
# 2. 从该 commit 重新创建分支
git branch feat/xxx <commit-hash>

# 场景：误删了远程分支
# 1. 如果本地还有该分支的引用
git push origin feat/xxx
# 2. 如果本地也没有，先找到 commit hash
git reflog show --all | grep feat/xxx
# 3. 重新创建并推送
git branch feat/xxx <commit-hash>
git push origin feat/xxx

# 场景：误执行了 git branch -D（强制删除）
# 1. 通过 fsck 找到悬空 commit
git fsck --full --no-reflogs --unreachable --lost-found
# 2. 查看悬空 commit 内容
git show <commit-hash>
# 3. 确认后恢复分支
git branch feat/xxx <commit-hash>
```

### 9.5 撤销 Commit

```bash
# 撤销最近一次 commit（保留代码改动）
git reset --soft HEAD~1

# 撤销最近一次 commit（丢弃代码改动，危险！）
git reset --hard HEAD~1

# 撤销已推送的 commit（生成新的 revert commit）
git revert <commit-hash>

# 修改最近一次 commit 信息
git commit --amend -m "新的 commit 信息"

# 修改已推送的 commit 信息（需要 force push，仅限个人分支）
git commit --amend -m "新的 commit 信息"
git push origin feat/xxx --force
```

### 9.6 合并多个 Commit（Squash）

```bash
# 场景：将最近 3 个 commit 合并为 1 个
git rebase -i HEAD~3
# 将第 2、3 个 commit 前的 pick 改为 squash（或 s）
# 保存后会弹出编辑器，编辑合并后的 commit 信息

# 场景：合并所有未推送的 commit
git rebase -i origin/main
# 将除第一个外的所有 pick 改为 squash
```

---

## 十、反模式与 FAQ

### 10.1 常见反模式（禁止操作）

| 反模式 | 后果 | 正确做法 |
|--------|------|----------|
| 直接在 `main` 上开发 | 污染主分支，无法发布 | 始终在 `feat/*` / `fix/*` 分支开发 |
| `force push` 到共享分支 | 覆盖他人代码，丢失历史 | 仅对个人分支使用 `--force` |
| 长期不合并的 feat 分支 | 合并冲突越来越大 | 定期 rebase main，保持分支短期存在 |
| 一个分支做多个不相关改动 | PR 难以 review | 每个功能/修复独立分支 |
| commit 信息写 "update"、"fix" | 无法追溯变更原因 | 使用规范的 commit 格式 |
| 提交敏感信息（密钥、密码） | 安全风险 | 使用环境变量，`.gitignore` 排除配置文件 |
| 不 review 直接合并 | 代码质量下降 | 至少一人 approve 后才能合并 |
| submodule 管理不当 | 子模块指向错误 commit，协作成员代码不一致 | 更新后显式 commit 子模块引用；使用 `git submodule update --init --recursive` 初始化 |
| 大文件直接提交（>50MB） | 仓库体积膨胀，clone 缓慢，GitHub 拒绝 push | 使用 Git LFS 跟踪大文件；`.gitignore` 排除二进制文件 |
| CI 配置错误（错误的 workflow 文件） | 每次 push 都跑失败的 CI，浪费资源，掩盖真实问题 | 修改 CI 后在分支上验证通过再合并到 main；使用 `gh run list` 查看状态 |

### 10.2 FAQ

**Q: 如何撤销已经 push 到远程的 commit？**
```bash
# 方法1：生成 revert commit（推荐，安全）
git revert <commit-hash>
git push origin feat/xxx

# 方法2：回退并 force push（仅限个人分支）
git reset --hard HEAD~1
git push origin feat/xxx --force
```

**Q: 如何修改已经 push 的 commit 信息？**
```bash
git commit --amend -m "新的 commit 信息"
git push origin feat/xxx --force
# 注意：仅限个人分支，且需确认无人基于该 commit 开发
```

**Q: 如何合并多个 commit 为一个？**
```bash
git rebase -i HEAD~N  # N 为要合并的 commit 数
# 将后续 commit 的 pick 改为 squash
```

**Q: 如何查看某个分支是从哪个 commit 创建的？**
```bash
git merge-base main feat/xxx
```

**Q: 如何查看两个分支的差异？**
```bash
git diff main..feat/xxx          # 文件差异
git log main..feat/xxx           # commit 列表
git log --oneline main..feat/xxx # 简洁 commit 列表
```

**Q: 本地分支和远程分支不同步怎么办？**
```bash
# 查看远程分支状态
git remote show origin

# 清理已删除的远程分支的本地引用
git fetch --prune

# 强制同步本地分支到远程
git reset --hard origin/feat/xxx
```

**Q: 如何临时保存未完成的工作去处理其他事？**
```bash
# 暂存当前改动
git stash -m "描述当前工作"

# 恢复暂存
git stash pop
# 或查看暂存列表后恢复指定项
git stash list
git stash apply stash@{0}
```

**Q: submodule 怎么管理？**
```bash
# 首次 clone 含 submodule 的仓库
git clone --recurse-submodules https://github.com/owner/repo.git
# 或 clone 后初始化
git submodule update --init --recursive

# 更新 submodule 到最新
git submodule update --remote

# 在子模块内修改后，回到主仓库提交引用变更
cd submodule-dir
git checkout main && git pull
cd ..
git add submodule-dir
git commit -m "chore(submodule): 更新 submodule 到最新版本"
```

**Q: 大文件怎么处理？**
```bash
# 安装 Git LFS
git lfs install

# 跟踪大文件类型（如模型文件、图片）
git lfs track "*.psd"
git lfs track "*.bin"
git lfs track "*.model"

# 确保 .gitattributes 被提交
git add .gitattributes
git commit -m "chore: 配置 Git LFS 跟踪大文件"

# 正常 add/commit/push，LFS 文件自动走 LFS 存储
git add large-file.bin
git commit -m "feat: 添加模型文件"
git push origin feat/xxx
```

**Q: CI 失败怎么排查？**
```bash
# 查看最近的 CI 运行状态
gh run list --branch=feat/xxx --limit=5

# 查看失败详情
gh run view <run-id> --log-failed

# 本地复现 CI 问题（使用 act 工具）
# 安装 act: https://github.com/nektos/act
act push --secret GITHUB_TOKEN=your_token

# 常见失败原因：
# 1. lint 错误 → 本地运行 npm run lint 修复
# 2. 测试失败 → 本地运行 npm test 定位
# 3. 类型检查失败 → 运行 npx tsc --noEmit
# 4. 依赖安装失败 → 删除 node_modules 和 lock 文件后重新 install
```

**Q: 如何清理大文件历史？**
```bash
# 方法1：使用 git filter-repo（推荐，需先安装）
# pip install git-filter-repo
git filter-repo --path large-file.bin --invert-paths

# 方法2：使用 BFG Repo-Cleaner（更简单）
# 下载 BFG: https://rtyley.github.io/bfg-repo-cleaner/
java -jar bfg.jar --delete-files '*.bin' --no-blob-protection .
git reflog expire --expire=now --all
git gc --prune=now --aggressive

# 清理后需要 force push（仅限个人分支或确认无人基于该历史开发）
git push origin main --force

# 清理后通知所有协作者重新 clone 或 rebase
```

---

## 十一、自动化工具

### 11.1 分支命名规范检查脚本

自动校验分支名是否符合规范。完整脚本位于 `scripts/validate-branch-name.sh`，也可复制下方的精简版本：

```bash
#!/bin/bash
# check-branch-name.sh - 分支命名规范检查
BRANCH_NAME=$(git symbolic-ref --short HEAD)
PATTERN="^(main|dev|feat/[a-z0-9-]+|fix/[a-z0-9-]+|test/[a-z0-9-]+|release/v[0-9]+\.[0-9]+\.[0-9]+|hotfix/v[0-9]+\.[0-9]+\.[0-9]+)$"
if [[ ! $BRANCH_NAME =~ $PATTERN ]]; then
    echo "ERROR: 分支名 '$BRANCH_NAME' 不符合规范"
    exit 1
fi
echo "PASS: 分支名 '$BRANCH_NAME' 符合规范"
```

**使用方式**：

```bash
# 直接运行
bash scripts/validate-branch-name.sh

# 集成到 Husky pre-push hook
npx husky add .husky/pre-push 'bash scripts/validate-branch-name.sh'
```

### 11.2 Commit Message 格式校验脚本

自动校验 commit message 是否符合 Conventional Commits 规范。完整脚本位于 `scripts/validate-commit-msg.sh`，也可复制下方的精简版本：

```bash
#!/bin/bash
# check-commit-msg.sh - commit message 格式校验
COMMIT_MSG_FILE=$1
COMMIT_MSG=$(head -n1 "$COMMIT_MSG_FILE")
PATTERN="^(feat|fix|docs|style|ref|test|chore|ci|revert)(\([a-z0-9-]+\))?: .{1,72}$"
if [[ ! $COMMIT_MSG =~ $PATTERN ]]; then
    echo "ERROR: commit message 格式不符合规范"
    echo "正确格式: <type>(<scope>): <中文描述>"
    exit 1
fi
echo "PASS: commit message 格式正确"
```

**使用方式**：

```bash
# 校验指定文件中的 commit message
bash scripts/validate-commit-msg.sh .git/COMMIT_EDITMSG

# 集成到 Husky commit-msg hook
npx husky add .husky/commit-msg 'bash scripts/validate-commit-msg.sh "$1"'
```

### 11.3 分支清理脚本

自动清理已合并的本地和远程分支：

```bash
#!/bin/bash
# cleanup-branches.sh - 清理已合并的分支
set -e
echo "=== 同步远程分支 ==="
git fetch --prune
echo "=== 清理已合并的本地分支 ==="
git branch --merged main | grep -v "^\*" | grep -v "main" | grep -v "dev" | xargs -r git branch -d
echo "=== 清理已合并的远程分支 ==="
git branch -r --merged main | grep -v "main" | grep -v "dev" | sed 's/origin\///' | xargs -r -I {} git push origin --delete {} 2>/dev/null || true
echo "=== 清理完成 ==="
git branch -a
```

### 11.4 Git Hooks 自动化方案（Husky + commitlint 完整配置）

一键配置完整的 commit 校验流水线：

```bash
# 1. 安装依赖
npm install --save-dev @commitlint/cli @commitlint/config-conventional husky

# 2. 初始化 husky
npx husky install

# 3. 添加 commit-msg hook（校验 commit message 格式）
npx husky add .husky/commit-msg 'npx --no -- commitlint --edit "$1"'

# 4. 添加 pre-push hook（校验分支名）
npx husky add .husky/pre-push 'bash scripts/check-branch-name.sh'

# 5. 创建 commitlint 配置
cat > commitlint.config.js << 'EOF'
module.exports = {
  extends: ['@commitlint/config-conventional'],
  rules: {
    'type-enum': [2, 'always', [
      'feat', 'fix', 'docs', 'style', 'ref', 'test', 'chore', 'ci', 'revert'
    ]],
    'type-case': [2, 'always', 'lower-case'],
    'type-empty': [2, 'never'],
    'scope-case': [2, 'always', 'lower-case'],
    'subject-case': [0],
    'subject-empty': [2, 'never'],
    'subject-full-stop': [2, 'never', '.'],
    'subject-max-length': [2, 'always', 72],
    'header-max-length': [2, 'always', 100],
  }
};
EOF

# 6. 设置 husky 自动启用（新成员 clone 后自动生效）
npm pkg set scripts.prepare="husky install"
```

**效果**：
- 提交时自动校验 commit message 格式，不合法则阻止提交
- 推送时自动校验分支名规范，不合法则阻止推送
- 新成员 `npm install` 后自动启用 hooks，无需手动配置

**终端输出样例**：

执行成功时：
```
$ git commit -m "feat(payment): 添加支付宝支付接口"
[feat/payment 3a4b5c6] feat(payment): 添加支付宝支付接口
 2 files changed, 45 insertions(+)
 create mode 100644 src/payment/alipay.ts
```

执行失败时（commit message 不合规）：
```
$ git commit -m "add payment"
⧗   input: add payment
✖   subject may not be empty [subject-empty]
✖   type may not be empty [type-empty]

✖   found 2 problems, 0 warnings
▻   help: https://github.com/conventional-changelog/commitlint/#what-is-commitlint

husky - commit-msg hook exited with code 1
```

### 11.5 多环境分支策略（dev/staging/prod）

适用于需要多环境部署的项目：

```
分支结构：
  prod  ← 始终与生产环境一致（受保护，仅通过 PR 合并）
  staging ← 预发布环境，QA 验证通过后合并到 prod
  dev   ← 开发集成分支，日常开发合并目标
  feat/* ← 功能分支，从 dev 创建，PR 合并到 dev
  fix/*  ← 修复分支，根据影响范围选择合并到 dev 或 staging
```

**完整工作流**：

```bash
# 日常开发：feat → dev
git checkout dev && git pull origin dev
git checkout -b feat/new-feature
# ... 开发 ...
git push origin feat/new-feature
gh pr create --base dev --title "feat: 新功能"

# 发布到预发布环境：dev → staging
git checkout staging && git pull origin staging
git merge dev
git push origin staging
# QA 在 staging 环境验证

# 发布到生产环境：staging → prod
git checkout prod && git pull origin prod
git merge staging
git tag -a v1.3.0 -m "Release v1.3.0"
git push origin prod --tags

# 紧急修复：hotfix → prod + staging + dev
git checkout prod
git checkout -b hotfix/v1.3.1
# ... 修复 ...
git push origin hotfix/v1.3.1
# 分别提 PR 合并到 prod、staging、dev
```

**分支保护配置**：

```bash
# prod 分支：要求 2 人 review + CI 通过
gh api repos/{owner}/{repo}/branches/prod/protection \
  --method PUT \
  --field required_pull_request_reviews='{"required_approving_review_count":2}' \
  --field enforce_admins=true \
  --field required_status_checks='{"strict":true,"contexts":[]}' \
  --field restrictions=null

# staging 分支：要求 1 人 review + CI 通过
gh api repos/{owner}/{repo}/branches/staging/protection \
  --method PUT \
  --field required_pull_request_reviews='{"required_approving_review_count":1}' \
  --field enforce_admins=false \
  --field required_status_checks='{"strict":true,"contexts":[]}' \
  --field restrictions=null
```

### 11.6 自动化 Changelog 生成（git-chglog 完整配置）

基于 conventional commits 自动生成 changelog：

```bash
# 安装 git-chglog
go install github.com/git-chglog/git-chglog@latest

# 创建配置文件 .chglog/config.yml
mkdir -p .chglog
cat > .chglog/config.yml << 'EOF'
style: github
template: CHANGELOG.tpl.md
info:
  title: CHANGELOG
  repository_url: https://github.com/owner/repo
options:
  commits:
    filters:
      Type:
        - feat
        - fix
        - perf
        - ref
  commit_groups:
    title_maps:
      feat: 新功能
      fix: Bug 修复
      perf: 性能优化
      ref: 重构
  header:
    pattern: "^(\\w*)(?:\\(([\\w\\$\\.\\-\\*\\s]*)\\))?\\:\\s(.*)$"
    pattern_maps:
      - Type
      - Scope
      - Subject
  notes:
    keywords:
      - BREAKING CHANGE
EOF

# 创建模板 .chglog/CHANGELOG.tpl.md
cat > .chglog/CHANGELOG.tpl.md << 'EOF'
{{ range .Versions }}
## {{ .Tag.Name }} ({{ .Date.Format "2006-01-02" }})
{{ range .CommitGroups }}
### {{ .Title }}
{{ range .Commits }}
- {{ .Subject }} ({{ .Hash.Short }})
{{ end }}
{{ end }}
{{ if .NoteGroups }}
{{ range .NoteGroups }}
### {{ .Title }}
{{ range .Notes }}
- {{ .Subject }}
{{ end }}
{{ end }}
{{ end }}
{{ end }}
EOF

# 生成 changelog
git-chglog -o CHANGELOG.md

# 生成指定版本的 changelog
git-chglog v1.2.0..v1.3.0 -o CHANGELOG-1.3.0.md
```

**集成到 release 流程**：

```bash
# 在 release 分支上生成 changelog
git checkout release/v1.3.0
git-chglog -o CHANGELOG.md
git add CHANGELOG.md
git commit -m "chore(release): 更新 changelog v1.3.0"
```

**git-chglog 生成的 CHANGELOG.md 样例**：

```markdown
# Changelog

## [v1.3.0](https://github.com/owner/repo/compare/v1.2.0...v1.3.0) (2024-01-15)

### 新功能

- 添加用户头像上传功能 (3a4b5c6)
- 集成支付宝支付接口 (7d8e9f0)
- 新增夜间模式切换 (a1b2c3d)

### Bug 修复

- 修复登录后跳转回首页的问题 (e4f5a6b)
- 修复支付回调超时未重试 (c7d8e9f)

### 性能优化

- 优化图片加载懒加载策略 (b0c1d2e)

### 重构

- 重构用户认证模块，提取公共逻辑 (f3a4b5c)

## [v1.2.0](https://github.com/owner/repo/compare/v1.1.0...v1.2.0) (2023-12-01)

### 新功能

- 添加商品搜索功能 (a1b2c3d)
- 支持多语言切换 (e4f5a6b)

### Bug 修复

- 修复购物车数量显示错误 (c7d8e9f)
```

---

## 十二、自动化验证脚本

本章节提供 4 个独立可执行的 bash 脚本（位于 `scripts/` 目录），用于在 CI/CD 或本地 hooks 中自动验证分支合并的安全性。每个脚本均包含 `set -euo pipefail` 严格模式、错误处理和使用说明。

### 12.1 init-hooks.sh - 一键安装 Git Hooks

直接运行即可将 3 个验证脚本自动安装到 `.git/hooks/` 目录：

```bash
bash scripts/init-hooks.sh
```

安装结果：

```
=== Git Hooks 一键安装 ===
仓库路径: /path/to/repo
Hooks 目录: /path/to/repo/.git/hooks

[OK] pre-push hook 已安装（分支命名规范检查）
[OK] commit-msg hook 已安装（commit message 格式校验）
[OK] pre-merge-commit hook 已安装（安全合并检查）

=== 安装完成 ===
已安装 3 个 Git hooks：
  pre-push         → 分支命名规范检查
  commit-msg       → commit message 格式校验
  pre-merge-commit → 安全合并检查
```

### 12.2 validate-branch-name.sh - 分支命名规范检查

**功能**：自动校验当前分支名是否符合本规范定义的命名规则。

**文件位置**：`scripts/validate-branch-name.sh`

**单独运行**：

```bash
bash scripts/validate-branch-name.sh
```

**退出码**：0=通过, 1=不通过

**合法分支名格式**：
- `main`, `dev`
- `feat/<name>`, `fix/<name>`, `test/<name>`（小写字母和连字符）
- `release/v<semver>`, `hotfix/v<semver>`（语义化版本）

### 12.3 validate-commit-msg.sh - Commit Message 格式校验

**功能**：校验 commit message 是否符合 Conventional Commits 规范（`<type>(<scope>): <中文描述>`）。

**文件位置**：`scripts/validate-commit-msg.sh`

**单独运行**：

```bash
bash scripts/validate-commit-msg.sh .git/COMMIT_EDITMSG
```

**退出码**：0=通过, 1=不通过

**校验规则**：
- `type`: feat|fix|docs|style|ref|test|chore|ci|revert
- `scope`: 可选，小写字母和连字符
- `subject`: 中文，1-72 字符

### 12.4 safe-merge.sh - 安全合并检查

**功能**：在执行合并前自动检查冲突和 CI 状态，确保合并安全。

**文件位置**：`scripts/safe-merge.sh`

**单独运行**：

```bash
bash scripts/safe-merge.sh main
```

**退出码**：0=安全可合并, 1=存在风险

**检查项**：
1. 无未提交改动
2. 目标分支已同步
3. 无合并冲突
4. CI 状态通过（需 gh CLI）

### 12.5 手动集成到 Husky（可选）

如果使用 Husky 管理 hooks，可以手动集成：

```bash
# 初始化 husky
npx husky install

# 添加 pre-push hook：分支命名检查
npx husky add .husky/pre-push 'bash scripts/validate-branch-name.sh'

# 添加 commit-msg hook：commit message 校验
npx husky add .husky/commit-msg 'bash scripts/validate-commit-msg.sh "$1"'

# 添加 pre-merge-commit hook：安全合并检查
npx husky add .husky/pre-merge-commit 'bash scripts/safe-merge.sh main'

# 设置自动启用
npm pkg set scripts.prepare="husky install"
```

---

## 十三、组合工作流

### 13.1 多人协作完整工作流（Fork → PR → Review → 合并）

适用于开源项目或跨团队协作场景：

```bash
# === 阶段 1: Fork 与克隆 ===
# 在 GitHub 上 fork 目标仓库
git clone https://github.com/你的用户名/目标仓库.git
cd 目标仓库

# 添加 upstream 远程
git remote add upstream https://github.com/原作者/目标仓库.git

# 验证远程配置
git remote -v
# origin    https://github.com/你的用户名/目标仓库.git (fetch/push)
# upstream  https://github.com/原作者/目标仓库.git (fetch/push)

# === 阶段 2: 同步与创建分支 ===
# 同步 upstream 到本地
git checkout main
git pull upstream main
git push origin main

# 创建功能分支
git checkout -b feat/contributor-feature

# === 阶段 3: 开发与提交 ===
# 开发过程中保持与 upstream 同步（每天至少一次）
git fetch upstream
git rebase upstream/main

# 提交代码（遵循 commit 规范）
git add src/feature.ts
git commit -m "feat(feature): 实现新功能模块"
git add tests/feature.test.ts
git commit -m "test(feature): 添加新功能单元测试"

# === 阶段 4: 推送与提 PR ===
# 推送到 fork
git push origin feat/contributor-feature

# 创建 PR
gh pr create \
  --head feat/contributor-feature \
  --base main \
  --title "feat(feature): 新功能模块" \
  --body "## 变更说明
- 实现新功能模块
- 添加完整单元测试
- 更新相关文档

## 测试方式
- [ ] 单元测试通过
- [ ] 集成测试通过
- [ ] 手动验证通过

Closes #123"

# === 阶段 5: Review 与修改 ===
# 根据 review 意见修改
git add src/feature.ts
git commit -m "fix(feature): 根据 review 意见修复边界条件"
git push origin feat/contributor-feature

# === 阶段 6: 合并与清理 ===
# PR 被合并后，清理本地分支
git checkout main
git pull upstream main
git push origin main
git branch -d feat/contributor-feature
git push origin --delete feat/contributor-feature
```

### 13.2 发布管理完整工作流（Release 分支 → Changelog → Tag → GitHub Release）

适用于版本化发布场景：

```bash
# === 阶段 1: 创建 Release 分支 ===
git checkout main
git pull origin main
git checkout -b release/v1.3.0

# === 阶段: 版本号更新 ===
# 更新 package.json 版本号
npm version 1.3.0 --no-git-tag-version
git add package.json package-lock.json
git commit -m "chore(release): bump version to v1.3.0"

# === 阶段 3: 生成 Changelog ===
# 使用 git-chglog 自动生成
git-chglog -o CHANGELOG.md
git add CHANGELOG.md
git commit -m "chore(release): 更新 changelog v1.3.0"

# === 阶段 4: 最终修复（仅 bug fix） ===
# 在 release 分支上只修复阻塞性 bug
git add src/critical-fix.ts
git commit -m "fix(critical): 修复发布前发现的阻塞性问题"

# === 阶段 5: 推送 Release 分支 ===
git push origin release/v1.3.0

# === 阶段: 创建 PR 合并到 main ===
gh pr create \
  --head release/v1.3.0 \
  --base main \
  --title "release: v1.3.0" \
  --body "发布 v1.3.0，包含新功能和 bug 修复"

# === 阶段 7: 合并到 main 并打 tag ===
git checkout main
git merge release/v1.3.0
git tag -a v1.3.0 -m "Release v1.3.0"
git push origin main --tags

# === 阶段 8: 同步到 dev ===
git checkout dev
git merge release/v1.3.0
git push origin dev

# === 阶段 9: 创建 GitHub Release ===
gh release create v1.3.0 \
  --title "v1.3.0" \
  --notes-file CHANGELOG.md \
  --target main

# === 阶段 10: 清理 ===
git push origin --delete release/v1.3.0
git branch -d release/v1.3.0
```

---

## 十四、能力边界

### 支持的分支策略

- **GitHub Flow**：`main` + `feat/*` + `fix/*`，适合持续交付
- **Git Flow**：`main` + `dev` + `feat/*` + `fix/*` + `release/*` + `hotfix/*`，适合版本化发布
- **Fork 协作**：通过 fork + upstream 模式向开源项目贡献代码
- **Trunk-Based**：基于主干的短期分支开发（本规范覆盖其核心实践）
- **多环境策略**：`dev` + `staging` + `prod`，适合需要多阶段验证的项目

### 支持的场景

- 分支创建、命名、合并、删除
- PR 创建、review、合并
- Merge conflict 解决
- Rebase 操作与冲突恢复
- 分支保护规则配置
- CODEOWNERS 配置
- Release/Hotfix 分支管理
- Commit 信息规范与校验
- Changelog 自动生成
- Git hooks 自动化（Husky + commitlint）
- 多环境分支策略（dev/staging/prod）
- 分支命名规范检查
- Commit message 格式校验
- 安全合并检查（冲突预检 + CI 状态检查）
- 多人协作完整工作流
- 发布管理完整工作流

### 不支持的场景

- **GitLab / Bitbucket 特有功能**：本规范仅针对 GitHub 平台
- **Monorepo 复杂依赖管理**：如 Nx、Turborepo 的依赖图分析
- **自动化版本发布语义化**：如 `semantic-release` 的完整集成（仅提供 changelog 生成）
- **大规模团队权限体系**：如基于 SAML/SSO 的团队权限管理
- **GitHub Enterprise Server 特有配置**：如自托管 runner 的注册与管理

---

## 十五、注意事项

- 禁止直接推送到 `main`，必须通过 PR
- 禁止在 `main` 上开发，所有改动在 feat/fix 分支
- feat 分支用完即删，合并后删除远程分支
- 同步上游前先 stash 或 commit，避免冲突
- rebase 前先备份：`git branch backup/feat-xxx`
- `force push` 仅限个人分支，禁止对共享分支使用
- 提交前检查敏感信息（密钥、密码、token）
- 长期分支定期 rebase main，避免合并冲突累积
