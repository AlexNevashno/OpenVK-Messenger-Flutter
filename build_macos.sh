#!/usr/bin/env bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd "$DIR"

MODE="${1:-release}"

echo "=============================================="
echo " Building OpenVK Messenger for macOS ($MODE)"
echo "=============================================="

echo "--> Установка и обновление зависимостей..."
flutter pub get

if [ "$MODE" = "debug" ]; then
    echo "--> Компиляция Debug сборки..."
    flutter build macos --debug
    APP_PATH="$DIR/build/macos/Build/Products/Debug/OpenVK Messenger.app"
else
    echo "--> Компиляция Release сборки..."
    flutter build macos --release
    APP_PATH="$DIR/build/macos/Build/Products/Release/OpenVK Messenger.app"
fi

echo ""
echo "=============================================="
echo "Сборка успешно завершена!"
echo "Путь к приложению: $APP_PATH"
echo "Запустить приложение: open \"$APP_PATH\""
echo "=============================================="
