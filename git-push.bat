@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

echo ════════════════════════════════════════════
echo   skills-manage-free — Git Push Tool
echo ════════════════════════════════════════════
echo.

:: ── Detect remote ──────────────────────────────────────────────────────────
set REMOTE=github
git remote get-url %REMOTE% >nul 2>&1
if errorlevel 1 (
    echo [错误] 未找到远程仓库 '%REMOTE%'，请先添加：
    echo   git remote add github https://github.com/jianghw/skills-manage-free.git
    pause
    exit /b 1
)

:: ── Check for uncommitted changes ──────────────────────────────────────────
git diff --quiet HEAD
if errorlevel 1 (
    echo [提示] 你有未提交的更改。
    set /p COMMIT_MSG="输入提交信息 (留空则跳过提交): "
    if not "!COMMIT_MSG!"=="" (
        git add -A
        git commit -m "!COMMIT_MSG!"
        if errorlevel 1 (
            echo [错误] 提交失败。
            pause
            exit /b 1
        )
        echo [OK] 已提交。
    ) else (
        echo [跳过] 未提交更改。
    )
) else (
    echo [OK] 工作区干净，无未提交更改。
)

echo.

:: ── Choose push mode ───────────────────────────────────────────────────────
echo 请选择推送模式:
echo.
echo   [1] 仅推送代码（触发 CI 检查）
echo   [2] 推送代码 + 发布新版本（触发 macOS/Windows/Linux 全平台构建）
echo.
set /p MODE="输入选择 (1 或 2): "

if "!MODE!"=="1" (
    goto push_code
) else if "!MODE!"=="2" (
    goto push_release
) else (
    echo [错误] 无效选择。
    pause
    exit /b 1
)

:: ── Push code only ─────────────────────────────────────────────────────────
:push_code
echo.
echo ── 推送代码到 %REMOTE%/main（触发 CI）──
git push %REMOTE% main
if errorlevel 1 (
    echo [错误] 推送失败。
    pause
    exit /b 1
)
echo.
echo [OK] 推送完成！查看 CI 进度：
echo   https://github.com/jianghw/skills-manage-free/actions
echo.
pause
exit /b 0

:: ── Push code + release tag ────────────────────────────────────────────────
:push_release
echo.
:: ── Read current version from package.json ─────────────────────────────────
for /f "tokens=2 delims=:" %%a in ('findstr /b /c:"  \"version\"" package.json') do (
    set VER_RAW=%%a
)
set VER_RAW=!VER_RAW:"=!
set VER_RAW=!VER_RAW: =!
set VER_RAW=!VER_RAW:,=!
set CUR_VERSION=v!VER_RAW!

echo 当前版本: %CUR_VERSION%
echo.
set /p TAG_VERSION="输入版本标签 (直接回车使用 %CUR_VERSION%): "
if "!TAG_VERSION!"=="" set TAG_VERSION=%CUR_VERSION%

:: ── Check if tag already exists locally ────────────────────────────────────
git tag | findstr /X "!TAG_VERSION!" >nul
if not errorlevel 1 (
    echo [警告] 标签 '!TAG_VERSION!' 已存在。
    set /p FORCE="覆盖并重新推送? (y/N): "
    if /i "!FORCE!"=="y" (
        git tag -d "!TAG_VERSION!"
        git push %REMOTE% :refs/tags/"!TAG_VERSION!" >nul 2>&1
    ) else (
        echo [取消] 未推送标签。
        set SKIP_TAG=1
    )
)

:: ── Create and push tag ────────────────────────────────────────────────────
if not "!SKIP_TAG!"=="1" (
    git tag "!TAG_VERSION!"
    if errorlevel 1 (
        echo [错误] 创建标签失败。
        pause
        exit /b 1
    )
)

:: ── Push code + tag ────────────────────────────────────────────────────────
echo.
echo ── 推送代码到 %REMOTE%/main ──
git push %REMOTE% main
if errorlevel 1 (
    echo [错误] 推送代码失败。
    pause
    exit /b 1
)

if not "!SKIP_TAG!"=="1" (
    echo.
    echo ── 推送标签 '!TAG_VERSION!'（触发全平台构建）──
    git push %REMOTE% "!TAG_VERSION!"
    if errorlevel 1 (
        echo [错误] 推送标签失败。
        pause
        exit /b 1
    )
)

echo.
echo [OK] 完成！查看构建进度：
echo   https://github.com/jianghw/skills-manage-free/actions
if not "!SKIP_TAG!"=="1" (
    echo.
    echo 构建完成后，Release 产物将出现在：
    echo   https://github.com/jianghw/skills-manage-free/releases
)
echo.
pause
exit /b 0
