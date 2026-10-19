import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/attachment.dart';
import '../../services/image_cache_manager.dart';
import '../../services/memory_manager.dart';
import '../../services/messenger_store.dart';
import '../../services/openvk_api.dart';
import '../../services/theme_manager.dart';
import '../widgets/vk_animated_sticker_view.dart';

enum VKPickerMainTab {
  emoji('Эмодзи'),
  stickers('Стикеры');

  final String title;
  const VKPickerMainTab(this.title);
}

class EmojiStickerPickerSheet extends StatefulWidget {
  final Function(String emoji) onSelectEmoji;
  final Function(int stickerId) onSelectSticker;

  const EmojiStickerPickerSheet({
    super.key,
    required this.onSelectEmoji,
    required this.onSelectSticker,
  });

  @override
  State<EmojiStickerPickerSheet> createState() => _EmojiStickerPickerSheetState();
}

class _EmojiStickerPickerSheetState extends State<EmojiStickerPickerSheet> {
  VKPickerMainTab _activeTab = VKPickerMainTab.stickers;
  int _selectedEmojiCategoryIndex = 0;
  int? _activePackId;

  List<VKStickerPack> _packs = [];
  bool _loadingStickers = false;

  final ScrollController _stickersScrollController = ScrollController();
  final GlobalKey _recentsKey = GlobalKey();
  final GlobalKey _favoritesKey = GlobalKey();
  final Map<int, GlobalKey> _packKeys = {};

