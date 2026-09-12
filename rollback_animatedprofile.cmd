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
    echo [ERROR] This script is not running as Administrator.
    echo.
    echo Right-click this CMD file and select:
    echo Run as administrator
    echo.
    pause
    exit /b 1
)

echo [OK] Administrator permission granted.
echo.

:: ------------------------------------------------------------
:: GET CURRENT USER SID
:: ------------------------------------------------------------
for /f "delims=" %%A in ('powershell.exe -NoProfile -Command "[System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value"') do set "SID=%%A"

if not defined SID (
    echo [ERROR] Unable to get the current user SID.
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
    echo [ERROR] The original registry backup was not found:
    echo %BACKUP%
    echo.
    echo Automatic rollback has been cancelled to avoid damaging the
    echo Windows profile picture configuration. You can still change
    echo the picture manually from Settings ^> Accounts ^> Your info.
    echo.
    pause
    exit /b 1
)

echo [OK] Original backup found:
echo      %BACKUP%
echo.

:: Verify that the backup belongs to this SID/key.
:: NOTE: .reg files exported by REG.EXE use HKEY_LOCAL_MACHINE,
:: not the HKLM abbreviation used by REG QUERY/ADD.
set "REGKEYFULL=HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\AccountPicture\Users\%SID%"

powershell.exe -NoProfile -Command ^
"$target='[%REGKEYFULL%]'; $content=Get-Content -LiteralPath '%BACKUP%' -Encoding Unicode; if($content -contains $target){exit 0}else{exit 1}" >nul 2>&1

if errorlevel 1 (
    echo [ERROR] The backup exists, but it does not contain the registry header for this SID.
    echo.
    echo Expected header:
    echo [%REGKEYFULL%]
    echo.
    echo Registry headers found in the backup:
    powershell.exe -NoProfile -Command ^
    "Get-Content -LiteralPath '%BACKUP%' -Encoding Unicode ^| Where-Object { $_ -like '[[]*' }"
    echo.
    echo Rollback cancelled for safety.
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
        echo [OK] Current animated state also backed up to:
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
    echo [ERROR] Failed to create the rollback helper.
    pause
    exit /b 1
)

:: ------------------------------------------------------------
:: RUN HELPER AS SYSTEM
:: ------------------------------------------------------------
echo [*] Preparing rollback as SYSTEM...

schtasks /Delete /TN "%TASK%" /F >nul 2>&1

schtasks /Create /TN "%TASK%" /TR "\"%HELPER%\"" /SC ONCE /ST 23:59 /RU SYSTEM /RL HIGHEST /F >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Failed to create the temporary SYSTEM task.
    echo.
    pause
    exit /b 1
)

echo [*] Restoring the original registry state...
schtasks /Run /TN "%TASK%" >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Failed to run the rollback task.
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
    echo [ERROR] The registry still points to profile.gif.
    echo The GIF file will not be deleted.
    echo Review the registry output above for troubleshooting.
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

echo [SUCCESS] The original profile picture registry state was restored successfully!
echo.
echo The animated GIF and temporary helper files have been removed.
echo Registry backup files are still stored in:
echo %PROFILEDIR%
echo.
echo Sign out of Windows and sign back in.
echo If the old avatar is still cached, restart Windows once.
echo.
pause
