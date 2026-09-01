---
name: "dsh-plugin-dev"
description: "DSH (DeepSeek Harness) plugin development guide with official docs, tutorials, and pre-development checklist. Invoke when the user wants to develop, build, or debug DSH plugins. 触发示例：「帮我创建一个 DSH 插件」「插件加载失败怎么办」「如何调试插件的 HMR」「插件和 skill 有什么区别」「如何发布插件到 npm」「插件性能优化」「插件安全防护」「从 v1 迁移到 v2」。"
---

# DSH 插件开发指南

> 开发前必须先查看本技能文档。

**官方文档源**：<https://github.com/deepseek-ai/deepseek-harness/tree/master/docs/user/develop>

---

## 5 分钟快速入门

> 新手目标：5 分钟内创建第一个能运行的插件。

### 步骤 1：生成插件骨架（30 秒）

```powershell
. "$env:USERPROFILE\.dsh\skills\dsh-plugin-dev\scripts\new-plugin.ps1" -Name "my-first-plugin"
```

### 步骤 2：安装依赖（2 分钟）

```powershell
cd "my-first-plugin"
npm install
npm install --save-dev typescript @types/node vitest
npm install @deepseek-ai/cordis @deepseek-ai/schemastery @deepseek-ai/dsh-tools
```

### 步骤 3：编写一个最简单的工具

编辑 `src/index.ts`，将内容替换为：

```ts
import type { Context } from '@deepseek-ai/cordis'
import Schema from '@deepseek-ai/schemastery'
import { defineTool } from '@deepseek-ai/dsh-tools'

export const name = 'my-first-plugin'

export interface Config {
  greeting: string
}

export const Config: Schema<Config> = Schema.object({
  greeting: Schema.string().default('Hello'),
})

export function apply(ctx: Context, config: Config) {
  ctx.tools.register(defineTool({
    name: 'greet',
    description: 'Greet someone.',
    parameters: {
      name: { type: 'string', required: true, description: 'The name' },
    },
    output: {
      schema: { type: 'string' },
      render: (_args, value) => [{ type: 'text', text: value }],
    },
    async execute(args) {
      return `${config.greeting}, ${args.name}!`
    },
  }))
}
```

### 步骤 4：启动并验证（1 分钟）

```powershell
pnpm dsh web --patch "$env:USERPROFILE\my-first-plugin\cordis.patch.yml"
```

启动成功后，终端输出应包含：

```
[INFO] Loading plugin: my-first-plugin
[INFO] Plugin registered: greet
[INFO] DSH Web is running at http://127.0.0.1:3080
```

### 步骤 5：验证工具可用

在 Web UI 中发送消息："用 greet 工具打个招呼，名字是 Alice"，预期返回：`Hello, Alice!`

> 下一步：阅读下方完整开发指南，了解 HMR 调试、测试和发布流程。

---

## 获取官方文档

```powershell
. "$env:USERPROFILE\.dsh\skills\dsh-plugin-dev\scripts\fetch-docs.ps1"
```

### 使用场景说明

- 首次开发：需要获取官方文档中文版作为开发参考时
- 文档更新：官方文档有新增内容，需要同步到本地时
- 网络恢复：之前因网络问题获取失败后，重新执行即可自动重试

### 获取失败排查

| 错误现象 | 原因 | 解决方案 |
|----------|------|----------|
| `git: command not found` | 未安装 Git | 安装 Git 后重试 |
| `fatal: unable to access ...` | 网络连接失败 | 检查网络，或配置代理：`git config --global http.proxy http://127.0.0.1:7890` |
| `fatal: not a git repository` | docs 目录损坏 | 删除 `deepseek-harness-docs` 目录后重新执行脚本 |
| `Permission denied` | 权限不足 | 以管理员权限运行 PowerShell，或检查目录权限 |
| `already exists and is not an empty directory` | 目录已存在但非 git 仓库 | 删除该目录后重试，或手动 `git init` 并设置 remote |
| `sparse-checkout` 失败 | Git 版本过低（需 ≥2.25） | 升级 Git 到最新版本 |

---

## 文档索引

| 类别 | 文件 | 内容 |
|------|------|------|
| 入门 | `deepseek-harness-docs/docs/user/develop/basic/index.md` | 插件开发总览 |
| 入门 | `deepseek-harness-docs/docs/user/develop/basic/config.md` | cordis.yml 配置 |
| 入门 | `deepseek-harness-docs/docs/user/develop/basic/tool.md` | defineTool 注册 |
| 入门 | `deepseek-harness-docs/docs/user/develop/basic/publish.md` | 打包安装 |
| 框架 | `deepseek-harness-docs/docs/user/develop/framework/index.md` | 架构总览与生命周期 |
| 框架 | `deepseek-harness-docs/docs/user/develop/framework/service.md` | 服务注入与生命周期 |
| 框架 | `deepseek-harness-docs/docs/user/develop/framework/events.md` | 事件系统 |
| 进阶 | `deepseek-harness-docs/docs/user/develop/practice/index.md` | 三角色能力设计 |
| 进阶 | `deepseek-harness-docs/docs/user/develop/practice/llm-adapter.md` | 自定义 LLM 适配器 |

