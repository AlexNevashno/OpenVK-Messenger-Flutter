import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/conversation.dart';
import '../../services/messenger_store.dart';
import '../../services/theme_manager.dart';
import '../widgets/avatar.dart';
import '../widgets/typing_dots_indicator.dart';

class ChatHeaderView extends StatelessWidget {
  final VKConversation conversation;
  final bool isSearchActive;
  final VoidCallback onToggleSearch;
  final VoidCallback onOpenInfo;

  const ChatHeaderView({
    super.key,
    required this.conversation,
    required this.isSearchActive,
    required this.onToggleSearch,
    required this.onOpenInfo,
  });

  String _pluralizeMembers(int count) {
    final mod10 = count % 10;
    final mod100 = count % 100;
    if (mod100 >= 11 && mod100 <= 19) return '$count участников';
    if (mod10 == 1) return '$count участник';
    if (mod10 >= 2 && mod10 <= 4) return '$count участника';
    return '$count участников';
  }

  String _pluralizeMinutes(int n) {
    final mod10 = n % 10;
    final mod100 = n % 100;
    if (mod100 >= 11 && mod100 <= 19) return 'минут';
    if (mod10 == 1) return 'минуту';
    if (mod10 >= 2 && mod10 <= 4) return 'минуты';
    return 'минут';
  }

  String _formatUserOnlineStatus(VKConversation conv) {
    if (conv.isOnline) {
      return conv.isMobile ? 'в сети с телефона' : 'в сети';
    }

    final isFemale = conv.sex == 1;
    final prefix = isFemale ? 'была в сети' : 'был в сети';

    if (conv.lastSeen == null) {
      return '$prefix недавно';
    }

    final date = conv.lastSeen!;
    final diff = DateTime.now().difference(date);

    if (diff.inSeconds < 60 && !diff.isNegative) {
      return '$prefix только что';
    }

    if (diff.inMinutes < 60 && diff.inMinutes >= 1) {
      final min = diff.inMinutes;
      return '$prefix $min ${_pluralizeMinutes(min)} назад';
    }

    final now = DateTime.now();
    final timeStr = DateFormat('HH:mm').format(date);

    if (now.year == date.year && now.month == date.month && now.day == date.day) {
      return '$prefix сегодня в $timeStr';
    }

    final yesterday = now.subtract(const Duration(days: 1));
    if (yesterday.year == date.year && yesterday.month == date.month && yesterday.day == date.day) {
      return '$prefix вчера в $timeStr';
    }

    if (now.year == date.year) {
      try {
        final dStr = DateFormat('d MMMM', 'ru').format(date);
        return '$prefix $dStr в $timeStr';
      } catch (_) {
        return '$prefix ${date.day}.${date.month} в $timeStr';
      }
    } else {
      try {
        final dStr = DateFormat('d MMMM yyyy', 'ru').format(date);
        return '$prefix $dStr';
      } catch (_) {
        return '$prefix ${date.day}.${date.month}.${date.year}';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MessengerStore>();
    final theme = context.watch<ThemeManager>();
    final isMuted = store.isMuted(conversation.peerId);
    final typingText = store.typingStatus(conversation.peerId);
    final isTyping = typingText != null;
    final isSaved = conversation.isSavedMessages ||
        (store.activeAccount != null && conversation.peerId == store.activeAccount!.userId);

    String subtitle = '';
    Color subtitleColor = theme.getSecondaryTextColor(context);

    if (isTyping) {
      subtitle = typingText;
      subtitleColor = theme.accentColor;
    } else if (isSaved) {
      subtitle = 'Сохранённые сообщения';
    } else if (conversation.isGroupChat) {
      subtitle = conversation.membersCount > 0
          ? _pluralizeMembers(conversation.membersCount)
          : 'Групповая беседа';
    } else if (conversation.peerId < 0) {
      subtitle = 'Сообщество';
    } else {
      subtitle = _formatUserOnlineStatus(conversation);
      if (conversation.isOnline) {
        subtitleColor = theme.accentColor;
      }
    }

    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: theme.getSurfaceColor(context),
        border: Border(
          bottom: BorderSide(
            color: theme.getSeparatorColor(context),
            width: 0.8,
          ),
        ),
      ),
      child: Row(
        children: [
          // Avatar (tap to open info)
          VKAvatar(
            url: isSaved ? null : conversation.photoUrl,
            name: isSaved ? 'Избранное' : conversation.displayTitle,
            size: 34,
            isOnline: isSaved ? false : conversation.isOnline,
            isMobile: isSaved ? false : conversation.isMobile,
            isSavedMessages: isSaved,
            onTap: onOpenInfo,
          ),
          const SizedBox(width: 10),

          // Title & Status
          Expanded(
            child: InkWell(
              onTap: onOpenInfo,
              borderRadius: BorderRadius.circular(6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          isSaved ? 'Избранное' : conversation.displayTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: theme.getTextColor(context),
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (isMuted) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.notifications_off,
                          size: 12,
                          color: theme.getSecondaryTextColor(context),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 1),
                  if (isTyping)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TypingDotsIndicator(color: theme.accentColor, size: 3.5),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: subtitleColor,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: subtitleColor,
                        fontSize: 11.5,
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Action buttons
          // 1. Mute/Unmute
          IconButton(
            tooltip: isMuted ? 'Включить звук' : 'Без звука',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: Icon(
              isMuted ? Icons.notifications_off_rounded : Icons.notifications_none_rounded,
              size: 18,
              color: isMuted ? theme.getSecondaryTextColor(context) : theme.accentColor,
            ),
            onPressed: () => store.toggleMute(conversation.peerId),
          ),

          // 2. Search in conversation
          IconButton(
            tooltip: 'Поиск по истории (Ctrl+F)',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: Icon(
              Icons.search_rounded,
              size: 18,
              color: isSearchActive ? theme.accentColor : theme.getSecondaryTextColor(context),
            ),
            onPressed: onToggleSearch,
          ),

          // 3. Info Button
          IconButton(
            tooltip: 'Информация о беседе',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: Icon(
              Icons.info_outline_rounded,
              size: 18,
              color: theme.accentColor,
            ),
            onPressed: onOpenInfo,
          ),
        ],
      ),
    );
  }
}
