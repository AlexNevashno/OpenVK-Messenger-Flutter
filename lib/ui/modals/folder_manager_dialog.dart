import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/conversation.dart';
import '../../services/messenger_store.dart';
import '../../services/theme_manager.dart';
import '../widgets/avatar.dart';

class FolderManagerDialog extends StatefulWidget {
  final VKChatFolder? initialFolder;

  const FolderManagerDialog({
    super.key,
    this.initialFolder,
  });

  @override
  State<FolderManagerDialog> createState() => _FolderManagerDialogState();
}

class _FolderManagerDialogState extends State<FolderManagerDialog> {
  bool _isCreatingOrEditing = false;
  String? _editingId;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _chatSearchController = TextEditingController();
  String _selectedIcon = 'folder';
  final Set<int> _selectedPeerIds = {};
  String _chatSearchQuery = '';

  static const List<({String id, IconData icon})> availableIcons = [
    (id: 'folder', icon: Icons.folder_rounded),
    (id: 'person', icon: Icons.person_rounded),
    (id: 'bubbles', icon: Icons.chat_bubble_rounded),
    (id: 'briefcase', icon: Icons.work_rounded),
    (id: 'star', icon: Icons.star_rounded),
    (id: 'heart', icon: Icons.favorite_rounded),
    (id: 'game', icon: Icons.sports_esports_rounded),
    (id: 'music', icon: Icons.music_note_rounded),
    (id: 'film', icon: Icons.movie_rounded),
    (id: 'newspaper', icon: Icons.newspaper_rounded),
    (id: 'tag', icon: Icons.local_offer_rounded),
    (id: 'bell', icon: Icons.notifications_rounded),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialFolder != null) {
      _startEditing(widget.initialFolder!);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _chatSearchController.dispose();
    super.dispose();
  }

  void _startEditing(VKChatFolder folder) {
    setState(() {
      _isCreatingOrEditing = true;
      _editingId = folder.id;
      _nameController.text = folder.name;
      _selectedIcon = folder.icon;
      _selectedPeerIds.clear();
      _selectedPeerIds.addAll(folder.peerIds);
    });
  }

  void _startCreating() {
    setState(() {
      _isCreatingOrEditing = true;
      _editingId = null;
      _nameController.clear();
      _selectedIcon = 'folder';
      _selectedPeerIds.clear();
      _chatSearchQuery = '';
      _chatSearchController.clear();
    });
  }

  void _saveFolder(MessengerStore store) {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    if (_editingId != null) {
      final updated = VKChatFolder(
        id: _editingId!,
        name: name,
        icon: _selectedIcon,
        peerIds: _selectedPeerIds.toList(),
      );
      store.updateFolder(updated);
    } else {
      store.createFolder(
        name,
        icon: _selectedIcon,
        peerIds: _selectedPeerIds.toList(),
      );
    }

    setState(() {
      _isCreatingOrEditing = false;
      _editingId = null;
    });
  }

  IconData _iconForName(String name) {
    return availableIcons.firstWhere(
      (e) => e.id == name,
      orElse: () => availableIcons.first,
    ).icon;
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeManager>();
    final store = context.watch<MessengerStore>();

    return Dialog(
      backgroundColor: theme.getSurfaceColor(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 480,
        height: 540,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Modal Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _isCreatingOrEditing
                      ? (_editingId != null ? 'Редактировать папку' : 'Новая папка')
                      : 'Папки с чатами',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: theme.getTextColor(context),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: () {
                    if (_isCreatingOrEditing) {
                      setState(() {
                        _isCreatingOrEditing = false;
                        _editingId = null;
                      });
                    } else {
                      Navigator.pop(context);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            Divider(height: 1, color: theme.getSeparatorColor(context)),

            // Body
            Expanded(
              child: _isCreatingOrEditing
                  ? _buildFolderEditView(context, theme, store)
                  : _buildFolderListView(context, theme, store),
            ),
          ],
        ),
      ),
    );
  }

