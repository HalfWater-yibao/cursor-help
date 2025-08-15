# Cursor硬件指纹重制工具 - PowerShell在线版本
# 使用方法: irm https://raw.githubusercontent.com/你的用户名/项目名/main/cursor_win_patcher.ps1 | iex

param(
    [switch]$Force = $false
)

# 设置控制台编码为UTF-8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# 颜色定义
$Colors = @{
    Red = "Red"
    Green = "Green"
    Yellow = "Yellow"
    Blue = "Cyan"
    Purple = "Magenta"
    White = "White"
}

function Write-ColorText {
    param(
        [string]$Text,
        [string]$Color = "White"
    )
    Write-Host $Text -ForegroundColor $Colors[$Color]
}

function Write-Header {
    param([string]$Title)
    Write-Host ""
    Write-ColorText "============================================================" "Blue"
    Write-ColorText "    $Title" "Purple"
    Write-ColorText "============================================================" "Blue"
    Write-Host ""
}

function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Find-CursorPath {
    # 检查默认安装路径
    $possiblePaths = @(
        "$env:LOCALAPPDATA\Programs\cursor\resources\app",
        "$env:PROGRAMFILES\Cursor\resources\app",
        "${env:PROGRAMFILES(X86)}\Cursor\resources\app",
        "$env:USERPROFILE\AppData\Local\Programs\cursor\resources\app"
    )
    
    foreach ($path in $possiblePaths) {
        $mainJsPath = Join-Path $path "out\main.js"
        if (Test-Path $mainJsPath) {
            return $path
        }
    }
    
    # 在PATH中查找
    $pathEnv = $env:PATH -split ";"
    foreach ($p in $pathEnv) {
        try {
            $cursorExe = Join-Path $p "cursor.exe"
            if (Test-Path $cursorExe) {
                $appPath = Join-Path (Split-Path $p -Parent) "resources\app"
                $mainJsPath = Join-Path $appPath "out\main.js"
                if (Test-Path $mainJsPath) {
                    return $appPath
                }
            }
        } catch {
            continue
        }
    }
    
    return $null
}

function Stop-CursorProcess {
    Write-ColorText "🔄 检查Cursor进程..." "Yellow"
    
    $cursorProcesses = Get-Process -Name "Cursor" -ErrorAction SilentlyContinue
    if ($cursorProcesses) {
        Write-ColorText "⚠️ 发现Cursor进程，正在关闭..." "Yellow"
        
        # 温和关闭
        $cursorProcesses | ForEach-Object { $_.CloseMainWindow() }
        Start-Sleep -Seconds 3
        
        # 检查是否还在运行
        $remainingProcesses = Get-Process -Name "Cursor" -ErrorAction SilentlyContinue
        if ($remainingProcesses) {
            Write-ColorText "⚠️ 强制关闭Cursor进程..." "Yellow"
            $remainingProcesses | Stop-Process -Force
            Start-Sleep -Seconds 2
        }
        
        Write-ColorText "✅ Cursor进程已关闭" "Green"
    } else {
        Write-ColorText "ℹ️ Cursor未在运行" "Blue"
    }
}

function Start-CursorProcess {
    param([string]$AppPath)
    
    $possibleExePaths = @(
        (Join-Path (Split-Path (Split-Path $AppPath -Parent) -Parent) "Cursor.exe"),
        (Join-Path (Split-Path $AppPath -Parent) "Cursor.exe"),
        "$env:LOCALAPPDATA\Programs\cursor\Cursor.exe"
    )
    
    $cursorExe = $null
    foreach ($path in $possibleExePaths) {
        if (Test-Path $path) {
            $cursorExe = $path
            break
        }
    }
    
    if ($cursorExe) {
        Write-ColorText "🚀 正在启动Cursor..." "Blue"
        Start-Process -FilePath $cursorExe -WindowStyle Hidden
        
        # 等待启动
        for ($i = 0; $i -lt 10; $i++) {
            Start-Sleep -Seconds 1
            $process = Get-Process -Name "Cursor" -ErrorAction SilentlyContinue
            if ($process) {
                Write-ColorText "✅ Cursor已成功启动" "Green"
                return $true
            }
        }
        
        Write-ColorText "⚠️ Cursor启动超时" "Yellow"
        return $false
    } else {
        Write-ColorText "❌ 未找到Cursor可执行文件" "Red"
        return $false
    }
}

function New-RandomMac {
    do {
        $mac = (1..6 | ForEach-Object { "{0:X2}" -f (Get-Random -Maximum 256) }) -join ":"
    } while ($mac -in @("00:00:00:00:00:00", "FF:FF:FF:FF:FF:FF", "AC:DE:48:00:11:22"))
    
    return $mac
}

function New-Identifiers {
    return @{
        MachineId = [System.Guid]::NewGuid().ToString()
        MacAddress = New-RandomMac
        SqmMachineId = [System.Guid]::NewGuid().ToString()
        DeviceId = [System.Guid]::NewGuid().ToString()
    }
}

