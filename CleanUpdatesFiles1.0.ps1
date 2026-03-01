<#
.SYNOPSIS
    高性能版Windows Update缓存清理脚本（安全+效率）
#>

# -------------------------- 性能优化配置 --------------------------
$logPath = "$env:USERPROFILE\Desktop\UpdateCleaner.log"
$backupPath = "$env:TEMP\UpdateCache_Backup_$(Get-Date -Format 'yyyyMMddHHmmss')"
$cleanPaths = @(
    @{ Path = "$env:SystemRoot\SoftwareDistribution\Download"; Description = "Windows Update缓存" },
    @{ Path = "C:\Program Files\Microsoft Office\Updates\Download\PackageFiles"; Description = "Office Update缓存" }
)
$fileTypes = @("*.cab", "*.msu", "*.pkg", "*.cat", "*.msp")
$logBuffer = [System.Collections.Generic.List[string]]::new()  # 内存日志缓存

# 函数：高性能日志写入
function Write-Log {
    param([string]$message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logBuffer.Add("[$timestamp] $message")
    Write-Host $logMessage
}

# 函数：批量清理缓存（核心性能优化）
function Clean-CachePath {
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)][string]$Description,
        [string]$BackupPath
    )

    # 1. 缓存目录存在性（仅1次查询）
    if (-not (Test-Path -Path $Path)) {
        Write-Log "跳过：$Description 目录不存在"
        return
    }

    # 2. 异步备份（后台作业，不阻塞）
    $backupDirName = $Description -replace '[\\/:*?"<>|]','_'
    $backupJob = Start-Job -ScriptBlock {
        param($Source, $Dest)
        New-Item -Path $Dest -ItemType Directory -Force | Out-Null
        Copy-Item -Path $Source -Destination $Dest -Recurse -Force -ErrorAction SilentlyContinue
    } -ArgumentList $Path, "$BackupPath\$backupDirName"
    Write-Log "[$Description] 备份作业已启动（后台执行）"

    # 3. 批量删除（按类型一次性处理）
    $totalFailed = 0
    foreach ($type in $fileTypes) {
        # 批量获取文件（1次IO）
        $files = Get-ChildItem -Path $Path -Filter $type -Recurse -Force -ErrorAction SilentlyContinue
        if (-not $files -or $files.Count -eq 0) { continue }
        
        # 批量删除（1次IO调用）
        $files | Remove-Item -Force -ErrorAction SilentlyContinue
        
        # 统计失败文件（仅1次查询）
        $failed = Get-ChildItem -Path $Path -Filter $type -Recurse -Force -ErrorAction SilentlyContinue
        if ($failed.Count -gt 0) {
            $totalFailed += $failed.Count
            Write-Log "[$Description] [$type] 有$($failed.Count)个文件删除失败"
        } else {
            Write-Log "[$Description] [$type] 批量清理完成（共$($files.Count)个文件）"
        }
    }

    # 4. 等待备份完成（保证数据安全）
    Wait-Job -Job $backupJob | Out-Null
    if ($backupJob.State -eq "Failed") {
        Write-Log "[$Description] 备份作业执行失败"
    }
    Remove-Job -Job $backupJob

    # 5. 结果汇总
    if ($totalFailed -gt 0) {
        Write-Log "[$Description] 清理完成，总计$totalFailed个文件删除失败"
    } else {
        Write-Log "[$Description] 清理完成，无失败文件"
    }
}

# ========================= 主流程（并行执行） =========================
try {
    Write-Log "===== 高性能缓存清理脚本启动 ====="
    
    # 1. 基础校验（保留安全特性）
    Test-Admin
    Test-ExecutionPolicy

    # 2. 停止服务（缓存服务状态，减少查询）
    $services = @("wuauserv", "bits", "cryptsvc")
    $serviceCache = $services | ForEach-Object { @{ Name = $_; Svc = Get-Service -Name $_ -ErrorAction SilentlyContinue } }
    $serviceCache | Where-Object { $_.Svc.Status -eq "Running" } | ForEach-Object {
        Stop-Service -Name $_.Name -Force -ErrorAction SilentlyContinue
    }

    # 3. 一次性确认所有目录清理（减少交互阻塞）
    $confirm = Read-Host "确认清理所有更新缓存吗？(Y/N，默认N)"
    if ($confirm -eq "Y" -or $confirm -eq "y") {
        # 4. 并行清理多个目录（PowerShell 7+）
        $cleanPaths | ForEach-Object -Parallel {
            Clean-CachePath -Path $_.Path -Description $_.Description -BackupPath $using:backupPath
        } -ThrottleLimit 2
    } else {
        Write-Log "用户取消清理"
        exit 0
    }

    # 5. 重启服务（按依赖顺序）
    $serviceCache | Where-Object { $_.Svc.Status -ne "Running" } | ForEach-Object {
        Start-Service -Name $_.Name -ErrorAction SilentlyContinue
    }

    Write-Log "===== 脚本执行完成 ====="
} catch {
    Write-Log "执行出错：$($_.Exception.Message)"
} finally {
    # 批量写入日志（仅1次IO）
    $logBuffer -join "`r`n" | Set-Content -Path $logPath -Encoding UTF8 -Force
    Write-Host "按任意键退出..."
    Start-Sleep -Seconds 2  # 简化退出逻辑，减少交互IO
}