@echo off
echo 正在下载Cursor补丁程序...

:: 创建临时目录
mkdir %temp%\cursor_patch 2>nul
cd /d %temp%\cursor_patch

:: 下载exe文件
powershell -Command "& {Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/你的用户名/你的仓库/main/dist/patch_handler.exe' -OutFile 'patch_handler.exe'}"

:: 运行程序
start /wait patch_handler.exe

:: 清理临时文件
cd /d %userprofile%
rd /s /q %temp%\cursor_patch