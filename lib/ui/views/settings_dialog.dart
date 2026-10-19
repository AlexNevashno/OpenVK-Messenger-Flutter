import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/theme_pack.dart';
import '../../services/chat_cache.dart';
import '../../services/memory_manager.dart';
import '../../services/messenger_store.dart';
import '../../services/notification_service.dart';
import '../../services/telegram_theme_importer.dart';
import '../../services/theme_manager.dart';
import '../modals/theme_preview_dialog.dart';

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key});

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<String> _tabs = [
    'Внешний вид',
    'Основные',
    'О программе',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _importTelegramTheme(BuildContext context) async {
    try {
      final files = await FilePicker.pickFiles(
        dialogTitle: 'Выберите тему Telegram (.tdesktop-theme, .attheme, .tgios-theme, .tgx-theme, .palette, .zip, .txt)',
        type: FileType.custom,
        allowedExtensions: ['tdesktop-theme', 'attheme', 'tgios-theme', 'tgx-theme', 'palette', 'tgtheme', 'zip', 'txt', 'themepack', 'json'],
      );

      if (files.isNotEmpty && files.first.path != null) {
        final file = File(files.first.path!);
        VKThemePack pack;

        final ext = file.path.split('.').last.toLowerCase();
        if (ext == 'json' || ext == 'themepack') {
          final content = await file.readAsString();
          final json = jsonDecode(content) as Map<String, dynamic>;
          pack = VKThemePack.fromJson(json);
        } else {
          pack = await TelegramThemeImporter.importThemeFromFile(file);
        }

        if (context.mounted) {
          showDialog(
            context: context,
            builder: (_) => ThemePreviewDialog(themePack: pack),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка импорта темы: $e')),
        );
      }
    }
  }

  Future<void> _exportTheme(BuildContext context, ThemeManager theme) async {
    try {
      final current = theme.customTheme ?? VKThemePack.telegramDark;
      final jsonStr = jsonEncode(current.toJson());
      final bytes = Uint8List.fromList(utf8.encode(jsonStr));
      final uri = await FilePicker.saveFile(
        dialogTitle: 'Сохранить тему оформления',
        fileName: '${current.name}.themepack.txt',
        bytes: bytes,
      );
      if (uri != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Тема успешно сохранена: ${current.name}.themepack.txt')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка сохранения темы: $e')),
        );
      }
    }
  }

  Future<void> _chooseCustomWallpaper(BuildContext context, ThemeManager theme) async {
    try {
      final files = await FilePicker.pickFiles(
        dialogTitle: 'Выберите фоновое изображение для чатов',
        type: FileType.image,
      );
      if (files.isNotEmpty && files.first.path != null) {
        final file = File(files.first.path!);
        final bytes = await file.readAsBytes();
        final b64 = base64Encode(bytes);
        await theme.setCustomWallpaper(filePath: file.path, base64: b64);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Фоновое изображение установлено!')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка выбора фона: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeManager>();
    final store = context.watch<MessengerStore>();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: theme.getSurfaceColor(context),
      child: Container(
        width: 600,
        height: 540,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title & Close
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Настройки',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: theme.getTextColor(context),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Tab bar
            TabBar(
              controller: _tabController,
              indicatorColor: theme.accentColor,
              labelColor: theme.accentColor,
              unselectedLabelColor: theme.getSecondaryTextColor(context),
              tabs: _tabs.map((t) => Tab(text: t)).toList(),
            ),
            const SizedBox(height: 12),

            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildAppearanceTab(context, theme),
                  _buildGeneralTab(context, theme, store),
                  _buildAboutTab(context, theme),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppearanceTab(BuildContext context, ThemeManager theme) {
    final currentTheme = theme.customTheme ?? VKThemePack.telegramDark;

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        // Section 1: Presets & Telegram Import
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Темы оформления',
              style: TextStyle(fontWeight: FontWeight.bold, color: theme.getTextColor(context), fontSize: 13.5),
            ),
            Row(
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.download_rounded, size: 15),
                  label: const Text('Портировать из Telegram...', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.accentColor.withValues(alpha: 0.15),
                    foregroundColor: theme.accentColor,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  onPressed: () => _importTelegramTheme(context),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.visibility_outlined, size: 15),
                  label: const Text('Предпросмотр...', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.accentColor,
                    side: BorderSide(color: theme.accentColor.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => ThemePreviewDialog(themePack: currentTheme),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Presets Grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.2,
          ),
          itemCount: VKThemePack.allPresets.length,
          itemBuilder: (ctx, idx) {
            final preset = VKThemePack.allPresets[idx];
            final isSelected = theme.customTheme?.id == preset.id;

            return InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => theme.applyThemePack(preset),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: preset.backgroundColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? theme.accentColor : Colors.white24,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(radius: 5, backgroundColor: preset.accentColor),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        preset.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: preset.isDark ? Colors.white : Colors.black,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),

        const SizedBox(height: 14),
        Divider(color: theme.getSeparatorColor(context)),
        const SizedBox(height: 12),

        // Section 2: Chat Wallpaper Customization (Matching Swift SettingsModalView)
        Text(
          'Фоновое изображение чатов',
          style: TextStyle(fontWeight: FontWeight.bold, color: theme.getTextColor(context), fontSize: 13.5),
        ),
        const SizedBox(height: 10),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Wallpaper Preview Box
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: theme.getBackgroundColor(context),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.getSeparatorColor(context)),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (theme.wallpaperImageProvider != null && theme.wallpaperPattern != 'none')
                    RepaintBoundary(
                      child: ImageFiltered(
                        imageFilter: ImageFilter.blur(
                          sigmaX: theme.wallpaperBlur / 2,
                          sigmaY: theme.wallpaperBlur / 2,
                        ),
                        child: Opacity(
                          opacity: theme.wallpaperOpacity.clamp(0.0, 1.0),
                          child: Image(
                            image: theme.wallpaperImageProvider!,
                            fit: BoxFit.cover,
                            repeat: theme.wallpaperPattern == 'telegram_doodles' ? ImageRepeat.repeat : ImageRepeat.noRepeat,
                            gaplessPlayback: true,
                            errorBuilder: (ctx, err, stack) => const SizedBox(),
                          ),
                        ),
                      ),
                    )
                  else
                    Icon(Icons.photo, color: theme.getSecondaryTextColor(context)),
                ],
              ),
            ),
            const SizedBox(width: 14),

            // Wallpaper Controls
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.file_upload_outlined, size: 14),
                        label: const Text('Выбрать с компьютера...', style: TextStyle(fontSize: 11.5)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.getSecondarySurfaceColor(context),
                          foregroundColor: theme.getTextColor(context),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        onPressed: () => _chooseCustomWallpaper(context, theme),
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.auto_awesome, size: 14),
                        label: const Text('Telegram Doodles', style: TextStyle(fontSize: 11.5)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.wallpaperPattern == 'telegram_doodles'
                              ? theme.accentColor.withValues(alpha: 0.18)
                              : theme.getSecondarySurfaceColor(context),
                          foregroundColor: theme.wallpaperPattern == 'telegram_doodles'
                              ? theme.accentColor
                              : theme.getTextColor(context),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        onPressed: () => theme.setTelegramDoodlesWallpaper(),
                      ),
                      if (theme.wallpaperPattern != 'none')
                        TextButton(
                          onPressed: () => theme.removeWallpaper(),
                          child: const Text('Удалить фон', style: TextStyle(color: Colors.red, fontSize: 11.5)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Opacity Slider
                  Row(
                    children: [
                      SizedBox(
                        width: 90,
                        child: Row(
                          children: [
                            Text('Прозрачность: ', style: TextStyle(fontSize: 11, color: theme.getSecondaryTextColor(context))),
                          ],
                        ),
                      ),
                      Text('${(theme.wallpaperOpacity * 100).toInt()}%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.accentColor)),
                      Expanded(
                        child: Slider(
                          value: theme.wallpaperOpacity,
                          min: 0.05,
                          max: 1.0,
                          divisions: 19,
                          activeColor: theme.accentColor,
                          onChanged: (val) => theme.setWallpaperOpacity(val, persist: false),
                          onChangeEnd: (val) => theme.setWallpaperOpacity(val, persist: true),
                        ),
                      ),
                    ],
                  ),

                  // Blur Slider (matching Mac Swift SettingsModalView)
                  Row(
                    children: [
                      SizedBox(
                        width: 90,
                        child: Row(
                          children: [
                            Text('Размытие: ', style: TextStyle(fontSize: 11, color: theme.getSecondaryTextColor(context))),
                          ],
                        ),
                      ),
                      Text('${theme.wallpaperBlur.toInt()} px', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.accentColor)),
                      Expanded(
                        child: Slider(
                          value: theme.wallpaperBlur.clamp(0.0, 20.0),
                          min: 0.0,
                          max: 20.0,
                          divisions: 20,
                          activeColor: theme.accentColor,
                          onChanged: (val) => theme.setWallpaperBlur(val, persist: false),
                          onChangeEnd: (val) => theme.setWallpaperBlur(val, persist: true),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),
        Divider(color: theme.getSeparatorColor(context)),
        const SizedBox(height: 10),

        // Section 3: Export Theme
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.ios_share_rounded, color: theme.accentColor),
          title: const Text('Сохранить тему в файл (.themepack.txt)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          subtitle: const Text('Экспортировать текущее оформление для отправки друзьям', style: TextStyle(fontSize: 11)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _exportTheme(context, theme),
        ),

        const SizedBox(height: 10),
        Divider(color: theme.getSeparatorColor(context)),
        const SizedBox(height: 10),

        // Base theme mode
        Text(
          'Режим',
          style: TextStyle(fontWeight: FontWeight.bold, color: theme.getTextColor(context), fontSize: 13),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            _buildModeChoice(context, theme, 'Тёмная', AppThemeMode.dark),
            _buildModeChoice(context, theme, 'Светлая', AppThemeMode.light),
            _buildModeChoice(context, theme, 'AMOLED', AppThemeMode.amoled),
            _buildModeChoice(context, theme, 'Системная', AppThemeMode.system),
          ],
        ),

        const SizedBox(height: 14),

        // Accent Colors
        Text(
          'Цветовой акцент',
          style: TextStyle(fontWeight: FontWeight.bold, color: theme.getTextColor(context), fontSize: 13),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          children: [
            _buildColorCircle(theme, const Color(0xFFE25241)), // Telegram Red
            _buildColorCircle(theme, const Color(0xFF2D81E0)), // VK Blue
            _buildColorCircle(theme, const Color(0xFF3390EC)), // Telegram Day Blue
            _buildColorCircle(theme, const Color(0xFF5288C1)), // Indigo
            _buildColorCircle(theme, const Color(0xFF2ECC71)), // Emerald Green
            _buildColorCircle(theme, const Color(0xFFFF007F)), // Neon Pink
          ],
        ),

        const SizedBox(height: 14),

        // Section: Bubble Stroke
        Text(
          'Обводка сообщений',
          style: TextStyle(fontWeight: FontWeight.bold, color: theme.getTextColor(context), fontSize: 13),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          children: [
            _buildStrokeColorCircle(theme, null, 'Без обводки'),
            _buildStrokeColorCircle(theme, const Color(0x33FFFFFF), 'Светлая'),
            _buildStrokeColorCircle(theme, const Color(0x88FFFFFF), 'Яркая'),
            _buildStrokeColorCircle(theme, theme.accentColor, 'В цвет акцента'),
            _buildStrokeColorCircle(theme, const Color(0x55000000), 'Тёмная'),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Толщина обводки', style: TextStyle(color: theme.getTextColor(context), fontSize: 13)),
            Text('${theme.bubbleStrokeWidth.toStringAsFixed(1)} px', style: TextStyle(color: theme.accentColor, fontWeight: FontWeight.bold)),
          ],
        ),
        Slider(
          value: theme.bubbleStrokeWidth.clamp(0.0, 3.0),
          min: 0.0,
          max: 3.0,
          divisions: 30,
          activeColor: theme.accentColor,
          onChanged: (val) {
            theme.setBubbleStroke(color: theme.bubbleStrokeColor, width: val);
          },
        ),

        const SizedBox(height: 14),

        // Font size slider
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Масштаб шрифта', style: TextStyle(color: theme.getTextColor(context), fontSize: 13)),
            Text('${(theme.fontSizeScale * 100).toInt()}%', style: TextStyle(color: theme.accentColor, fontWeight: FontWeight.bold)),
          ],
        ),
        Slider(
          value: theme.fontSizeScale,
          min: 0.8,
          max: 1.4,
          divisions: 6,
          activeColor: theme.accentColor,
          onChanged: (val) => theme.setFontScale(val),
        ),

        const SizedBox(height: 12),
        Divider(color: theme.getSeparatorColor(context)),
        const SizedBox(height: 8),

        // Section: Форма сообщений (Квадратные баблы VK 2013)
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          activeThumbColor: theme.accentColor,
          secondary: Icon(
            theme.useSquareBubbles ? Icons.crop_square_rounded : Icons.rounded_corner_rounded,
            color: theme.accentColor,
          ),
          title: Text(
            'Квадратные баблы',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: theme.getTextColor(context),
            ),
          ),
          subtitle: Text(
            'Классическая прямоугольная форма облачков сообщений в стиле ВКонтакте 2013 года',
            style: TextStyle(
              fontSize: 11,
              color: theme.getSecondaryTextColor(context),
            ),
          ),
          value: theme.useSquareBubbles,
          onChanged: (val) => theme.setUseSquareBubbles(val),
        ),
      ],
    );
  }

  Widget _buildGeneralTab(BuildContext context, ThemeManager theme, MessengerStore store) {
    final notifService = context.watch<NotificationService>();

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        if (store.activeAccount != null) ...[
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.person, color: theme.accentColor),
            title: Text(store.activeAccount!.name),
            subtitle: Text('ID: ${store.activeAccount!.userId} • ${store.activeAccount!.serverURL}'),
          ),
          const Divider(),
        ],

        // Section: Уведомления
        Text(
          'УВЕДОМЛЕНИЯ',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: theme.accentColor,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 4),

        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          activeThumbColor: theme.accentColor,
          secondary: Icon(
            notifService.notificationsEnabled ? Icons.notifications_active_rounded : Icons.notifications_off_rounded,
            color: theme.accentColor,
          ),
          title: Text(
            'Уведомления на рабочем столе',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: theme.getTextColor(context)),
          ),
          subtitle: Text(
            'Показывать системные уведомления для новых сообщений',
            style: TextStyle(fontSize: 11, color: theme.getSecondaryTextColor(context)),
          ),
          value: notifService.notificationsEnabled,
          onChanged: (val) => notifService.setNotificationsEnabled(val),
        ),

        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          activeThumbColor: theme.accentColor,
          secondary: Icon(
            notifService.soundEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
            color: theme.accentColor,
          ),
          title: Text(
            'Звуковые уведомления',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: theme.getTextColor(context)),
          ),
          subtitle: Text(
            'Воспроизводить системный звук при получении сообщения',
            style: TextStyle(fontSize: 11, color: theme.getSecondaryTextColor(context)),
          ),
          value: notifService.soundEnabled,
          onChanged: (val) => notifService.setSoundEnabled(val),
        ),

        const SizedBox(height: 10),
        const Divider(),
        const SizedBox(height: 6),

        // Section: Память и оптимизация
        Text(
          'ПРОИЗВОДИТЕЛЬНОСТЬ И ПАМЯТЬ',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: theme.accentColor,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 4),

        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.memory_rounded, color: theme.accentColor),
          title: Row(
            children: [
              Text(
                'Лимит ОЗУ (150–200 МБ)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: theme.getTextColor(context)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Активно',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green),
                ),
              ),
            ],
          ),
          subtitle: Text(
            'Автоматическая выгрузка текстур, ограничение кэша до 40 МБ и очистка скрытых изображений',
            style: TextStyle(fontSize: 11, color: theme.getSecondaryTextColor(context)),
          ),
          trailing: TextButton.icon(
            icon: const Icon(Icons.cleaning_services_rounded, size: 16),
            label: const Text('Сбросить ОЗУ', style: TextStyle(fontSize: 11)),
            onPressed: () {
              MemoryManager.instance.purgeAllMemoryCaches();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Кэш изображений и текстур в ОЗУ очищен'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 6),
        const Divider(),
        const SizedBox(height: 6),

        // Section: Хранилище
        Text(
          'ХРАНИЛИЩЕ',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: theme.accentColor,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 4),

        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.delete_outline, color: Colors.orange),
          title: Text(
            'Очистить локальный кэш диалогов',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: theme.getTextColor(context)),
          ),
          subtitle: Text(
            'Удаляет сохранённые сообщения из локальной БД',
            style: TextStyle(fontSize: 11, color: theme.getSecondaryTextColor(context)),
          ),
          trailing: TextButton(
            child: const Text('Очистить'),
            onPressed: () async {
              await ChatCache.instance.clearAll();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Кэш успешно очищен')),
                );
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAboutTab(BuildContext context, ThemeManager theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset(
              'assets/images/app_icon.png',
              width: 68,
              height: 68,
              errorBuilder: (ctx, err, stack) => Icon(Icons.chat_bubble_rounded, size: 54, color: theme.accentColor),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'OpenVK Messenger',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.getTextColor(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Версия 1.0 (Flutter Desktop: Windows & Linux & macOS)',
            style: TextStyle(color: theme.getSecondaryTextColor(context), fontSize: 12),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Неофициальный клиент для социальной сети OpenVK.\nРазработано с заботой о скорости, удобстве и дизайне.',
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.getSecondaryTextColor(context), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeChoice(BuildContext context, ThemeManager theme, String title, AppThemeMode mode) {
    final isSelected = theme.mode == mode && theme.customTheme == null;
    return ChoiceChip(
      label: Text(title),
      selected: isSelected,
      selectedColor: theme.accentColor,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : theme.getSecondaryTextColor(context),
        fontSize: 12,
      ),
      onSelected: (_) => theme.setThemeMode(mode),
    );
  }

  Widget _buildColorCircle(ThemeManager theme, Color color) {
    final isSelected = theme.accentColor.toARGB32() == color.toARGB32();
    return GestureDetector(
      onTap: () => theme.setAccentColor(color),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: isSelected ? Border.all(color: Colors.white, width: 2.5) : null,
        ),
      ),
    );
  }

  Widget _buildStrokeColorCircle(ThemeManager theme, Color? color, String tooltip) {
    final isSelected = color == null
        ? (theme.bubbleStrokeColor == null || theme.bubbleStrokeWidth == 0)
        : (theme.bubbleStrokeColor != null && theme.bubbleStrokeColor!.toARGB32() == color.toARGB32() && theme.bubbleStrokeWidth > 0);

    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: () {
          if (color == null) {
            theme.setBubbleStroke(color: null, width: 0);
          } else {
            theme.setBubbleStroke(color: color, width: theme.bubbleStrokeWidth > 0 ? theme.bubbleStrokeWidth : 1.0);
          }
        },
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color ?? Colors.transparent,
            border: Border.all(
              color: isSelected ? theme.accentColor : Colors.grey.withValues(alpha: 0.5),
              width: isSelected ? 2.5 : 1.0,
            ),
          ),
          child: color == null
              ? const Icon(Icons.block, size: 14, color: Colors.grey)
              : null,
        ),
      ),
    );
  }
}
