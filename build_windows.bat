@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

set "DIR=%~dp0"
cd /d "%DIR%"

set "MODE=release"
if /i "%~1"=="debug" set "MODE=debug"

echo ==========================================================
echo    Building OpenVK Messenger for Windows (%MODE%)
echo ==========================================================

where flutter >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo ОШИБКА: Команда 'flutter' не найдена в переменной PATH!
    echo Установите Flutter SDK: https://docs.flutter.dev/get-started/install/windows
    echo Также убедитесь, что установлен Visual Studio с компонентом "Desktop development with C++".
    pause
    exit /b 1
)

echo --> Включение поддержки Windows Desktop в Flutter...
call flutter config --enable-windows-desktop >nul 2>&1

echo --> Обновление зависимостей...
call flutter pub get
if %ERRORLEVEL% neq 0 (
    echo ОШИБКА при загрузке зависимостей!
    pause
    exit /b %ERRORLEVEL%
)

if /i "%MODE%"=="debug" (
    echo --> Компиляция Windows Debug...
    call flutter build windows --debug
    set "EXE_DIR=%DIR%build\windows\x64\runner\Debug"
) else (
    echo --> Компиляция Windows Release...
    call flutter build windows --release
    set "EXE_DIR=%DIR%build\windows\x64\runner\Release"
)

if %ERRORLEVEL% neq 0 (
    echo.
    echo ОШИБКА: Сборка не удалась. Убедитесь, что установлен Visual Studio 2022 с рабочей нагрузкой "Разработка классических приложений на C++" (Desktop development with C++).
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo ==========================================================
echo  Сборка для Windows успешно завершена!
echo  Папка с приложением: !EXE_DIR!
echo  Исполняемый файл: !EXE_DIR!\openvk_messenger.exe
echo ==========================================================
echo.
pause
