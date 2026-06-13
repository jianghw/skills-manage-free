@echo off
setlocal enabledelayedexpansion

echo ============================================
echo   skills-manage-free - Git Push Tool
echo ============================================
echo.

:: --- Detect remote -----------------------------------------------------------
set REMOTE=github
git remote get-url %REMOTE% >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Remote '%REMOTE%' not found. Add it first:
    echo   git remote add github https://github.com/jianghw/skills-manage-free.git
    pause
    exit /b 1
)

:: --- Check for uncommitted changes -------------------------------------------
git diff --quiet HEAD
if errorlevel 1 (
    echo [INFO] You have uncommitted changes.
    set /p COMMIT_MSG="Enter commit message (leave empty to skip): "
    if not "!COMMIT_MSG!"=="" (
        git add -A
        git commit -m "!COMMIT_MSG!"
        if errorlevel 1 (
            echo [ERROR] Commit failed.
            pause
            exit /b 1
        )
        echo [OK] Committed.
    ) else (
        echo [SKIP] No commit made.
    )
) else (
    echo [OK] Working tree clean.
)

echo.

:: --- Choose push mode --------------------------------------------------------
echo Select push mode:
echo.
echo   [1] Push code only (triggers CI checks)
echo   [2] Push code + new version tag (triggers full cross-platform build)
echo.
set /p MODE="Enter choice (1 or 2): "

if "!MODE!"=="1" goto push_code
if "!MODE!"=="2" goto push_release
echo [ERROR] Invalid choice.
pause
exit /b 1

:: --- Push code only ----------------------------------------------------------
:push_code
echo.
echo --- Pushing code to %REMOTE%/main (triggers CI) ---
git push %REMOTE% main
if errorlevel 1 (
    echo [ERROR] Push failed.
    pause
    exit /b 1
)
echo.
echo [OK] Push complete! Check CI progress at:
echo   https://github.com/jianghw/skills-manage-free/actions
echo.
pause
exit /b 0

:: --- Push code + release tag -------------------------------------------------
:push_release
echo.

:: --- Read current version from package.json ----------------------------------
for /f "tokens=2 delims=:" %%a in ('findstr /b /c:"  \"version\"" package.json') do (
    set VER_RAW=%%a
)
set VER_RAW=!VER_RAW:"=!
set VER_RAW=!VER_RAW: =!
set VER_RAW=!VER_RAW:,=!
set CUR_VERSION=v!VER_RAW!

echo Current version: %CUR_VERSION%
set /p TAG_VERSION="Enter version tag (press Enter for %CUR_VERSION%): "
if "!TAG_VERSION!"=="" set TAG_VERSION=%CUR_VERSION%

:: --- Check if tag already exists ---------------------------------------------
git tag | findstr /X "!TAG_VERSION!" >nul
if not errorlevel 1 (
    echo [WARN] Tag '!TAG_VERSION!' already exists.
    set /p FORCE="Overwrite and re-push? (y/N): "
    if /i "!FORCE!"=="y" (
        git tag -d "!TAG_VERSION!"
        git push %REMOTE% :refs/tags/"!TAG_VERSION!" >nul 2>&1
    ) else (
        echo [CANCEL] Skipping tag push.
        set SKIP_TAG=1
    )
)

:: --- Create tag --------------------------------------------------------------
if not defined SKIP_TAG (
    git tag "!TAG_VERSION!"
    if errorlevel 1 (
        echo [ERROR] Failed to create tag.
        pause
        exit /b 1
    )
)

:: --- Push code + tag ---------------------------------------------------------
echo.
echo --- Pushing code to %REMOTE%/main ---
git push %REMOTE% main
if errorlevel 1 (
    echo [ERROR] Push failed.
    pause
    exit /b 1
)

if not defined SKIP_TAG (
    echo.
    echo --- Pushing tag '!TAG_VERSION!' (triggers cross-platform build) ---
    git push %REMOTE% "!TAG_VERSION!"
    if errorlevel 1 (
        echo [ERROR] Push tag failed.
        pause
        exit /b 1
    )
)

echo.
echo [OK] Done! Check build progress:
echo   https://github.com/jianghw/skills-manage-free/actions
if not defined SKIP_TAG (
    echo.
    echo Build artifacts will appear at:
    echo   https://github.com/jianghw/skills-manage-free/releases
)
echo.
pause
exit /b 0
