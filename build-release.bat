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
REM Wait for lock to release
if exist "%CD%\src-tauri\target\release\.cargo-lock" (
    timeout /t 3 /nobreak >nul
)
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

REM ----- Step 1: Init MSVC env -----
echo [1/4] 初始化 MSVC 编译环境...
call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
if %ERRORLEVEL% NEQ 0 (
    echo   [错误] vcvars64.bat 初始化失败，请检查 Visual Studio Build Tools 安装
    pause
    exit /b 1
)
echo   OK
echo.

REM ----- Step 2: Install dependencies -----
echo [2/4] 安装项目依赖...
cd /d "%~dp0"
pnpm install --frozen-lockfile 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo   [警告] frozen-lockfile 失败，尝试普通 install...
    pnpm install
)
echo   OK
echo.

REM ----- Step 3: Full Tauri build (Rust + frontend + NSIS bundle) -----
echo [3/4] Tauri 全量构建...
echo   * 编译 Rust 二进制（含嵌入前端）
echo   * 构建前端（TypeScript + Vite）
echo   * 打包 NSIS 安装程序
echo.
echo   注意：Rust 链接阶段可能会有短暂无输出，这是正常现象。
echo   请耐心等待，不要关闭窗口。
echo.
cd /d "%~dp0"
pnpm tauri build --bundles nsis
if %ERRORLEVEL% NEQ 0 (
    echo   [错误] Tauri 构建失败
    echo.
    echo   常见原因：
    echo     1. Rust 编译错误（查看上方红色输出）
    echo     2. 磁盘空间不足
    echo     3. 被杀毒软件拦截
    pause
    exit /b 1
)
echo   OK
echo.

REM ----- Step 4: Verify output -----
echo [4/4] 验证构建产物...
set EXE_PATH=%~dp0src-tauri\target\release\skills-manage.exe
set NSIS_PATH=%~dp0src-tauri\target\release\bundle\nsis

if exist "%EXE_PATH%" (
    for %%I in ("%EXE_PATH%") do echo   可执行文件: %%~nxI (%%~zI 字节)
) else (
    echo   [警告] 未找到可执行文件
)

if exist "%NSIS_PATH%\*.exe" (
    for %%I in ("%NSIS_PATH%\*.exe") do echo   NSIS 安装包: %%~nxI (%%~zI 字节)
) else (
    echo   [警告] 未找到 NSIS 安装包
)
echo   OK
echo.

REM ----- Done -----
echo ==================================================
echo   构建成功！
echo ==================================================
echo.
echo   输出目录:
echo     %~dp0src-tauri\target\release\
echo.
echo   磁盘清理建议（可选）:
echo     rmdir /s /q "%~dp0src-tauri\target\debug"    释放 ~3.2 GB
echo     rmdir /s /q "%~dp0node_modules\.cache"        释放 ~200 MB
echo.
pause
