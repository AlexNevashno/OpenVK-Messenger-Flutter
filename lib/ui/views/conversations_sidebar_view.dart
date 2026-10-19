import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/conversation.dart';
import '../../services/messenger_store.dart';
import '../../services/theme_manager.dart';
import '../widgets/avatar.dart';
import '../widgets/typing_dots_indicator.dart';

class ConversationsSidebarView extends StatefulWidget {
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenNewMessage;
  final VoidCallback onOpenLogin;

  const ConversationsSidebarView({
    super.key,
    required this.onOpenSettings,
    required this.onOpenNewMessage,
    required this.onOpenLogin,
  });

  @override
  State<ConversationsSidebarView> createState() => _ConversationsSidebarViewState();
}

class _ConversationsSidebarViewState extends State<ConversationsSidebarView> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return DateFormat('HH:mm').format(dt);
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (dt.year == yesterday.year && dt.month == yesterday.month && dt.day == yesterday.day) {
      return 'вчера';
    }
    if (dt.year == now.year) {
      try {
        return DateFormat('d MMM', 'ru').format(dt);
      } catch (_) {
        return '${dt.day}.${dt.month}';
      }
    }
    return '${dt.day}.${dt.month}.${dt.year % 100}';
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MessengerStore>();
    final theme = context.watch<ThemeManager>();
    final isDark = theme.isDark(context);

    return Container(
      width: 300,
      color: theme.getSurfaceColor(context),
      child: Column(
        children: [
          // Header Bar: Search + Compose + Refresh + Menu
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            child: Row(
              children: [
                // Search Input
                Expanded(
                  child: Container(
                    height: 32,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2C2D2E) : const Color(0xFFEBEDF0),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.search,
                          size: 16,
                          color: theme.getSecondaryTextColor(context),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            style: TextStyle(
                              color: theme.getTextColor(context),
                              fontSize: 13,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Поиск',
                              hintStyle: TextStyle(
                                color: theme.getSecondaryTextColor(context),
                                fontSize: 13,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(vertical: 6),
                            ),
                            onChanged: (text) => store.setSearchQuery(text),
                          ),
                        ),
                        if (_searchController.text.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              _searchController.clear();
                              store.setSearchQuery('');
                            },
                            child: Icon(
                              Icons.cancel,
                              size: 16,
                              color: theme.getSecondaryTextColor(context),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Compose Button (Pencil in circular accent bg)
                IconButton(
                  tooltip: 'Написать сообщение',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  icon: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: theme.accentColor.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.edit_square,
                      size: 14,
                      color: theme.accentColor,
                    ),
                  ),
                  onPressed: widget.onOpenNewMessage,
                ),

                // Refresh Button
                if (store.isLoadingConversations)
                  const SizedBox(
                    width: 28,
                    height: 28,
                    child: Center(
                      child: SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                else
                  IconButton(
                    tooltip: 'Обновить диалоги',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    icon: Icon(
                      Icons.refresh_rounded,
                      size: 19,
                      color: theme.getSecondaryTextColor(context),
                    ),
                    onPressed: () => store.fetchConversations(forceRefresh: true),
                  ),

                // Options Menu
                PopupMenuButton<String>(
                  tooltip: 'Меню',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  icon: Icon(
                    Icons.more_vert,
                    size: 19,
                    color: theme.getSecondaryTextColor(context),
                  ),
                  color: theme.getSecondarySurfaceColor(context),
                  onSelected: (choice) {
                    if (choice == 'settings') {
                      widget.onOpenSettings();
                    } else if (choice == 'refresh') {
                      store.fetchConversations(forceRefresh: true);
                    } else if (choice == 'logout') {
                      if (store.activeAccount != null) {
                        store.logout(store.activeAccount!);
                      }
                      widget.onOpenLogin();
                    }
                  },
                  itemBuilder: (ctx) => [
                    if (store.activeAccount != null)
                      PopupMenuItem(
                        enabled: false,
                        child: Text(
                          store.activeAccount!.name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: theme.getTextColor(context),
                          ),
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'refresh',
                      child: Row(
                        children: [
                          Icon(Icons.refresh, size: 18),
                          SizedBox(width: 8),
                          Text('Обновить диалоги'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'settings',
                      child: Row(
                        children: [
                          Icon(Icons.settings_outlined, size: 18),
                          SizedBox(width: 8),
                          Text('Настройки...'),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'logout',
                      child: Row(
                        children: [
                          Icon(Icons.logout, size: 18, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Выйти из аккаунта', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Divider(height: 1, color: theme.getSeparatorColor(context)),

          if (store.isCommunityFilterActive)
            Container(
              margin: const EdgeInsets.fromLTRB(10, 6, 10, 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: theme.accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.domain_rounded, size: 16, color: theme.accentColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Только сообщества',
                      style: TextStyle(
                        color: theme.getTextColor(context),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => store.setCommunityFilter(false),
                    child: Icon(
                      Icons.cancel,
                      size: 16,
                      color: theme.getSecondaryTextColor(context),
                    ),
                  ),
                ],
              ),
            ),

          // Conversation List
          Expanded(
            child: store.conversations.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 36,
                          color: theme.getSecondaryTextColor(context).withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          store.isLoadingConversations ? 'Загрузка диалогов...' : 'Нет диалогов',
                          style: TextStyle(
                            color: theme.getSecondaryTextColor(context),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    itemCount: store.conversations.length,
                    itemBuilder: (ctx, index) {
                      final conv = store.conversations[index];
                      final isSelected = store.selectedPeerId == conv.peerId;
                      final isPinned = store.isPinned(conv.peerId);
                      final isMuted = store.isMuted(conv.peerId);

                      return _buildConversationRow(
                        context: context,
                        conv: conv,
                        isSelected: isSelected,
                        isPinned: isPinned,
                        isMuted: isMuted,
                        store: store,
                        theme: theme,
                      );
                    },
                  ),
          ),

          Divider(height: 1, color: theme.getSeparatorColor(context)),

          // Bottom Filter Bar: "Только непрочитанные"
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Только непрочитанные',
                  style: TextStyle(
                    color: theme.getSecondaryTextColor(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(
                  height: 24,
                  child: Transform.scale(
                    scale: 0.75,
                    child: Switch(
                      value: store.onlyUnread,
                      activeTrackColor: theme.accentColor,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
                      onChanged: (val) => store.setOnlyUnread(val),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationRow({
    required BuildContext context,
    required VKConversation conv,
    required bool isSelected,
    required bool isPinned,
    required bool isMuted,
    required MessengerStore store,
    required ThemeManager theme,
  }) {
    final isTyping = store.typingUsers(conv.peerId).isNotEmpty;

    // Preview snippet text
    String previewText = conv.lastMessage?.text ?? '';
    if (previewText.isEmpty && conv.lastMessage != null) {
      final lm = conv.lastMessage!;
      if (lm.photos.isNotEmpty || lm.photo != null) {
        previewText = '📷 Фотография';
      } else if (lm.video != null) {
        final vt = lm.video!.title;
        previewText = '🎬 ${vt.isNotEmpty ? vt : 'Видеозапись'}';
      } else if (lm.docs.isNotEmpty || lm.doc != null) {
        final dt = lm.docs.isNotEmpty ? lm.docs.first.title : (lm.doc?.title ?? 'Документ');
        previewText = '📎 $dt';
      } else if (lm.audioList.isNotEmpty || lm.audio != null) {
        final at = lm.audioList.isNotEmpty ? lm.audioList.first.title : (lm.audio?.title ?? 'Аудиозапись');
        previewText = '🎵 $at';
      } else if (lm.voice != null || lm.voiceMessage != null) {
        previewText = '🎙️ Голосовое сообщение';
      } else if (lm.sticker != null) {
        previewText = '✨ Стикер';
      } else if (lm.isMoneyTransfer) {
        final amount = lm.moneyTransfer?.amount ?? lm.parsedTransferAmount;
        if (amount > 0) {
          previewText = '💵 Перевод ($amount)';
        } else {
          previewText = '💵 Перевод голосов';
        }
      } else if (lm.isGiftOrStickerpack) {
        final lower = lm.text.toLowerCase();
        if (lower.contains('стикерпак') || lower.contains('стикер')) {
          previewText = '🎁 Подарок (стикерпак)';
        } else {
          previewText = '🎁 Подарок';
        }
      } else if (lm.wallPost != null) {
        previewText = '📢 Запись на стене';
      }
    }

    final hasUnread = conv.unreadCount > 0;

    final onAccent = theme.textOnAccentColor(context);

    return GestureDetector(
      onSecondaryTapUp: (details) {
        _showRowContextMenu(context, details.globalPosition, conv, store);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 1),
        decoration: BoxDecoration(
          color: isSelected ? theme.accentColor : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => store.selectConversation(conv.peerId),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Builder(
              builder: (context) {
                final isSaved = conv.isSavedMessages ||
                    (store.activeAccount != null && conv.peerId == store.activeAccount!.userId);
                return Row(
                  children: [
                    // Avatar with online status
                    VKAvatar(
                      url: isSaved ? null : conv.photoUrl,
                      name: isSaved ? 'Избранное' : conv.displayTitle,
                      size: 44,
                      isOnline: isSaved ? false : conv.isOnline,
                      isMobile: isSaved ? false : conv.isMobile,
                      isSavedMessages: isSaved,
                    ),
                    const SizedBox(width: 10),

                    // Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Top Row: Title + Muted + Pinned + Time
                          Row(
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        isSaved ? 'Избранное' : conv.displayTitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: isSelected ? onAccent : theme.getTextColor(context),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isMuted) ...[
                            Icon(
                              Icons.notifications_off,
                              size: 11.5,
                              color: isSelected ? onAccent.withValues(alpha: 0.8) : theme.getSecondaryTextColor(context),
                            ),
                            const SizedBox(width: 3),
                          ],
                          if (isPinned) ...[
                            Transform.rotate(
                              angle: 0.785, // 45 deg
                              child: Icon(
                                Icons.push_pin,
                                size: 11.5,
                                color: isSelected ? onAccent : theme.accentColor,
                              ),
                            ),
                            const SizedBox(width: 3),
                          ],
                          Text(
                            _formatDate(conv.lastMessage?.date),
                            style: TextStyle(
                              color: isSelected ? onAccent.withValues(alpha: 0.8) : theme.getSecondaryTextColor(context),
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),

                      // Bottom Row: Message snippet + Unread badge
                      Row(
                        children: [
                          Expanded(
                            child: isTyping
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      TypingDotsIndicator(
                                        color: isSelected ? onAccent : theme.accentColor,
                                        size: 3,
                                      ),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          'печатает...',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: isSelected ? onAccent : theme.accentColor,
                                            fontWeight: FontWeight.w500,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : Text(
                                    conv.lastMessage?.isOut == true ? 'Вы: $previewText' : previewText,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: isSelected ? onAccent.withValues(alpha: 0.85) : theme.getSecondaryTextColor(context),
                                      fontSize: 12,
                                    ),
                                  ),
                          ),
                          if (conv.hasUnreadMention)
                            Container(
                              margin: const EdgeInsets.only(right: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: isSelected ? onAccent : theme.accentColor,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '@',
                                style: TextStyle(
                                  color: isSelected ? theme.accentColor : onAccent,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          if (hasUnread)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: isSelected ? onAccent : theme.accentColor,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${conv.unreadCount}',
                                style: TextStyle(
                                  color: isSelected ? theme.accentColor : onAccent,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
        ),
      ),
    );
  }

  void _showRowContextMenu(BuildContext context, Offset globalPos, VKConversation conv, MessengerStore store) {
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final isPinned = store.isPinned(conv.peerId);
    final isMuted = store.isMuted(conv.peerId);

    showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        globalPos & const Size(40, 40),
        Offset.zero & overlay.size,
      ),
      items: [
        PopupMenuItem(
          value: 'pin',
          child: Row(
            children: [
              Icon(isPinned ? Icons.push_pin_outlined : Icons.push_pin, size: 18),
              const SizedBox(width: 8),
              Text(isPinned ? 'Открепить чат' : 'Закрепить чат'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'mute',
          child: Row(
            children: [
              Icon(isMuted ? Icons.notifications : Icons.notifications_off, size: 18),
              const SizedBox(width: 8),
              Text(isMuted ? 'Включить звук' : 'Без звука'),
            ],
          ),
        ),
        if (store.folders.isNotEmpty)
          PopupMenuItem(
            value: 'folders',
            child: Row(
              children: [
                const Icon(Icons.folder_outlined, size: 18),
                const SizedBox(width: 8),
                const Text('Папки'),
              ],
            ),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'read',
          child: Row(
            children: [
              Icon(Icons.mark_email_read, size: 18),
              SizedBox(width: 8),
              Text('Прочитано'),
            ],
          ),
        ),
      ],
    ).then((choice) {
      if (choice == 'pin') {
        store.togglePin(conv.peerId);
      } else if (choice == 'mute') {
        store.toggleMute(conv.peerId);
      } else if (choice == 'read') {
        store.markAsRead(conv.peerId);
      } else if (choice == 'folders' && context.mounted) {
        _showFolderChooser(context, conv, store);
      }
    });
  }

  void _showFolderChooser(BuildContext context, VKConversation conv, MessengerStore store) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Папки для «${conv.title}»'),
        content: SizedBox(
          width: 280,
          child: ListView(
            shrinkWrap: true,
            children: store.folders.map((f) {
              final isIn = store.isChatInFolder(conv.peerId, f.id);
              return CheckboxListTile(
                title: Text(f.name),
                value: isIn,
                onChanged: (val) {
                  store.toggleChatInFolder(conv.peerId, f.id);
                  Navigator.pop(ctx);
                },
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Готово'),
          ),
        ],
      ),
    );
  }
}