---

## 开发前检查清单

- [ ] 已读 `basic/index.md`（了解 host 面 + client 面）
- [ ] 已读 `basic/config.md`（配置定义）
- [ ] 已读 `basic/tool.md`（工具注册）
- [ ] 已读 `basic/publish.md`（打包安装）
- [ ] 涉及服务/事件 → 读 `framework/service.md` + `framework/events.md`
- [ ] 涉及自定义 LLM → 读 `practice/llm-adapter.md`
- [ ] 涉及三角色能力 → 读 `practice/index.md`

---

## 核心包

- `@deepseek-ai/cordis`（框架）
- `@deepseek-ai/schemastery`（配置校验）
- `@deepseek-ai/dsh-tools`（工具定义）
- `@deepseek-ai/dsh-llm`（LLM 适配器基类）

---

## 端到端开发案例：从零创建并发布一个工具插件

以下完整流程涵盖创建、调试、测试、打包、发布五个阶段。

### 阶段 1：创建插件项目

```powershell
# 1. 创建项目目录（路径动态获取，禁止硬编码）
$pluginDir = Join-Path $env:USERPROFILE "my-dsh-plugin"
New-Item -ItemType Directory -Path $pluginDir -Force
Set-Location $pluginDir

# 2. 初始化 npm 包
npm init -y

# 3. 安装依赖
npm install --save-dev typescript @types/node
npm install @deepseek-ai/cordis @deepseek-ai/schemastery @deepseek-ai/dsh-tools
```

### 阶段 2：编写插件代码

项目结构：
```
my-dsh-plugin/
├── src/
│   └── index.ts          # 插件入口
├── package.json          # 含 dsh.bundle 声明
├── cordis.patch.yml      # 插件层配置
├── tsconfig.json         # TypeScript 配置
└── vitest.config.ts      # 测试配置（可选）
```

`src/index.ts`：
```ts
import type { Context } from '@deepseek-ai/cordis'
import Schema from '@deepseek-ai/schemastery'
import { defineTool } from '@deepseek-ai/dsh-tools'

export const name = 'my-greet-plugin'
export const inject = ['tools']

export interface Config {
  greeting: string
  uppercase: boolean
}

export const Config: Schema<Config> = Schema.object({
  greeting: Schema.string().default('Hello'),
  uppercase: Schema.boolean().default(false),
})

export function apply(ctx: Context, config: Config) {
  ctx.tools.register(defineTool({
    name: 'greet',
    description: 'Greet someone by name.',
    parameters: {
      name: { type: 'string', required: true, description: 'The name to greet' },
    },
    output: {
      schema: { type: 'string' },
      render: (_args, value) => [{ type: 'text', text: value }],
    },
    async execute(args) {
      let result = `${config.greeting}, ${args.name}!`
      return config.uppercase ? result.toUpperCase() : result
    },
  }))
}
```

`cordis.patch.yml`：
```yaml
- insert:
    - id: my-greet
      name: my-greet-plugin
      config:
        greeting: 'Hi'
        uppercase: false
```

`package.json`（关键字段）：
```json
{
  "name": "my-greet-plugin",
  "version": "0.1.0",
  "type": "module",
  "main": "src/index.ts",
  "files": ["src", "cordis.patch.yml"],
  "scripts": {
    "build": "tsc",
    "test": "vitest run",
    "prepare": "npm run build"
  },
  "dsh": {
    "bundle": {
      "patch": "./cordis.patch.yml"
    }
  }
}
```

### 阶段 3：本地调试

```powershell
# 方式 1：通过 --patch 直接加载（开发推荐）
pnpm dsh web --patch "$env:USERPROFILE\my-dsh-plugin\cordis.patch.yml"

# 方式 2：安装到 profile 后启动
dsh plugin --profile dev add "$env:USERPROFILE\my-dsh-plugin"
dsh --profile dev
```

**调试技巧**：
- 修改代码后，HMR 会自动热替换插件（需 `@deepseek-ai/cordis-plugin-hmr` 已加载）
- 查看浏览器控制台和终端输出，确认 `console.log` 是否正常打印
- 若插件未加载，检查终端是否有 `Config validation failed` 等错误信息

**插件加载成功时的控制台输出示例**：