  final List<Map<String, dynamic>> _emojiCategories = [
    {
      'title': 'Смайлы',
      'icon': '😀',
      'emojis': [
        '😀', '😃', '😄', '😁', '😆', '😅', '😂', '🤣', '🥲', '🥹',
        '😊', '😇', '🙂', '🙃', '😉', '😌', '😍', '🥰', '😘', '😗',
        '😙', '😚', '😋', '😛', '😝', '😜', '🤪', '🤨', '🧐', '🤓',
        '😎', '🥸', '🤩', '🥳', '😏', '😒', '😞', '😔', '😟', '😕',
        '🙁', '☹️', '😣', '😖', '😫', '😩', '🥺', '😢', '😭', '😤',
        '😠', '😡', '🤬', '🤯', '😳', '🥵', '🥶', '😱', '😨', '😰',
        '😥', '😓', '🤗', '🤔', '🫣', '🤭', '🫢', '🤫', '🤥', '😶',
        '😐', '😑', '😬', '🫨', '🙄', '😯', '😦', '😧', '😮', '😲',
        '🥱', '😴', '🤤', '😪', '😵', '😵‍💫', '🤐', '🥴', '🤢', '🤮',
        '🤧', '😷', '🤒', '🤕', '🤑', '🤠', '😈', '👿', '🤡', '💩',
        '👻', '💀', '☠️', '👽', '👾', '🤖', '🎃', '😺', '😸', '😹',
        '😻', '😼', '😽', '🙀', '😿', '😾',
      ],
    },
    {
      'title': 'Люди',
      'icon': '👋',
      'emojis': [
        '👋', '🤚', '🖐', '✋', '🖖', '🫱', '🫲', '🫳', '🫴', '👌',
        '🤌', '🤏', '✌️', '🤞', '🫰', '🤟', '🤘', '🤙', '👈', '👉',
        '👆', '🖕', '👇', '☝️', '🫵', '👍', '👎', '✊', '👊', '🤛',
        '🤜', '👏', '🙌', '🫶', '👐', '🤲', '🤝', '🙏', '✍️', '💅',
        '🤳', '💪', '🦾', '🦿', '🦵', '🦶', '👂', '🦻', '👃', '🫀',
        '🫁', '🧠', '🦷', '🦴', '👀', '👁', '👅', '👄', '🫦', '💋',
      ],
    },
    {
      'title': 'Чувства',
      'icon': '❤️',
      'emojis': [
        '❤️', '🧡', '💛', '💚', '💙', '💜', '🖤', '🤍', '🤎', '💔',
        '❤️‍🔥', '❤️‍🩹', '❣️', '💕', '💞', '💓', '💗', '💖', '💘', '💝',
        '💟', '☮️', '✝️', '☪️', '🪷', '💐', '🌸', '💮', '🏵', '🌹',
        '🥀', '🌺', '🌻', '🌼', '🌷', '🪻', '🌱', '🪴', '🌲', '🌳',
        '🌴', '🌵', '🌾', '🌿', '☘️', '🍀', '🍁', '🍂', '🍃', '🍄',
      ],
    },
    {
      'title': 'Животные',
      'icon': '🐶',
      'emojis': [
        '🐶', '🐱', '🐭', '🐹', '🐰', '🦊', '🐻', '🐼', '🐻‍❄️', '🐨',
        '🐯', '🦁', '🐮', '🐷', '🐽', '🐸', '🐵', '🙈', '🙉', '🙊',
        '🐒', '🐔', '🐧', '🐦', '🐤', '🐣', '🐥', '🦆', '🦅', '🦉',
        '🦇', '🐺', '🐗', '🐴', '🦄', '🐝', '🪱', '🐛', '🦋', '🐌',
      ],
    },
    {
      'title': 'Еда',
      'icon': '🍕',
      'emojis': [
        '🍏', '🍎', '🍐', '🍊', '🍋', '🍌', '🍉', '🍇', '🍓', '🫐',
        '🍈', '🍒', '🍑', '🥭', '🍍', '🥥', '🥝', '🍅', '🍆', '🥑',
        '🥦', '🥬', '🥒', '🌶', '🫑', '🌽', '🥕', '🫒', '🧄', '🧅',
        '🥔', '🍠', '🥐', '🥯', '🍞', '🥖', '🥨', '🧀', '🥚', '🍳',
        '🧈', '🥞', '🧇', '🥓', '🥩', '🍗', '🍖', '🌭', '🍔', '🍟',
        '🍕', '🫓', '🥪', '🥙', '🧆', '🌮', '🌯', '🫔', '🥗', '🥘',
      ],
    },
    {
      'title': 'Спорт',
      'icon': '⚽️',
      'emojis': [
        '⚽️', '🏀', '🏈', '⚾️', '🥎', '🎾', '🏐', '🏉', '🥏', '🎱',
        '🪀', '🏓', '🏸', '🏒', '🏑', '🥍', '🏏', '🪃', '🥅', '⛳️',
        '🪁', '🏹', '🎣', '🤿', '🥊', '🥋', '🎽', '🛹', '🛼', '🛷',
      ],
    },
    {
      'title': 'Символы',
      'icon': '💡',
      'emojis': [
        '💯', '💢', '💬', '💭', '🗯', '💤', '✨', '⭐️', '🌟', '💫',
        '💥', '🔥', '⚡️', '☄️', '🌈', '☀️', '🌤', '⛅️', '🌥', '☁️',
        '🌦', '🌧', '⛈', '🌩', '🌨', '❄️', '☃️', '⛄️', '🌬', '💨',
        '💧', '💦', '🫧', '☔️', '☂️', '💰', '💵', '💳', '💎', '💡',
      ],
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadPacks();
  }

  @override
  void dispose() {
    _stickersScrollController.dispose();
    MemoryManager.instance.trimMemory();
    super.dispose();
  }

  Future<void> _loadPacks() async {
    final store = context.read<MessengerStore>();
    if (store.stickerPacks.isNotEmpty) {
      _initPacks(store.stickerPacks);
      return;
    }

    setState(() => _loadingStickers = true);
    final packs = await OpenVKAPIService.instance.fetchStickerPacks();
    if (mounted) {
      _initPacks(packs);
      store.loadStickerPacks();
    }
  }

  void _initPacks(List<VKStickerPack> packs) {
    setState(() {
      _packs = packs;
      _loadingStickers = false;
      for (final p in packs) {
        _packKeys[p.id] = GlobalKey();
      }
      if (packs.isNotEmpty && _activePackId == null) {
        _activePackId = packs.first.id;
      }
    });
  }

  void _scrollToKey(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        alignment: 0.0,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeManager>();

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 360,
        height: 420,
        decoration: BoxDecoration(
          color: theme.getSurfaceColor(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.getSeparatorColor(context).withValues(alpha: 0.55),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // Top Tab Bar: Эмодзи | Стикеры
            _buildTopTabBar(theme),

            Divider(height: 1, thickness: 0.8, color: theme.getSeparatorColor(context).withValues(alpha: 0.5)),

            // Content
            Expanded(
              child: _activeTab == VKPickerMainTab.stickers
                  ? _buildStickersContent(theme)
                  : _buildEmojiContent(theme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopTabBar(ThemeManager theme) {
    return Container(
      color: theme.getSurfaceColor(context),
      child: Row(
        children: [
          _buildTabButton(VKPickerMainTab.emoji, theme),
          _buildTabButton(VKPickerMainTab.stickers, theme),
        ],
      ),
    );
  }

  Widget _buildTabButton(VKPickerMainTab tab, ThemeManager theme) {
    final isSelected = _activeTab == tab;

    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() => _activeTab = tab);
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 6),
              child: Text(
                tab.title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? theme.accentColor : theme.getSecondaryTextColor(context),
                ),
              ),
            ),
            Container(
              height: 2.5,
              width: double.infinity,
              decoration: BoxDecoration(
                color: isSelected ? theme.accentColor : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStickersContent(ThemeManager theme) {
    final store = context.watch<MessengerStore>();

    if (_loadingStickers && _packs.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_packs.isEmpty && store.recentStickerIds.isEmpty && store.favoriteStickerIds.isEmpty) {
      return Center(
        child: Text(
          'Стикеры не найдены',
          style: TextStyle(color: theme.getSecondaryTextColor(context)),
        ),
      );
    }

    return Column(
      children: [
        // Continuous Scrollable Stickers Area
        Expanded(
          child: SingleChildScrollView(
            controller: _stickersScrollController,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Recents section (if any)
                if (store.recentStickerIds.isNotEmpty) ...[
                  Padding(
                    key: _recentsKey,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    child: Text(
                      'Недавние',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: theme.getSecondaryTextColor(context),
                      ),
                    ),
                  ),
                  _buildStickersGrid(
                    store.recentStickerIds.map((id) => store.stickerItem(id)).toList(),
                    theme,
                  ),
                  const SizedBox(height: 10),
                ],

                // 2. Favorites section (if any)
                if (store.favoriteStickerIds.isNotEmpty) ...[
                  Padding(
                    key: _favoritesKey,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    child: Text(
                      'Избранные',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: theme.getSecondaryTextColor(context),
                      ),
                    ),
                  ),
                  _buildStickersGrid(
                    store.favoriteStickerIds.map((id) => store.stickerItem(id)).toList(),
                    theme,
                  ),
                  const SizedBox(height: 10),
                ],

                // 3. Continuous packs
                for (final pack in _packs) ...[
                  Padding(
                    key: _packKeys[pack.id],
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    child: Text(
                      pack.title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: theme.getSecondaryTextColor(context),
                      ),
                    ),
                  ),
                  _buildStickersGrid(pack.stickers, theme),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ),

        // Bottom Dock Bar (Matching macOS Swift reference)
        Divider(height: 1, thickness: 0.8, color: theme.getSeparatorColor(context).withValues(alpha: 0.5)),
        _buildBottomDock(theme, store),
      ],
    );
  }

  Widget _buildStickersGrid(List<VKStickerItem> stickers, ThemeManager theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.0,
        ),
        itemCount: stickers.length,
        itemBuilder: (ctx, idx) {
          final item = stickers[idx];
          return _StickerThumbnail(
            sticker: item,
            onSelect: () => widget.onSelectSticker(item.id),
          );
        },
      ),
    );
  }

  Widget _buildBottomDock(ThemeManager theme, MessengerStore store) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      color: theme.getSurfaceColor(context),
      child: Row(
        children: [
          // ⭐ Favorites Anchor
          IconButton(
            icon: Icon(
              store.favoriteStickerIds.isNotEmpty ? Icons.star_rounded : Icons.star_border_rounded,
              size: 20,
              color: theme.getSecondaryTextColor(context),
            ),
            splashRadius: 18,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            tooltip: 'Избранные',
            onPressed: () => _scrollToKey(_favoritesKey),
          ),

          // 🕒 Recents Anchor
          IconButton(
            icon: Icon(
              Icons.access_time_rounded,
              size: 19,
              color: theme.getSecondaryTextColor(context),
            ),
            splashRadius: 18,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            tooltip: 'Недавние',
            onPressed: () => _scrollToKey(_recentsKey),
          ),

          // Vertical Separator
          Container(
            width: 1,
            height: 18,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            color: theme.getSeparatorColor(context).withValues(alpha: 0.6),
          ),

          // Scrollable Packs Row
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _packs.length,
              separatorBuilder: (ctx, idx) => const SizedBox(width: 4),
              itemBuilder: (ctx, idx) {
                final pack = _packs[idx];
                final isSelected = _activePackId == pack.id;
                final iconUrl = pack.iconURL ?? (pack.stickers.isNotEmpty ? pack.stickers.first.url : null);

                return Tooltip(
                  message: pack.title,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () {
                      setState(() => _activePackId = pack.id);
                      final key = _packKeys[pack.id];
                      if (key != null) _scrollToKey(key);
                    },
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: isSelected ? theme.accentColor.withValues(alpha: 0.12) : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isSelected ? theme.accentColor.withValues(alpha: 0.4) : Colors.transparent,
                          width: 1,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: iconUrl != null
                          ? CachedNetworkImage(
                              imageUrl: iconUrl,
                              cacheManager: VKImageCacheManager.instance,
                              width: 22,
                              height: 22,
                              memCacheWidth: 44,
                              memCacheHeight: 44,
                              fit: BoxFit.contain,
                              placeholder: (ctx, url) => const SizedBox(width: 22, height: 22),
                              errorWidget: (ctx, url, err) => Icon(
                                Icons.image_outlined,
                                size: 16,
                                color: theme.getSecondaryTextColor(context),
                              ),
                            )
                          : Icon(
                              Icons.sentiment_satisfied_outlined,
                              size: 16,
                              color: theme.getSecondaryTextColor(context),
                            ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmojiContent(ThemeManager theme) {
    final emojis = _emojiCategories[_selectedEmojiCategoryIndex]['emojis'] as List<String>;

    return Column(
      children: [
        // Category Selector (matching macOS icon pills)
        Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color: theme.getSurfaceColor(context),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _emojiCategories.length,
            separatorBuilder: (ctx, idx) => const SizedBox(width: 3),
            itemBuilder: (ctx, idx) {
              final cat = _emojiCategories[idx];
              final isSel = _selectedEmojiCategoryIndex == idx;

              return Tooltip(
                message: cat['title'] as String,
                child: InkWell(
                  borderRadius: BorderRadius.circular(7),
                  onTap: () => setState(() => _selectedEmojiCategoryIndex = idx),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: isSel ? theme.getSecondarySurfaceColor(context) : Colors.transparent,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      cat['icon'] as String,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        Divider(height: 1, thickness: 0.8, color: theme.getSeparatorColor(context).withValues(alpha: 0.4)),

        // Emojis Grid
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 8,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
            ),
            itemCount: emojis.length,
            itemBuilder: (ctx, idx) {
              final e = emojis[idx];
              return InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () => widget.onSelectEmoji(e),
                child: Center(
                  child: Text(
                    e,
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _StickerThumbnail extends StatefulWidget {
  final VKStickerItem sticker;
  final VoidCallback onSelect;

  const _StickerThumbnail({
    required this.sticker,
    required this.onSelect,
  });

  @override
  State<_StickerThumbnail> createState() => _StickerThumbnailState();
}

class _StickerThumbnailState extends State<_StickerThumbnail> {
  bool _isHovered = false;

  void _showContextMenu(BuildContext context, Offset position) {
    final store = context.read<MessengerStore>();
    final isFav = store.isFavoriteSticker(widget.sticker.id);

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx + 1, position.dy + 1),
      items: [
        PopupMenuItem(
          value: 'toggle_fav',
          child: Row(
            children: [
              Icon(
                isFav ? Icons.star_border_rounded : Icons.star_rounded,
                size: 18,
                color: isFav ? Colors.grey : Colors.amber,
              ),
              const SizedBox(width: 8),
              Text(isFav ? 'Удалить из избранного' : 'В избранное'),
            ],
          ),
        ),
      ],
    ).then((choice) {
      if (choice == 'toggle_fav') {
        store.toggleFavoriteSticker(widget.sticker.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeManager>();

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onSelect,
        onSecondaryTapDown: (details) => _showContextMenu(context, details.globalPosition),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          transform: Matrix4.diagonal3Values(_isHovered ? 1.05 : 1.0, _isHovered ? 1.05 : 1.0, 1.0),
          transformAlignment: Alignment.center,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: _isHovered ? theme.getSecondarySurfaceColor(context) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: VKAnimatedStickerView(
            url: widget.sticker.url,
            animationUrl: widget.sticker.animationURL,
            size: 68,
            loop: _isHovered,
          ),
        ),
      ),
    );
  }
}
