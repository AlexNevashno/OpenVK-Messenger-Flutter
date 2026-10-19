import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/conversation.dart';
import '../../services/messenger_store.dart';
import '../../services/theme_manager.dart';
import '../modals/folder_manager_dialog.dart';
import '../widgets/avatar.dart';

class ChatFoldersRail extends StatelessWidget {
  final VoidCallback onOpenFolderManager;
  final VoidCallback onOpenAccountBank;
  final VoidCallback onOpenCommunityManager;

  const ChatFoldersRail({
    super.key,
    required this.onOpenFolderManager,
    required this.onOpenAccountBank,
    required this.onOpenCommunityManager,
  });

  IconData _getFolderIcon(String iconName) {
    switch (iconName) {
      case 'person':
        return Icons.person_rounded;
      case 'bubbles':
      case 'groups':
        return Icons.chat_bubble_rounded;
      case 'briefcase':
      case 'work':
        return Icons.work_rounded;
      case 'star':
        return Icons.star_rounded;
      case 'heart':
      case 'favorite':
        return Icons.favorite_rounded;
      case 'game':
        return Icons.sports_esports_rounded;
      case 'music':
        return Icons.music_note_rounded;
      case 'film':
        return Icons.movie_rounded;
      case 'newspaper':
        return Icons.newspaper_rounded;
      case 'tag':
        return Icons.local_offer_rounded;
      case 'bell':
        return Icons.notifications_rounded;
      default:
        return Icons.folder_rounded;
    }
  }

  void _showFolderContextMenu(BuildContext context, MessengerStore store, VKChatFolder folder) {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(folder.name),
        children: [
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(ctx);
              showDialog(
                context: context,
                builder: (_) => FolderManagerDialog(initialFolder: folder),
              );
            },
            child: const Row(
              children: [
                Icon(Icons.edit_outlined, size: 18),
                SizedBox(width: 10),
                Text('Редактировать папку'),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(ctx);
              store.deleteFolder(folder.id);
            },
            child: const Row(
              children: [
                Icon(Icons.delete_outline, size: 18, color: Colors.red),
                SizedBox(width: 10),
                Text('Удалить папку', style: TextStyle(color: Colors.red)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MessengerStore>();
    final theme = context.watch<ThemeManager>();

    final railColor = theme.getFoldersSidebarColor(context);

    return Container(
      width: 68,
      color: railColor,
      child: Column(
        children: [
          const SizedBox(height: 8),

          // Scrollable folder buttons
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              children: [
                // 1. "All Chats" button
                _buildFolderItem(
                  context: context,
                  theme: theme,
                  icon: Icons.chat_bubble_rounded,
                  title: 'Все чаты',
                  badgeCount: store.totalUnreadCount,
                  isSelected: store.selectedFolderId == null,
                  onTap: () => store.selectFolder(null),
                ),
                const SizedBox(height: 6),

                // 2. Custom User Folders (matching Mac Swift)
                ...store.folders.map((folder) {
                  final isSelected = store.selectedFolderId == folder.id;
                  final badge = store.unreadCountForFolder(folder);
                  final iconData = _getFolderIcon(folder.icon);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: _buildFolderItem(
                      context: context,
                      theme: theme,
                      icon: iconData,
                      title: folder.name,
                      badgeCount: badge,
                      isSelected: isSelected,
                      onTap: () => store.selectFolder(folder.id),
                      onSecondaryTap: () => _showFolderContextMenu(context, store, folder),
                    ),
                  );
                }),
              ],
            ),
          ),

          Divider(height: 1, color: theme.getSeparatorColor(context).withValues(alpha: 0.6)),

          // Bottom Action Dock (Folder Settings, User Profile)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [

                // 2. Folder settings button
                Tooltip(
                  message: 'Управление папками',
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 44, minHeight: 28),
                    icon: Icon(
                      Icons.tune_rounded,
                      color: theme.getSecondaryTextColor(context),
                      size: 19,
                    ),
                    onPressed: onOpenFolderManager,
                  ),
                ),

                const SizedBox(height: 4),

                // 3. User Avatar / Account Bank button
                Tooltip(
                  message: 'Банк аккаунтов (${store.activeAccount?.name ?? "Вы"})',
                  child: GestureDetector(
                    onTap: onOpenAccountBank,
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        VKAvatar(
                          url: store.activeAccount?.avatarUrl,
                          name: store.activeAccount?.name ?? 'OpenVK',
                          size: 34,
                        ),
                        Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            color: const Color(0xFF4BB34B),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: railColor,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildFolderItem({
    required BuildContext context,
    required ThemeManager theme,
    required IconData icon,
    required String title,
    required int badgeCount,
    required bool isSelected,
    required VoidCallback onTap,
    VoidCallback? onSecondaryTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      onSecondaryTap: onSecondaryTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 56,
        height: 52,
        decoration: BoxDecoration(
          color: isSelected ? theme.accentColor : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  size: 21,
                  color: isSelected ? Colors.white : theme.getSecondaryTextColor(context),
                ),
                if (badgeCount > 0)
                  Positioned(
                    right: -10,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white.withValues(alpha: 0.35) : theme.accentColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        badgeCount > 99 ? '99+' : '$badgeCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected ? Colors.white : theme.getSecondaryTextColor(context),
                fontSize: 9.5,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
