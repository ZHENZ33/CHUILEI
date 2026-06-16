@echo off

echo.
echo   Chui System - Local Server
echo   http://localhost:8080
echo.
echo   Close this window to stop.
echo.

cd /d C:\Users\Administrator\Desktop\垂类

start "" http://localhost:8080

python -m http.server 8080

pause