```
[INFO] Loading plugin: my-greet-plugin
[INFO] Resolving dependencies: inject=['tools']
[INFO] Service 'tools' found, initializing...
[INFO] Plugin registered: greet (tool)
[INFO] Config loaded: { greeting: 'Hi', uppercase: false }
[INFO] Plugin 'my-greet-plugin' loaded successfully in 12ms
[INFO] DSH Web is running at http://127.0.0.1:3080
```

**HMR 触发时的日志输出示例**：

```
[HMR] Detected change in: C:\Users\Cecilia\my-dsh-plugin\src\index.ts
[HMR] Unloading old instance of 'my-greet-plugin'...
[HMR] Cleaning up registered tools: greet
[HMR] Loading new instance of 'my-greet-plugin'...
[HMR] Plugin registered: greet (tool)
[HMR] Hot reload completed in 8ms
```

### 阶段 4：重启测试（必须杀进程）

```powershell
# 1. 杀死所有 node 进程
taskkill /F /IM node.exe

# 2. 确认进程已完全终止
Get-Process node -ErrorAction SilentlyContinue

# 3. 确认无残留后，重新启动 DSH Web
pnpm dsh web --patch "$env:USERPROFILE\my-dsh-plugin\cordis.patch.yml"
```

### 阶段 5：发布到 npm 注册表

```powershell
# 1. 登录 npm（首次）
npm login

# 2. 构建
npm run build

# 3. 发布（确保已构建，发布的是编译产物）
npm publish --access public
```

用户安装方式：
```powershell
# 从 npm 安装
dsh plugin --profile demo add my-greet-plugin

# 从 GitHub 安装（需配置 allowBuilds）
dsh plugin --profile demo add github:your-username/my-greet-plugin

# 从 tarball 安装
npm pack
dsh plugin --profile demo add ./my-greet-plugin-0.1.0.tgz
```

---

## 插件测试指南

### 单元测试

使用 Vitest 测试插件逻辑：

`vitest.config.ts`：
```ts
import { defineConfig } from 'vitest/config'

export default defineConfig({
  test: {
    environment: 'node',
    include: ['test/**/*.test.ts'],
  },
})
```

`test/index.test.ts`：
```ts
import { describe, it, expect } from 'vitest'
import { Config } from '../src/index'
import Schema from '@deepseek-ai/schemastery'

describe('my-greet-plugin', () => {
  it('Config schema validates correct input', () => {
    const result = Schema.resolve(Config, { greeting: 'Hi', uppercase: true })
    expect(result.valid).toBe(true)
  })

  it('Config schema fills defaults', () => {
    const result = Schema.resolve(Config, {})
    expect(result.valid).toBe(true)
    expect(result.value.greeting).toBe('Hello')
    expect(result.value.uppercase).toBe(false)
  })

  it('Config schema rejects invalid types', () => {
    const result = Schema.resolve(Config, { greeting: 123 })
    expect(result.valid).toBe(false)
  })
})
```

运行测试：
```powershell
npm test
```

### 集成测试

1. 启动 DSH Web 并加载插件
2. 在 Web UI 中发送消息触发工具调用
3. 验证工具返回结果符合预期
4. 检查浏览器控制台无报错

### 手动测试检查清单

- [ ] 插件加载无报错
- [ ] 工具出现在可用工具列表中
- [ ] 工具调用返回正确结果
- [ ] 配置修改后 HMR 正常生效
- [ ] 重启后插件仍然正常工作
- [ ] 卸载插件后无残留

---

## CI/CD 配置示例

### GitHub Actions 自动测试与发布

`.github/workflows/ci.yml`：
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
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
      - run: npm ci
      - run: npm test
      - run: npm run build

  publish:
    needs: test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main' && github.event_name == 'push'
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
          registry-url: 'https://registry.npmjs.org'
      - run: npm ci
      - run: npm run build
      - run: npm publish --access public
        env:
          NODE_AUTH_TOKEN: ${{ secrets.NPM_TOKEN }}
```

### 版本管理

遵循语义化版本（SemVer）：
- `patch`：bug 修复，向后兼容
- `minor`：新功能，向后兼容
- `major`：破坏性变更

```powershell
# 自动升级版本
npm version patch   # 0.1.0 → 0.1.1
npm version minor   # 0.1.0 → 0.2.0
npm version major   # 0.1.0 → 1.0.0
```

---

## 插件模板生成脚本

使用以下脚本快速生成插件项目骨架：

```powershell
# new-plugin.ps1 - 创建新插件项目
param(
    [Parameter(Mandatory=$true)]
    [string]$Name,
    [string]$Description = "A DSH plugin"
)

$targetDir = Join-Path $pwd $Name
if (Test-Path $targetDir) {
    Write-Error "Directory already exists: $targetDir"
    exit 1
}

# 创建目录结构
New-Item -ItemType Directory -Path "$targetDir\src" -Force | Out-Null
New-Item -ItemType Directory -Path "$targetDir\test" -Force | Out-Null

