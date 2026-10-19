import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/messenger_store.dart';
import '../../services/theme_manager.dart';
import '../widgets/avatar.dart';

class AccountBankDialog extends StatelessWidget {
  final VoidCallback onAddAccount;

  const AccountBankDialog({
    super.key,
    required this.onAddAccount,
  });

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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Банк аккаунтов',
                      style: TextStyle(
                        color: theme.getTextColor(context),
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Мгновенное переключение профилей OpenVK',
                      style: TextStyle(
                        color: theme.getSecondaryTextColor(context),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(color: theme.getSeparatorColor(context)),

            // Account List
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: store.accounts.length,
                separatorBuilder: (ctx, idx) => const SizedBox(height: 6),
                itemBuilder: (ctx, idx) {
                  final acc = store.accounts[idx];
                  final isCurrent = acc.id == store.activeAccount?.id;

                  return Container(
                    decoration: BoxDecoration(
                      color: isCurrent ? theme.accentColor.withValues(alpha: 0.12) : theme.getSecondarySurfaceColor(context),
                      borderRadius: BorderRadius.circular(10),
                      border: isCurrent ? Border.all(color: theme.accentColor, width: 1.5) : null,
                    ),
                    child: ListTile(
                      leading: VKAvatar(
                        url: acc.avatarUrl,
                        name: acc.name,
                        size: 40,
                      ),
                      title: Text(
                        acc.name,
                        style: TextStyle(
                          color: theme.getTextColor(context),
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Row(
                        children: [
                          Icon(Icons.dns, size: 11, color: theme.getSecondaryTextColor(context)),
                          const SizedBox(width: 4),
                          Text(
                            acc.serverURL.replaceAll('https://', ''),
                            style: TextStyle(
                              color: theme.getSecondaryTextColor(context),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isCurrent)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4BB34B).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircleAvatar(radius: 3, backgroundColor: Color(0xFF4BB34B)),
                                  SizedBox(width: 4),
                                  Text(
                                    'Активен',
                                    style: TextStyle(
                                      color: Color(0xFF4BB34B),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                              tooltip: 'Удалить аккаунт',
                              onPressed: () {
                                store.logout(acc);
                              },
                            ),
                        ],
                      ),
                      onTap: () {
                        if (!isCurrent) {
                          store.switchAccount(acc);
                          Navigator.pop(context);
                        }
                      },
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 12),
            Divider(color: theme.getSeparatorColor(context)),
            const SizedBox(height: 8),

            // Add Account Button
            SizedBox(
              width: double.infinity,
              height: 42,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Добавить аккаунт...'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.accentColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  onAddAccount();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
