# OpenVK Messenger (Flutter)

<div align="center">

![OpenVK Messenger Banner](https://raw.githubusercontent.com/openvk/openvk/master/public/assets/packages/static/openvk/img/logo_big.png)

### Быстрый, легковесный и кроссплатформенный клиент OpenVK на базе Flutter

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Platform](https://img.shields.io/badge/Platforms-macOS%20%7C%20Windows%20%7C%20Linux%20%7C%20Android-blue)](#поддерживаемые-платформы)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![RAM Usage](https://img.shields.io/badge/RAM-100--200%20MB-brightgreen)](#оптимизация-памяти)

</div>

---

## 📖 О проекте

**OpenVK Messenger** — современный клиент для социальной сети [OpenVK](https://github.com/openvk/openvk), написанный на **Flutter**.  
Клиент спроектирован с упором на максимальную производительность, удобство работы на десктопных и мобильных ОС, сверхнизкое потребление ресурсов оперативной памяти и богатый набор возможностей для комфортного общения.

---

## ✨ Основные возможности

### 💬 Сообщения и чаты
- **Адаптивные баблы сообщений**: баблы автоматически подстраиваются под ширину и размер контента (`IntrinsicWidth`), как в современных мессенджерах.
- **Редактирование сообщений**: мгновенный переход в режим редактирования, панель предпросмотра, поддержка горячих клавиш (`Enter` для сохранения, `Esc` для отмены).
- **Удаление сообщений**: удаление для себя или для всех участников беседы.
- **Упоминания и пинги (@mentions)**:
  - Автоматическое форматирование разметки `[id123|Имя]` в читаемые `@Имя`.
  - Уникальные цвета для авторов сообщений в беседах.
  - Подсветка сообщений с пингом текущего пользователя.
  - Значок собаки `@` возле счетчика непрочитанных сообщений в списке чатов при наличии упоминания.
- **LongPoll синхронизация**: мгновенное получение новых сообщений, статусов прочтения и индикаторов набора текста (typing) в реальном времени.
- **Закрепленные сообщения** и быстрый поиск по диалогам.

### 📋 Буфер обмена и Drag-and-Drop
- **Вставка из буфера обмена (Pasteboard)**: поддержка хоткеев `Cmd + V` (macOS) / `Ctrl + V` (Windows / Linux) для прямой вставки скопированных скриншотов, картинок и файлов в очередь вложений.
- **Drag & Drop**: возможность просто перетащить файлы и изображения мышью прямо в окно чата.

### 🎨 Кастомизация и движок тем
- **Поддержка тем Telegram Desktop (`.tdesktop-theme`)**:
  - Полная поддержка синтаксиса цветов и прозрачности (включая 8-значные hex-коды `#RRGGBBAA`).
  - Распаковка и применение кастомных фонов и фоновых узоров (doodles).
  - Настройка размытия (blur) и прозрачности фонового изображения чата.
- **Настройка обводки баблов**: выбор толщины и цвета контура сообщений с живым предпросмотром.

### 🎵 Медиаплееры
- **Музыкальный плеер в стиле Telegram**: встроенный аудиоконтроллер с возможностью воспроизведения, паузы, перемотки, переключения треков и сворачиваемым миниплеером.
- **Встроенный видеоплеер**: просмотр видеозаписей с регулировкой громкости, поддержкой аудиодорожек и полноэкранным режимом.

### 👥 Мультиаккаунт
- Хранение нескольких сессий и мгновенное переключение между аккаунтами без повторной авторизации.

### ⚡ Оптимизация памяти
- Жесткий контроль потребления ОЗУ (**100–200 МБ** в активном режиме).
- Умный LRU-кэш для сетевых изображений и аватарок (`flutter_cache_manager` / `cached_network_image`).
- Очистка неиспользуемых текстур и ресурсов при переключении между диалогами.

---

## 🖥 Поддерживаемые платформы

| Платформа | Статус | Примечание |
| :--- | :---: | :--- |
| **macOS** | ✅ Поддерживается | Apple Silicon (M1/M2/M3/M4) и Intel x86_64, нативная интеграция хоткеев |
| **Windows** | ✅ Поддерживается | Windows 10/11 x64, поддержка `video_player_win` |
| **Linux** | ✅ Поддерживается | Ubuntu / Debian / Arch / Fedora |
| **Android** | ✅ Поддерживается | Android 6.0+ (ARM64 / ARMv7) |
| **iOS** | ℹ️ Доступна отдельно | Для iOS используется отдельная нативная версия на Swift |

---

## 🛠 Стек технологий

- **Фреймворк**: [Flutter](https://flutter.dev) (Dart 3)
- **Управление состоянием**: `provider`
- **Сетевой слой & API**: `dio`, `http`, кастомный клиент OpenVK API v5.x + LongPoll
- **Кэширование и хранение**: `shared_preferences`, `path_provider`, `cached_network_image`
- **Мультимедиа**: `audioplayers`, `video_player`, `video_player_win`
- **Десктопные интеграции**: `pasteboard`, `desktop_drop`, `local_notifier`, `file_picker`, `url_launcher`
- **Архивы и темы**: `archive`, `crypto`

---

## 🚀 Сборка и запуск проекта

### Требования
1. Установленный [Flutter SDK](https://docs.flutter.dev/get-started/install) (версия >= 3.19.0).
2. Зависимости платформы:
   - **macOS**: Xcode и CocoaPods (`brew install cocoapods`).
   - **Windows**: Visual Studio 2022 с компонентом «Desktop development with C++».
   - **Linux**: `clang`, `cmake`, `ninja-build`, `pkg-config`, `libgtk-3-dev`.

### Установка зависимостей
```bash
# Клонирование репозитория
git clone https://github.com/openvk/OpenVK-Messenger-Flutter.git
cd OpenVK-Messenger-Flutter

# Получение пакетов
flutter pub get
```

### Запуск в режиме разработки
```bash
# macOS
flutter run -d macos

# Windows
flutter run -d windows

# Linux
flutter run -d linux

# Android
flutter run -d android
```

### Сборка релизной версии
```bash
# macOS App / DMG
flutter build macos --release

# Windows Exe
flutter build windows --release

# Linux App
flutter build linux --release

# Android APK
flutter build apk --release
```

---

## 📁 Структура проекта

```text
lib/
├── api/              # Работа с OpenVK API, авторизация, LongPoll слушатель
├── models/           # Модели данных (User, Message, Conversation, Attachment)
├── providers/        # State management (ChatProvider, ThemeProvider, MultiAccountProvider)
├── screens/          # Экраны (Авторизация, Список чатов, Диалог, Настройки, Профиль)
├── themes/           # Парсер .tdesktop-theme, цветовые палитры, стили баблов
├── widgets/          # Переиспользуемые виджеты (аудиоплеер, видеоплеер, баблы, вложения)
└── main.dart         # Точка входа в приложение и инициализация сервисов
```

---

## 🤝 Вклад в проект (Contributing)

Мы рады любому вкладу в развитие проекта:
1. Форкните репозиторий.
2. Создайте свою ветку (`git checkout -b feature/awesome-feature`).
3. Сделайте коммит ваших изменений (`git commit -m 'Add awesome feature'`).
4. Отправьте ветку в origin (`git push origin feature/awesome-feature`).
5. Откройте **Pull Request**.

---

## 📄 Лицензия

Проект распространяется под лицензией **MIT**. Подробности в файле [LICENSE](LICENSE).
