@echo off
title Server Keuangan Pribadi (Laravel + Google Sheets)
echo ====================================================================
echo   SERVER BACKEND KEUANGAN PRIBADI (LARAVEL + GOOGLE SHEETS)
echo ====================================================================
echo.
echo Server berjalan di:
echo   - API Endpoint  : http://localhost:8000/api/dashboard
echo   - Web/iOS PWA   : http://localhost:8000/app
echo.
echo Untuk membuka dari iPhone (Safari):
echo   Pastikan iPhone dan PC Windows terhubung ke Wi-Fi yang sama,
echo   lalu buka http://[IP-PC-ANDA]:8000/app di Safari iOS.
echo ====================================================================
echo.
cd /d "%~dp0backend-laravel"
php -S 0.0.0.0:8000 -t public
pause
