<#
.SYNOPSIS
    DSH 插件项目模板生成脚本
.DESCRIPTION
    快速生成一个符合 DSH 插件规范的项目骨架，包含标准目录结构、
    配置文件、示例代码和测试框架。
.PARAMETER Name
    插件名称（npm 包名格式，如 my-greet-plugin）
.PARAMETER Description
    插件描述
.PARAMETER Path
    创建路径（默认为当前目录）
.EXAMPLE
    .\new-plugin.ps1 -Name "my-greet-plugin"
    .\new-plugin.ps1 -Name "my-tool" -Description "A custom tool plugin" -Path "$env:USERPROFILE\projects"
#>
param(
    [Parameter(Mandatory=$true)]
    [ValidatePattern('^[a-z0-9][a-z0-9-]*$')]
    [string]$Name,

    [string]$Description = "A DSH plugin",

    [string]$Path = $pwd
)

$ErrorActionPreference = 'Stop'

$targetDir = Join-Path $Path $Name
if (Test-Path $targetDir) {
    Write-Error "目录已存在: $targetDir"
    exit 1
}

Write-Host "[INFO] 正在创建插件项目: $Name"

# 创建目录结构
$dirs = @(
    "$targetDir\src",
    "$targetDir\test"
)
foreach ($dir in $dirs) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
}

# 创建 package.json
$packageJson = @"
{
  "name": "$Name",
  "version": "0.1.0",
  "type": "module",
  "description": "$Description",
  "main": "src/index.ts",
  "files": ["src", "cordis.patch.yml"],
  "scripts": {
    "build": "tsc",
    "test": "vitest run",
    "test:watch": "vitest",
    "prepare": "npm run build"
  },
  "dsh": {
    "bundle": {
      "patch": "./cordis.patch.yml"
    }
  },
  "devDependencies": {
    "typescript": "^5.4.0",
    "@types/node": "^20.0.0",
    "vitest": "^1.6.0"
  },
  "dependencies": {
    "@deepseek-ai/cordis": "latest",
    "@deepseek-ai/schemastery": "latest",
    "@deepseek-ai/dsh-tools": "latest"
  }
}
"@
$packageJson | Out-File -FilePath "$targetDir\package.json" -Encoding UTF8

# 创建 src/index.ts
$indexTs = @"
import type { Context } from '@deepseek-ai/cordis'
import Schema from '@deepseek-ai/schemastery'

export const name = '$Name'

export interface Config {
  // 在此定义配置字段
  // example: string
}

export const Config: Schema<Config> = Schema.object({
  // 在此定义 Schema
  // example: Schema.string().default('default value')
})

export function apply(ctx: Context, config: Config) {
  // 在此注册插件能力
  console.log('[${Name}] Plugin loaded!')
}
"@
$indexTs | Out-File -FilePath "$targetDir\src\index.ts" -Encoding UTF8

# 创建 cordis.patch.yml
$idName = $Name.Replace('-', '_')
$cordisPatch = @"
- insert:
    - id: $idName
      name: $Name
"@
$cordisPatch | Out-File -FilePath "$targetDir\cordis.patch.yml" -Encoding UTF8

# 创建 tsconfig.json
$tsConfig = @"
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "outDir": "dist",
    "declaration": true
  },
  "include": ["src"]
}
"@
$tsConfig | Out-File -FilePath "$targetDir\tsconfig.json" -Encoding UTF8

# 创建 vitest.config.ts
$vitestConfig = @"
import { defineConfig } from 'vitest/config'

export default defineConfig({
  test: {
    environment: 'node',
    include: ['test/**/*.test.ts'],
  },
})
"@
$vitestConfig | Out-File -FilePath "$targetDir\vitest.config.ts" -Encoding UTF8

# 创建 test/index.test.ts
$testTs = @"
import { describe, it, expect } from 'vitest'
import { Config } from '../src/index'
import Schema from '@deepseek-ai/schemastery'

describe('$Name', () => {
  it('Config schema validates correct input', () => {
    const result = Schema.resolve(Config, {})
    expect(result.valid).toBe(true)
  })

  it('Config schema fills defaults', () => {
    const result = Schema.resolve(Config, {})
    expect(result.valid).toBe(true)
  })
})
"@
$testTs | Out-File -FilePath "$targetDir\test\index.test.ts" -Encoding UTF8

# 创建 .gitignore
$gitignore = @"
node_modules/
dist/
*.log
.DS_Store
"@
$gitignore | Out-File -FilePath "$targetDir\.gitignore" -Encoding UTF8

# 创建 README.md
$readme = @"
# $Name

$Description

## 安装

\`\`\`powershell
dsh plugin --profile <profile-name> add ./$Name
\`\`\`

## 开发

\`\`\`powershell
# 安装依赖
npm install

# 运行测试
npm test

# 构建
npm run build

# 本地调试
pnpm dsh web --patch ./cordis.patch.yml
\`\`\`

## 配置

在 \`cordis.yml\` 中配置：

\`\`\`yaml
- insert:
    - id: $idName
      name: $Name
      config:
        # 在此添加配置
\`\`\`
"@
$readme | Out-File -FilePath "$targetDir\README.md" -Encoding UTF8

Write-Host "[OK] 插件项目已创建: $targetDir"
Write-Host ""
Write-Host "下一步:"
Write-Host "  cd $Name"
Write-Host "  npm install"
Write-Host "  npm test"
Write-Host "  pnpm dsh web --patch ./cordis.patch.yml"
