#!/usr/bin/env bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd "$DIR"

MODE="${1:-release}"

echo "=========================================================="
echo "   Building OpenVK Messenger for Linux ($MODE)"
echo "=========================================================="

# Check if flutter is installed
if ! command -v flutter &> /dev/null; then
    echo "ОШИБКА: Команда 'flutter' не найдена в PATH!"
    echo "Установите Flutter SDK: https://docs.flutter.dev/get-started/install/linux"
    exit 1
fi

# Inform about Linux system dependencies if cmake/ninja/clang are missing
MISSING_PKGS=0
for cmd in cmake ninja pkg-config clang; do
    if ! command -v "$cmd" &> /dev/null; then
        MISSING_PKGS=1
    fi
done

if [ "$MISSING_PKGS" -eq 1 ]; then
    echo "Примечание: для сборки под Linux требуются системные пакеты."
    echo "Если сборка завершится с ошибкой, установите их:"
    echo "  Ubuntu/Debian/Mint:"
    echo "    sudo apt-get update && sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev"
    echo "  Fedora:"
    echo "    sudo dnf install -y clang cmake ninja-build pkgconf-pkg-config gtk3-devel xz-devel gstreamer1-devel gstreamer1-plugins-base-devel"
    echo "  Arch Linux:"
    echo "    sudo pacman -S --needed clang cmake ninja pkgconf gtk3 xz gstreamer gst-plugins-base"
    echo ""
fi

echo "--> Включение поддержки Linux Desktop в Flutter..."
flutter config --enable-linux-desktop >/dev/null 2>&1 || true

echo "--> Обновление зависимостей..."
flutter pub get

if [ "$MODE" = "debug" ]; then
    echo "--> Компиляция Linux Debug..."
    flutter build linux --debug
    BUNDLE_DIR="$DIR/build/linux/x64/debug/bundle"
else
    echo "--> Компиляция Linux Release..."
    flutter build linux --release
    BUNDLE_DIR="$DIR/build/linux/x64/release/bundle"
fi

echo ""
echo "=========================================================="
echo " Сборка для Linux успешно завершена!"
echo " Папка с приложением: $BUNDLE_DIR"
echo " Запуск приложения:"
echo "   $BUNDLE_DIR/openvk_messenger"
echo "=========================================================="
