@echo off
setlocal EnableExtensions
title Rollback Animated Windows Profile Picture

echo ============================================================
echo     ROLLBACK WINDOWS 11 ANIMATED PROFILE PICTURE
echo ============================================================
echo.

:: ------------------------------------------------------------
:: CHECK ADMIN
:: ------------------------------------------------------------
fltmc >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Script belum dijalankan sebagai Administrator.
    echo.
    echo Klik kanan file CMD ini lalu pilih:
    echo Run as administrator
    echo.
    pause
    exit /b 1
)

echo [OK] Administrator permission
echo.

:: ------------------------------------------------------------
:: GET CURRENT USER SID
:: ------------------------------------------------------------
for /f "delims=" %%A in ('powershell.exe -NoProfile -Command "[System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value"') do set "SID=%%A"

if not defined SID (
    echo [ERROR] Tidak bisa mendapatkan SID user.
    pause
    exit /b 1
)

echo User : %USERNAME%
echo SID  : %SID%
echo.

:: ------------------------------------------------------------
:: PATHS
:: ------------------------------------------------------------
set "PROFILEDIR=C:\ProgramData\AnimatedProfilePicture"
set "BACKUP=%PROFILEDIR%\AccountPicture-backup.reg"
set "REGKEY=HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\AccountPicture\Users\%SID%"
set "HELPER=%PROFILEDIR%\rollback-system.cmd"
set "TASK=RollbackAnimatedProfilePicture"
set "CURRENTBACKUP=%PROFILEDIR%\AccountPicture-animated-state.reg"

:: ------------------------------------------------------------
:: CHECK ORIGINAL BACKUP
:: ------------------------------------------------------------
if not exist "%BACKUP%" (
    echo [ERROR] Backup registry asli tidak ditemukan:
    echo %BACKUP%
    echo.
    echo Rollback otomatis dibatalkan supaya profile picture Windows
    echo tidak rusak. Kamu masih bisa mengganti foto secara manual dari
    echo Settings ^> Accounts ^> Your info.
    echo.
    pause
    exit /b 1
)

echo [OK] Backup asli ditemukan:
echo      %BACKUP%
echo.

:: Verify that the backup belongs to this SID/key.
:: NOTE: .reg files exported by REG.EXE use HKEY_LOCAL_MACHINE,
:: not the HKLM abbreviation used by REG QUERY/ADD.
set "REGKEYFULL=HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\AccountPicture\Users\%SID%"

powershell.exe -NoProfile -Command ^
"$target='[%REGKEYFULL%]'; $content=Get-Content -LiteralPath '%BACKUP%' -Encoding Unicode; if($content -contains $target){exit 0}else{exit 1}" >nul 2>&1

if errorlevel 1 (
    echo [ERROR] Backup ditemukan, tapi header registry untuk SID ini tidak ditemukan.
    echo.
    echo Yang dicari:
    echo [%REGKEYFULL%]
    echo.
    echo Header registry yang ada di backup:
    powershell.exe -NoProfile -Command ^
    "Get-Content -LiteralPath '%BACKUP%' -Encoding Unicode ^| Where-Object { $_ -like '[[]*' }"
    echo.
    echo Rollback dibatalkan untuk keamanan.
    pause
    exit /b 1
)

:: ------------------------------------------------------------
:: SAVE CURRENT ANIMATED STATE AS AN EXTRA SAFETY BACKUP
:: ------------------------------------------------------------
reg query "%REGKEY%" >nul 2>&1
if not errorlevel 1 (
    reg export "%REGKEY%" "%CURRENTBACKUP%" /y >nul 2>&1
    if not errorlevel 1 (
        echo [OK] Kondisi animated saat ini juga dibackup:
        echo      %CURRENTBACKUP%
        echo.
    )
)

:: ------------------------------------------------------------
:: CREATE SYSTEM HELPER
:: Delete the modified key first so values created by the GIF script
:: do not survive, then import the exact original backup.
:: ------------------------------------------------------------
>"%HELPER%" echo @echo off
>>"%HELPER%" echo reg delete "%REGKEY%" /f ^>nul 2^>^&1
>>"%HELPER%" echo reg import "%BACKUP%"

if not exist "%HELPER%" (
    echo [ERROR] Gagal membuat rollback helper.
    pause
    exit /b 1
)

:: ------------------------------------------------------------
:: RUN HELPER AS SYSTEM
:: ------------------------------------------------------------
echo [*] Menyiapkan rollback sebagai SYSTEM...

schtasks /Delete /TN "%TASK%" /F >nul 2>&1

schtasks /Create /TN "%TASK%" /TR "\"%HELPER%\"" /SC ONCE /ST 23:59 /RU SYSTEM /RL HIGHEST /F >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Gagal membuat temporary SYSTEM task.
    echo.
    pause
    exit /b 1
)

echo [*] Mengembalikan registry asli...
schtasks /Run /TN "%TASK%" >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Gagal menjalankan rollback task.
    schtasks /Delete /TN "%TASK%" /F >nul 2>&1
    echo.
    pause
    exit /b 1
)

timeout /t 4 /nobreak >nul
schtasks /Delete /TN "%TASK%" /F >nul 2>&1

:: ------------------------------------------------------------
:: VERIFY
:: ------------------------------------------------------------
echo.
echo ============================================================
echo VERIFY RESTORED REGISTRY
echo ============================================================
echo.
reg query "%REGKEY%"
echo.

:: If profile.gif is still referenced, rollback did not take effect.
reg query "%REGKEY%" 2>nul | findstr /I /L "C:\ProgramData\AnimatedProfilePicture\profile.gif" >nul
if not errorlevel 1 (
    echo [ERROR] Registry masih menunjuk ke profile.gif.
    echo File GIF tidak akan dihapus.
    echo Kirim output di atas untuk dicek.
    echo.
    pause
    exit /b 1
)

:: ------------------------------------------------------------
:: CLEAN ANIMATED-PROFILE FILES
:: Keep both .reg backups for safety.
:: ------------------------------------------------------------
del "%PROFILEDIR%\profile.gif" >nul 2>&1
del "%PROFILEDIR%\apply.cmd" >nul 2>&1
del "%HELPER%" >nul 2>&1

echo [SUCCESS] Profile picture registry berhasil dikembalikan.
echo.
echo File GIF dan helper animated profile sudah dibersihkan.
echo Backup .reg tetap disimpan di:
echo %PROFILEDIR%
echo.
echo Sekarang SIGN OUT lalu SIGN IN lagi.
echo Kalau avatar masih ter-cache, restart Windows sekali.
echo.
pause
