@echo off
setlocal EnableExtensions
title Animated Windows Profile Picture

echo ============================================================
echo     WINDOWS 11 ANIMATED PROFILE PICTURE
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
    exit /b
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
    exit /b
)

echo User : %USERNAME%
echo SID  : %SID%
echo.

:: ------------------------------------------------------------
:: FILE PICKER
:: ------------------------------------------------------------
set "PICKFILE=%TEMP%\gifpick.txt"

del "%PICKFILE%" >nul 2>&1

echo [*] Opening GIF file picker...

powershell.exe -NoProfile -STA -Command "Add-Type -AssemblyName System.Windows.Forms; $f=New-Object System.Windows.Forms.OpenFileDialog; $f.Title='Select GIF for Profile Picture'; $f.Filter='GIF Images (*.gif)|*.gif'; $f.Multiselect=$false; if($f.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){[System.IO.File]::WriteAllText($env:TEMP+'\gifpick.txt',$f.FileName)}"

if not exist "%PICKFILE%" (
    echo.
    echo [INFO] No GIF was selected.
    pause
    exit /b
)

set /p "GIF="<"%PICKFILE%"
del "%PICKFILE%" >nul 2>&1

echo.
echo [OK] Selected GIF:
echo "%GIF%"
echo.

if not exist "%GIF%" (
    echo [ERROR] The selected GIF could not be found.
    pause
    exit /b
)

:: ------------------------------------------------------------
:: COPY GIF
:: ------------------------------------------------------------
set "PROFILEDIR=C:\ProgramData\AnimatedProfilePicture"
set "DEST=C:\ProgramData\AnimatedProfilePicture\profile.gif"

if not exist "%PROFILEDIR%" mkdir "%PROFILEDIR%"

copy /y "%GIF%" "%DEST%"

if errorlevel 1 (
    echo.
    echo [ERROR] Failed to copy the GIF.
    pause
    exit /b
)

echo.
echo [OK] GIF saved to:
echo %DEST%
echo.

:: ------------------------------------------------------------
:: REGISTRY
:: ------------------------------------------------------------
set "REGKEY=HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\AccountPicture\Users\%SID%"
set "BACKUP=%PROFILEDIR%\AccountPicture-backup.reg"

echo [*] Backing up the registry...

reg query "%REGKEY%" >nul 2>&1

if not errorlevel 1 (
    if exist "%BACKUP%" (
        echo [INFO] The original backup already exists and will not be overwritten:
        echo      %BACKUP%
    ) else (
        reg export "%REGKEY%" "%BACKUP%" /y
        if errorlevel 1 (
            echo [ERROR] Failed to create the registry backup.
            pause
            exit /b 1
        )
        echo [OK] Original registry backup created:
        echo      %BACKUP%
    )
) else (
    echo [WARNING] The AccountPicture registry key does not exist; no backup was created.
)

echo.

:: ------------------------------------------------------------
:: CREATE SYSTEM HELPER
:: ------------------------------------------------------------
set "HELPER=C:\ProgramData\AnimatedProfilePicture\apply.cmd"

echo @echo off>"%HELPER%"
echo reg add "%REGKEY%" /f>>"%HELPER%"
echo reg add "%REGKEY%" /v Image32 /t REG_SZ /d "%DEST%" /f>>"%HELPER%"
echo reg add "%REGKEY%" /v Image40 /t REG_SZ /d "%DEST%" /f>>"%HELPER%"
echo reg add "%REGKEY%" /v Image48 /t REG_SZ /d "%DEST%" /f>>"%HELPER%"
echo reg add "%REGKEY%" /v Image64 /t REG_SZ /d "%DEST%" /f>>"%HELPER%"
echo reg add "%REGKEY%" /v Image96 /t REG_SZ /d "%DEST%" /f>>"%HELPER%"
echo reg add "%REGKEY%" /v Image192 /t REG_SZ /d "%DEST%" /f>>"%HELPER%"
echo reg add "%REGKEY%" /v Image200 /t REG_SZ /d "%DEST%" /f>>"%HELPER%"
echo reg add "%REGKEY%" /v Image208 /t REG_SZ /d "%DEST%" /f>>"%HELPER%"
echo reg add "%REGKEY%" /v Image240 /t REG_SZ /d "%DEST%" /f>>"%HELPER%"
echo reg add "%REGKEY%" /v Image424 /t REG_SZ /d "%DEST%" /f>>"%HELPER%"
echo reg add "%REGKEY%" /v Image448 /t REG_SZ /d "%DEST%" /f>>"%HELPER%"
echo reg add "%REGKEY%" /v Image1080 /t REG_SZ /d "%DEST%" /f>>"%HELPER%"

echo [OK] SYSTEM helper created.
echo.

:: ------------------------------------------------------------
:: CREATE SYSTEM TASK
:: ------------------------------------------------------------
set "TASK=AnimatedProfilePicture"

echo [*] Creating temporary SYSTEM task...

schtasks /Delete /TN "%TASK%" /F >nul 2>&1

schtasks /Create /TN "%TASK%" /TR "\"%HELPER%\"" /SC ONCE /ST 23:59 /RU SYSTEM /RL HIGHEST /F

if errorlevel 1 (
    echo.
    echo [ERROR] Failed to create the SYSTEM task.
    pause
    exit /b
)

echo.
echo [*] Applying changes as SYSTEM...

schtasks /Run /TN "%TASK%"

if errorlevel 1 (
    echo.
    echo [ERROR] Failed to run the SYSTEM task.
    pause
    exit /b
)

timeout /t 3 /nobreak

:: ------------------------------------------------------------
:: DELETE TASK
:: ------------------------------------------------------------
schtasks /Delete /TN "%TASK%" /F >nul 2>&1

echo.
echo [OK] Temporary task removed.
echo.

:: ------------------------------------------------------------
:: VERIFY
:: ------------------------------------------------------------
echo ============================================================
echo VERIFY REGISTRY
echo ============================================================
echo.

reg query "%REGKEY%"

echo.
echo ============================================================
echo.

reg query "%REGKEY%" /v Image1080 >nul 2>&1

if errorlevel 1 (
    echo [ERROR] Image1080 was not found.
    echo.
    echo Keep this window open and review the registry output above.
) else (
    echo [SUCCESS] Animated profile picture applied successfully!
    echo.
    echo All account picture entries now point to:
    echo %DEST%
    echo.
    echo Sign out of Windows and sign back in to refresh the profile picture.
)

echo.
pause
