import 'dart:convert';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/attachment.dart';
import '../../models/message.dart';
import '../../models/theme_pack.dart';
import '../../services/audio_player_service.dart';
import '../../services/image_cache_manager.dart';
import '../../services/messenger_store.dart';
import '../../services/theme_manager.dart';
import '../modals/photo_viewer_dialog.dart';
import '../modals/theme_preview_dialog.dart';
import '../modals/video_player_dialog.dart';
import '../widgets/avatar.dart';
import '../widgets/vk_animated_sticker_view.dart';

class MessageBubble extends StatelessWidget {
  final VKMessage message;
  final VoidCallback onReply;
  final void Function(VKMessage message)? onEdit;
  final Function(int messageId)? onJumpToMessage;

  const MessageBubble({
    super.key,
    required this.message,
    required this.onReply,
    this.onEdit,
    this.onJumpToMessage,
  });

  String _formatTime(DateTime dt) {
    return DateFormat('HH:mm').format(dt);
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  static Color getPeerColor(int id) {
    const colors = [
      Color(0xFFE17076), // Red
      Color(0xFFE58237), // Orange
      Color(0xFFA69840), // Olive
      Color(0xFF41A85F), // Green
      Color(0xFF3390EC), // Blue
      Color(0xFF299FE9), // Cyan
      Color(0xFFA37CF0), // Purple
    ];
    return colors[id.abs() % colors.length];
  }

  void _showContextMenu(BuildContext context, Offset globalPos) {
    final store = context.read<MessengerStore>();
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        globalPos & const Size(40, 40),
        Offset.zero & overlay.size,
      ),
      items: [
        const PopupMenuItem(
          value: 'reply',
          child: Row(
            children: [
              Icon(Icons.reply, size: 18),
              SizedBox(width: 8),
              Text('Ответить'),
            ],
          ),
        ),
        if (message.out && message.text.isNotEmpty)
          const PopupMenuItem(
            value: 'edit',
            child: Row(
              children: [
                Icon(Icons.edit_outlined, size: 18),
                SizedBox(width: 8),
                Text('Редактировать'),
              ],
            ),
          ),
        if (message.text.isNotEmpty)
          const PopupMenuItem(
            value: 'copy',
            child: Row(
              children: [
                Icon(Icons.copy, size: 18),
                SizedBox(width: 8),
                Text('Скопировать текст'),
              ],
            ),
          ),
        const PopupMenuItem(
          value: 'pin',
          child: Row(
            children: [
              Icon(Icons.push_pin, size: 18),
              SizedBox(width: 8),
              Text('Закрепить'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 18, color: Colors.red),
              SizedBox(width: 8),
              Text('Удалить', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
    ).then((choice) {
      if (choice == 'reply') {
        onReply();
      } else if (choice == 'edit') {
        onEdit?.call(message);
      } else if (choice == 'copy') {
        Clipboard.setData(ClipboardData(text: message.text));
      } else if (choice == 'pin') {
        store.pinMessage(message.peerId, message.id);
      } else if (choice == 'delete') {
        if (context.mounted) {
          _confirmDelete(context, store);
        }
      }
    });
  }

  void _confirmDelete(BuildContext context, MessengerStore store) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить сообщение?'),
        content: const Text('Вы действительно хотите удалить это сообщение?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              store.deleteMessage(message.peerId, message.id);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }

  void _openPhotoViewer(BuildContext context, VKPhotoAttachment photo) {
    final all = message.photos.isNotEmpty ? message.photos : (message.photo != null ? [message.photo!] : [photo]);
    final items = all.map((p) => PhotoViewerItem(
      id: '${p.id}',
      url: p.bestUrl,
      localPath: p.localPath,
      caption: p.text,
      authorName: message.sender?.fullName ?? '',
      date: message.date,
    )).toList();
    final idx = all.indexWhere((p) => p.id == photo.id);
    PhotoViewerDialog.show(
      context,
      items: items,
      initialIndex: idx >= 0 ? idx : 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeManager>();
    final isDark = theme.isDark(context);

    // 1. Money transfer / votes status message
    if (message.isMoneyTransfer) {
      return _buildMoneyTransferCard(context, theme);
    }

    // 2. Gift / Stickerpack gift status message
    if (message.isGiftOrStickerpack) {
      return _buildGiftOrStickerpackCard(context, theme);
    }

    // 3. Service Action / System Message
    if (message.isServiceAction) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 24),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.38),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Text(
            message.serviceDisplayText,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12 * theme.fontSizeScale,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }

    final isOut = message.isOut;
    final isGroupChat = message.peerId >= 2000000000 || message.peerId < 0;
    final senderName = message.sender?.fullName ?? 'id${message.fromId}';

    // 3. Sticker Message (standalone without bubble background)
    if (message.sticker != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          mainAxisAlignment: isOut ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isOut && isGroupChat) ...[
              VKAvatar(
                url: message.sender?.avatarUrl,
                name: senderName,
                size: 34,
              ),
              const SizedBox(width: 8),
            ],
            GestureDetector(
              onDoubleTap: onReply,
              onSecondaryTapDown: (details) => _showContextMenu(context, details.globalPosition),
              child: Column(
                crossAxisAlignment: isOut ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (!isOut && isGroupChat)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        senderName,
                        style: TextStyle(
                          color: theme.accentColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  VKAnimatedStickerView(
                    url: message.sticker!.bestUrl,
                    animationUrl: message.sticker!.animationURL,
                    size: 140,
                    loop: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }


    // 4. Standard Message Bubble
    final curUid = context.watch<MessengerStore>().activeAccount?.userId;
    final allPhotos = message.photos.isNotEmpty ? message.photos : (message.photo != null ? [message.photo!] : <VKPhotoAttachment>[]);
    final cleanText = message.text.replaceAll('&#8203;', '').trim();
    final displayText = cleanText.replaceAllMapped(
      RegExp(r'\[(id|club)\d+\|([^\]]+)\]'),
      (m) => '@${m.group(2)}',
    );
    final isPhotoOnly = allPhotos.isNotEmpty &&
        cleanText.isEmpty &&
        message.replyMessage == null &&
        message.voice == null &&
        message.doc == null &&
        message.audio == null &&
        message.video == null &&
        message.wallPost == null;
    final isShortSingleLine = !isPhotoOnly &&
        displayText.isNotEmpty &&
        !displayText.contains('\n') &&
        displayText.length <= 50 &&
        allPhotos.isEmpty &&
        message.replyMessage == null &&
        message.voice == null &&
        message.doc == null &&
        message.audio == null &&
        message.video == null &&
        message.wallPost == null &&
        !(isGroupChat && !isOut);

    final bubbleBg = isOut ? theme.getBubbleOutColor(context) : theme.getBubbleInColor(context);
    final textColor = isOut ? theme.getBubbleOutTextColor(context) : theme.getBubbleInTextColor(context);
    final maxBubbleWidth = (MediaQuery.of(context).size.width * 0.48).clamp(200.0, 420.0);
    final strokeColor = theme.getBubbleStrokeColor(context) ??
        (isOut ? Colors.transparent : (isDark ? const Color(0xFF363738) : const Color(0xFFE4E6E9)));
    final strokeWidth = theme.getBubbleStrokeWidth(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 1.5),
      child: Row(
        mainAxisAlignment: isOut ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Left avatar in group chats
          if (!isOut) ...[
            if (isGroupChat)
              VKAvatar(
                url: message.sender?.avatarUrl,
                name: senderName,
                size: 28,
              )
            else
              const SizedBox(width: 4),
            const SizedBox(width: 6),
          ],

          // Bubble Container
          Flexible(
            child: GestureDetector(
              onDoubleTap: onReply,
              onSecondaryTapDown: (details) => _showContextMenu(context, details.globalPosition),
              child: Container(
                constraints: BoxConstraints(maxWidth: maxBubbleWidth),
                padding: EdgeInsets.symmetric(
                  horizontal: isPhotoOnly ? 0 : (isShortSingleLine ? 8.5 : 9.5),
                  vertical: isPhotoOnly ? 0 : (isShortSingleLine ? 3.5 : 4.5),
                ),
                decoration: BoxDecoration(
                  color: isPhotoOnly ? Colors.transparent : bubbleBg,
                  borderRadius: theme.getBubbleBorderRadius(isOut: isOut),
                  border: isPhotoOnly
                      ? null
                      : Border.all(
                          color: strokeColor,
                          width: strokeWidth > 0 ? strokeWidth : (isOut ? 0 : 0.8),
                        ),
                  boxShadow: [
                    if (!isPhotoOnly)
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                  ],
                ),
                child: IntrinsicWidth(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Sender Name inside bubble (group chats)
                      if (!isOut && isGroupChat)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Text(
                            senderName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: getPeerColor(message.fromId),
                              fontWeight: FontWeight.w600,
                              fontSize: 12.0,
                            ),
                          ),
                        ),

                      // Reply block
                      if (message.replyMessage != null)
                        _buildReplyBlock(context, theme, isDark),

                      // Photos
                      if (allPhotos.isNotEmpty)
                        _buildPhotos(context, allPhotos, isPhotoOnly, theme),

                      // Video
                      if (message.video != null)
                        _buildVideoItem(context, message.video!, theme, isDark, textColor),

                      // Wall post (Repost)
                      if (message.wallPost != null)
                        _buildWallPostItem(context, message.wallPost!, theme, isDark, textColor),

                      // Documents
                      if (message.docs.isNotEmpty)
                        ...message.docs.map((d) => _buildDocItem(context, d, theme, isDark)),

                      // Audio
                      if (message.audioList.isNotEmpty)
                        ...message.audioList.map((a) => _buildAudioItem(context, a, theme, isDark)),

                      // Voice
                      if (message.voice != null)
                        _buildVoiceItem(context, message.voice!, theme, isDark),

                      // Text & Timestamp (Compact Inline vs Multiline)
                      if (isShortSingleLine) ...[
                        // Inline compact layout (no extra width or lines!)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Flexible(
                              child: Text.rich(
                                TextSpan(
                                  children: _buildFormattedSpans(
                                    cleanText,
                                    textColor,
                                    theme,
                                    isOut,
                                    curUid,
                                  ),
                                ),
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 13.0 * theme.fontSizeScale,
                                  height: 1.25,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _formatTime(message.date),
                              style: TextStyle(
                                color: theme.getSecondaryTextColor(context),
                                fontSize: 10.0,
                              ),
                            ),
                            if (isOut) ...[
                              const SizedBox(width: 2.5),
                              _buildStatusIcon(theme),
                            ],
                          ],
                        ),
                      ] else if (!isPhotoOnly) ...[
                        if (cleanText.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text.rich(
                              TextSpan(
                                children: _buildFormattedSpans(
                                  cleanText,
                                  textColor,
                                  theme,
                                  isOut,
                                  curUid,
                                ),
                              ),
                              style: TextStyle(
                                color: textColor,
                                fontSize: 13.0 * theme.fontSizeScale,
                                height: 1.3,
                              ),
                            ),
                          )
                        else if (!message.hasAttachments && message.replyMessage == null && message.action == null)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.attach_file_rounded,
                                  size: 14,
                                  color: isOut ? theme.getBubbleOutTextColor(context).withValues(alpha: 0.7) : theme.getSecondaryTextColor(context),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Вложение',
                                  style: TextStyle(
                                    color: isOut ? theme.getBubbleOutTextColor(context).withValues(alpha: 0.8) : theme.getSecondaryTextColor(context),
                                    fontSize: 13 * theme.fontSizeScale,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Timestamp at bottom right without expanding bubble
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _formatTime(message.date),
                                  style: TextStyle(
                                    color: theme.getSecondaryTextColor(context),
                                    fontSize: 10.5,
                                  ),
                                ),
                                if (isOut) ...[
                                  const SizedBox(width: 3),
                                  _buildStatusIcon(theme),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
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

  static List<InlineSpan> _buildFormattedSpans(
    String text,
    Color textColor,
    ThemeManager theme,
    bool isOut,
    int? currentUserId,
  ) {
    final List<InlineSpan> spans = [];
    final mentionRegex = RegExp(r'\[(id|club)(\d+)\|([^\]]+)\]');
    int lastIndex = 0;

    for (final match in mentionRegex.allMatches(text)) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: text.substring(lastIndex, match.start),
          style: TextStyle(color: textColor),
        ));
      }

      final type = match.group(1);
      final rawId = match.group(2) ?? '0';
      final name = match.group(3) ?? '';
      final idNum = int.tryParse(rawId) ?? 0;
      final isMe = type == 'id' && currentUserId != null && idNum == currentUserId;

      final mentionColor = isMe
          ? theme.accentColor
          : (type == 'id' ? getPeerColor(idNum) : theme.accentColor);

      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: isMe ? 4 : 2, vertical: 0.5),
          decoration: isMe
              ? BoxDecoration(
                  color: theme.accentColor.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(4),
                )
              : null,
          child: Text(
            '@$name',
            style: TextStyle(
              color: mentionColor,
              fontWeight: isMe ? FontWeight.bold : FontWeight.w600,
              fontSize: 13.0 * theme.fontSizeScale,
            ),
          ),
        ),
      ));

      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastIndex),
        style: TextStyle(color: textColor),
      ));
    }

    return spans;
  }

