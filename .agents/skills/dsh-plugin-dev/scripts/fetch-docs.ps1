# 智能获取/更新 DSH 官方开发文档（含错误处理与重试）
param(
    [int]$MaxRetries = 3,
    [int]$RetryDelaySeconds = 5
)

$skillDir = Join-Path $env:USERPROFILE ".dsh\skills\dsh-plugin-dev"
$docsDir = Join-Path $skillDir "deepseek-harness-docs"
$repoUrl = "https://github.com/deepseek-ai/deepseek-harness.git"

function Invoke-WithRetry {
    param(
        [scriptblock]$ScriptBlock,
        [string]$OperationName,
        [int]$MaxAttempts = $MaxRetries
    )
    $lastError = $null
    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        try {
            $result = & $ScriptBlock
            return $result
        } catch {
            $lastError = $_
            Write-Warn "[WARN] ${OperationName} 失败 (尝试 ${attempt}/${MaxAttempts}): $($_.Exception.Message)"
            if ($attempt -lt $MaxAttempts) {
                Write-Host "[INFO] ${RetryDelaySeconds} 秒后重试..."
                Start-Sleep -Seconds $RetryDelaySeconds
            }
        }
    }
    throw "[ERROR] ${OperationName} 在 ${MaxAttempts} 次尝试后仍然失败: $($lastError.Exception.Message)"
}

# 检查 git 是否可用
try {
    $gitVersion = git --version 2>&1
    if ($LASTEXITCODE -ne 0) { throw "git not found" }
    Write-Host "[OK] Git 版本: $gitVersion"
} catch {
    Write-Error "[ERROR] 未检测到 Git。请先安装 Git: https://git-scm.com/downloads"
    exit 1
}

# 主逻辑
try {
    if (Test-Path (Join-Path $docsDir ".git")) {
        # 已有仓库，检查更新
        Write-Host "[INFO] 检测到已有文档仓库，检查更新..."
        Push-Location $docsDir
        try {
            $localHash = Invoke-WithRetry -ScriptBlock { (git rev-parse HEAD).Trim() } -OperationName "获取本地版本"
            $remoteHash = Invoke-WithRetry -ScriptBlock {
                $output = git ls-remote origin master --heads 2>&1
                if ($LASTEXITCODE -ne 0) { throw "git ls-remote failed" }
                ($output | ForEach-Object { $_.Split()[0] })
            } -OperationName "获取远程版本"

            if ($localHash -eq $remoteHash) {
                Write-Host "[OK] 文档已是最新版本 ($localHash)"
            } else {
                Write-Host "[INFO] 文档有更新 ($localHash → $remoteHash)，正在拉取..."
                Invoke-WithRetry -ScriptBlock {
                    $output = git pull origin master 2>&1
                    if ($LASTEXITCODE -ne 0) { throw "git pull failed: $output" }
                    $output
                } -OperationName "拉取更新"
                Write-Host "[OK] 文档更新完成"
            }
        } finally {
            Pop-Location
        }
    } elseif (Test-Path $docsDir) {
        # 目录存在但不是 git 仓库
        Write-Warn "[WARN] 目录存在但不是 git 仓库: $docsDir"
        Write-Host "[INFO] 删除旧目录并重新获取..."
        Remove-Item -Recurse -Force $docsDir
        if (Test-Path $docsDir) {
            throw "无法删除目录，请手动删除: $docsDir"
        }
        # 继续执行下面的 clone 逻辑
        $needClone = $true
    } else {
        $needClone = $true
    }

    if ($needClone) {
        Write-Host "[INFO] 首次获取文档，正在 clone..."
        Invoke-WithRetry -ScriptBlock {
            $output = git clone --depth 1 --filter=blob:none --sparse $repoUrl $docsDir 2>&1
            if ($LASTEXITCODE -ne 0) { throw "git clone failed: $output" }
            $output
        } -OperationName "Clone 仓库"

        Push-Location $docsDir
        try {
            Invoke-WithRetry -ScriptBlock {
                $output = git sparse-checkout set docs/user/develop 2>&1
                if ($LASTEXITCODE -ne 0) { throw "sparse-checkout failed: $output" }
                $output
            } -OperationName "设置稀疏检出"
        } finally {
            Pop-Location
        }
        Write-Host "[OK] 文档获取完成"
    }
} catch {
    Write-Error "[ERROR] 文档获取失败: $($_.Exception.Message)"
    Write-Host ""
    Write-Host "常见解决方案:"
    Write-Host "  1. 网络问题: 检查网络连接，或配置 Git 代理:"
    Write-Host "     git config --global http.proxy http://127.0.0.1:7890"
    Write-Host "     git config --global https.proxy http://127.0.0.1:7890"
    Write-Host "  2. 权限问题: 以管理员权限运行 PowerShell"
    Write-Host "  3. 目录占用: 关闭可能占用 deepseek-harness-docs 目录的程序"
    Write-Host "  4. 手动获取: 自行 clone 仓库到 $docsDir"
    exit 1
}