# 创建 package.json
$packageJson = @{
    name = $Name
    version = "0.1.0"
    type = "module"
    description = $Description
    main = "src/index.ts"
    files = @("src", "cordis.patch.yml")
    scripts = @{
        build = "tsc"
        test = "vitest run"
        prepare = "npm run build"
    }
    dsh = @{
        bundle = @{
            patch = "./cordis.patch.yml"
        }
    }
} | ConvertTo-Json -Depth 10

$packageJson | Out-File -FilePath "$targetDir\package.json" -Encoding UTF8

# 创建 src/index.ts
@"
import type { Context } from '@deepseek-ai/cordis'
import Schema from '@deepseek-ai/schemastery'

export const name = '$Name'

export interface Config {
  // Define your config fields here
}

export const Config: Schema<Config> = Schema.object({
  // Define your schema here
})

export function apply(ctx: Context, config: Config) {
  // Register your plugin capabilities here
}
"@ | Out-File -FilePath "$targetDir\src\index.ts" -Encoding UTF8

# 创建 cordis.patch.yml
@"
- insert:
    - id: $($Name.Replace('-', '_'))
      name: $Name
"@ | Out-File -FilePath "$targetDir\cordis.patch.yml" -Encoding UTF8

# 创建 tsconfig.json
@"
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "outDir": "dist"
  },
  "include": ["src"]
}
"@ | Out-File -FilePath "$targetDir\tsconfig.json" -Encoding UTF8

Write-Host "[OK] Plugin project created at $targetDir"
Write-Host "Next steps:"
Write-Host "  cd $Name"
Write-Host "  npm install"
Write-Host "  npm install --save-dev typescript @types/node vitest"
Write-Host "  npm install @deepseek-ai/cordis @deepseek-ai/schemastery @deepseek-ai/dsh-tools"
```

使用方式：
```powershell
. "$env:USERPROFILE\.dsh\skills\dsh-plugin-dev\scripts\new-plugin.ps1" -Name "my-new-plugin"
```

### 使用场景说明

- 快速原型：想在 30 秒内验证一个插件想法时
- 脚手架复用：需要创建多个结构相同的新插件时
- 教学演示：向新手展示标准插件项目结构时

---

## 自动化测试脚本

以下脚本用于自动化验证插件是否正确加载：

```powershell
# test-plugin-load.ps1 - 验证插件加载状态（含重试机制）
#
# 重试机制工作原理：
# 1. 脚本按 RetryCount（默认 3 次）依次尝试检测 DSH Web 是否就绪
# 2. 每次检测分三层：node 进程是否存在 → 端口 3080 是否监听 → HTTP 200 是否返回
# 3. 任一层失败则等待 RetryIntervalSeconds（默认 5 秒）后重试
# 4. 全部重试耗尽后返回非零退出码（exit 1）
# 5. 当遇到网络波动或 DSH Web 启动较慢时，重试机制可避免误报失败
#
# 使用场景：
# - 当遇到网络问题时，脚本会自动重试，无需手动重新执行
# - CI/CD 流水线中，DSH Web 启动时间不确定时，重试确保测试稳定性
# - 本地开发中，重启 DSH Web 后立即验证插件是否加载成功
param(
    [Parameter(Mandatory=$true)]
    [string]$PluginName,
    [int]$TimeoutSeconds = 30,
    [int]$RetryCount = 3,
    [int]$RetryIntervalSeconds = 5
)

function Test-DshWeb {
    # 1. 检查 node 进程是否运行
    $nodeProcess = Get-Process node -ErrorAction SilentlyContinue
    if (-not $nodeProcess) {
        Write-Warn "[FAIL] No node process found. Is DSH Web running?"
        return $false
    }

    # 2. 检查端口是否监听
    $portTest = Test-NetConnection -ComputerName 127.0.0.1 -Port 3080 -WarningAction SilentlyContinue
    if (-not $portTest.TcpTestSucceeded) {
        Write-Warn "[FAIL] Port 3080 is not listening. Is DSH Web running?"
        return $false
    }

    # 3. 检查 HTTP 响应
    try {
        $response = Invoke-WebRequest -Uri "http://127.0.0.1:3080" -TimeoutSec 5 -ErrorAction Stop
        if ($response.StatusCode -eq 200) {
            Write-Host "[OK] DSH Web is responding (HTTP 200)"
            return $true
        }
    } catch {
        Write-Warn "[FAIL] DSH Web is not responding: $_"
        return $false
    }
    return $false
}

Write-Host "[INFO] Testing plugin load: $PluginName"
Write-Host "[INFO] Retry config: max $RetryCount attempts, ${RetryIntervalSeconds}s interval"

