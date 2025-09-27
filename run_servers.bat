@echo off
echo Starting FixMate Servers...
echo.

echo [1] Starting Dashboard Server...
cd /d "%~dp0"
start "Dashboard Server" cmd /k "cd dashboard && python server.py"

echo [2] Starting HTTP Server on port 3000...
start "HTTP Server" cmd /k "cd dashboard && python -m http.server 3000"

echo [3] Starting Backend Server...
start "Backend Server" cmd /k "cd backend && python main.py"

echo.
echo All servers are starting...
echo - Dashboard Server: http://localhost:5000 (or check server output)
echo - Dashboard (HTTP): http://localhost:3000 (serves dashboard files)
echo - Backend Server: http://localhost:8000 (or check server output)
echo.
echo Press any key to close all servers, or close each window manually.
pause >nul

echo Closing servers...
taskkill /FI "WINDOWTITLE eq Dashboard Server*" /T /F
taskkill /FI "WINDOWTITLE eq HTTP Server*" /T /F
taskkill /FI "WINDOWTITLE eq Backend Server*" /T /F
