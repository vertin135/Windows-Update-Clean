# Windows Update 缓存清理脚本

## 项目简介

一款**高安全性、高性能**的PowerShell脚本，用于清理Windows Update和Microsoft Office Update的本地缓存文件，解决系统更新缓存占用磁盘空间、更新失败等问题。脚本在保留核心清理功能的基础上，做了**权限自动校验、文件自动备份、操作日志记录、多任务并行处理**等增强，兼顾使用安全性和执行效率，避免误删系统文件、服务异常等风险。

## 核心特性

### ✅ 安全防护

1. 管理员权限自动校验，非管理员运行时自动提权

2. 清理前**异步备份**缓存文件至系统临时目录，误删可恢复

3. 仅过滤清理更新相关文件（.cab/.msu/.pkg等），避免删除无关文件

4. 清理前交互式确认，防止误操作

### ✅ 性能优化

1. **批量IO操作**，替代逐文件删除/备份，减少磁盘IO调用次数

2. **异步备份**，备份在后台执行，不阻塞核心清理流程

3. **多目录并行清理**，利用多核CPU提升效率（PowerShell 7+支持）

4. **内存日志缓存**，批量写入日志文件，减少磁盘频繁读写

### ✅ 健壮性增强

1. 处理Windows Update相关依赖服务（wuauserv/bits/cryptsvc），按顺序启停

2. 服务状态校验，确保核心服务停止后再执行清理，避免文件占用

3. 完整的错误捕获，单个文件/步骤失败不影响整体执行，记录失败详情

4. 脚本出错时自动重启更新服务，防止系统服务异常

5. 兼容PowerShell 5.1/7+，无交互环境下自动适配退出逻辑

### ✅ 可追溯性

1. 所有操作（启动/停止/备份/清理/失败）均记录日志

2. 日志文件保存至桌面，包含时间戳、操作详情、错误信息

3. 统计清理文件数量、失败文件数，清晰展示执行结果

## 脚本信息

- **脚本名称**：CleanUpdatesFiles.ps1

- **适用系统**：Windows 10/11 32/64位

- **PowerShell版本**：PowerShell 5.1（兼容）、PowerShell 7+（推荐，支持并行）

- **运行权限**：管理员权限（脚本自动校验/提权）

## 清理范围

|缓存目录|描述|
|---|---|
|C:\Windows\SoftwareDistribution\Download|Windows Update 核心缓存目录|
|C:\Program Files\Microsoft Office\Updates\Download\PackageFiles|Microsoft Office 更新缓存目录|
## 快速使用

### 步骤1：下载脚本

将脚本文件`CleanUpdatesFiles.ps1`保存至本地任意目录（如桌面、下载文件夹）。

### 步骤2：运行脚本

**推荐方式**：右键点击脚本文件 → 选择**以管理员身份运行**，无需手动修改PowerShell执行策略，脚本自动处理。

### 步骤3：执行操作

1. 脚本启动后自动校验权限和执行策略，非管理员会自动弹窗提权；

2. 停止相关更新服务后，会提示**确认清理所有更新缓存吗？(Y/N)**，输入`Y`并回车开始清理，输入其他键则取消；

3. 清理过程中实时输出操作日志，包含备份、文件清理、服务启停等详情；

4. 执行完成后，按任意键退出（无交互环境自动延时退出）。

### 步骤4：查看结果

1. **实时日志**：脚本运行窗口直接查看执行过程和结果；

2. **本地日志**：桌面自动生成`UpdateCleaner.log`文件，包含完整操作记录，可后续追溯；

3. **备份文件**：缓存文件自动备份至`%TEMP%\UpdateCache_Backup_时间戳`目录，若清理后出现异常，可从该目录恢复文件。

## 高级说明

### 配置项自定义

脚本头部**配置区**可根据需求修改，无需改动核心逻辑：