# 重试循环
$success = $false
for ($i = 1; $i -le $RetryCount; $i++) {
    Write-Host "[INFO] Attempt $i of $RetryCount..."
    if (Test-DshWeb) {
        $success = $true
        break
    }
    if ($i -lt $RetryCount) {
        Write-Host "[INFO] Waiting $RetryIntervalSeconds seconds before retry..."
        Start-Sleep -Seconds $RetryIntervalSeconds
    }
}

if ($success) {
    Write-Host "[OK] Plugin load test completed for: $PluginName"
    Write-Host "[INFO] Please verify in browser console that the plugin loaded without errors"
} else {
    Write-Error "[FAIL] Plugin load test failed after $RetryCount attempts. Check if DSH Web is running and accessible."
    exit 1
}
```

---

## 错误处理与排查指南

### 插件加载失败

| 错误码 | 错误信息 | 原因 | 解决方案 |
|--------|----------|------|----------|
| `E_CFG_VALIDATION` | `Config validation failed` | 配置不符合 Schema 定义 | 检查 `cordis.yml` 中的 config 字段类型是否与 Schema 定义一致 |
| `E_MODULE_NOT_FOUND` | `Cannot find module '...'` | 依赖未安装 | 运行 `npm install` 安装缺失依赖 |
| `E_SERVICE_NOT_FOUND` | `inject: ['xxx'] service not found` | 依赖的服务未加载 | 检查服务名称拼写，确认提供该服务的插件已启用 |
| `E_DUPLICATE_PLUGIN` | `Plugin 'xxx' already registered` | 插件 ID 重复 | 修改 `cordis.yml` 中的 `id` 确保唯一 |
| `E_COMPILE_ERROR` | `SyntaxError: Unexpected token` | TypeScript 编译失败 | 运行 `npm run build` 查看详细编译错误 |

### 工具调用失败

| 错误码 | 错误现象 | 原因 | 解决方案 |
|--------|----------|------|----------|
| `E_TOOL_NOT_LOADED` | 工具未出现在工具列表 | 插件未成功加载 | 检查终端输出，排查加载错误 |
| `E_TOOL_NOT_FOUND` | 工具调用返回 `tool not found` | 工具名称不匹配 | 确认 `defineTool` 中的 `name` 与注册一致 |
| `E_TOOL_TIMEOUT` | 工具执行超时 | execute 函数耗时过长 | 优化异步逻辑，或检查外部 API 是否可达 |
| `E_TOOL_OUTPUT` | 工具返回格式错误 | output.render 实现有误 | 确保 render 返回 `ContentBlock[]` 格式 |

### HMR 热替换失败

| 错误码 | 错误现象 | 原因 | 解决方案 |
|--------|----------|------|----------|
| `E_HMR_DISABLED` | 修改代码后插件未更新 | HMR 未启用 | 确认 `@deepseek-ai/cordis-plugin-hmr` 已加载 |
| `E_HMR_DUPLICATE` | 修改后报错 `already registered` | 旧实例未正确清理 | 完全重启 DSH Web（先杀进程再启动） |
| `E_HMR_CONFIG` | 配置修改后插件崩溃 | 新配置未通过 Schema 校验 | 检查配置值是否符合 Schema 定义 |

### 发布与安装失败

| 错误码 | 错误信息 | 原因 | 解决方案 |
|--------|----------|------|----------|
| `E_NPM_AUTH` | `npm publish: 403` | 未登录或包名已被占用 | 运行 `npm login`，或更换包名 |
| `E_PREPARE_DENIED` | `dsh plugin add: ERR_PNPM_PREPARE_SCRIPT_DENIED` | Git 安装未配置 allowBuilds | 在 `pnpm-workspace.yaml` 中添加 `allowBuilds: <package>: true` |
| `E_RUNTIME_DEP` | `Cannot find module 'xxx' after install` | 缺少运行时依赖 | 将依赖添加到 `dependencies` 而非 `devDependencies` |
| `E_PREPARE_FAILED` | `prepare script failed` | 构建脚本执行失败 | 本地运行 `npm run prepare` 排查构建错误 |

---

## 反模式与常见错误

### 反模式

**1. 硬编码路径**
```ts
// 错误
const configPath = 'C:\\Users\\Cecilia\\config.json'

// 正确
const configPath = Join-Path $env:USERPROFILE 'config.json'
```

**2. 忽略版本兼容性**
```json
// 错误：使用过于宽泛的版本范围
"@deepseek-ai/cordis": "*"

// 正确：锁定兼容版本范围
"@deepseek-ai/cordis": "^1.0.0"
```

**3. 在 apply 中执行阻塞操作**
```ts
// 错误：同步阻塞
export function apply(ctx: Context) {
  const data = fs.readFileSync('large-file.json') // 阻塞加载
}

