@echo off
setlocal

if "%~1"=="" (
    echo Usage: find-topics "C:\path\to\repo"
    echo Example: find-topics "C:\Users\jeffb\Desktop\code\cloudpipe"
    exit /b 1
)

set "REPO=%~1"
set "POSTS=C:\Users\jeffb\Desktop\code\Evernote\src\pages\posts"
set "WORK=C:\Users\jeffb\Desktop\code\cloudpipe"

echo Finding topics from: %REPO%
echo.

cd /d "%WORK%"

REM List existing articles
dir /b "%POSTS%\*.md" > _existing.txt 2>nul

REM Get recent commits from target repo
git -C "%REPO%" log --oneline -30 > _commits.txt 2>nul

REM Ask Gemini
gemini "Look at _existing.txt (articles already written) and _commits.txt (recent commits). Suggest 3 new article topics that haven't been covered. Reply in Traditional Chinese." -y

REM Cleanup
del _existing.txt _commits.txt >nul 2>&1

echo.
echo Done!
endlocal
