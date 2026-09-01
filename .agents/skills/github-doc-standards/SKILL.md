---
name: "github-doc-standards"
description: "Documentation standards for GitHub projects. Covers language priority, README template, topic tags, and sensitive data desensitization rules. Invoke when creating or maintaining project documentation. 触发示例：(1) 新建仓库需要写 README 时；(2) 给项目添加或修改话题标签时；(3) 检查文档是否泄露敏感信息时；(4) 需要补全 CONTRIBUTING.md / CHANGELOG.md 时；(5) 审查项目文档质量时；(6) 多语言项目需要统一文档规范时。"
---

# GitHub 项目文档规范

> 适用于所有个人日常开发中创建和维护的项目。

---

## 零、适用范围与边界

> 本规范明确覆盖与不覆盖的范围，避免误用。

### 覆盖范围

- 个人及小型团队 GitHub 项目的文档规范
- README / CONTRIBUTING / CHANGELOG 等核心文档模板
- 话题标签管理与脱敏规范
- 文档质量检查与故障排查
- 文档即代码实践与自动化工具链

### 不覆盖范围

| 领域 | 原因 | 替代资源 |
|------|------|----------|
| **API 文档规范**（OpenAPI/Swagger） | 需遵循 OpenAPI Specification 标准，涉及 schema 定义、路径规范等独立体系 | 参考 `swagger.io/specification` 官方文档 |
| **GitHub Pages 文档** | 静态站点生成涉及 Jekyll/Hugo 配置、主题定制，超出本规范范围 | 参考 GitHub Pages 官方文档 |
| **CI/CD 文档** | 各平台（GitHub Actions、GitLab CI、Jenkins）语法差异大，需单独学习 | 参考各平台官方文档 |
| **技术白皮书/架构文档** | 面向企业决策层，需遵循行业模板（如 ARC42、C4 Model），非个人项目场景 | 参考 `arc42.org` |
| **法律文档**（隐私政策、服务条款） | 涉及法律合规，需专业法律人士审核 | 使用模板生成工具如 TermsFeed |
| **学术论文/技术报告** | 需遵循学术引用规范（APA、IEEE 等）与 LaTeX 排版 | 参考各期刊投稿指南 |

**判断标准：** 如果文档内容涉及上述领域，建议先查找该领域的专项规范，本规范仅提供通用文档质量建议。

---

## 一、语言优先级

| 场景 | 主文档 | 备注 |
|------|--------|------|
| 个人小项目 | `README.md`（中文） | 默认方案 |
| 热门/正式项目 | `README.md`（中文）+ `README_en.md`（英文） | 国际化补充 |

**原则：**
- 默认中文优先，README.md 必须是中文
- 个人小项目只需中文，热门/正式项目才考虑中英双语
- 多语言文档需保持内容同步，避免中英文版本信息不一致

---

## 二、项目话题标签

做项目与维护项目时，需要给项目合适的话题（topic）标签，便于分类和检索。

### 常用标签分类

| 分类 | 标签示例 |
|------|----------|
| 语言 | `python`、`javascript`、`typescript`、`rust`、`go`、`java` |
| 框架 | `react`、`vue`、`nextjs`、`fastapi`、`django`、`flutter` |
| 领域 | `machine-learning`、`web-scraping`、`automation`、`cli`、`mcp` |
| 工具 | `docker`、`pm2`、`github-actions`、`nginx`、`redis` |
| 平台 | `windows`、`linux`、`macos`、`android`、`ios` |
| 状态 | `wip`、`archived`、`deprecated` |

### 使用规则

- 每个项目 **3-8 个**标签，不超过 10 个
- 标签使用**小写字母 + 连字符**（kebab-case）
- 优先使用 GitHub 已有热门标签，避免生造
- 必须包含：语言标签 + 至少一个领域/框架标签
- 在仓库 Settings → Topics 中添加

### 反模式（常见错误）

| 错误做法 | 正确做法 |
|----------|----------|
| 生造标签如 `my-awesome-tool` | 使用 GitHub 已有的热门标签 |
| 堆砌 15 个标签 | 控制在 3-8 个，精准描述 |
| 使用大写字母或下划线 | 使用小写字母 + 连字符（kebab-case） |
| 只加语言标签不加领域标签 | 语言 + 领域/框架组合 |
| 标签与项目实际内容无关 | 标签必须准确反映项目技术栈和用途 |

### FAQ