  Widget _buildStatusIcon(ThemeManager theme) {
    if (message.isPending) {
      return const Icon(Icons.access_time, size: 11, color: Colors.grey);
    }
    if (message.readState) {
      return Icon(Icons.done_all, size: 13, color: theme.accentColor);
    }
    return const Icon(Icons.done, size: 13, color: Colors.grey);
  }

  Widget _buildReplyBlock(BuildContext context, ThemeManager theme, bool isDark) {
    final reply = message.replyMessage!;
    return GestureDetector(
      onTap: () {
        if (onJumpToMessage != null) {
          onJumpToMessage!(reply.id);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: isDark ? Colors.black.withValues(alpha: 0.28) : Colors.black.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: BorderSide(color: theme.accentColor, width: 2.5),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      VKAvatar(
                        url: reply.senderAvatarURL,
                        name: reply.senderName,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          reply.senderName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: theme.accentColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 12 * theme.fontSizeScale,
                          ),
                        ),
                      ),
                      if (reply.date != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          _formatReplyTime(reply.date!),
                          style: TextStyle(
                            fontSize: 10.5 * theme.fontSizeScale,
                            color: theme.getSecondaryTextColor(context).withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    reply.text.isNotEmpty
                        ? reply.text
                        : (reply.hasPhoto ? 'Фотография' : 'Вложение'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12 * theme.fontSizeScale,
                      color: isDark ? Colors.white.withValues(alpha: 0.9) : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            if (reply.hasPhoto && reply.photoURL != null && reply.photoURL!.isNotEmpty) ...[
              const SizedBox(width: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: CachedNetworkImage(
                  imageUrl: reply.photoURL!,
                  cacheManager: VKImageCacheManager.instance,
                  width: 34,
                  height: 34,
                  memCacheWidth: 68,
                  memCacheHeight: 68,
                  fit: BoxFit.cover,
                  placeholder: (ctx, url) => Container(width: 34, height: 34, color: Colors.black12),
                  errorWidget: (ctx, url, err) => const SizedBox(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatReplyTime(DateTime dt) {
    final now = DateTime.now();
    final timeStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return 'сегодня в $timeStr';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (dt.year == yesterday.year && dt.month == yesterday.month && dt.day == yesterday.day) {
      return 'вчера в $timeStr';
    }
    return '${dt.day}.${dt.month.toString().padLeft(2, '0')} в $timeStr';
  }

  String _formatVotes(int amount, String currency) {
    if (currency.isNotEmpty &&
        currency != 'RUB' &&
        currency != 'голосов' &&
        currency != 'голоса' &&
        currency != 'голос' &&
        currency != 'votes') {
      return '$amount $currency';
    }
    final mod10 = amount % 10;
    final mod100 = amount % 100;
    String word = 'голосов';
    if (mod100 < 11 || mod100 > 14) {
      if (mod10 == 1) {
        word = 'голос';
      } else if (mod10 >= 2 && mod10 <= 4) {
        word = 'голоса';
      }
    }
    return '$amount $word';
  }

  Widget _buildMoneyTransferCard(BuildContext context, ThemeManager theme) {
    final transfer = message.moneyTransfer;
    final senderName = message.sender?.fullName ?? 'Пользователь';
    final targetText = message.isOut ? 'Вы передали' : '$senderName передал(а) вам';

    final int amount = transfer?.amount ?? message.parsedTransferAmount;
    final String currency = transfer?.currency ?? 'голосов';
    final String amountText = amount > 0 ? _formatVotes(amount, currency) : 'голоса';

    final rawComment = (transfer?.comment != null && transfer!.comment!.isNotEmpty)
        ? transfer.comment!
        : message.text;
    final trimmedComment = rawComment
        .replaceAll('\u200B', '')
        .replaceAll('&#8203;', '')
        .trim();
    final lowerTrimmed = trimmedComment.toLowerCase();
    final bool showComment = trimmedComment.isNotEmpty &&
        !lowerTrimmed.contains('передал вам') &&
        !lowerTrimmed.contains('передала вам') &&
        !lowerTrimmed.contains('передал(а) вам') &&
        !lowerTrimmed.startsWith('перевод');

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 20),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.42),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(
                  Icons.payments_rounded,
                  color: Color(0xFFFFD600),
                  size: 15,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '$targetText ',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13 * theme.fontSizeScale,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextSpan(
                          text: amountText,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13 * theme.fontSizeScale,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextSpan(
                          text: '.  ${_formatTime(message.date)}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 11 * theme.fontSizeScale,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
            if (showComment)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '«$trimmedComment»',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontSize: 12 * theme.fontSizeScale,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGiftOrStickerpackCard(BuildContext context, ThemeManager theme) {
    final gift = message.gift;
    final senderName = message.sender?.fullName ?? 'Пользователь';
    final lowerText = message.text.toLowerCase();
    final lowerDesc = gift?.description?.toLowerCase() ?? '';
    final bool isStickerpack = lowerText.contains('стикерпак') ||
        lowerText.contains('стикер') ||
        lowerDesc.contains('стикерпак') ||
        lowerDesc.contains('стикер');

    final String targetText;
    if (message.isOut) {
      targetText = isStickerpack ? 'Вы подарили стикерпак' : 'Вы отправили подарок';
    } else {
      if (message.sender != null) {
        targetText = isStickerpack
            ? '$senderName подарил(а) вам стикерпак'
            : '$senderName отправил(а) вам подарок';
      } else {
        targetText = isStickerpack
            ? 'Вам подарили стикерпак'
            : 'Вам отправили подарок';
      }
    }

    final comment = message.text.trim();
    final lowerComment = comment.toLowerCase();
    final bool isPureSystemText = lowerComment.startsWith('вам подарили стикерпак') ||
        lowerComment.startsWith('вам подарили подарок') ||
        lowerComment.startsWith('отправил(а) вам подарок') ||
        lowerComment.startsWith('подарил(а) вам стикерпак');

    String? displayComment;
    if (comment.isNotEmpty) {
      if (isPureSystemText) {
        final quoteMatch = RegExp(r'[«"“](.*?)[»"”]').firstMatch(comment);
        if (quoteMatch != null && quoteMatch.group(1)?.isNotEmpty == true) {
          displayComment = '«${quoteMatch.group(1)}»';
        }
      } else {
        displayComment = '«$comment»';
      }
    }

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 20),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.42),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (gift?.thumbURL != null && gift!.thumbURL!.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 96,
                  height: 96,
                  child: CachedNetworkImage(
                    imageUrl: gift.thumbURL!,
                    cacheManager: VKImageCacheManager.instance,
                    fit: BoxFit.contain,
                    memCacheWidth: 192,
                    memCacheHeight: 192,
                    placeholder: (ctx, url) => const SizedBox(),
                    errorWidget: (ctx, url, err) => Icon(
                      isStickerpack ? Icons.redeem_rounded : Icons.card_giftcard_rounded,
                      size: 40,
                      color: Colors.orangeAccent,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
            ] else ...[
              Icon(
                isStickerpack ? Icons.redeem_rounded : Icons.card_giftcard_rounded,
                size: 38,
                color: Colors.orangeAccent,
              ),
              const SizedBox(height: 4),
            ],
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: targetText,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12.5 * theme.fontSizeScale,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextSpan(
                    text: '.  ${_formatTime(message.date)}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 11 * theme.fontSizeScale,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
            if (displayComment != null && displayComment.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  displayComment,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontSize: 12 * theme.fontSizeScale,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotos(BuildContext context, List<VKPhotoAttachment> photos, bool isPhotoOnly, ThemeManager theme) {
    if (photos.length == 1) {
      final photo = photos.first;
      return GestureDetector(
        onTap: () => _openPhotoViewer(context, photo),
        child: Container(
          margin: EdgeInsets.symmetric(vertical: isPhotoOnly ? 0 : 4),
          constraints: const BoxConstraints(maxHeight: 280, maxWidth: 360),
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: photo.localPath != null
                    ? Image.file(File(photo.localPath!), fit: BoxFit.cover)
                    : CachedNetworkImage(
                        imageUrl: photo.bestUrl,
                        cacheManager: VKImageCacheManager.instance,
                        fit: BoxFit.cover,
                        memCacheWidth: 720,
                        placeholder: (ctx, url) => Container(height: 180, width: 240, color: Colors.black12),
                        errorWidget: (ctx, url, err) => const Icon(Icons.broken_image, size: 40),
                      ),
              ),
              if (isPhotoOnly)
                Container(
                  margin: const EdgeInsets.all(6),
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(message.date),
                        style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w500),
                      ),
                      if (message.isOut) ...[
                        const SizedBox(width: 3),
                        _buildStatusIcon(theme),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      );
    }

    // Gallery 2+ photos
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      constraints: const BoxConstraints(maxWidth: 290),
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: photos.map((photo) {
              return GestureDetector(
                onTap: () => _openPhotoViewer(context, photo),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 140,
                    height: 130,
                    child: photo.localPath != null
                        ? Image.file(File(photo.localPath!), fit: BoxFit.cover)
                        : CachedNetworkImage(
                            imageUrl: photo.previewUrl,
                            cacheManager: VKImageCacheManager.instance,
                            fit: BoxFit.cover,
                            memCacheWidth: 280,
                            memCacheHeight: 260,
                            placeholder: (ctx, url) => Container(color: Colors.black12),
                            errorWidget: (ctx, url, err) => const Icon(Icons.broken_image),
                          ),
                  ),
                ),
              );
            }).toList(),
          ),
          if (isPhotoOnly)
            Container(
              margin: const EdgeInsets.all(6),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatTime(message.date),
                    style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w500),
                  ),
                  if (message.isOut) ...[
                    const SizedBox(width: 3),
                    _buildStatusIcon(theme),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDocItem(BuildContext context, VKDocAttachment doc, ThemeManager theme, bool isDark) {
    final lower = doc.title.toLowerCase();
    final isTheme = lower.endsWith('.themepack') ||
        lower.endsWith('.themepack.txt') ||
        lower.endsWith('.theme.txt') ||
        doc.ext.toLowerCase() == 'themepack';

    if (isTheme) {
      return _buildThemeCard(context, doc, theme, isDark);
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1F) : const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF363738) : const Color(0xFFE4E6E9),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: theme.accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              Icons.insert_drive_file_outlined,
              color: theme.accentColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  doc.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.getTextColor(context),
                    fontWeight: FontWeight.w500,
                    fontSize: 12.5,
                  ),
                ),
                Text(
                  _formatFileSize(doc.size),
                  style: TextStyle(
                    color: theme.getSecondaryTextColor(context),
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.download_rounded, color: theme.accentColor, size: 18),
            tooltip: 'Скачать',
            onPressed: () {
              if (doc.url.isNotEmpty) launchUrl(Uri.parse(doc.url));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildThemeCard(BuildContext context, VKDocAttachment doc, ThemeManager theme, bool isDark) {
    final cleanName = doc.title
        .replaceAll('.themepack.txt', '')
        .replaceAll('.themepack', '')
        .replaceAll('.theme.txt', '');

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(10),
      constraints: const BoxConstraints(maxWidth: 340),
      decoration: BoxDecoration(
        color: (message.isOut ? theme.getBubbleOutColor(context) : theme.getBubbleInColor(context)).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.accentColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.palette_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      cleanName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: message.isOut ? theme.getBubbleOutTextColor(context) : theme.getBubbleInTextColor(context),
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Тема оформления OpenVK (.themepack)',
                      style: TextStyle(
                        color: (message.isOut ? theme.getBubbleOutTextColor(context) : theme.getBubbleInTextColor(context)).withValues(alpha: 0.72),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 32,
            child: ElevatedButton.icon(
              onPressed: () => _previewThemeDoc(context, doc),
              icon: const Icon(Icons.remove_red_eye_rounded, size: 16, color: Colors.white),
              label: const Text(
                'Предпросмотр темы...',
                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.accentColor,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _previewThemeDoc(BuildContext context, VKDocAttachment doc) async {
    try {
      final res = await http.get(Uri.parse(doc.url));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        final pack = VKThemePack.fromJson(decoded);
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (ctx) => ThemePreviewDialog(
              themePack: pack,
              onApply: () {
                context.read<ThemeManager>().applyCustomTheme(pack);
              },
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error previewing theme: $e');
    }
  }

  Widget _buildAudioItem(BuildContext context, VKAudioAttachment audio, ThemeManager theme, bool isDark) {
    final player = context.watch<AudioPlayerService>();
    final audioId = 'audio_${audio.id}_${audio.ownerId}';
    final isCurrent = player.activeId == audioId || player.currentUrl == audio.url;
    final isPlaying = isCurrent && player.isPlaying;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1F) : const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
              color: theme.accentColor,
              size: 28,
            ),
            onPressed: () {
              player.togglePlay(
                id: audioId,
                url: audio.url,
                title: audio.title,
                artist: audio.artist,
                duration: Duration(seconds: audio.duration),
              );
            },
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  audio.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: theme.getTextColor(context), fontWeight: FontWeight.w600, fontSize: 12.5),
                ),
                Text(
                  audio.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: theme.getSecondaryTextColor(context), fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${audio.duration ~/ 60}:${(audio.duration % 60).toString().padLeft(2, '0')}',
            style: TextStyle(color: theme.getSecondaryTextColor(context), fontSize: 10.5),
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceItem(BuildContext context, VKVoiceAttachment voice, ThemeManager theme, bool isDark) {
    final player = context.watch<AudioPlayerService>();
    final voiceId = 'voice_${message.id}_${voice.duration}';
    final url = voice.linkMp3.isNotEmpty ? voice.linkMp3 : voice.linkOgg;
    final isCurrent = player.activeId == voiceId || player.currentUrl == url;
    final isPlaying = isCurrent && player.isPlaying;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
              color: theme.accentColor,
              size: 28,
            ),
            onPressed: () {
              player.togglePlay(
                id: voiceId,
                url: url,
                title: 'Голосовое сообщение',
                artist: message.sender?.fullName ?? '',
                duration: Duration(seconds: voice.duration),
                isVoice: true,
              );
            },
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 130,
            height: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(20, (i) {
                final h = ((i * 7 + 5) % 16) + 4.0;
                return Container(
                  width: 2.5,
                  height: h,
                  decoration: BoxDecoration(
                    color: theme.accentColor.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${voice.duration ~/ 60}:${(voice.duration % 60).toString().padLeft(2, '0')}',
            style: TextStyle(color: theme.getSecondaryTextColor(context), fontSize: 10.5),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoItem(
    BuildContext context,
    VKVideoAttachment video,
    ThemeManager theme,
    bool isDark,
    Color textColor,
  ) {
    final dur = video.duration;
    final mins = dur ~/ 60;
    final secs = dur % 60;
    final formattedDuration = '${mins.toString().padLeft(1, '0')}:${secs.toString().padLeft(2, '0')}';
    final hasThumb = video.imageURL != null && video.imageURL!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => VKVideoPlayerDialog.show(context, video: video),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 270,
                    height: 140,
                    color: theme.getSecondarySurfaceColor(context),
                    child: hasThumb
                        ? CachedNetworkImage(
                            imageUrl: video.imageURL!,
                            cacheManager: VKImageCacheManager.instance,
                            fit: BoxFit.cover,
                            width: 270,
                            height: 140,
                            memCacheWidth: 540,
                            memCacheHeight: 280,
                            placeholder: (ctx, url) => Container(
                              color: theme.getSecondarySurfaceColor(context),
                            ),
                            errorWidget: (ctx, url, err) => Container(
                              color: theme.getSecondarySurfaceColor(context),
                              child: Icon(
                                Icons.videocam,
                                size: 40,
                                color: theme.getSecondaryTextColor(context).withValues(alpha: 0.5),
                              ),
                            ),
                          )
                        : Icon(
                            Icons.videocam,
                            size: 40,
                            color: theme.getSecondaryTextColor(context).withValues(alpha: 0.5),
                          ),
                  ),

                  // Centered Play Button
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      size: 28,
                      color: Colors.white,
                    ),
                  ),

                  // Duration Badge bottom right
                  if (dur > 0)
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          formattedDuration,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWallPostItem(
    BuildContext context,
    VKWallPost wall,
    ThemeManager theme,
    bool isDark,
    Color textColor,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1F) : const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF363738) : const Color(0xFFE4E6E9),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.repeat_rounded, size: 16, color: theme.accentColor),
              const SizedBox(width: 6),
              Text(
                'Запись на стене',
                style: TextStyle(
                  color: theme.accentColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          if (wall.text.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              wall.text,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: theme.getTextColor(context),
                fontSize: 13 * theme.fontSizeScale,
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