```PowerShell

# 日志保存路径（默认：桌面）
$logPath = "$env:USERPROFILE\Desktop\UpdateCleaner.log"
# 备份目录（默认：系统临时目录，带时间戳）
$backupPath = "$env:TEMP\UpdateCache_Backup_$(Get-Date -Format 'yyyyMMddHHmmss')"
# 要清理的缓存路径列表（可添加/删除目录）
$cleanPaths = @(
    @{ Path = "$env:SystemRoot\SoftwareDistribution\Download"; Description = "Windows Update缓存" },
    @{ Path = "C:\Program Files\Microsoft Office\Updates\Download\PackageFiles"; Description = "Office Update缓存" }
)
# 要清理的更新文件类型（可添加/删除类型）
$fileTypes = @("*.cab", "*.msu", "*.pkg", "*.cat", "*.msp")
```

### 并行清理说明

- PowerShell 7+版本默认开启**双目录并行清理**，ThrottleLimit=2（避免磁盘IO过载）；

- PowerShell 5.1版本不支持`ForEach-Object -Parallel`，自动降级为**串行清理**，不影响功能使用；

- 若为固态硬盘（SSD），可适当提高ThrottleLimit值（如3），提升并行效率。

### 备份文件清理

脚本生成的备份文件保存在系统临时目录，**不会自动删除**，若确认清理后系统无异常，可手动删除该目录释放磁盘空间：

1. 按下`Win+R`，输入`%TEMP%`打开系统临时目录；

2. 删除名称以`UpdateCache_Backup_`开头的文件夹即可。

## 常见问题

### Q1：运行脚本提示“禁止运行脚本”？

**原因**：PowerShell执行策略限制（脚本已做自动处理，该问题极少出现）。

**解决方案**：以管理员身份打开PowerShell，执行以下命令临时放宽策略：

```PowerShell

Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
```

再切换到脚本目录重新运行：`.\CleanUpdatesFiles.ps1`。

### Q2：清理后部分文件删除失败？

**原因**：文件被系统进程占用、权限不足或文件损坏。

**解决方案**：

1. 重启电脑后重新运行脚本，避免进程占用；

2. 查看桌面日志文件，定位失败文件路径，手动删除（需管理员权限）。

### Q3：清理后Windows Update无法正常使用？

**原因**：极端情况下服务启停异常（脚本已做出错回滚，该问题极少出现）。

**解决方案**：

1. 以管理员身份打开PowerShell，手动重启更新服务：

    ```PowerShell
    
    Start-Service -Name wuauserv,bits,cryptsvc
    ```

2. 从系统临时目录的备份文件夹中恢复缓存文件；

3. 查看日志文件定位具体错误，针对性处理。

### Q4：PowerShell 5.1运行无并行效果？

**原因**：`ForEach-Object -Parallel`是PowerShell 7+的特性。

**解决方案**：

1. 无需处理，脚本自动降级为串行清理，功能不受影响；

2. 推荐安装**PowerShell 7+**，下载地址：[PowerShell 官方下载](https://learn.microsoft.com/zh-cn/powershell/scripting/install/installing-powershell-on-windows?view=powershell-7.4)。

## 脚本执行流程

```Plain Text

1. 初始化配置 → 2. 管理员权限校验（自动提权） → 3. 执行策略校验（临时放宽）
→ 4. 缓存服务状态 → 5. 停止更新相关服务 → 6. 交互式清理确认
→ 7. 异步备份缓存文件（后台） → 8. 批量/并行清理缓存文件 → 9. 等待备份完成
→ 10. 重启更新相关服务 → 11. 批量写入操作日志 → 12. 退出脚本
```

## 免责声明

1. 本脚本仅用于清理Windows/Office更新缓存，**请勿修改核心逻辑**，避免误删系统文件；

2. 脚本运行前已做多层安全防护，但仍建议在运行前备份重要系统文件，避免意外；

3. 因修改脚本、非管理员运行、系统环境异常等原因导致的系统问题，脚本作者不承担任何责任；

4. 本脚本为开源免费工具，仅限个人非商业使用，禁止用于商业盈利场景。
