@echo off
chcp 65001 >nul
title skills-manage Release Build
setlocal enabledelayedexpansion

echo ==================================================
echo   skills-manage Release Builder
echo ==================================================
echo.

REM ----- Step 0: Kill old processes -----
echo [0/4] 清理残留编译进程...
taskkill /F /IM cargo.exe 2>nul
taskkill /F /IM rustc.exe 2>nul
timeout /t 2 /nobreak >nul
echo   OK
echo.

REM ----- Step 0.5: Verify prerequisites -----
echo [检查] 前置依赖...
where node >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo   [错误] 未找到 node，请安装 Node.js ^>=18
    pause
    exit /b 1
)
where pnpm >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo   [错误] 未找到 pnpm，请执行: npm install -g pnpm
    pause
    exit /b 1
)
where rustc >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo   [错误] 未找到 rustc，请安装 Rust: https://rustup.rs
    pause
    exit /b 1
)
echo   全部就绪
echo.

REM ----- Step 1: Build Rust release binary -----
echo [1/4] 初始化 MSVC 编译环境...
call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
if %ERRORLEVEL% NEQ 0 (
    echo   [错误] vcvars64.bat 初始化失败，请检查 Visual Studio Build Tools 安装
    pause
    exit /b 1
)
echo   OK
echo.

echo [2/4] 编译 Rust release 二进制...
cd /d "%~dp0src-tauri"
cargo build --release
if %ERRORLEVEL% NEQ 0 (
    echo   [错误] Rust 编译失败
    pause
    exit /b 1
)
echo   输出: src-tauri\target\release\skills-manage.exe
echo.

REM ----- Step 2: Build frontend + bundle NSIS installer -----
echo [3/4] 安装前端依赖...
cd /d "%~dp0"
pnpm install --frozen-lockfile
if %ERRORLEVEL% NEQ 0 (
    echo   [警告] frozen-lockfile 失败，尝试普通 install...
    pnpm install
)
echo   OK
echo.

echo [4/4] 构建前端并打包 NSIS 安装程序...
call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
pnpm tauri build --bundles nsis
if %ERRORLEVEL% NEQ 0 (
    echo   [错误] Tauri 打包失败
    pause
    exit /b 1
)
echo.

REM ----- Done -----
echo ==================================================
echo   构建成功！
echo ==================================================
echo.
echo   可执行文件:
echo     %~dp0src-tauri\target\release\skills-manage.exe
echo.
echo   NSIS 安装包:
echo     %~dp0src-tauri\target\release\bundle\nsis\skills-manage_*-x64-setup.exe
echo.
echo   磁盘清理建议（可选）:
echo     rmdir /s /q "%~dp0src-tauri\target\debug"     可以节省 ~3.2 GB
echo     del "%USERPROFILE%\.atomcode\temp\install_rust.bat"
echo.
pause
