import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/message.dart';
import '../../models/pending_upload_item.dart';
import '../../services/messenger_store.dart';
import '../../services/theme_manager.dart';
import '../modals/emoji_sticker_picker_sheet.dart';
import '../modals/media_attach_dialog.dart';

import 'package:pasteboard/pasteboard.dart';
import 'package:path_provider/path_provider.dart';

class WriteBar extends StatefulWidget {
  final VKMessage? replyToMessage;
  final VoidCallback onCancelReply;
  final VKMessage? editingMessage;
  final VoidCallback? onCancelEdit;
  final void Function(int messageId, String newText)? onEditMessage;

  const WriteBar({
    super.key,
    this.replyToMessage,
    required this.onCancelReply,
    this.editingMessage,
    this.onCancelEdit,
    this.onEditMessage,
  });

  @override
  State<WriteBar> createState() => _WriteBarState();
}

class _WriteBarState extends State<WriteBar> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _hasText = false;
  bool _showPicker = false;
  final OverlayPortalController _overlayController = OverlayPortalController();

  @override
  void initState() {
    super.initState();
    _textController.addListener(() {
      final has = _textController.text.trim().isNotEmpty;
      if (has != _hasText) {
        setState(() => _hasText = has);
      }
    });
    if (widget.editingMessage != null) {
      _textController.text = widget.editingMessage!.text;
    }
  }

  @override
  void didUpdateWidget(WriteBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.editingMessage != null && widget.editingMessage != oldWidget.editingMessage) {
      _textController.text = widget.editingMessage!.text;
      _textController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _textController.text.length,
      );
      _focusNode.requestFocus();
    } else if (widget.editingMessage == null && oldWidget.editingMessage != null) {
      _textController.clear();
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _send() {
    final text = _textController.text.trim();
    final store = context.read<MessengerStore>();
    if (text.isEmpty && store.pendingUploads.isEmpty) return;

    if (widget.editingMessage != null) {
      if (text.isNotEmpty) {
        widget.onEditMessage?.call(widget.editingMessage!.id, text);
      }
      _textController.clear();
      widget.onCancelEdit?.call();
      _focusNode.requestFocus();
      return;
    }

    store.sendMessage(text, replyToMsgId: widget.replyToMessage?.id);
    _textController.clear();
    widget.onCancelReply();
    _focusNode.requestFocus();
  }

  Future<void> _handlePaste() async {
    try {
      // 1. Check for image in clipboard
      final imageBytes = await Pasteboard.image;
      if (imageBytes != null && imageBytes.isNotEmpty) {
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/pasted_img_${DateTime.now().millisecondsSinceEpoch}.png');
        await tempFile.writeAsBytes(imageBytes);
        if (!mounted) return;
        final store = context.read<MessengerStore>();
        store.addPendingFile(tempFile, isPhoto: true);
        return;
      }

      // 2. Check for copied files in clipboard
      final files = await Pasteboard.files();
      if (files.isNotEmpty) {
        if (!mounted) return;
        final store = context.read<MessengerStore>();
        for (final path in files) {
          if (path.isNotEmpty && File(path).existsSync()) {
            final isImg = ['.png', '.jpg', '.jpeg', '.gif', '.webp'].any((ext) => path.toLowerCase().endsWith(ext));
            store.addPendingFile(File(path), isPhoto: isImg);
          }
        }
        return;
      }

      // 3. Fallback to text paste
      final text = await Pasteboard.text;
      if (text != null && text.isNotEmpty) {
        final current = _textController.text;
        final sel = _textController.selection;
        final start = sel.isValid ? sel.start : current.length;
        final end = sel.isValid ? sel.end : current.length;
        final newText = current.replaceRange(start, end, text);
        _textController.text = newText;
        _textController.selection = TextSelection.collapsed(offset: start + text.length);
      }
    } catch (e) {
      debugPrint('[WriteBar] Paste error: $e');
    }
  }

  Future<void> _pickPhotosFromPC() async {
    final res = await FilePicker.pickFiles(
      type: FileType.image,
    );
    if (res.isNotEmpty && mounted) {
      final store = context.read<MessengerStore>();
      for (final f in res) {
        if (f.path != null) {
          store.addPendingFile(File(f.path!), isPhoto: true);
        }
      }
    }
  }

  Future<void> _pickDocsFromPC() async {
    final res = await FilePicker.pickFiles(
      type: FileType.any,
    );
    if (res.isNotEmpty && mounted) {
      final store = context.read<MessengerStore>();
      for (final f in res) {
        if (f.path != null) {
          store.addPendingFile(File(f.path!), isPhoto: false);
        }
      }
    }
  }

  void _openMediaDialog() {
    showDialog(
      context: context,
      builder: (ctx) => MediaAttachDialog(
        onFileSelected: (file, isPhoto) {
          final store = context.read<MessengerStore>();
          store.addPendingFile(file, isPhoto: isPhoto);
        },
        onInstanceMediaSelected: (attachCode, {type, title, thumbnailUrl, subtitle}) {
          final store = context.read<MessengerStore>();
          store.addPendingInstanceMedia(
            type: type ?? 'doc',
            attachmentCode: attachCode,
            title: title ?? 'Медиафайл',
            thumbnailUrl: thumbnailUrl,
            subtitle: subtitle,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeManager>();
    final isDark = theme.isDark(context);
    final store = context.watch<MessengerStore>();

    final hasPending = store.pendingUploads.isNotEmpty;
    final canSend = _hasText || hasPending;

    // Dynamic placeholder matching Mac Swift app
    String placeholder = 'Напишите сообщение...';
    final conv = store.selectedConversation;
    final isSaved = conv != null &&
        (conv.isSavedMessages || (store.activeAccount != null && conv.peerId == store.activeAccount!.userId));
    if (conv != null) {
      if (isSaved) {
        placeholder = 'Сохранить в Избранное...';
      } else {
        final title = conv.title.trim();
        final firstWord = title.split(' ').first;
        placeholder = 'Напишите $firstWord...';
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Edit Preview Banner
        if (widget.editingMessage != null) _buildEditPreview(theme, isDark),

        // Reply Preview Banner
        if (widget.replyToMessage != null) _buildReplyPreview(theme, isDark),


        // Compose Capsule Container
        Padding(
          padding: const EdgeInsets.only(left: 14, right: 14, bottom: 10, top: 4),
          child: Container(
            decoration: BoxDecoration(
              color: theme.getSecondarySurfaceColor(context).withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(hasPending ? 16 : 20),
              border: Border.all(
                color: theme.getSeparatorColor(context).withValues(alpha: 0.55),
                width: 0.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Pending Uploads Attachment Tray (Matches user's reference screenshot media_1792335333350_1d19bef3.png)
                if (hasPending) ...[
                  _buildAttachmentTray(context, store, theme, isDark),
                  Divider(
                    height: 1,
                    thickness: 0.7,
                    color: theme.getSeparatorColor(context).withValues(alpha: 0.4),
                  ),
                ],

                // 2. Input Row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Paperclip button with macOS popup menu options
                      PopupMenuButton<String>(
                        tooltip: 'Прикрепить медиа...',
                        constraints: const BoxConstraints(minWidth: 220, maxWidth: 320),
                        icon: Icon(
                          Icons.attach_file_rounded,
                          color: theme.getSecondaryTextColor(context),
                          size: 20,
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        color: theme.getSurfaceColor(context),
                        elevation: 6,
                        onSelected: (value) {
                          if (value == 'photo') {
                            _pickPhotosFromPC();
                          } else if (value == 'doc') {
                            _pickDocsFromPC();
                          } else if (value == 'ovk') {
                            _openMediaDialog();
                          }
                        },
                        itemBuilder: (ctx) => [
                          PopupMenuItem(
                            value: 'photo',
                            child: Row(
                              children: [
                                Icon(Icons.photo_outlined, size: 18, color: theme.accentColor),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Фото с компьютера',
                                    style: TextStyle(
                                      color: theme.getTextColor(context),
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'doc',
                            child: Row(
                              children: [
                                Icon(Icons.insert_drive_file_outlined, size: 18, color: theme.accentColor),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Файл / Документ с компьютера',
                                    style: TextStyle(
                                      color: theme.getTextColor(context),
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const PopupMenuDivider(),
                          PopupMenuItem(
                            value: 'ovk',
                            child: Row(
                              children: [
                                Icon(Icons.auto_awesome_motion_outlined, size: 18, color: theme.accentColor),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Медиа с OpenVK',
                                    style: TextStyle(
                                      color: theme.getTextColor(context),
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 4),

                      // Center Text Field
                      Expanded(
                        child: Focus(
                          onKeyEvent: (node, event) {
                            if (event is KeyDownEvent) {
                              final isPasteShortcut = (event.logicalKey == LogicalKeyboardKey.keyV) &&
                                  (HardwareKeyboard.instance.isMetaPressed || HardwareKeyboard.instance.isControlPressed);
                              if (isPasteShortcut) {
                                _handlePaste();
                                return KeyEventResult.handled;
                              }

                              if (event.logicalKey == LogicalKeyboardKey.escape) {
                                if (widget.editingMessage != null) {
                                  widget.onCancelEdit?.call();
                                  _textController.clear();
                                  return KeyEventResult.handled;
                                }
                                if (widget.replyToMessage != null) {
                                  widget.onCancelReply();
                                  return KeyEventResult.handled;
                                }
                              }

                              if (event.logicalKey == LogicalKeyboardKey.enter &&
                                  !HardwareKeyboard.instance.isShiftPressed) {
                                _send();
                                return KeyEventResult.handled;
                              }
                            }
                            return KeyEventResult.ignored;
                          },
                          child: TextField(
                            controller: _textController,
                            focusNode: _focusNode,
                            minLines: 1,
                            maxLines: 5,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _send(),
                            style: TextStyle(
                              color: theme.getTextColor(context),
                              fontSize: 13.5 * theme.fontSizeScale,
                            ),
                            decoration: InputDecoration(
                              hintText: placeholder,
                              hintStyle: TextStyle(
                                color: theme.getSecondaryTextColor(context).withValues(alpha: 0.75),
                                fontSize: 13.5 * theme.fontSizeScale,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 7),
                              isDense: true,
                            ),
                            onChanged: (text) {
                              store.sendTypingActivity();
                            },
                          ),
                        ),
                      ),

                      // Sticker & Emoji toggle button (Floating Popover matching macOS Swift)
                      OverlayPortal(
                        controller: _overlayController,
                        overlayChildBuilder: (overlayContext) {
                          return Stack(
                            children: [
                              Positioned.fill(
                                child: GestureDetector(
                                  behavior: HitTestBehavior.translucent,
                                  onTap: () {
                                    setState(() => _showPicker = false);
                                    _overlayController.hide();
                                  },
                                ),
                              ),
                              Positioned(
                                bottom: hasPending ? 124 : 64,
                                right: 14,
                                child: EmojiStickerPickerSheet(
                                  onSelectEmoji: (emoji) {
                                    final cur = _textController.text;
                                    final sel = _textController.selection;
                                    if (sel.isValid && sel.start >= 0 && sel.end <= cur.length) {
                                      final newText = cur.replaceRange(sel.start, sel.end, emoji);
                                      _textController.value = TextEditingValue(
                                        text: newText,
                                        selection: TextSelection.collapsed(offset: sel.start + emoji.length),
                                      );
                                    } else {
                                      _textController.text = '$cur$emoji';
                                    }
                                  },
                                  onSelectSticker: (stickerId) {
                                    store.sendSticker(stickerId);
                                    setState(() => _showPicker = false);
                                    _overlayController.hide();
                                  },
                                ),
                              ),
                            ],
                          );
                        },
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          icon: Icon(
                            _showPicker ? Icons.keyboard_rounded : Icons.sentiment_satisfied_alt_outlined,
                            color: _showPicker ? theme.accentColor : theme.getSecondaryTextColor(context),
                            size: 20,
                          ),
                          tooltip: 'Стикеры и эмодзи',
                          onPressed: () {
                            setState(() => _showPicker = !_showPicker);
                            _overlayController.toggle();
                          },
                        ),
                      ),

                      // Send button
                      if (canSend) ...[
                        const SizedBox(width: 2),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                          icon: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: theme.accentColor,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.arrow_upward_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                          tooltip: 'Отправить',
                          onPressed: _send,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAttachmentTray(BuildContext context, MessengerStore store, ThemeManager theme, bool isDark) {
    return SizedBox(
      width: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(left: 12, right: 12, top: 10, bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: store.pendingUploads.map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _buildAttachmentItem(context, store, item, theme, isDark),
                  );
                }).toList(),
              ),
            ),
          ),
        if (store.pendingUploads.any((item) => item.error != null))
          Padding(
            padding: const EdgeInsets.only(left: 12, right: 12, bottom: 6),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    store.pendingUploads.firstWhere((item) => item.error != null).error!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 11),
                  ),
                ),
                GestureDetector(
                  onTap: () => store.clearPendingUploads(),
                  child: const Text(
                    'Убрать',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
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

  Widget _buildAttachmentItem(
    BuildContext context,
    MessengerStore store,
    PendingUploadItem item,
    ThemeManager theme,
    bool isDark,
  ) {
    const double size = 58;

    Widget content;
    if (item.isPhoto) {
      if (item.localFile != null && item.localFile!.existsSync()) {
        content = Image.file(
          item.localFile!,
          width: size,
          height: size,
          fit: BoxFit.cover,
        );
      } else if (item.remoteThumbnailUrl != null && item.remoteThumbnailUrl!.isNotEmpty) {
        content = CachedNetworkImage(
          imageUrl: item.remoteThumbnailUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (ctx, url) => Container(color: Colors.black26),
          errorWidget: (ctx, url, err) => const Icon(Icons.broken_image, size: 24),
        );
      } else {
        content = Container(
          width: size,
          height: size,
          color: theme.getSecondarySurfaceColor(context),
          child: Icon(Icons.photo, color: theme.accentColor, size: 24),
        );
      }
    } else if (item.isDocument) {
      content = Container(
        width: size,
        height: size,
        color: isDark ? const Color(0xFF26282B) : const Color(0xFFE8EAED),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.insert_drive_file_rounded, color: theme.accentColor, size: 22),
            const SizedBox(height: 2),
            Text(
              item.fileExtension,
              style: TextStyle(
                color: theme.getSecondaryTextColor(context),
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
    } else if (item.isAudio) {
      content = Container(
        width: size,
        height: size,
        color: isDark ? const Color(0xFF26282B) : const Color(0xFFE8EAED),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.music_note_rounded, color: theme.accentColor, size: 22),
            const SizedBox(height: 2),
            Text(
              'AUDIO',
              style: TextStyle(
                color: theme.getSecondaryTextColor(context),
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    } else {
      // Video
      if (item.remoteThumbnailUrl != null && item.remoteThumbnailUrl!.isNotEmpty) {
        content = Stack(
          alignment: Alignment.center,
          children: [
            CachedNetworkImage(
              imageUrl: item.remoteThumbnailUrl!,
              width: size,
              height: size,
              fit: BoxFit.cover,
            ),
            const Icon(Icons.play_circle_fill, color: Colors.white, size: 20),
          ],
        );
      } else {
        content = Container(
          width: size,
          height: size,
          color: isDark ? const Color(0xFF26282B) : const Color(0xFFE8EAED),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.videocam_rounded, color: theme.accentColor, size: 22),
              const SizedBox(height: 2),
              Text(
                'VIDEO',
                style: TextStyle(
                  color: theme.getSecondaryTextColor(context),
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      }
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(child: content),

            // Semi-transparent overlay button with centered white '✕' / progress
            GestureDetector(
              onTap: () => store.removePendingUpload(item.id),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: item.error != null
                      ? Colors.red.withValues(alpha: 0.85)
                      : Colors.black.withValues(alpha: 0.52),
                  shape: BoxShape.circle,
                ),
                child: item.isUploading
                    ? Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              value: item.progress > 0.05 ? item.progress : null,
                              strokeWidth: 2.4,
                              color: Colors.white,
                              backgroundColor: Colors.white.withValues(alpha: 0.25),
                            ),
                          ),
                          const Icon(Icons.close_rounded, size: 14, color: Colors.white),
                        ],
                      )
                    : item.error != null
                        ? const Icon(Icons.priority_high_rounded, size: 16, color: Colors.white)
                        : const Icon(Icons.close_rounded, size: 15, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReplyPreview(ThemeManager theme, bool isDark) {
    final msg = widget.replyToMessage!;
    return Padding(
      padding: const EdgeInsets.only(left: 14, right: 14, bottom: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: theme.getSecondarySurfaceColor(context).withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.getSeparatorColor(context).withValues(alpha: 0.5),
            width: 0.8,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 3,
              height: 28,
              decoration: BoxDecoration(
                color: theme.accentColor,
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    msg.sender?.fullName ?? 'Ответ на сообщение',
                    style: TextStyle(
                      color: theme.accentColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    msg.text.isNotEmpty ? msg.text : 'Вложение',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: theme.getSecondaryTextColor(context),
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              icon: Icon(
                Icons.close,
                color: theme.getSecondaryTextColor(context),
                size: 16,
              ),
              onPressed: widget.onCancelReply,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditPreview(ThemeManager theme, bool isDark) {
    final msg = widget.editingMessage!;
    return Padding(
      padding: const EdgeInsets.only(left: 14, right: 14, bottom: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: theme.getSecondarySurfaceColor(context).withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.accentColor.withValues(alpha: 0.5),
            width: 0.8,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.edit_rounded, size: 18, color: theme.accentColor),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Редактирование сообщения',
                    style: TextStyle(
                      color: theme.accentColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    msg.text.isNotEmpty ? msg.text : 'Текст сообщения',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: theme.getSecondaryTextColor(context),
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              icon: Icon(
                Icons.close,
                color: theme.getSecondaryTextColor(context),
                size: 16,
              ),
              onPressed: () {
                widget.onCancelEdit?.call();
                _textController.clear();
              },
            ),
          ],
        ),
      ),
    );
  }
}
