@echo off
chcp 65001 >nul
echo 正在下载Cursor补丁程序...

:: 创建临时目录
mkdir %temp%\cursor_patch 2>nul
cd /d %temp%\cursor_patch

:: 使用PowerShell下载文件
powershell -Command "$ProgressPreference = 'SilentlyContinue'; Invoke-WebRequest -UseBasicParsing -Uri 'https://github.com/HalfWater-yibao/cursor-help/raw/main/patch_handler.exe' -OutFile 'patch_handler.exe'"

:: 检查文件是否下载成功
if not exist patch_handler.exe (
    echo 下载失败，正在尝试备用下载方式...
    powershell -Command "$ProgressPreference = 'SilentlyContinue'; Invoke-WebRequest -UseBasicParsing -Uri 'https://github.com/HalfWater-yibao/cursor-help/blob/main/patch_handler.exe?raw=true' -OutFile 'patch_handler.exe'"
)

:: 再次检查文件
if exist patch_handler.exe (
    :: 运行程序
    echo 下载成功，正在运行程序...
    start /wait patch_handler.exe
) else (
    echo 下载失败，请访问 https://github.com/HalfWater-yibao/cursor-help 手动下载
    pause
)

:: 清理临时文件
cd /d %userprofile%
rd /s /q %temp%\cursor_patch
