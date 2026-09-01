<#
.SYNOPSIS
    DSH 插件加载验证脚本
.DESCRIPTION
    自动化验证插件是否正确加载到 DSH Web 中。
    检查 node 进程、端口监听、HTTP 响应状态。
.PARAMETER PluginName
    要验证的插件名称
.PARAMETER TimeoutSeconds
    等待超时秒数（默认 30）
.PARAMETER Port
    DSH Web 端口（默认 3080）
.EXAMPLE
    .\test-plugin-load.ps1 -PluginName "my-greet-plugin"
    .\test-plugin-load.ps1 -PluginName "my-tool" -Port 3080 -TimeoutSeconds 60
#>
param(
    [Parameter(Mandatory=$true)]
    [string]$PluginName,

    [int]$TimeoutSeconds = 30,
    [int]$Port = 3080
)

$ErrorActionPreference = 'Stop'
$passed = 0
$failed = 0

function Test-Step {
    param(
        [string]$Name,
        [scriptblock]$Test
    )
    try {
        $result = & $Test
        if ($result) {
            Write-Host "[PASS] $Name" -ForegroundColor Green
            $script:passed++
        } else {
            Write-Host "[FAIL] $Name" -ForegroundColor Red
            $script:failed++
        }
    } catch {
        Write-Host "[FAIL] $Name - $($_.Exception.Message)" -ForegroundColor Red
        $script:failed++
    }
}

Write-Host "========================================"
Write-Host "  DSH 插件加载验证: $PluginName"
Write-Host "========================================"
Write-Host ""

# 1. 检查 node 进程
Test-Step "Node.js 进程运行中" {
    $proc = Get-Process node -ErrorAction SilentlyContinue
    return ($proc -ne $null)
}

# 2. 检查端口监听
Test-Step "端口 $Port 正在监听" {
    $test = Test-NetConnection -ComputerName 127.0.0.1 -Port $Port -WarningAction SilentlyContinue
    return $test.TcpTestSucceeded
}

# 3. HTTP 响应检查
Test-Step "DSH Web HTTP 响应正常" {
    try {
        $response = Invoke-WebRequest -Uri "http://127.0.0.1:$Port" -TimeoutSec 5 -ErrorAction Stop
        return ($response.StatusCode -eq 200)
    } catch {
        return $false
    }
}

# 4. 检查插件包是否存在（如果已安装到 profile）
Test-Step "插件包文件存在" {
    $dsplHome = if ($env:DSH_HOME) { $env:DSH_HOME } else { Join-Path $env:USERPROFILE ".dsh" }
    $profilesDir = Join-Path $dsplHome "profiles"
    if (-not (Test-Path $profilesDir)) { return $false }
    $profiles = Get-ChildItem -Path $profilesDir -Directory -ErrorAction SilentlyContinue
    foreach ($profile in $profiles) {
        $pkgJson = Join-Path $profile.FullName "package.json"
        if (Test-Path $pkgJson) {
            $content = Get-Content $pkgJson -Raw
            if ($content -match $PluginName) { return $true }
        }
    }
    return $false
}

# 5. 检查 node_modules 中是否有该插件
Test-Step "插件依赖已安装" {
    $dsplHome = if ($env:DSH_HOME) { $env:DSH_HOME } else { Join-Path $env:USERPROFILE ".dsh" }
    $profilesDir = Join-Path $dsplHome "profiles"
    if (-not (Test-Path $profilesDir)) { return $false }
    $profiles = Get-ChildItem -Path $profilesDir -Directory -ErrorAction SilentlyContinue
    foreach ($profile in $profiles) {
        $nmDir = Join-Path $profile.FullName "node_modules\$PluginName"
        if (Test-Path $nmDir) { return $true }
    }
    return $false
}

Write-Host ""
Write-Host "========================================"
Write-Host "  验证结果: $passed 通过, $failed 失败"
Write-Host "========================================"

if ($failed -gt 0) {
    Write-Host ""
    Write-Host "排查建议:"
    Write-Host "  1. 检查终端输出是否有插件加载错误"
    Write-Host "  2. 运行: dsh --profile <name> --dump-config"
    Write-Host "  3. 检查浏览器控制台是否有 JavaScript 错误"
    Write-Host "  4. 确认 cordis.patch.yml 中的 name 字段正确"
    exit 1
} else {
    Write-Host ""
    Write-Host "[OK] 所有检查通过。请在浏览器中确认插件功能正常。"
    exit 0
}