function Update-MainJs {
    param(
        [string]$MainJsPath,
        [hashtable]$Identifiers
    )
    
    # 备份文件
    $backupPath = "$MainJsPath.bak"
    if (-not (Test-Path $backupPath)) {
        Copy-Item $MainJsPath $backupPath
        Write-ColorText "✅ 已创建备份文件" "Green"
    }
    
    # 读取文件内容
    $content = Get-Content $MainJsPath -Raw -Encoding UTF8
    
    # 检查是否已经被修改
    if ($content -match "/\*csp[1-4]\*/") {
        Write-ColorText "ℹ️ 检测到已有修改，将更新..." "Blue"
    }
    
    # 应用修改
    Write-ColorText "🔧 正在修改硬件指纹..." "Yellow"
    
    # 1. Machine ID
    $content = $content -replace "=.{0,50}timeout.{0,10}5e3.*?,", "=/*csp1*/`"$($Identifiers.MachineId)`"/*1csp*/,"
    $content = $content -replace "=/\*csp1\*/.*?/\*1csp\*/,", "=/*csp1*/`"$($Identifiers.MachineId)`"/*1csp*/,"
    
    # 2. MAC地址
    $content = $content -replace "(function .{0,50}\{).{0,300}Unable to retrieve mac address.*?(\})", "`$1return/*csp2*/`"$($Identifiers.MacAddress)`"/*2csp*/;`$2"
    $content = $content -replace "()return/\*csp2\*/.*?/\*2csp\*/;()", "`$1return/*csp2*/`"$($Identifiers.MacAddress)`"/*2csp*/;`$2"
    
    # 3. SQM Machine ID
    $content = $content -replace "return.{0,50}\.GetStringRegKey.*?HKEY_LOCAL_MACHINE.*?MachineId.*?\|\|.*?`"`"", "return/*csp3*/`"$($Identifiers.SqmMachineId)`"/*3csp*/"
    $content = $content -replace "return/\*csp3\*/.*?/\*3csp\*/", "return/*csp3*/`"$($Identifiers.SqmMachineId)`"/*3csp*/"
    
    # 4. Device ID
    $content = $content -replace "return.{0,50}vscode\/deviceid.*?getDeviceId\(\)", "return/*csp4*/`"$($Identifiers.DeviceId)`"/*4csp*/"
    $content = $content -replace "return/\*csp4\*/.*?/\*4csp\*/", "return/*csp4*/`"$($Identifiers.DeviceId)`"/*4csp*/"
    
    # 保存文件
    try {
        # 移除只读属性
        if (Test-Path $MainJsPath) {
            Set-ItemProperty $MainJsPath -Name IsReadOnly -Value $false
        }
        
        [System.IO.File]::WriteAllText($MainJsPath, $content, [System.Text.Encoding]::UTF8)
        Write-ColorText "✅ 文件修改已保存" "Green"
        
        return $true
    } catch {
        Write-ColorText "❌ 保存文件失败: $($_.Exception.Message)" "Red"
        return $false
    }
}

function Clear-CursorCache {
    Write-ColorText "🧹 清理缓存文件..." "Yellow"
    
    $cacheLocations = @(
        "$env:APPDATA\Cursor\User\globalStorage",
        "$env:APPDATA\Cursor\logs",
        "$env:APPDATA\Cursor\CachedData"
    )
    
    $cleanedCount = 0
    foreach ($location in $cacheLocations) {
        if (Test-Path $location) {
            try {
                Get-ChildItem $location -Recurse -File | ForEach-Object {
                    try {
                        Remove-Item $_.FullName -Force
                        $cleanedCount++
                    } catch {}
                }
            } catch {}
        }
    }
    
    if ($cleanedCount -gt 0) {
        Write-ColorText "✅ 已清理 $cleanedCount 个缓存文件" "Green"
    }
}

# 主程序
function Main {
    Write-Header "Cursor 硬件指纹重制工具 (在线版)"
    
    # 检查系统
    if ($PSVersionTable.Platform -and $PSVersionTable.Platform -ne "Win32NT") {
        Write-ColorText "❌ 此工具仅支持Windows系统" "Red"
        return
    }
    
    # 检查管理员权限
    if (-not (Test-Administrator) -and -not $Force) {
        Write-ColorText "⚠️ 建议以管理员身份运行以确保完整功能" "Yellow"
        Write-ColorText "如要强制继续，请添加 -Force 参数" "Yellow"
        return
    }
    
    try {
        # 查找Cursor安装路径
        Write-ColorText "🔍 正在查找Cursor安装..." "Blue"
        $appPath = Find-CursorPath
        
        if (-not $appPath) {
            Write-ColorText "❌ 未找到Cursor安装，请确保Cursor已正确安装" "Red"
            return
        }
        
        Write-ColorText "✅ 找到Cursor: $appPath" "Green"
        $mainJsPath = Join-Path $appPath "out\main.js"
        
        # 关闭Cursor进程
        Stop-CursorProcess
        
        # 生成新标识符
        Write-ColorText "🔑 生成新的设备标识符..." "Blue"
        $identifiers = New-Identifiers
        
        Write-ColorText "   • Machine ID: $($identifiers.MachineId.Substring(0,8))..." "White"
        Write-ColorText "   • MAC地址: $($identifiers.MacAddress)" "White"
        Write-ColorText "   • SQM ID: $($identifiers.SqmMachineId.Substring(0,8))..." "White"
        Write-ColorText "   • 设备ID: $($identifiers.DeviceId.Substring(0,8))..." "White"
        
        # 修改文件
        if (-not (Update-MainJs -MainJsPath $mainJsPath -Identifiers $identifiers)) {
            Write-ColorText "❌ 文件修改失败" "Red"
            return
        }
        
        # 清理缓存
        Clear-CursorCache
        
        # 重启Cursor
        Write-Header "✅ 硬件指纹重制完成！"
        $restartSuccess = Start-CursorProcess -AppPath $appPath
        
        if ($restartSuccess) {
            Write-ColorText "🎉 重制完成！Cursor已自动重启" "Green"
        } else {
            Write-ColorText "🎉 重制完成！请手动启动Cursor" "Green"
        }
        
    } catch {
        Write-ColorText "❌ 执行过程中发生错误: $($_.Exception.Message)" "Red"
        Write-ColorText "详细错误: $($_.ScriptStackTrace)" "Red"
    }
    
    Write-Host ""
    Write-ColorText "按任意键退出..." "Yellow"
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# 执行主程序
Main