**Q：如何判断该用哪些标签？**
A：先确定语言标签（必选），再选 1-2 个框架/库标签，最后选 1-2 个领域标签。总共不超过 8 个。

**Q：标签可以随时修改吗？**
A：可以。在仓库 Settings → Topics 中随时增删，建议项目稳定后固定下来。

**Q：热门标签在哪里查？**
A：访问 `https://github.com/topics/` 浏览已有标签及其使用量。

**Q：项目从活跃转为归档，标签需要调整吗？**
A：需要。将 `wip` 替换为 `archived`，并添加说明项目已停止维护。在 README 顶部追加归档声明，避免新用户误用。

**Q： Fork 仓库需要修改标签吗？**
A：建议修改。Fork 后的项目用途可能与上游不同，保留原标签会造成误导。至少替换领域标签以反映实际用途。

**Q：同一标签在多个层级重复（如 `python` 和 `python3`）怎么办？**
A：只保留一个最精准的。GitHub 的标签系统不区分版本，`python` 已足够。多个相似标签反而降低检索效率。

**Q：文档类仓库（如笔记、知识库）用什么领域标签？**
A：推荐使用 `documentation`、`notes`、`knowledge-base` 等。若内容偏技术教程，可加 `tutorial`。避免使用过于宽泛的标签如 `misc`。

**Q：如何处理"文档债务"？**
A：文档债务指因长期未维护而导致文档与代码严重脱节的现象。偿还策略：
1. **识别债务**：运行 `git log --since="3 months ago" --name-only --pretty=format:"" | sort | uniq -c | sort -rn` 找出高频变更文件
2. **优先偿还**：变更频率高但文档未更新的文件优先处理
3. **批量修复**：每周固定 30 分钟集中处理，而非一次性重写
4. **预防机制**：将文档更新纳入 PR 模板检查项，代码变更必须同步更新文档

---

## 三、README.md 内容规范

### 结构要求

- 项目简介（一段话说清楚是什么）
- 目录结构
- 快速开始（安装、使用）
- 配置说明
- 常见问题
- 许可证

### README 长度建议

| 项目类型 | 建议长度 | 说明 |
|----------|----------|------|
| 小工具/脚本 | 50-150 行 | 简洁为主，快速上手 |
| 中型项目 | 150-400 行 | 包含完整使用说明 |
| 大型/正式项目 | 400-800 行 | 详尽文档，可拆分到 `docs/` |

### 完整 README 模板

```markdown
# 项目名称

> 一句话描述项目是什么、解决什么问题

## 特性

- 核心功能 1
- 核心功能 2
- 核心功能 3

## 快速开始

### 环境要求

- 运行时/语言版本
- 依赖的第三方服务

### 安装

\`\`\`bash
# 克隆仓库
git clone https://github.com/用户名/项目名.git
cd 项目名

# 安装依赖
npm install
# 或
pip install -r requirements.txt
\`\`\`

### 使用

\`\`\`bash
# 启动命令
npm start
# 或
python main.py
\`\`\`

## 配置

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `PARAM_A` | `default_a` | 参数 A 说明 |
| `PARAM_B` | `default_b` | 参数 B 说明 |

## 项目结构

\`\`\`
.
├── src/          # 源代码
├── docs/         # 文档
├── tests/        # 测试
└── README.md     # 本文件
\`\`\`

## 常见问题

**Q：问题描述？**
A：解答内容。

## 许可证

[MIT](LICENSE) © 作者名
```

### 真实项目示例参考

优秀 README 参考项目：
- `microsoft/vscode` — 结构清晰，信息密度高
- `facebook/react` — 简洁有力，快速上手
- `vercel/next.js` — 文档与代码分离，README 做导航

---

## 四、CONTRIBUTING.md 模板

> 当项目接受外部贡献时，必须提供此文件。

```markdown
# 贡献指南

感谢你对本项目的兴趣！以下是参与贡献的指南。

## 如何贡献

1. Fork 本仓库
2. 创建你的功能分支 (`git checkout -b feature/xxx`)
3. 提交你的修改 (`git commit -m 'feat: 添加 xxx 功能'`)
4. 推送到分支 (`git push origin feature/xxx`)
5. 开启 Pull Request

## 提交规范

提交信息格式：`<type>(<scope>): <中文描述>`

type 类型：
- `feat`：新功能
- `fix`：修复 bug
- `docs`：文档变更
- `style`：代码格式调整
- `refactor`：重构
- `test`：测试相关
- `chore`：构建/工具变更

## 代码规范

- 代码风格遵循项目现有约定
- 新增功能需包含对应测试
- 所有测试必须通过

## 问题反馈

- 使用 Issue 提交问题
- 描述清楚复现步骤和环境信息
```

