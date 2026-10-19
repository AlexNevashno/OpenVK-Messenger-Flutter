import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/message.dart';
import '../../services/theme_manager.dart';

class PinnedMessageBar extends StatelessWidget {
  final VKMessage pinnedMessage;
  final VoidCallback onJumpToMessage;
  final VoidCallback onUnpin;

  const PinnedMessageBar({
    super.key,
    required this.pinnedMessage,
    required this.onJumpToMessage,
    required this.onUnpin,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeManager>();
    final isDark = theme.isDark(context);

    String displayText = pinnedMessage.text;
    if (displayText.isEmpty) {
      if (pinnedMessage.photos.isNotEmpty) {
        displayText = '📷 Фотография';
      } else if (pinnedMessage.docs.isNotEmpty) {
        displayText = '📎 Документ';
      } else if (pinnedMessage.audioList.isNotEmpty) {
        displayText = '🎵 Аудиозапись';
      } else if (pinnedMessage.voice != null) {
        displayText = '🎙️ Голосовое сообщение';
      } else {
        displayText = 'Закреплённое сообщение';
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF262627) : const Color(0xFFF2F3F5),
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF363738) : const Color(0xFFDCE1E6),
            width: 1,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Left accent bar
          Container(
            width: 3,
            height: 36,
            decoration: BoxDecoration(
              color: theme.accentColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),

          // Pinned text & author
          Expanded(
            child: InkWell(
              onTap: onJumpToMessage,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.push_pin,
                        size: 14,
                        color: theme.accentColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Закреплённое сообщение',
                        style: TextStyle(
                          color: theme.accentColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    displayText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: theme.getTextColor(context),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Unpin button
          IconButton(
            icon: Icon(
              Icons.close,
              color: theme.getSecondaryTextColor(context),
              size: 18,
            ),
            tooltip: 'Открепить',
            onPressed: onUnpin,
          ),
        ],
      ),
    );
  }
}