// 正确：异步非阻塞
export function apply(ctx: Context) {
  ctx.effect(() => {
    const data = await fs.promises.readFile('large-file.json')
    return () => { /* cleanup */ }
  })
}
```

**4. 忘记声明依赖**
```ts
// 错误：使用 tools 但未声明 inject
export function apply(ctx: Context) {
  ctx.tools.register(/* ... */) // 可能因 tools 未就绪而失败
}

// 正确
export const inject = ['tools']
export function apply(ctx: Context) {
  ctx.tools.register(/* ... */)
}
```

**5. 配置 Schema 使用普通对象**
```ts
// 错误
export const Config = { greeting: 'Hello' }

// 正确
export const Config = Schema.object({
  greeting: Schema.string().default('Hello'),
})
```

**6. 在 waterfall 事件中忘记调用 next()**
```ts
// 错误：管道被截断
ctx.on('transform', async (input, next) => {
  return input.toUpperCase() // 下游监听器不会执行
})

// 正确
ctx.on('transform', async (input, next) => {
  const downstream = await next()
  return downstream.toUpperCase()
})
```

**7. 手动清理 ctx 注册资源**
```ts
// 错误：手动清理（框架已自动处理）
export function apply(ctx: Context) {
  const dispose = ctx.on('event', handler)
  // 不需要手动调用 dispose()
}

// 正确：依赖框架自动清理
export function apply(ctx: Context) {
  ctx.on('event', handler)
  // 需要手动清理的资源使用 ctx.effect()
  ctx.effect(() => {
    const resource = createResource()
    return () => resource.cleanup()
  })
}
```

---

## 能力边界（本技能不覆盖的内容）

| 不在范围内 | 原因 | 替代方案 |
|-----------|------|----------|
| Cordis 框架内部原理 | 本技能聚焦插件开发，不深入框架源码实现 | 阅读官方框架文档 `framework/index.md` |
| 插件市场审核流程 | DSH 目前无集中插件市场，发布走 npm 或 GitHub | 遵循 npm 发布规范 |
| 高级 TypeScript 类型体操 | 插件开发使用基础类型即可，高级类型非必需 | 参考 TypeScript 官方 Handbook |
| 底层 Node.js 调试 | 本技能覆盖应用层调试（终端日志、浏览器控制台） | 使用 VS Code debugger 或 `node --inspect` |
| 插件 UI 开发（React/Vue 组件） | DSH 插件以工具注册为主，不涉及前端组件开发 | 参考 DSH Web 扩展文档 |

---

## FAQ

### 如何调试插件？

1. **终端输出**：使用 `console.log` 在关键位置打印，观察终端输出
2. **浏览器控制台**：打开 DevTools → Console，查看前端日志
3. **配置导出**：运行 `dsh --profile <name> --dump-config` 查看最终合并的配置
4. **断点调试**：在 VS Code 中配置 attach 调试器到 Node.js 进程

### 如何测试插件？

- 单元测试：使用 Vitest 测试纯逻辑（Schema 校验、工具 execute 函数）
- 集成测试：启动 DSH Web 后手动触发工具调用
- 自动化：使用 CI/CD 在每次提交时运行测试套件

### 如何发布到 npm 注册表？

1. 确保 `package.json` 中 `files` 字段包含所有需要发布的文件
2. 运行 `npm login` 登录
3. 运行 `npm run build` 构建
4. 运行 `npm publish --access public` 发布
5. 用户通过 `dsh plugin --profile <name> add <package-name>` 安装

### 如何从 GitHub 安装插件？

```powershell
dsh plugin --profile demo add github:username/repo
```

注意：Git 安装需要配置 `allowBuilds`，且会运行 `prepare` 脚本。建议优先使用 npm 发布。

### 插件和技能（Skill）有什么区别？

- **插件（Plugin）**：TypeScript 模块，通过 Cordis 框架注册工具、服务、事件监听器，运行在 Node.js 环境中
- **技能（Skill）**：Markdown 指令文件（SKILL.md），为 AI 代理提供任务指导，不直接运行代码

### 如何让插件支持 HMR？

确保 `@deepseek-ai/cordis-plugin-hmr` 已在 `cordis.yml` 中加载。修改插件源文件后，框架会自动卸载旧实例并加载新代码。

### 插件之间如何通信？

1. **服务注入**：一个插件提供服务，另一个通过 `inject` 消费
2. **事件系统**：使用 `ctx.emit()` / `ctx.on()` 进行松耦合通信
3. **共享配置**：通过 `cordis.yml` 的 config 字段传递

### 如何处理异步资源清理？

使用 `ctx.effect()` 注册清理函数：
```ts
ctx.effect(() => {
  const connection = createConnection()
  return async () => {
    await connection.close() // 异步清理
  }
})
```

---

## 插件性能优化指南

### 懒加载（Lazy Loading）

对于非核心功能，延迟初始化以减少启动开销：

```ts
export function apply(ctx: Context, config: Config) {
  // 错误：启动时立即初始化所有资源
  const heavyResource = createHeavyResource()

  // 正确：按需初始化
  let heavyResource: HeavyResource | null = null
  ctx.tools.register(defineTool({
    name: 'heavy-tool',
    async execute(args) {
      if (!heavyResource) {
        heavyResource = await createHeavyResource()
      }
      return heavyResource.process(args)
    },
  }))
}
```

### 代码分割（Code Splitting）

将大型插件拆分为多个子模块，利用动态 `import()` 实现按需加载：

```ts
export function apply(ctx: Context, config: Config) {
  ctx.tools.register(defineTool({
    name: 'analyze',
    async execute(args) {
      // 仅在调用时加载分析模块
      const { analyze } = await import('./analyzer.js')
      return analyze(args)
    },
  }))
}
```

### 缓存策略

```ts
// 使用内存缓存避免重复计算
const cache = new Map<string, { data: unknown; expiry: number }>()