---

## 五、CHANGELOG.md 模板

> 记录项目版本变更历史，帮助用户了解更新内容。

```markdown
# 变更日志

所有项目的显著变更都将记录在此文件中。

格式基于 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.0.0/)，
版本号遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

## [Unreleased]

### Added
- 新增功能描述

### Fixed
- 修复问题描述

## [1.0.0] - 2024-01-15

### Added
- 初始版本发布
- 核心功能实现

[Unreleased]: https://github.com/用户名/项目名/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/用户名/项目名/releases/tag/v1.0.0
```

---

## 六、文档脱敏规范

项目文档中**禁止包含任何真实敏感数据**，包括但不限于：

| 敏感类型 | 说明 | 处理方式 |
|----------|------|----------|
| API Key / Token | 接口认证密钥 | 替换为 `***` 或 `[已脱敏]` |
| 设备指纹 ID | deviceId、machineId、qimei 等 | 替换为 `***` 或示例值 |
| 用户标识 | QQ号、用户ID、邮箱等 | 替换为示例或打码 |
| Cookie / Session | 登录凭证 | 替换为 `[已脱敏]` |
| RSA 密钥 | 公私钥内容 | 替换为 `[已脱敏]` |
| 文件哈希 | MD5、SHA256 等完整值 | 保留前几位 + `...` |
| IP 地址 | 内网/外网 IP | 替换为 `x.x.x.x` 或示例 |

**脱敏示例：**

```markdown
# 脱敏前
token: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
qqNumber: "5729475454240175104"

# 脱敏后
token: "***"
qqNumber: "5729xxxx75104"
```

**检查清单：**
- [ ] 文档中无真实 API Key / Token
- [ ] 文档中无真实设备指纹 / 用户标识
- [ ] 文档中无真实 Cookie / Session
- [ ] 文档中无完整 RSA 密钥
- [ ] 截图中的敏感信息已打码

---

## 七、文档质量检查清单

> 发布前逐项检查，确保文档质量达标。

### 基础检查

- [ ] README.md 存在且内容完整
- [ ] 项目简介清晰，一句话说明项目用途
- [ ] 快速开始可复现（按步骤操作能跑起来）
- [ ] 许可证文件存在
- [ ] 话题标签已添加（3-8 个）

### 内容质量

- [ ] 无错别字、语法错误
- [ ] 链接有效（无 404）
- [ ] 代码示例可执行
- [ ] 截图清晰、已脱敏
- [ ] 目录结构（如有）与实际一致

### 进阶检查

- [ ] CONTRIBUTING.md 存在（接受贡献时）
- [ ] CHANGELOG.md 存在（版本化项目）
- [ ] 多语言文档内容同步
- [ ] 文档更新频率与代码变更匹配

---

## 八、文档质量故障排查

### 常见问题诊断与修复

| 问题 | 检测原因 | 检测方法 | 修复步骤 |
|------|----------|----------|----------|
| 文档与代码不同步 | 更新代码后忘记更新文档 | 运行 `git log --since="3 months ago" --name-only` 对比文档修改时间 | 1. 找出最近修改的源码文件<br>2. 检查对应文档章节<br>3. 更新差异内容<br>4. 提交 `docs:` 类型 commit |
| README 信息过时 | 项目功能已扩展但文档未跟进 | 对比 README 描述与实际功能列表 | 1. 列出当前所有功能点<br>2. 对比 README「特性」章节<br>3. 补充缺失功能描述<br>4. 更新版本号 |
| 章节缺失 | 模板不完整或遗漏关键信息 | 使用下方自评问卷逐项检查 | 1. 定位缺失章节<br>2. 从模板中复制对应结构<br>3. 填充实际内容 |
| 格式混乱 | 多人编辑或缺乏 lint 工具 | 使用 `markdownlint` 扫描文档 | 1. 安装 `npm install -g markdownlint-cli`<br>2. 运行 `markdownlint README.md`<br>3. 按提示修复格式问题 |
| 代码示例不可执行 | 环境变化或依赖版本更新 | 在干净环境中按 README 步骤复现 | 1. 在 Docker 或新机器上测试<br>2. 记录失败的步骤<br>3. 更新安装/使用命令<br>4. 标注最低环境要求 |
| 多语言版本不一致 | 只更新了一个语言版本 | 对比中英文版本的章节结构和关键信息 | 1. 建立「最后同步时间」标注机制<br>2. 每次更新双语文档<br>3. 或使用自动化翻译工具辅助 |

