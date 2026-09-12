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
    echo [ERROR] Script belum dijalankan sebagai Administrator.
    echo.
    echo Klik kanan file CMD ini lalu:
    echo Run as administrator
    echo.
    pause
    exit /b
)

echo [OK] Administrator permission
echo.

:: ------------------------------------------------------------
:: GET CURRENT USER SID
:: ------------------------------------------------------------
for /f "delims=" %%A in ('powershell.exe -NoProfile -Command "[System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value"') do set "SID=%%A"

if not defined SID (
    echo [ERROR] Tidak bisa mendapatkan SID.
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

echo [*] Membuka pilihan GIF...

powershell.exe -NoProfile -STA -Command "Add-Type -AssemblyName System.Windows.Forms; $f=New-Object System.Windows.Forms.OpenFileDialog; $f.Title='Pilih GIF untuk Profile Picture'; $f.Filter='GIF Images (*.gif)|*.gif'; $f.Multiselect=$false; if($f.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){[System.IO.File]::WriteAllText($env:TEMP+'\gifpick.txt',$f.FileName)}"

if not exist "%PICKFILE%" (
    echo.
    echo [INFO] Tidak ada GIF dipilih.
    pause
    exit /b
)

set /p "GIF="<"%PICKFILE%"
del "%PICKFILE%" >nul 2>&1

echo.
echo [OK] GIF:
echo "%GIF%"
echo.

if not exist "%GIF%" (
    echo [ERROR] GIF tidak ditemukan.
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
    echo [ERROR] Gagal copy GIF.
    pause
    exit /b
)

echo.
echo [OK] GIF disimpan ke:
echo %DEST%
echo.

:: ------------------------------------------------------------
:: REGISTRY
:: ------------------------------------------------------------
set "REGKEY=HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\AccountPicture\Users\%SID%"
set "BACKUP=%PROFILEDIR%\AccountPicture-backup.reg"

echo [*] Backup registry...

reg query "%REGKEY%" >nul 2>&1

if not errorlevel 1 (
    if exist "%BACKUP%" (
        echo [INFO] Backup asli sudah ada dan tidak akan ditimpa:
        echo      %BACKUP%
    ) else (
        reg export "%REGKEY%" "%BACKUP%" /y
        if errorlevel 1 (
            echo [ERROR] Gagal membuat backup registry.
            pause
            exit /b 1
        )
        echo [OK] Backup registry asli dibuat:
        echo      %BACKUP%
    )
) else (
    echo [WARNING] Registry AccountPicture belum ada; backup tidak dibuat.
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

echo [OK] Helper dibuat.
echo.

:: ------------------------------------------------------------
:: CREATE SYSTEM TASK
:: ------------------------------------------------------------
set "TASK=AnimatedProfilePicture"

echo [*] Membuat temporary SYSTEM task...

schtasks /Delete /TN "%TASK%" /F >nul 2>&1

schtasks /Create /TN "%TASK%" /TR "\"%HELPER%\"" /SC ONCE /ST 23:59 /RU SYSTEM /RL HIGHEST /F

if errorlevel 1 (
    echo.
    echo [ERROR] Gagal membuat SYSTEM task.
    pause
    exit /b
)

echo.
echo [*] Menjalankan sebagai SYSTEM...

schtasks /Run /TN "%TASK%"

if errorlevel 1 (
    echo.
    echo [ERROR] Gagal menjalankan SYSTEM task.
    pause
    exit /b
)

timeout /t 3 /nobreak

:: ------------------------------------------------------------
:: DELETE TASK
:: ------------------------------------------------------------
schtasks /Delete /TN "%TASK%" /F >nul 2>&1

echo.
echo [OK] Temporary task dihapus.
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
    echo [ERROR] Image1080 tidak ditemukan.
    echo.
    echo Jangan tutup window ini.
    echo Kirim screenshot/output-nya ke aku.
) else (
    echo [SUCCESS] Registry berhasil diterapkan!
    echo.
    echo Semua account picture diarahkan ke:
    echo %DEST%
    echo.
    echo Sekarang coba SIGN OUT lalu SIGN IN.
)

echo.
pause
