import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/messenger_store.dart';
import '../../services/theme_manager.dart';
import '../modals/account_bank_dialog.dart';
import '../modals/community_messages_dialog.dart';
import '../modals/folder_manager_dialog.dart';
import '../modals/new_message_dialog.dart';
import '../widgets/chat_folders_rail.dart';
import 'chat_view.dart';
import 'conversations_sidebar_view.dart';
import 'login_view.dart';
import 'settings_dialog.dart';

class MainDesktopView extends StatefulWidget {
  const MainDesktopView({super.key});

  @override
  State<MainDesktopView> createState() => _MainDesktopViewState();
}

class _MainDesktopViewState extends State<MainDesktopView> {
  bool _showAddAccountDialog = false;

  void _openSettings() {
    showDialog(
      context: context,
      builder: (ctx) => const SettingsDialog(),
    );
  }

  void _openAddAccount() {
    setState(() => _showAddAccountDialog = true);
  }

  void _openFolderManager() {
    showDialog(
      context: context,
      builder: (ctx) => const FolderManagerDialog(),
    );
  }

  void _openAccountBank() {
    showDialog(
      context: context,
      builder: (ctx) => AccountBankDialog(
        onAddAccount: _openAddAccount,
      ),
    );
  }

  void _openCommunityManager() {
    showDialog(
      context: context,
      builder: (ctx) => const CommunityMessagesDialog(),
    );
  }

  void _openNewMessage() {
    showDialog(
      context: context,
      builder: (ctx) => const NewMessageDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MessengerStore>();
    final theme = context.watch<ThemeManager>();

    // If no accounts logged in, show Login Screen
    if (store.accounts.isEmpty || _showAddAccountDialog) {
      return Scaffold(
        body: Stack(
          children: [
            LoginView(
              onLoginSuccess: () {
                setState(() => _showAddAccountDialog = false);
              },
            ),
            if (_showAddAccountDialog && store.accounts.isNotEmpty)
              Positioned(
                top: 24,
                left: 24,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Назад к моим чатам',
                  onPressed: () {
                    setState(() => _showAddAccountDialog = false);
                  },
                ),
              ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          // Column 1: Left Narrow Folder Rail (68px wide)
          ChatFoldersRail(
            onOpenFolderManager: _openFolderManager,
            onOpenAccountBank: _openAccountBank,
            onOpenCommunityManager: _openCommunityManager,
          ),

          // 1px Vertical Separator
          VerticalDivider(
            width: 1,
            thickness: 1,
            color: theme.getSeparatorColor(context),
          ),

          // Column 2: Conversations Sidebar (300px wide)
          ConversationsSidebarView(
            onOpenSettings: _openSettings,
            onOpenNewMessage: _openNewMessage,
            onOpenLogin: _openAddAccount,
          ),

          // 1px Vertical Separator
          VerticalDivider(
            width: 1,
            thickness: 1,
            color: theme.getSeparatorColor(context),
          ),

          // Column 3: Chat Content Area
          const Expanded(
            child: ChatView(),
          ),
        ],
      ),
    );
  }
}
