import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/theme_pack.dart';
import '../../services/theme_manager.dart';

class ThemePreviewDialog extends StatelessWidget {
  final VKThemePack themePack;
  final VoidCallback? onApply;

  const ThemePreviewDialog({
    super.key,
    required this.themePack,
    this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeManager>();
    final isDark = themePack.isDark;

    final primaryTextColor = isDark ? Colors.white : const Color(0xFF19191A);
    final secondaryTextColor = isDark ? const Color(0xFFA0A5AC) : const Color(0xFF818C99);

    return Dialog(
      backgroundColor: theme.getSurfaceColor(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 680,
        height: 580,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Modal Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Предпросмотр темы: ${themePack.name}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: theme.getTextColor(context),
                      ),
                    ),
                    Text(
                      'Автор: ${themePack.author}',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.getSecondaryTextColor(context),
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Live Window Mockup
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: themePack.backgroundColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: themePack.separatorColor,
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Row(
                  children: [
                    // Mock Sidebar (Left)
                    Container(
                      width: 200,
                      color: themePack.surfaceColor,
                      child: Column(
                        children: [
                          // Mock Sidebar Header
                          Container(
                            height: 44,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: themePack.separatorColor, width: 0.8),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.search, size: 16, color: secondaryTextColor),
                                const SizedBox(width: 8),
                                Text(
                                  'Поиск',
                                  style: TextStyle(color: secondaryTextColor, fontSize: 12),
                                ),
                              ],
                            ),
                          ),

                          // Mock Active Chat Item
                          Container(
                            margin: const EdgeInsets.all(6),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(
                              color: themePack.accentColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                                  child: const Text('ПД', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Павел Дуров', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                      Text('Вы: Выглядит шика...', style: TextStyle(color: Colors.white70, fontSize: 10.5), maxLines: 1),
                                    ],
                                  ),
                                ),
                                const Text('14:33', style: TextStyle(color: Colors.white70, fontSize: 10)),
                              ],
                            ),
                          ),

                          // Mock Second Chat Item
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: themePack.secondarySurfaceColor,
                                  child: Text('БД', style: TextStyle(color: primaryTextColor, fontSize: 11)),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Беседа разработчиков', style: TextStyle(color: primaryTextColor, fontSize: 12, fontWeight: FontWeight.bold), maxLines: 1),
                                      Text('Новый коммит в ветку...', style: TextStyle(color: secondaryTextColor, fontSize: 10.5), maxLines: 1),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: themePack.accentColor,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Text('3', style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Divider
                    Container(width: 0.8, color: themePack.separatorColor),

                    // Mock Chat Area (Right)
                    Expanded(
                      child: Stack(
                        children: [
                          // Wallpaper
                          if (themePack.wallpaperPattern == 'telegram_doodles')
                            Positioned.fill(
                              child: Opacity(
                                opacity: themePack.wallpaperOpacity.clamp(0.0, 1.0),
                                child: Image.asset(
                                  'assets/images/telegram_doodles.png',
                                  fit: BoxFit.cover,
                                  repeat: ImageRepeat.repeat,
                                  errorBuilder: (ctx, err, stack) => const SizedBox(),
                                ),
                              ),
                            )
                          else if (themePack.wallpaperBase64 != null && themePack.wallpaperBase64!.isNotEmpty)
                            Positioned.fill(
                              child: Opacity(
                                opacity: themePack.wallpaperOpacity.clamp(0.0, 1.0),
                                child: Image.memory(
                                  base64Decode(themePack.wallpaperBase64!),
                                  fit: BoxFit.cover,
                                  errorBuilder: (ctx, err, stack) => const SizedBox(),
                                ),
                              ),
                            ),

                          // Chat Content
                          Column(
                            children: [
                              // Chat Header
                              Container(
                                height: 44,
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                decoration: BoxDecoration(
                                  color: themePack.surfaceColor,
                                  border: Border(
                                    bottom: BorderSide(color: themePack.separatorColor, width: 0.8),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'Павел Дуров',
                                          style: TextStyle(
                                            color: primaryTextColor,
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          'был в сети 2 часа назад',
                                          style: TextStyle(
                                            color: secondaryTextColor,
                                            fontSize: 10.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Spacer(),
                                    Icon(Icons.more_vert, size: 18, color: secondaryTextColor),
                                  ],
                                ),
                              ),

                              // Messages Area
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      // Incoming Bubble
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: Container(
                                          constraints: const BoxConstraints(maxWidth: 320),
                                          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                                          decoration: BoxDecoration(
                                            color: themePack.bubbleIncomingColor,
                                            borderRadius: BorderRadius.circular(10),
                                            border: themePack.bubbleStrokeColor != null
                                                ? Border.all(color: themePack.bubbleStrokeColor!, width: themePack.bubbleStrokeWidth)
                                                : null,
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Привет! Как тебе тема Telegram в OpenVK Messenger?',
                                                style: TextStyle(
                                                  color: themePack.bubbleIncomingTextColor,
                                                  fontSize: 12.5,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Align(
                                                alignment: Alignment.bottomRight,
                                                child: Text(
                                                  '14:32',
                                                  style: TextStyle(
                                                    color: themePack.bubbleIncomingTextColor.withValues(alpha: 0.65),
                                                    fontSize: 10,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),

                                      // Outgoing Bubble
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: Container(
                                          constraints: const BoxConstraints(maxWidth: 320),
                                          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                                          decoration: BoxDecoration(
                                            color: themePack.bubbleOutgoingColor,
                                            borderRadius: BorderRadius.circular(10),
                                            border: themePack.bubbleStrokeColor != null
                                                ? Border.all(color: themePack.bubbleStrokeColor!, width: themePack.bubbleStrokeWidth)
                                                : null,
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Выглядит шикарно, полностью совпадает с нативным клиентом!',
                                                style: TextStyle(
                                                  color: themePack.bubbleOutgoingTextColor,
                                                  fontSize: 12.5,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Spacer(),
                                                  Text(
                                                    '14:33',
                                                    style: TextStyle(
                                                      color: themePack.bubbleOutgoingTextColor.withValues(alpha: 0.65),
                                                      fontSize: 10,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Icon(Icons.done_all, size: 12, color: themePack.bubbleOutgoingTextColor),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // Mock Write Bar
                              Container(
                                height: 42,
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  color: themePack.surfaceColor,
                                  border: Border(
                                    top: BorderSide(color: themePack.separatorColor, width: 0.8),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.attach_file, size: 18, color: secondaryTextColor),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Container(
                                        height: 28,
                                        padding: const EdgeInsets.symmetric(horizontal: 10),
                                        decoration: BoxDecoration(
                                          color: themePack.secondarySurfaceColor,
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            'Напишите сообщение...',
                                            style: TextStyle(color: secondaryTextColor, fontSize: 11.5),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(Icons.sentiment_satisfied_alt, size: 18, color: secondaryTextColor),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Bottom Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Отмена',
                    style: TextStyle(color: theme.getSecondaryTextColor(context)),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themePack.accentColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    context.read<ThemeManager>().applyThemePack(themePack);
                    onApply?.call();
                    Navigator.pop(context);
                  },
                  child: const Text('Применить тему', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
