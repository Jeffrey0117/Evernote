@echo off
setlocal

if "%~1"=="" (
    echo Usage: write-article "article topic"
    exit /b 1
)

set "TOPIC=%~1"
set "GUIDE=C:\Users\jeffb\Desktop\code\Evernote\src\pages\posts\project-guide.md"
set "WORK_DIR=C:\Users\jeffb\Desktop\code\cloudpipe"

copy "%GUIDE%" "%WORK_DIR%\_guide.md" >nul 2>&1

echo Writing article about: %TOPIC%
echo.
cd /d "%WORK_DIR%"
gemini "Read _guide.md for format. Write article: %TOPIC%. Use node for datetime. Save as lowercase-dash.md" -y

del "%WORK_DIR%\_guide.md" >nul 2>&1
echo.
echo Done! Run 'move-articles' to move to Evernote.

endlocal