function getCached(key: string, ttlMs: number): unknown | null {
  const entry = cache.get(key)
  if (entry && Date.now() < entry.expiry) {
    return entry.data
  }
  cache.delete(key)
  return null
}

function setCache(key: string, data: unknown, ttlMs: number) {
  cache.set(key, { data, expiry: Date.now() + ttlMs })
}
```

### 性能检查清单

- [ ] 启动时无不必要的同步 I/O
- [ ] 大型数据集使用流式处理而非一次性加载
- [ ] 频繁调用的工具使用缓存
- [ ] 非核心模块使用动态 import 懒加载
- [ ] 定期使用 `--dump-config` 检查配置加载耗时

---

## 插件安全最佳实践

### 输入校验

```ts
// 错误：直接使用用户输入
async execute(args) {
  const url = args.url // 未校验
  return fetch(url) // 可能请求内网地址
}

// 正确：白名单校验
async execute(args) {
  const url = new URL(args.url)
  const ALLOWED_HOSTS = ['api.example.com', 'cdn.example.com']
  if (!ALLOWED_HOSTS.includes(url.hostname)) {
    throw new Error(`Host not allowed: ${url.hostname}`)
  }
  return fetch(url)
}
```

### 权限控制

```ts
export function apply(ctx: Context, config: Config) {
  ctx.tools.register(defineTool({
    name: 'file-read',
    async execute(args) {
      // 限制可访问的目录范围
      const safePath = resolve(config.allowedDir, args.path)
      if (!safePath.startsWith(config.allowedDir)) {
        throw new Error('Access denied: path traversal detected')
      }
      return fs.promises.readFile(safePath, 'utf-8')
    },
  }))
}
```

### 敏感信息保护

```ts
// 错误：在日志中打印敏感信息
console.log('API Key:', config.apiKey)

