@echo off
setlocal enabledelayedexpansion

echo ============================================
echo   skills-manage-free - Git Push Tool
echo ============================================
echo.

:: --- Detect current branch --------------------------------------------------
for /f "tokens=*" %%i in ('git rev-parse --abbrev-ref HEAD') do set CUR_BRANCH=%%i
echo [INFO] Current branch: %CUR_BRANCH%

:: --- Detect remote -----------------------------------------------------------
set REMOTE=github
git remote get-url %REMOTE% >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Remote '%REMOTE%' not found. Add it first:
    echo   git remote add github https://github.com/jianghw/skills-manage-free.git
    pause
    exit /b 1
)

:: --- Proxy configuration (for users behind firewall, e.g. China) -------------
echo [INFO] Checking git proxy settings...
git config --global --get http.proxy >nul 2>&1
if errorlevel 1 (
    echo [INFO] No global git proxy configured.
    set /p USE_PROXY="Use proxy for git operations? (http://127.0.0.1:7897) [y/N]: "
    if /i "!USE_PROXY!"=="y" (
        set PROXY_URL=http://127.0.0.1:7897
        git config --global http.proxy !PROXY_URL!
        git config --global https.proxy !PROXY_URL!
        echo [OK] Git proxy set to !PROXY_URL!
    )
) else (
    for /f "tokens=*" %%p in ('git config --global --get http.proxy') do set GIT_PROXY=%%p
    echo [INFO] Git proxy found: !GIT_PROXY!
    echo [INFO] To remove: git config --global --unset http.proxy ^&^& git config --global --unset https.proxy
)

:: --- Check for uncommitted changes -------------------------------------------
git diff --quiet HEAD
if errorlevel 1 (
    echo [INFO] You have uncommitted changes.
    set /p COMMIT_MSG="Enter commit message: "
    if "!COMMIT_MSG!"=="" (
        echo [CANCEL] No commit message provided.
        pause
        exit /b 1
    )
    git add -A
    git commit -m "!COMMIT_MSG!"
    if errorlevel 1 (
        echo [ERROR] Commit failed.
        pause
        exit /b 1
    )
    echo [OK] Committed.
) else (
    echo [INFO] Working tree clean, no new commit needed.
)

echo.

:: --- Read current version from package.json ----------------------------------
for /f "tokens=2 delims=:" %%a in ('findstr /b /c:"  \"version\"" package.json') do set VER_RAW=%%a
set VER_RAW=!VER_RAW:"=!
set VER_RAW=!VER_RAW: =!
set VER_RAW=!VER_RAW:,=!
set CUR_VERSION=v!VER_RAW!

:: --- Choose push mode --------------------------------------------------------
echo Select push mode:
echo.
echo   [1] Push code to %CUR_BRANCH% only (triggers CI checks)
echo   [2] Push v* branch + tag (triggers full cross-platform release build)
echo   [3] Push both
echo.
set /p MODE="Enter choice (1/2/3): "

if "!MODE!"=="1" goto push_code
if "!MODE!"=="2" goto push_release
if "!MODE!"=="3" goto push_both
echo [ERROR] Invalid choice.
pause
exit /b 1

:: =============================================================================
::  Helper: push branch idempotently (no error on pre-existing)
:: =============================================================================
:git_push_branch
    git push %REMOTE% refs/heads/%1
    if errorlevel 1 (
        echo [WARN] Push of branch '%1' failed, retrying with force...
        git push %REMOTE% refs/heads/%1 --force
        if errorlevel 1 (
            echo [ERROR] Still failed after force push.
            pause
            exit /b 1
        )
    )
    echo [OK] Branch '%1' pushed.
    goto :eof

:: =============================================================================
::  Helper: push tag idempotently (no error on pre-existing)
:: =============================================================================
:git_push_tag
    git push %REMOTE% refs/tags/%1
    if errorlevel 1 (
        echo [WARN] Push of tag '%1' failed, retrying with force...
        git push %REMOTE% refs/tags/%1 --force
        if errorlevel 1 (
            echo [ERROR] Still failed after force push.
            pause
            exit /b 1
        )
    )
    echo [OK] Tag '%1' pushed.
    goto :eof

:: =============================================================================
::  Option 1: Push code only
:: =============================================================================
:push_code
echo.
echo --- Pushing code to %REMOTE%/%CUR_BRANCH% (triggers CI) ---
call :git_push_branch %CUR_BRANCH%
echo.
echo [OK] Push complete!
echo   https://github.com/jianghw/skills-manage-free/actions
echo.
pause
exit /b 0

:: =============================================================================
::  Option 2: Push v* branch + tag (release)
:: =============================================================================
:push_release
echo.
set /p VBRANCH="Enter version branch/tag (press Enter for %CUR_VERSION%): "
if "!VBRANCH!"=="" set VBRANCH=%CUR_VERSION%

:: --- Create or reuse v-branch ------------------------------------------------
git rev-parse --verify "refs/heads/!VBRANCH!" >nul 2>&1
if errorlevel 1 (
    git branch "!VBRANCH!"
    if errorlevel 1 (
        echo [ERROR] Failed to create branch '!VBRANCH!'.
        pause
        exit /b 1
    )
    echo [OK] Created branch '!VBRANCH!'.
) else (
    echo [INFO] Branch '!VBRANCH!' already exists, will force push to update.
)

:: --- Create or overwrite tag -------------------------------------------------
git tag -f "!VBRANCH!" >nul 2>&1
echo [OK] Tag '!VBRANCH!' ready.

:: --- Push branch + tag --------------------------------------------------------
echo.
echo --- Pushing branch '!VBRANCH!' ---
call :git_push_branch !VBRANCH!
echo.
echo --- Pushing tag '!VBRANCH!' (triggers cross-platform build) ---
call :git_push_tag !VBRANCH!
echo.
echo [OK] Release push complete!
echo   Build:  https://github.com/jianghw/skills-manage-free/actions
echo   DL:     https://github.com/jianghw/skills-manage-free/releases
echo.
pause
exit /b 0

:: =============================================================================
::  Option 3: Push both (code + release)
:: =============================================================================
:push_both
echo.
set /p VBRANCH="Enter version branch/tag (press Enter for %CUR_VERSION%): "
if "!VBRANCH!"=="" set VBRANCH=%CUR_VERSION%

:: --- Create or reuse v-branch ------------------------------------------------
git rev-parse --verify "refs/heads/!VBRANCH!" >nul 2>&1
if errorlevel 1 (
    git branch "!VBRANCH!"
    if errorlevel 1 (
        echo [ERROR] Failed to create branch '!VBRANCH!'.
        pause
        exit /b 1
    )
    echo [OK] Created branch '!VBRANCH!'.
) else (
    echo [INFO] Branch '!VBRANCH!' already exists, will force push.
)

:: --- Create or overwrite tag -------------------------------------------------
git tag -f "!VBRANCH!" >nul 2>&1
echo [OK] Tag '!VBRANCH!' ready.

:: --- Push everything ----------------------------------------------------------
echo.
echo --- Pushing code to %REMOTE%/%CUR_BRANCH% ---
call :git_push_branch %CUR_BRANCH%
echo.
echo --- Pushing version branch '!VBRANCH!' ---
call :git_push_branch !VBRANCH!
echo.
echo --- Pushing tag '!VBRANCH!' (triggers cross-platform build) ---
call :git_push_tag !VBRANCH!
echo.
echo [OK] All pushes complete!
echo   CI:      https://github.com/jianghw/skills-manage-free/actions
echo   Release: https://github.com/jianghw/skills-manage-free/releases
echo.
pause
exit /b 0
