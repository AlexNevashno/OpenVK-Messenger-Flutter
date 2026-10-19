param (
    [string]$Mode = "release"
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   Building OpenVK Messenger for Windows ($Mode)" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Host "ОШИБКА: Flutter не найден в PATH!" -ForegroundColor Red
    Write-Host "Установите Flutter SDK: https://docs.flutter.dev/get-started/install/windows"
    exit 1
}

Write-Host "--> Включение Windows Desktop в Flutter..."
flutter config --enable-windows-desktop | Out-Null

Write-Host "--> Обновление зависимостей..."
flutter pub get

if ($Mode.ToLower() -eq "debug") {
    Write-Host "--> Компиляция Windows Debug..." -ForegroundColor Yellow
    flutter build windows --debug
    $ExeDir = Join-Path $ScriptDir "build\windows\x64\runner\Debug"
} else {
    Write-Host "--> Компиляция Windows Release..." -ForegroundColor Green
    flutter build windows --release
    $ExeDir = Join-Path $ScriptDir "build\windows\x64\runner\Release"
}

Write-Host ""
Write-Host "==========================================================" -ForegroundColor Green
Write-Host " Сборка для Windows успешно завершена!" -ForegroundColor Green
Write-Host " Папка с приложением: $ExeDir"
Write-Host " Исполняемый файл: $ExeDir\openvk_messenger.exe"
Write-Host "==========================================================" -ForegroundColor Green