// 正确：脱敏处理
const masked = config.apiKey.slice(0, 4) + '****' + config.apiKey.slice(-4)
console.log('API Key:', masked)
```

### 安全清单

- [ ] 所有外部输入经过校验（URL、文件路径、用户文本）
- [ ] 工具执行有超时限制，防止资源耗尽
- [ ] 不在日志或错误信息中暴露密钥、Token
- [ ] 文件操作限制在沙箱目录内
- [ ] 网络请求使用白名单，防止 SSRF

---

## 插件版本迁移指南（v1 → v2）

### 常见破坏性变更与应对

| 变更类型 | v1 写法 | v2 写法 | 迁移说明 |
|---------|---------|---------|---------|
| 配置 Schema | `Schema.object({...})` | `Schema.object({...}).description('...')` | 新增 description 字段，建议补充 |
| 工具注册 | `ctx.tools.register(def)` | `ctx.tools.register(def).description('...')` | 链式调用增加描述 |
| 事件监听 | `ctx.on('event', fn)` | `ctx.on('event', fn, { prepend: true })` | 新增选项参数 |
| 服务注入 | `export const inject = ['svc']` | `export const inject = { svc: { required: true } }` | 支持声明可选依赖 |

### 迁移步骤

1. **评估影响**：运行 `npm outdated` 检查依赖版本
2. **更新依赖**：升级 `@deepseek-ai/cordis` 到目标版本
3. **兼容性测试**：运行现有测试套件，定位失败用例
4. **增量迁移**：按上表逐项修改，每次修改后运行测试
5. **发布 major 版本**：破坏性变更需升级 `package.json` 的 major 版本号

### 向后兼容策略

```ts
// 同时支持新旧配置格式
export const Config: Schema<Config> = Schema.object({
  // 新字段
  newField: Schema.string().default('auto'),
  // 旧字段保留为 deprecated，迁移期后移除
  oldField: Schema.string().default('legacy').deprecated('Use newField instead'),
})
```

---

## 最佳实践速查表

> 一行一条，10 条核心原则，快速查阅。

| # | 原则 | 要点 |
|---|------|------|
| 1 | 配置驱动 | 所有可调参数通过 Config Schema 暴露，禁止硬编码 |
| 2 | 依赖声明 | 明确声明 `inject`，让框架管理加载顺序 |
| 3 | 自动清理 | 利用 `ctx.effect()` 管理资源生命周期，不手动清理 |
| 4 | Schema 校验 | 使用 Schemastery 定义配置，利用默认值和类型检查 |
| 5 | 渐进式复杂度 | 从函数形式开始，仅在需要时切换到类形式 |
| 6 | 版本锁定 | 在 `package.json` 中使用合理的版本范围，避免破坏性更新 |
| 7 | 测试覆盖 | 为工具 execute 函数和 Config Schema 编写单元测试 |
| 8 | 文档同步 | 更新插件功能时同步更新 README 和代码注释 |
| 9 | 发布前验证 | 本地先 `npm pack` 检查打包内容，确认只包含必要文件 |
| 10 | Git 安装备选 | 提供 npm 发布和 GitHub 安装两种方式，降低用户使用门槛 |

## 最佳实践总结

1. **配置驱动**：所有可调参数通过 Config Schema 暴露，禁止硬编码
2. **依赖声明**：明确声明 `inject`，让框架管理加载顺序
3. **自动清理**：利用 `ctx.effect()` 管理资源生命周期，不手动清理
4. **Schema 校验**：使用 Schemastery 定义配置，利用默认值和类型检查
5. **渐进式复杂度**：从函数形式开始，仅在需要时切换到类形式
6. **版本锁定**：在 `package.json` 中使用合理的版本范围，避免破坏性更新
7. **测试覆盖**：为工具 execute 函数和 Config Schema 编写单元测试
8. **文档同步**：更新插件功能时同步更新 README 和代码注释
9. **发布前验证**：本地先 `npm pack` 检查打包内容，确认只包含必要文件
10. **Git 安装备选**：提供 npm 发布和 GitHub 安装两种方式，降低用户使用门槛

---

## DSH 插件命名规范

开发 DSH 插件时，`name` 和 `id` 必须遵循以下规则：
- **name**：`@BlueChonk/<代码仓库名>`，例如 `@BlueChonk/dsh-balance-phoebe`
- **id**：直接使用代码仓库名，例如 `dsh-balance-phoebe`
- `cordis.patch.yml` 中的 `id` 和 `name` 都要与上述保持一致
- `lib/index.js`（或 `src/index.ts`）中导出的 `name` 也要一致

---

## DSH 插件开发重启测试

在 DSH 插件（plugin）开发过程中，重启测试时必须先将 node 进程完全杀死，再重启 DSH Web。

**操作步骤：**

1. 杀死所有 node 进程：
```powershell
taskkill /F /IM node.exe
```

2. 确认进程已完全终止：
```powershell
Get-Process node -ErrorAction SilentlyContinue
```

3. 确认无残留进程后，再重新启动 DSH Web。

**注意：** 不要直接重启而不杀进程，否则可能出现端口占用、缓存残留等问题，导致测试结果不准确。

---

## DSH 插件开发安装策略

开发阶段与完成后的插件安装方式不同：

| 阶段 | 命令 | 说明 |
|------|------|------|
| **开发阶段** | `dsh plugin --profile web add "link:C:/本地项目路径"` | 使用 link 方式，本地代码实时同步，无需重新安装 |
| **完成后** | `dsh plugin --profile web add "github:BlueChonk/项目名"` | 从 GitHub 下载最新 release 版本 |

**规则：**
- 开发调试时一律使用 `link:` 方式，修改本地代码后重启 DSH Web 即可生效
- 功能完成并推送到 GitHub 后，切换为 `github:` 方式安装，确保使用的是稳定发布版
- 切换方式：先 `dsh plugin --profile web remove "@作者/包名"` 删除旧链接，再用对应方式重新安装

---

## 加载顺序与配置优先级

配置按以下顺序叠加应用（后层覆盖前层）：

1. Profile 的 `dsh.profile.bundles` 列表中的每个 bundle patch（按列表顺序）
2. Profile 自身的 `cordis.patch.yml`
3. Home 级别的 `$DSH_HOME/cordis.patch.yml`
4. 命令行 `--patch <path>` 覆盖层（按 argv 顺序）

**关键规则**：
- 后层覆盖前层是按行（row）整体替换，不是深度合并
- 一个 patch 可以通过 `id` 覆盖前面层的整行配置
- 用户可以在 profile 的 `cordis.patch.yml` 中覆盖 bundle 的行，无需修改 bundle 源码