### 文档质量自评问卷

> 发布前回答以下 10 个问题，每题 1-5 分，总分低于 35 分需改进。

| # | 问题 | 评分标准 |
|---|------|----------|
| 1 | README 是否能在 30 秒内让人理解项目用途？ | 5分=清晰一句话说明 / 1分=看不懂 |
| 2 | 快速开始步骤是否可在干净环境复现？ | 5分=完全可复现 / 1分=缺少关键步骤 |
| 3 | 是否有明确的版本或最后更新时间？ | 5分=有且近期 / 1分=完全没有 |
| 4 | 代码示例是否全部可执行？ | 5分=全部验证 / 1分=有错误示例 |
| 5 | 链接是否全部有效（无 404）？ | 5分=全部有效 / 1分=多处失效 |
| 6 | 是否存在敏感信息泄露？ | 5分=完全脱敏 / 1分=有真实密钥 |
| 7 | 文档结构是否符合规范模板？ | 5分=完整齐全 / 1分=严重缺失 |
| 8 | 多语言文档是否内容同步？ | 5分=完全同步 / 1分=仅单语言 |
| 9 | 是否有清晰的贡献指南？ | 5分=有且详细 / 1分=完全没有 |
| 10 | 文档更新频率是否与代码变更匹配？ | 5分=同步更新 / 1分=从未更新 |

**评分结果处理：**
- 45-50 分：优秀文档，可作为范例
- 35-44 分：合格文档，有小幅改进空间
- 25-34 分：需要改进，重点修复低分项
- 25 分以下：需要重写，建议从模板重新开始

---

## 九、最佳实践

### 文档更新检查清单

> 每次代码变更时，对照此清单同步更新文档。

**代码变更触发条件：**
- [ ] 新增/删除/修改功能 → 更新 README「特性」和「使用」章节
- [ ] 配置项变更 → 更新「配置」章节，标注版本兼容性
- [ ] API 接口变更 → 更新接口文档，标注废弃版本和迁移指南
- [ ] 依赖版本变更 → 更新「环境要求」和安装步骤
- [ ] Bug 修复 → 在 CHANGELOG 中记录，关闭相关 Issue
- [ ] 项目状态变更 → 更新话题标签和 README 状态标识

### 文档过期检测机制

```bash
# 检测超过 90 天未更新的文档文件
find . -name "*.md" -mtime +90 -not -path "./node_modules/*"

# 检测文档与源码修改时间差异
git log --since="6 months ago" --name-only --pretty=format:"" | sort | uniq -c | sort -rn | head -20
```

**建议频率：**
- 每次 PR 合并前：快速检查关联文档是否更新
- 每月一次：运行过期检测脚本，清理过时内容
- 每季度一次：全面审查文档质量，偿还文档债务

### 文档更新频率

| 变更类型 | 文档更新时机 |
|----------|--------------|
| 新功能发布 | 同步更新 README 和 CHANGELOG |
| 配置项变更 | 更新配置说明章节 |
| API 变更 | 更新接口文档，标注废弃版本 |
| Bug 修复 | 在 CHANGELOG 中记录 |
| 项目归档 | 更新状态标签为 `archived` |

### 文档自动化工具推荐

| 工具 | 用途 | 适用场景 |
|------|------|----------|
| `dbchangelog` | 数据库变更日志 | 数据库项目 |
| `standard-version` | 自动版本管理和 CHANGELOG | Node.js 项目 |
| `all-contributors` | 自动记录贡献者 | 开源项目 |
| `markdownlint` | Markdown 格式检查 | 所有项目 |
| `lychee` | 链接有效性检查 | 所有项目 |
| `typedoc` | TypeScript 自动生成 API 文档 | TypeScript 项目 |
| `docusaurus` | 文档站点生成 | 中大型项目 |
| `husky` + `lint-staged` | 提交前自动 lint 文档 | 所有项目 |

### 文档评分标准

