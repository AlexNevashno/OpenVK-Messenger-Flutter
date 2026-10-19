import 'dart:io';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/conversation.dart';
import '../../models/message.dart';
import '../../services/messenger_store.dart';
import '../../services/theme_manager.dart';
import '../modals/conversation_info_dialog.dart';
import '../widgets/audio_miniplayer.dart';
import '../widgets/chat_wallpaper_background.dart';
import '../widgets/pinned_message_bar.dart';
import '../widgets/write_bar.dart';
import 'chat_header_view.dart';
import 'message_bubble.dart';

class ChatView extends StatefulWidget {
  const ChatView({super.key});

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final ScrollController _scrollController = ScrollController();
  bool _showSearch = false;
  final TextEditingController _searchController = TextEditingController();
  String _inChatSearchQuery = '';
  int _lastMessagesLength = 0;
  bool _showScrollToBottom = false;
  bool _isDropTargeted = false;
  VKMessage? _editingMessage;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  int? _lastPeerId;

  void _onScroll() {
    if (_scrollController.hasClients) {
      // In reverse: true, offset 0 is at the bottom (most recent messages)
      final isUp = _scrollController.position.pixels > 200;
      if (isUp != _showScrollToBottom) {
        setState(() => _showScrollToBottom = isUp);
      }

      // Load older history when near top (maxScrollExtent in reverse mode)
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        final store = context.read<MessengerStore>();
        if (store.selectedPeerId != null && !store.isLoadingHistory) {
          store.fetchHistory(store.selectedPeerId!, loadOlder: true);
        }
      }
    }
  }

  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        if (animated) {
          _scrollController.animateTo(
            0.0,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        } else {
          _scrollController.jumpTo(0.0);
        }
      }
    });
  }

  void _jumpToMessage(int id, List<VKMessage> messages) {
    final msgIndex = messages.indexWhere((m) => m.id == id);
    if (msgIndex != -1 && _scrollController.hasClients) {
      final reversedIndex = messages.length - 1 - msgIndex;
      final targetOffset = (reversedIndex * 65.0).clamp(0.0, _scrollController.position.maxScrollExtent);
      _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatDateDivider(DateTime dt) {
    final now = DateTime.now();
    if (_isSameDay(dt, now)) return 'Сегодня';
    final yesterday = now.subtract(const Duration(days: 1));
    if (_isSameDay(dt, yesterday)) return 'Вчера';
    if (dt.year == now.year) {
      try {
        return DateFormat('d MMMM', 'ru').format(dt);
      } catch (_) {
        return '${dt.day}.${dt.month}';
      }
    }
    return DateFormat('d MMMM yyyy', 'ru').format(dt);
  }

  void _openConversationInfo(VKConversation conv) {
    showDialog(
      context: context,
      builder: (ctx) => ConversationInfoDialog(conversation: conv),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MessengerStore>();
    final theme = context.watch<ThemeManager>();
    final isDark = theme.isDark(context);

    if (store.selectedPeerId == null) {
      return ChatWallpaperBackground(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.forum_outlined,
                size: 64,
                color: theme.getSecondaryTextColor(context).withValues(alpha: 0.5),
              ),
              const SizedBox(height: 12),
              Text(
                'Выберите чат для начала общения',
                style: TextStyle(
                  color: theme.getSecondaryTextColor(context),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final conv = store.selectedConversation ??
        VKConversation(
          peerId: store.selectedPeerId!,
          title: 'Диалог',
        );

    var messages = store.currentMessages;
    if (_inChatSearchQuery.isNotEmpty) {
      messages = messages.where((m) => m.text.toLowerCase().contains(_inChatSearchQuery)).toList();
    }

    if (store.selectedPeerId != _lastPeerId) {
      _lastPeerId = store.selectedPeerId;
      _lastMessagesLength = 0;
      _scrollToBottom(animated: false);
    } else if (messages.length != _lastMessagesLength) {
      final wasNearBottom = !_showScrollToBottom;
      _lastMessagesLength = messages.length;
      if (wasNearBottom) {
        _scrollToBottom(animated: false);
      }
    }

    return DropTarget(
      onDragEntered: (detail) {
        setState(() => _isDropTargeted = true);
      },
      onDragExited: (detail) {
        setState(() => _isDropTargeted = false);
      },
      onDragDone: (detail) {
        setState(() => _isDropTargeted = false);
        for (final file in detail.files) {
          if (file.path.isNotEmpty) {
            store.addPendingFile(File(file.path));
          }
        }
      },
      child: Stack(
        children: [
          ChatWallpaperBackground(
            child: Column(
              children: [
                // Header Bar
                ChatHeaderView(
                  conversation: conv,
                  isSearchActive: _showSearch,
                  onToggleSearch: () {
                    setState(() {
                      _showSearch = !_showSearch;
                      if (!_showSearch) {
                        _inChatSearchQuery = '';
                        _searchController.clear();
                      }
                    });
                  },
                  onOpenInfo: () => _openConversationInfo(conv),
                ),

                // Audio Miniplayer
                const AudioMiniplayer(),

                // Pinned Message Bar
                if (conv.pinnedMessage != null)
                  PinnedMessageBar(
                    pinnedMessage: conv.pinnedMessage!,
                    onJumpToMessage: () => _jumpToMessage(conv.pinnedMessage!.id, messages),
                    onUnpin: () => store.unpinMessage(conv.peerId),
                  ),

                // In-Chat Search Bar (Ctrl+F)
                if (_showSearch) _buildInChatSearchBar(theme, isDark),

                // Messages List + Scroll To Bottom Button
                Expanded(
                  child: Stack(
                    children: [
                      store.isLoadingHistory && messages.isEmpty
                          ? const Center(child: CircularProgressIndicator())
                          : ListView.builder(
                              controller: _scrollController,
                              reverse: true,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: messages.length,
                              itemBuilder: (ctx, index) {
                                final msgIndex = messages.length - 1 - index;
                                final msg = messages[msgIndex];
                                final prevMsg = msgIndex > 0 ? messages[msgIndex - 1] : null;
                                final showDateDivider = prevMsg == null || !_isSameDay(prevMsg.date, msg.date);

                                return Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (showDateDivider) _buildDateDivider(msg.date, theme, isDark),
                                    MessageBubble(
                                      key: ValueKey('msg_${msg.id}'),
                                      message: msg,
                                      onReply: () {
                                        store.setReplyingTo(msg);
                                      },
                                      onEdit: (m) {
                                        setState(() => _editingMessage = m);
                                      },
                                      onJumpToMessage: (id) => _jumpToMessage(id, messages),
                                    ),
                                  ],
                                );
                              },
                            ),

                      // Floating Scroll to Bottom button
                      if (_showScrollToBottom)
                        Positioned(
                          right: 20,
                          bottom: 16,
                          child: FloatingActionButton.small(
                            backgroundColor: theme.getSurfaceColor(context),
                            foregroundColor: theme.accentColor,
                            elevation: 4,
                            tooltip: 'К последним сообщениям',
                            onPressed: () => _scrollToBottom(animated: true),
                            child: const Icon(Icons.keyboard_arrow_down_rounded, size: 24),
                          ),
                        ),
                    ],
                  ),
                ),

                // Write Bar
                WriteBar(
                  replyToMessage: store.replyingToMessage,
                  onCancelReply: () {
                    store.setReplyingTo(null);
                  },
                  editingMessage: _editingMessage,
                  onCancelEdit: () {
                    setState(() => _editingMessage = null);
                  },
                  onEditMessage: (msgId, newText) {
                    store.editMessage(conv.peerId, msgId, newText);
                    setState(() => _editingMessage = null);
                  },
                ),
              ],
            ),
          ),

          // Drag and drop overlay
          if (_isDropTargeted)
            Positioned.fill(
              child: Container(
                margin: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.accentColor,
                    width: 2.5,
                  ),
                ),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                    decoration: BoxDecoration(
                      color: theme.getSurfaceColor(context).withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.arrow_downward_rounded,
                          size: 38,
                          color: theme.accentColor,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Перетащите файлы сюда для прикрепления',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: theme.getTextColor(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInChatSearchBar(ThemeManager theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.getSecondarySurfaceColor(context),
        border: Border(
          bottom: BorderSide(
            color: theme.getSeparatorColor(context),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              autofocus: true,
              style: TextStyle(color: theme.getTextColor(context), fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Поиск в этой переписке...',
                hintStyle: TextStyle(color: theme.getSecondaryTextColor(context), fontSize: 13),
                prefixIcon: const Icon(Icons.search, size: 18),
                border: InputBorder.none,
                isDense: true,
              ),
              onChanged: (text) {
                setState(() => _inChatSearchQuery = text.toLowerCase().trim());
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () {
              setState(() {
                _showSearch = false;
                _inChatSearchQuery = '';
                _searchController.clear();
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDateDivider(DateTime dt, ThemeManager theme, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: isDark ? 0.42 : 0.25),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        _formatDateDivider(dt),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11.5,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
