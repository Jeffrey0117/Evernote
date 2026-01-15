@echo off
setlocal

set "SRC=C:\Users\jeffb\Desktop\code\cloudpipe"
set "DST=C:\Users\jeffb\Desktop\code\Evernote\src\pages\posts"

echo Moving articles from cloudpipe to Evernote...

for %%f in ("%SRC%\*.md") do (
    if /i not "%%~nxf"=="_guide.md" (
    if /i not "%%~nxf"=="README.md" (
    if /i not "%%~nxf"=="SPEC.md" (
        move "%%f" "%DST%\" >nul
        echo   %%~nxf
    )))
)

echo Done!
endlocal