| 维度 | 优秀（4-5分） | 合格（3分） | 不足（1-2分） |
|------|---------------|-------------|---------------|
| 完整性 | 所有章节齐全，模板完整 | 基本结构有 | 缺少关键章节 |
| 准确性 | 代码示例可直接运行 | 大部分正确 | 有误导性内容 |
| 可维护性 | 有 CHANGELOG，更新及时 | 偶尔更新 | 长期未更新 |
| 可读性 | 排版清晰，使用表格/代码块 | 基本可读 | 大段文字无格式 |
| 安全性 | 完全脱敏，无泄露 | 基本脱敏 | 存在敏感信息泄露 |

---

## 十、多语言项目文档差异

| 方面 | 中文项目 | 英文项目 | 双语项目 |
|------|----------|----------|----------|
| 主文档 | `README.md` | `README.md` | `README.md`（中文） |
| 副文档 | 无 | 无 | `README_en.md` |
| 提交信息 | 中文描述 | 英文描述 | 中文描述 |
| Issue 模板 | 中文 | 英文 | 双语 |
| 注释语言 | 中文 | 英文 | 英文（代码层面） |
| 维护成本 | 低 | 低 | 高（需同步） |

**建议：** 个人项目默认中文，有海外用户考虑时再补充英文版本。

---

## 十一、文档即代码（Docs as Code）实践方案

### 核心理念

将文档与代码同等对待，使用版本控制、代码审查、CI/CD 等工程化手段管理文档。

### 实践清单

| 实践 | 说明 | 工具 |
|------|------|------|
| 文档与代码同仓库 | 文档变更与代码变更在同一 PR 中审查 | GitHub PR |
| 文档格式 lint | 提交前自动检查 Markdown 格式 | `markdownlint-cli` + `husky` |
| 链接有效性检查 | CI 中自动检测死链 | `lychee-action` |
| 拼写检查 | 自动检测拼写错误 | `cspell` |
| 文档预览 | PR 中预览文档渲染效果 | `deploy-preview`（Netlify/Vercel） |
| 变更追踪 | 文档与代码使用同一 CHANGELOG | `standard-version` |

### 自动化生成工具链

#### TypeScript 项目：TypeDoc + Docusaurus

```bash
# 安装工具
npm install --save-dev typedoc typedoc-plugin-markdown docusaurus

# 从 TypeScript 源码生成 API 文档
npx typedoc --out docs/api src/index.ts

# 启动 Docusaurus 文档站点
npx docusaurus start
```

#### Python 项目：Sphinx + AutoDoc

```bash
# 安装工具
pip install sphinx sphinx-autodoc-typehints

# 从 docstring 生成文档
sphinx-apidoc -o docs/source src/
make html
```

#### 多语言管理策略

| 策略 | 适用场景 | 优缺点 |
|------|----------|--------|
| 双语文件 | 维护成本低 | 手动同步，易过时 |
| 自动翻译 | 大型项目 | 需审核翻译质量 |
| 单一语言 | 个人项目 | 简单直接，覆盖面有限 |

#### 文档版本管理方案

| 方案 | 适用场景 | 实现方式 |
|------|----------|----------|
| 分支管理 | 多版本维护 | `docs/v1`、`docs/v2` 分支 |
| 标签管理 | 发布版本 | Git tag + GitHub Release |
| 目录管理 | 少量版本 | `docs/v1/`、`docs/v2/` 子目录 |
| Docusaurus 版本 | 复杂项目 | 内置版本管理功能 |

### GitHub Actions 自动化示例

```yaml
name: Documentation CI
on:
  pull_request:
    paths:
      - '**.md'
      - 'docs/**'

jobs:
  lint-docs:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Markdown Lint
        uses: articulate/actions-markdownlint@v1
      - name: Link Check
        uses: lycheeverse/lychee-action@v1
```

---

## 附录：文档更新检查清单（速查表）

> 每次代码变更时快速对照。

```
代码变更时：
□ 功能新增 → 更新 README 特性章节
□ 配置变更 → 更新配置说明
□ API 变更 → 更新接口文档 + 迁移指南
□ 依赖更新 → 更新环境要求
□ Bug 修复 → 更新 CHANGELOG
□ 状态变更 → 更新话题标签

发布前：
□ 文档格式 lint 通过
□ 链接有效性检查通过
□ 代码示例可执行
□ 敏感信息已脱敏
□ 多语言版本同步

每月维护：
□ 运行过期检测脚本
□ 修复文档债务（高频变更文件优先）
□ 更新最后维护时间戳
```