  // MARK: - Folder List View
  Widget _buildFolderListView(BuildContext context, ThemeManager theme, MessengerStore store) {
    return Column(
      children: [
        Expanded(
          child: store.folders.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 30),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.create_new_folder_outlined,
                          size: 48,
                          color: theme.getSecondaryTextColor(context).withValues(alpha: 0.6),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'У вас пока нет папок',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: theme.getTextColor(context),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Создайте папки для организации чатов: Личные, Работа, Беседы и т.д.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.getSecondaryTextColor(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: store.folders.length,
                  itemBuilder: (ctx, idx) {
                    final folder = store.folders[idx];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: theme.getSecondarySurfaceColor(context),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: theme.accentColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(_iconForName(folder.icon), color: theme.accentColor, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  folder.name,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: theme.getTextColor(context),
                                  ),
                                ),
                                Text(
                                  '${folder.peerIds.length} чатов',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: theme.getSecondaryTextColor(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            tooltip: 'Редактировать',
                            onPressed: () => _startEditing(folder),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                            tooltip: 'Удалить',
                            onPressed: () => store.deleteFolder(folder.id),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),

        Divider(height: 1, color: theme.getSeparatorColor(context)),
        const SizedBox(height: 12),

        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Создать папку', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.accentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _startCreating,
            ),
          ],
        ),
      ],
    );
  }

  // MARK: - Folder Edit View
  Widget _buildFolderEditView(BuildContext context, ThemeManager theme, MessengerStore store) {
    final query = _chatSearchQuery.toLowerCase();
    final filteredConversations = store.conversations.where((c) {
      if (query.isEmpty) return true;
      return c.title.toLowerCase().contains(query);
    }).toList();

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 12),
            children: [
              // Folder Name Field
              Text(
                'Название папки:',
                style: TextStyle(fontSize: 12, color: theme.getSecondaryTextColor(context), fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _nameController,
                style: TextStyle(fontSize: 13.5, color: theme.getTextColor(context)),
                decoration: InputDecoration(
                  hintText: 'Например: Работа, Друзья...',
                  hintStyle: TextStyle(fontSize: 13, color: theme.getSecondaryTextColor(context)),
                  filled: true,
                  fillColor: theme.getSecondarySurfaceColor(context),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 14),

              // Icon Selector
              Text(
                'Иконка:',
                style: TextStyle(fontSize: 12, color: theme.getSecondaryTextColor(context), fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: availableIcons.map((item) {
                    final isSelected = _selectedIcon == item.id;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => setState(() => _selectedIcon = item.id),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: isSelected ? theme.accentColor : theme.getSecondarySurfaceColor(context),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            item.icon,
                            size: 19,
                            color: isSelected ? Colors.white : theme.getSecondaryTextColor(context),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
              Divider(height: 1, color: theme.getSeparatorColor(context)),
              const SizedBox(height: 12),

              // Chat Selection Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Включённые чаты (${_selectedPeerIds.length}):',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: theme.getTextColor(context)),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Search field
              TextField(
                controller: _chatSearchController,
                style: TextStyle(fontSize: 12.5, color: theme.getTextColor(context)),
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.search, size: 16, color: theme.getSecondaryTextColor(context)),
                  hintText: 'Поиск чатов для добавления',
                  hintStyle: TextStyle(fontSize: 12, color: theme.getSecondaryTextColor(context)),
                  filled: true,
                  fillColor: theme.getSecondarySurfaceColor(context),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  isDense: true,
                ),
                onChanged: (val) => setState(() => _chatSearchQuery = val),
              ),
              const SizedBox(height: 8),

              // List of chats
              ...filteredConversations.map((conv) {
                final isIncluded = _selectedPeerIds.contains(conv.peerId);
                return InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () {
                    setState(() {
                      if (isIncluded) {
                        _selectedPeerIds.remove(conv.peerId);
                      } else {
                        _selectedPeerIds.add(conv.peerId);
                      }
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: isIncluded ? theme.accentColor.withValues(alpha: 0.1) : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        VKAvatar(
                          url: conv.photoUrl,
                          name: conv.title,
                          size: 28,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            conv.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: theme.getTextColor(context),
                              fontWeight: isIncluded ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ),
                        Icon(
                          isIncluded ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                          size: 20,
                          color: isIncluded ? theme.accentColor : theme.getSecondaryTextColor(context).withValues(alpha: 0.4),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),

        Divider(height: 1, color: theme.getSeparatorColor(context)),
        const SizedBox(height: 10),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: () {
                setState(() {
                  _isCreatingOrEditing = false;
                  _editingId = null;
                });
              },
              child: Text(
                'Отмена',
                style: TextStyle(color: theme.getSecondaryTextColor(context)),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.accentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => _saveFolder(store),
              child: const Text('Сохранить папку', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ],
        ),
      ],
    );
  }
}
