import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/messenger_store.dart';
import '../../services/theme_manager.dart';
import '../widgets/avatar.dart';

class CommunityMessagesDialog extends StatelessWidget {
  const CommunityMessagesDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeManager>();
    final store = context.watch<MessengerStore>();

    return Dialog(
      backgroundColor: theme.getSurfaceColor(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 440,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Сообщения сообществ',
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
            const SizedBox(height: 12),
            Divider(color: theme.getSeparatorColor(context)),

            // Option 1: Send from personal name
            ListTile(
              leading: Icon(Icons.person, color: theme.accentColor),
              title: const Text('От своего имени'),
              subtitle: const Text('Обычный режим отправки'),
              trailing: store.activeAdminGroup == null ? Icon(Icons.check, color: theme.accentColor) : null,
              onTap: () {
                store.switchToAdminGroup(null);
                Navigator.pop(context);
              },
            ),

            Divider(color: theme.getSeparatorColor(context)),

            // Administered groups
            Text(
              'Управляемые сообщества',
              style: TextStyle(
                color: theme.getSecondaryTextColor(context),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),

            if (store.adminGroups.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    'Вы не являетесь администратором сообществ',
                    style: TextStyle(color: theme.getSecondaryTextColor(context)),
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: store.adminGroups.length,
                  itemBuilder: (ctx, idx) {
                    final group = store.adminGroups[idx];
                    final isSelected = store.activeAdminGroup?.id == group.id;

                    return ListTile(
                      leading: VKAvatar(
                        url: group.avatarUrl,
                        name: group.name,
                        size: 36,
                      ),
                      title: Text(
                        group.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: isSelected ? Icon(Icons.check, color: theme.accentColor) : null,
                      onTap: () {
                        store.switchToAdminGroup(group);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),

            const SizedBox(height: 12),
            Divider(color: theme.getSeparatorColor(context)),

            // Filter toggle
            SwitchListTile(
              title: const Text('Фильтр: только сообщества'),
              subtitle: const Text('Показывать только чаты с сообществами'),
              value: store.isCommunityFilterActive,
              activeThumbColor: theme.accentColor,
              onChanged: (val) {
                store.setCommunityFilter(val);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
