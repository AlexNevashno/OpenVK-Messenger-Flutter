import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/attachment.dart';
import '../../models/conversation.dart';
import '../../models/user.dart';
import '../../services/messenger_store.dart';
import '../../services/openvk_api.dart';
import '../../services/theme_manager.dart';
import '../widgets/avatar.dart';
import 'photo_viewer_dialog.dart';

class ConversationMaterialItem {
  final String id;
  final String title;
  final String subtitle;
  final String? thumbnailURL;
  final String? contentURL;
  final String? ext;

  ConversationMaterialItem({
    required this.id,
    required this.title,
    required this.subtitle,
    this.thumbnailURL,
    this.contentURL,
    this.ext,
  });
}

class ConversationInfoDialog extends StatefulWidget {
  final VKConversation conversation;

  const ConversationInfoDialog({
    super.key,
    required this.conversation,
  });

  @override
  State<ConversationInfoDialog> createState() => _ConversationInfoDialogState();
}

class _ConversationInfoDialogState extends State<ConversationInfoDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _memberSearchController = TextEditingController();
  bool _isEditingTitle = false;
  String _memberSearchQuery = '';

  // Members
  bool _loadingMembers = false;
  List<Map<String, dynamic>> _members = [];

  // Materials
  int _selectedMaterialIndex = 0;
  final List<String> _materialTitles = ['Фото', 'Видео', 'Аудио', 'Файлы'];
  final List<IconData> _materialIcons = [
    Icons.photo_outlined,
    Icons.videocam_outlined,
    Icons.music_note_outlined,
    Icons.insert_drive_file_outlined,
  ];

  bool _loadingMaterials = false;
  bool _hasLoadedMaterials = false;
  List<ConversationMaterialItem> _materialsPhotos = [];
  List<ConversationMaterialItem> _materialsVideos = [];
  List<ConversationMaterialItem> _materialsAudio = [];
  List<ConversationMaterialItem> _materialsDocs = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: widget.conversation.isGroupChat ? 2 : 1, vsync: this);
    _titleController.text = widget.conversation.title;

    if (widget.conversation.isGroupChat) {
      _loadMembers();
    }
    _loadAllMaterials();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _memberSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    setState(() => _loadingMembers = true);
    final res = await OpenVKAPIService.instance.getConversationMembers(peerId: widget.conversation.peerId);
    if (mounted) {
      setState(() {
        _members = List<Map<String, dynamic>>.from(res['members'] as List? ?? []);
        _loadingMembers = false;
      });
    }
  }

  Future<void> _loadAllMaterials() async {
    setState(() => _loadingMaterials = true);
    final peerId = widget.conversation.peerId;

    final photos = <ConversationMaterialItem>[];
    final videos = <ConversationMaterialItem>[];
    final audios = <ConversationMaterialItem>[];
    final docs = <ConversationMaterialItem>[];

    // 1. Fetch remote attachments via API
    try {
      final remotePhotos = await OpenVKAPIService.instance.getHistoryAttachments(
        peerId: peerId,
        mediaType: 'photo',
        count: 50,
      );
      for (final p in remotePhotos) {
        final ph = p['photo'] is Map ? p['photo'] as Map : p;
        final photoObj = VKPhotoAttachment.fromJson(Map<String, dynamic>.from(ph));
        if (photoObj.url != null && photoObj.url!.isNotEmpty) {
          photos.add(ConversationMaterialItem(
            id: 'photo_${photoObj.id}',
            title: photoObj.text.isNotEmpty ? photoObj.text : 'Фотография',
            subtitle: 'Фото',
            thumbnailURL: photoObj.url,
            contentURL: photoObj.url,
          ));
        }
      }
    } catch (_) {}

    try {
      final remoteVideos = await OpenVKAPIService.instance.getHistoryAttachments(
        peerId: peerId,
        mediaType: 'video',
        count: 50,
      );
      for (final v in remoteVideos) {
        final vd = v['video'] is Map ? v['video'] as Map : v;
        final videoObj = VKVideoAttachment.fromJson(Map<String, dynamic>.from(vd));
        final mins = videoObj.duration ~/ 60;
        final secs = videoObj.duration % 60;
        videos.add(ConversationMaterialItem(
          id: 'video_${videoObj.ownerId}_${videoObj.id}',
          title: videoObj.title,
          subtitle: '${mins.toString().padLeft(1, '0')}:${secs.toString().padLeft(2, '0')}',
          thumbnailURL: videoObj.imageURL,
          contentURL: videoObj.playerURL ?? videoObj.imageURL,
        ));
      }
    } catch (_) {}

    try {
      final remoteAudio = await OpenVKAPIService.instance.getHistoryAttachments(
        peerId: peerId,
        mediaType: 'audio',
        count: 50,
      );
      for (final a in remoteAudio) {
        final ad = a['audio'] is Map ? a['audio'] as Map : a;
        final audioObj = VKAudioAttachment.fromJson(Map<String, dynamic>.from(ad));
        final mins = audioObj.duration ~/ 60;
        final secs = audioObj.duration % 60;
        audios.add(ConversationMaterialItem(
          id: 'audio_${audioObj.ownerId}_${audioObj.id}',
          title: audioObj.title,
          subtitle: '${audioObj.artist} • ${mins.toString().padLeft(1, '0')}:${secs.toString().padLeft(2, '0')}',
          contentURL: audioObj.url,
        ));
      }
    } catch (_) {}

    try {
      final remoteDocs = await OpenVKAPIService.instance.getHistoryAttachments(
        peerId: peerId,
        mediaType: 'doc',
        count: 50,
      );
      for (final d in remoteDocs) {
        final dc = d['doc'] is Map ? d['doc'] as Map : d;
        final docObj = VKDocAttachment.fromJson(Map<String, dynamic>.from(dc));
        docs.add(ConversationMaterialItem(
          id: 'doc_${docObj.id}',
          title: docObj.title,
          subtitle: _formatFileSize(docObj.size),
          contentURL: docObj.url,
          ext: docObj.ext,
        ));
      }
    } catch (_) {}

    // 2. Extract attachments from local messages in store (like Swift app)
    if (!mounted) return;
    final store = context.read<MessengerStore>();
    final msgs = store.messages[peerId] ?? [];
    for (final m in msgs) {
      final mPhotos = m.photos.isNotEmpty ? m.photos : (m.photo != null ? [m.photo!] : <VKPhotoAttachment>[]);
      for (final p in mPhotos) {
        if (p.url != null && p.url!.isNotEmpty) {
          final id = 'photo_${p.id}';
          if (!photos.any((x) => x.id == id || x.thumbnailURL == p.url)) {
            photos.add(ConversationMaterialItem(
              id: id,
              title: p.text.isNotEmpty ? p.text : 'Фотография',
              subtitle: 'Фото',
              thumbnailURL: p.url,
              contentURL: p.url,
            ));
          }
        }
      }

      if (m.video != null) {
        final v = m.video!;
        final id = 'video_${v.ownerId}_${v.id}';
        if (!videos.any((x) => x.id == id)) {
          final mins = v.duration ~/ 60;
          final secs = v.duration % 60;
          videos.add(ConversationMaterialItem(
            id: id,
            title: v.title,
            subtitle: '${mins.toString().padLeft(1, '0')}:${secs.toString().padLeft(2, '0')}',
            thumbnailURL: v.imageURL,
            contentURL: v.playerURL ?? v.imageURL,
          ));
        }
      }

      if (m.audio != null) {
        final a = m.audio!;
        final id = 'audio_${a.ownerId}_${a.id}';
        if (!audios.any((x) => x.id == id)) {
          final mins = a.duration ~/ 60;
          final secs = a.duration % 60;
          audios.add(ConversationMaterialItem(
            id: id,
            title: a.title,
            subtitle: '${a.artist} • ${mins.toString().padLeft(1, '0')}:${secs.toString().padLeft(2, '0')}',
            contentURL: a.url,
          ));
        }
      }

      if (m.doc != null) {
        final d = m.doc!;
        final id = 'doc_${d.id}';
        if (!docs.any((x) => x.id == id)) {
          docs.add(ConversationMaterialItem(
            id: id,
            title: d.title,
            subtitle: _formatFileSize(d.size),
            contentURL: d.url,
            ext: d.ext,
          ));
        }
      }
    }

    if (mounted) {
      setState(() {
        _materialsPhotos = photos;
        _materialsVideos = videos;
        _materialsAudio = audios;
        _materialsDocs = docs;
        _loadingMaterials = false;
        _hasLoadedMaterials = true;
      });
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes Б';
    if (bytes < 1024 * 1024) return '${(bytes / 1024.0).toStringAsFixed(1)} КБ';
    return '${(bytes / (1024.0 * 1024.0)).toStringAsFixed(1)} МБ';
  }

  void _saveTitle() {
    final newTitle = _titleController.text.trim();
    if (newTitle.isNotEmpty && newTitle != widget.conversation.title) {
      context.read<MessengerStore>().editChatTitle(widget.conversation.peerId, newTitle);
    }
    setState(() => _isEditingTitle = false);
  }

  void _openPhotoAt(int index) {
    if (_materialsPhotos.isEmpty) return;
    final items = _materialsPhotos
        .where((m) => (m.contentURL ?? m.thumbnailURL ?? '').isNotEmpty)
        .map((m) => PhotoViewerItem(
              id: m.id,
              url: m.contentURL ?? m.thumbnailURL!,
              caption: m.title != 'Фотография' ? m.title : '',
            ))
        .toList();
    if (items.isEmpty) return;
    final clampedIdx = index.clamp(0, items.length - 1);
    PhotoViewerDialog.show(context, items: items, initialIndex: clampedIdx);
  }

  void _openUrl(String? urlStr) {
    if (urlStr == null || urlStr.isEmpty) return;
    try {
      launchUrl(Uri.parse(urlStr));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeManager>();
    final store = context.watch<MessengerStore>();

    final totalMaterials = _materialsPhotos.length + _materialsVideos.length + _materialsAudio.length + _materialsDocs.length;
    final isSaved = widget.conversation.isSavedMessages ||
        (store.activeAccount != null && widget.conversation.peerId == store.activeAccount!.userId);

    return Dialog(
      backgroundColor: theme.getSurfaceColor(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 390,
        height: 620,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Column(
          children: [
            // Header Bar
            Row(
              children: [
                Expanded(
                  child: Text(
                    isSaved
                        ? 'Избранное'
                        : (widget.conversation.isGroupChat ? 'Информация о беседе' : 'Информация'),
                    style: TextStyle(
                      color: theme.getTextColor(context),
                      fontSize: 15.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                  icon: Icon(Icons.close_rounded, color: theme.getSecondaryTextColor(context), size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Symmetrical Hero Profile Card (Avatar + Title + Subtitle)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  VKAvatar(
                    url: isSaved ? null : widget.conversation.photoUrl,
                    name: isSaved ? 'Избранное' : widget.conversation.displayTitle,
                    size: 74,
                    isSavedMessages: isSaved,
                  ),
                  const SizedBox(height: 10),

                  if (_isEditingTitle)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 240,
                          child: TextField(
                            controller: _titleController,
                            autofocus: true,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: theme.getTextColor(context),
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            decoration: const InputDecoration(isDense: true),
                            onSubmitted: (_) => _saveTitle(),
                          ),
                        ),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          icon: const Icon(Icons.check, color: Colors.green, size: 20),
                          onPressed: _saveTitle,
                        ),
                      ],
                    )
                  else
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            isSaved ? 'Избранное' : widget.conversation.displayTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: theme.getTextColor(context),
                              fontSize: 16.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (widget.conversation.isGroupChat) ...[
                          const SizedBox(width: 4),
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                            icon: Icon(Icons.edit_outlined, size: 15, color: theme.getSecondaryTextColor(context)),
                            tooltip: 'Изменить название',
                            onPressed: () => setState(() => _isEditingTitle = true),
                          ),
                        ],
                      ],
                    ),

                  const SizedBox(height: 2),
                  Text(
                    isSaved
                        ? 'Сохранённые сообщения'
                        : widget.conversation.isGroupChat
                            ? '${widget.conversation.membersCount > 0 ? widget.conversation.membersCount : _members.length} участников'
                            : (widget.conversation.isOnline ? 'в сети' : 'был(а) недавно'),
                    style: TextStyle(
                      color: theme.getSecondaryTextColor(context),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Quick Action Buttons (Milkshake circular buttons: Mute, Search, Link)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildQuickActionButton(
                    context: context,
                    theme: theme,
                    icon: store.isMuted(widget.conversation.peerId)
                        ? Icons.notifications_off_rounded
                        : Icons.notifications_rounded,
                    label: store.isMuted(widget.conversation.peerId) ? 'Вкл. звук' : 'Без звука',
                    onTap: () {
                      store.toggleMute(widget.conversation.peerId);
                    },
                  ),
                  const SizedBox(width: 24),
                  _buildQuickActionButton(
                    context: context,
                    theme: theme,
                    icon: Icons.search_rounded,
                    label: 'Поиск',
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                  if (widget.conversation.isGroupChat) ...[
                    const SizedBox(width: 24),
                    _buildQuickActionButton(
                      context: context,
                      theme: theme,
                      icon: Icons.link_rounded,
                      label: 'Ссылка',
                      onTap: () {
                        final base = OpenVKAPIService.instance.serverURL.replaceAll(RegExp(r'/+$'), '');
                        Clipboard.setData(ClipboardData(text: '$base/im?sel=${widget.conversation.peerId}'));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Ссылка на беседу скопирована')),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Tab Bar
            if (widget.conversation.isGroupChat)
              Container(
                height: 36,
                decoration: BoxDecoration(
                  color: theme.getSecondarySurfaceColor(context),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: TabBar(
                  controller: _tabController,
                  dividerColor: Colors.transparent,
                  dividerHeight: 0,
                  indicator: BoxDecoration(
                    color: theme.accentColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: Colors.white,
                  unselectedLabelColor: theme.getSecondaryTextColor(context),
                  labelStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                  unselectedLabelStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.normal),
                  tabs: [
                    Tab(text: 'Участники (${_members.isNotEmpty ? _members.length : (widget.conversation.membersCount > 0 ? widget.conversation.membersCount : "")})'),
                    Tab(text: 'Материалы ($totalMaterials)'),
                  ],
                ),
              ),
            const SizedBox(height: 10),

            // Tab Content
            Expanded(
              child: widget.conversation.isGroupChat
                  ? TabBarView(
                      controller: _tabController,
                      children: [
                        _buildMembersTab(context, theme, store),
                        _buildMaterialsTab(context, theme),
                      ],
                    )
                  : _buildMaterialsTab(context, theme),
            ),

            // Bottom Actions (Leave chat)
            if (widget.conversation.isGroupChat)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    store.leaveChat(widget.conversation.peerId);
                    Navigator.pop(context);
                  },
                  child: Container(
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.exit_to_app_rounded, color: Colors.red, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Покинуть беседу',
                          style: TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionButton({
    required BuildContext context,
    required ThemeManager theme,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: theme.accentColor.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: theme.accentColor, size: 20),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: theme.getTextColor(context),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMembersTab(BuildContext context, ThemeManager theme, MessengerStore store) {
    if (_loadingMembers) {
      return const Center(child: CircularProgressIndicator());
    }

    final filtered = _members.where((m) {
      if (_memberSearchQuery.isEmpty) return true;
      final u = m['user'] as VKUser?;
      final name = u?.fullName.toLowerCase() ?? 'id${m['memberId']}';
      return name.contains(_memberSearchQuery.toLowerCase());
    }).toList();

    return Column(
      children: [
        // Member search field
        Container(
          height: 32,
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            color: theme.getSecondarySurfaceColor(context),
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextField(
            controller: _memberSearchController,
            style: TextStyle(color: theme.getTextColor(context), fontSize: 12.5),
            decoration: InputDecoration(
              hintText: 'Поиск участников...',
              hintStyle: TextStyle(color: theme.getSecondaryTextColor(context), fontSize: 12.5),
              prefixIcon: Icon(Icons.search, size: 16, color: theme.getSecondaryTextColor(context)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 7),
              isDense: true,
            ),
            onChanged: (val) => setState(() => _memberSearchQuery = val),
          ),
        ),

        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    _memberSearchQuery.isEmpty ? 'Список участников пуст' : 'Участники не найдены',
                    style: TextStyle(color: theme.getSecondaryTextColor(context), fontSize: 13),
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: filtered.length,
                  itemBuilder: (ctx, idx) {
                    final item = filtered[idx];
                    final user = item['user'] as VKUser?;
                    final isOwner = item['isOwner'] == true;
                    final isAdmin = item['isAdmin'] == true;
                    final memberId = item['memberId'] as int;
                    final isSelf = user?.id == store.activeAccount?.userId;

                    String roleSubtitle;
                    Color roleColor;
                    if (isOwner) {
                      roleSubtitle = 'Создатель';
                      roleColor = const Color(0xFF4BB34B);
                    } else if (isAdmin) {
                      roleSubtitle = 'Администратор';
                      roleColor = const Color(0xFF4BB34B);
                    } else {
                      roleSubtitle = (user?.isOnline == true) ? 'в сети' : 'был(а) недавно';
                      roleColor = theme.getSecondaryTextColor(context);
                    }

                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                      leading: VKAvatar(
                        url: user?.avatarUrl,
                        name: user?.fullName ?? 'id$memberId',
                        size: 36,
                        isOnline: user?.isOnline ?? false,
                      ),
                      title: Text(
                        user?.fullName ?? 'id$memberId',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: theme.getTextColor(context),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        roleSubtitle,
                        style: TextStyle(
                          color: roleColor,
                          fontSize: 11,
                          fontWeight: (isOwner || isAdmin) ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                      trailing: (!isSelf && !isOwner)
                          ? IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                              icon: const Icon(Icons.person_remove_outlined, size: 17, color: Colors.red),
                              tooltip: 'Исключить из беседы',
                              onPressed: () {
                                store.removeChatMember(widget.conversation.peerId, memberId);
                                setState(() {
                                  _members.removeWhere((x) => x['memberId'] == memberId);
                                });
                              },
                            )
                          : null,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildMaterialsTab(BuildContext context, ThemeManager theme) {
    final subCounts = [
      _materialsPhotos.length,
      _materialsVideos.length,
      _materialsAudio.length,
      _materialsDocs.length,
    ];

    return Column(
      children: [
        // Sub-tabs row: [Фото (count), Видео (count), Аудио (count), Файлы (count)]
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(_materialTitles.length, (idx) {
              final isSel = _selectedMaterialIndex == idx;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => setState(() => _selectedMaterialIndex = idx),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isSel ? theme.accentColor.withValues(alpha: 0.15) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: isSel ? Border.all(color: theme.accentColor, width: 1) : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _materialIcons[idx],
                          size: 14,
                          color: isSel ? theme.accentColor : theme.getSecondaryTextColor(context),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${_materialTitles[idx]} (${subCounts[idx]})',
                          style: TextStyle(
                            color: isSel ? theme.accentColor : theme.getSecondaryTextColor(context),
                            fontSize: 11.5,
                            fontWeight: isSel ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 10),

        Expanded(
          child: _loadingMaterials && !_hasLoadedMaterials
              ? const Center(child: CircularProgressIndicator())
              : _buildSubTabContent(theme),
        ),
      ],
    );
  }

  Widget _buildSubTabContent(ThemeManager theme) {
    switch (_selectedMaterialIndex) {
      case 0:
        // Photos
        if (_materialsPhotos.isEmpty) {
          return _buildEmptyState(Icons.photo_outlined, 'Нет фотографий', 'В этой беседе пока нет отправленных фотографий', theme);
        }
        return GridView.builder(
          padding: EdgeInsets.zero,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 6,
            mainAxisSpacing: 6,
            childAspectRatio: 1.0,
          ),
          itemCount: _materialsPhotos.length,
          itemBuilder: (ctx, idx) {
            final item = _materialsPhotos[idx];
            return InkWell(
              onTap: () => _openPhotoAt(idx),
              borderRadius: BorderRadius.circular(8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: item.thumbnailURL ?? '',
                  fit: BoxFit.cover,
                  placeholder: (ctx, url) => Container(color: theme.getSecondarySurfaceColor(context)),
                  errorWidget: (ctx, url, err) => Container(
                    color: theme.getSecondarySurfaceColor(context),
                    child: const Icon(Icons.broken_image, size: 24),
                  ),
                ),
              ),
            );
          },
        );

      case 1:
        // Videos
        if (_materialsVideos.isEmpty) {
          return _buildEmptyState(Icons.videocam_outlined, 'Нет видеозаписей', 'В этой беседе пока нет отправленных видео', theme);
        }
        return ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: _materialsVideos.length,
          itemBuilder: (ctx, idx) {
            final item = _materialsVideos[idx];
            return ListTile(
              dense: true,
              onTap: () => _openUrl(item.contentURL),
              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              leading: Container(
                width: 44,
                height: 34,
                decoration: BoxDecoration(
                  color: theme.getSecondarySurfaceColor(context),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: item.thumbnailURL != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: CachedNetworkImage(imageUrl: item.thumbnailURL!, fit: BoxFit.cover),
                      )
                    : Icon(Icons.play_circle_outline, color: theme.accentColor, size: 20),
              ),
              title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.getTextColor(context), fontSize: 13)),
              subtitle: Text(item.subtitle, style: TextStyle(color: theme.getSecondaryTextColor(context), fontSize: 11)),
              trailing: Icon(Icons.open_in_new, size: 16, color: theme.getSecondaryTextColor(context)),
            );
          },
        );

      case 2:
        // Audio
        if (_materialsAudio.isEmpty) {
          return _buildEmptyState(Icons.music_note_outlined, 'Нет аудиозаписей', 'В этой беседе пока нет отправленной музыки', theme);
        }
        return ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: _materialsAudio.length,
          itemBuilder: (ctx, idx) {
            final item = _materialsAudio[idx];
            return ListTile(
              dense: true,
              onTap: () => _openUrl(item.contentURL),
              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              leading: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: theme.accentColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.music_note, color: theme.accentColor, size: 18),
              ),
              title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.getTextColor(context), fontSize: 13, fontWeight: FontWeight.w500)),
              subtitle: Text(item.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.getSecondaryTextColor(context), fontSize: 11)),
              trailing: item.contentURL != null
                  ? Icon(Icons.play_arrow_rounded, color: theme.accentColor, size: 22)
                  : null,
            );
          },
        );

      case 3:
      default:
        // Docs / Files
        if (_materialsDocs.isEmpty) {
          return _buildEmptyState(Icons.insert_drive_file_outlined, 'Нет файлов', 'В этой беседе пока нет документов или файлов', theme);
        }
        return ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: _materialsDocs.length,
          itemBuilder: (ctx, idx) {
            final item = _materialsDocs[idx];
            return ListTile(
              dense: true,
              onTap: () => _openUrl(item.contentURL),
              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              leading: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: theme.getSecondarySurfaceColor(context),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Icons.description_outlined, color: theme.accentColor, size: 18),
              ),
              title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.getTextColor(context), fontSize: 13, fontWeight: FontWeight.w500)),
              subtitle: Text(item.subtitle, style: TextStyle(color: theme.getSecondaryTextColor(context), fontSize: 11)),
              trailing: Icon(Icons.download_rounded, color: theme.accentColor, size: 18),
            );
          },
        );
    }
  }

  Widget _buildEmptyState(IconData icon, String title, String subtitle, ThemeManager theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: theme.getSecondaryTextColor(context).withValues(alpha: 0.5)),
          const SizedBox(height: 10),
          Text(title, style: TextStyle(color: theme.getTextColor(context), fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: theme.getSecondaryTextColor(context), fontSize: 12)),
        ],
      ),
    );
  }
}
