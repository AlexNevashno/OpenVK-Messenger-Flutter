import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/user.dart';
import '../../services/messenger_store.dart';
import '../../services/openvk_api.dart';
import '../../services/theme_manager.dart';
import '../widgets/avatar.dart';

class NewMessageDialog extends StatefulWidget {
  const NewMessageDialog({super.key});

  @override
  State<NewMessageDialog> createState() => _NewMessageDialogState();
}

class _NewMessageDialogState extends State<NewMessageDialog> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _groupTitleController = TextEditingController();

  bool _isCreatingGroup = false;
  final Set<int> _selectedUserIds = {};
  List<VKUser> _friends = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _groupTitleController.dispose();
    super.dispose();
  }

  Future<void> _loadFriends() async {
    setState(() => _loading = true);
    final users = await OpenVKAPIService.instance.getFriends();
    if (mounted) {
      setState(() {
        _friends = users;
        _loading = false;
      });
    }
  }

  Future<void> _onSearch(String query) async {
    if (query.trim().isEmpty) {
      _loadFriends();
      return;
    }
    setState(() => _loading = true);
    final results = await OpenVKAPIService.instance.searchUsers(query: query.trim());
    if (mounted) {
      setState(() {
        _friends = results;
        _loading = false;
      });
    }
  }

  Future<void> _createGroup(MessengerStore store) async {
    final title = _groupTitleController.text.trim();
    if (title.isEmpty || _selectedUserIds.isEmpty) return;

    final peerId = await store.createGroupChat(_selectedUserIds.toList(), title);
    if (peerId != null && mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeManager>();
    final store = context.watch<MessengerStore>();

    return Dialog(
      backgroundColor: theme.getSurfaceColor(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 460,
        height: 560,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _isCreatingGroup ? 'Новая беседа' : 'Новое сообщение',
                  style: TextStyle(
                    color: theme.getTextColor(context),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Mode switch
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: Icon(_isCreatingGroup ? Icons.person : Icons.group_add, size: 18),
                    label: Text(_isCreatingGroup ? 'Личное сообщение' : 'Создать беседу'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.accentColor,
                      side: BorderSide(color: theme.accentColor),
                    ),
                    onPressed: () {
                      setState(() {
                        _isCreatingGroup = !_isCreatingGroup;
                        _selectedUserIds.clear();
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Group title field (if creating group)
            if (_isCreatingGroup) ...[
              TextField(
                controller: _groupTitleController,
                style: TextStyle(color: theme.getTextColor(context), fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Название беседы...',
                  hintStyle: TextStyle(color: theme.getSecondaryTextColor(context)),
                  filled: true,
                  fillColor: theme.getSecondarySurfaceColor(context),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
            ],

            // Search Bar
            TextField(
              controller: _searchController,
              style: TextStyle(color: theme.getTextColor(context), fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Поиск друзей или пользователей...',
                hintStyle: TextStyle(color: theme.getSecondaryTextColor(context)),
                prefixIcon: const Icon(Icons.search, size: 18),
                filled: true,
                fillColor: theme.getSecondarySurfaceColor(context),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                isDense: true,
              ),
              onChanged: _onSearch,
            ),
            const SizedBox(height: 10),

            // Friends / Search Results List
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _friends.isEmpty
                      ? Center(
                          child: Text(
                            'Пользователи не найдены',
                            style: TextStyle(color: theme.getSecondaryTextColor(context)),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _friends.length,
                          itemBuilder: (ctx, idx) {
                            final user = _friends[idx];
                            final isSelected = _selectedUserIds.contains(user.id);

                            return ListTile(
                              dense: true,
                              leading: VKAvatar(
                                url: user.avatarUrl,
                                name: user.fullName,
                                size: 36,
                                isOnline: user.isOnline,
                              ),
                              title: Text(
                                user.fullName,
                                style: TextStyle(
                                  color: theme.getTextColor(context),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              subtitle: Text(
                                user.isOnline ? 'в сети' : 'был(а) недавно',
                                style: TextStyle(
                                  color: user.isOnline ? theme.accentColor : theme.getSecondaryTextColor(context),
                                  fontSize: 11,
                                ),
                              ),
                              trailing: _isCreatingGroup
                                  ? Checkbox(
                                      value: isSelected,
                                      activeColor: theme.accentColor,
                                      onChanged: (val) {
                                        setState(() {
                                          if (val == true) {
                                            _selectedUserIds.add(user.id);
                                          } else {
                                            _selectedUserIds.remove(user.id);
                                          }
                                        });
                                      },
                                    )
                                  : null,
                              onTap: () {
                                if (_isCreatingGroup) {
                                  setState(() {
                                    if (isSelected) {
                                      _selectedUserIds.remove(user.id);
                                    } else {
                                      _selectedUserIds.add(user.id);
                                    }
                                  });
                                } else {
                                  // Open 1-on-1 chat
                                  Navigator.pop(context);
                                  store.selectConversation(user.id);
                                }
                              },
                            );
                          },
                        ),
            ),

            // Create Group Button
            if (_isCreatingGroup)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.accentColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _selectedUserIds.isNotEmpty && _groupTitleController.text.trim().isNotEmpty
                        ? () => _createGroup(store)
                        : null,
                    child: Text('Создать беседу (${_selectedUserIds.length})'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
