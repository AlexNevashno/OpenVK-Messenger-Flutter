import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/openvk_api.dart';
import '../../services/theme_manager.dart';

class MediaAttachDialog extends StatefulWidget {
  final Function(File file, bool isPhoto) onFileSelected;
  final Function(String attachmentCode, {String? type, String? title, String? thumbnailUrl, String? subtitle}) onInstanceMediaSelected;

  const MediaAttachDialog({
    super.key,
    required this.onFileSelected,
    required this.onInstanceMediaSelected,
  });

  @override
  State<MediaAttachDialog> createState() => _MediaAttachDialogState();
}

class _MediaAttachDialogState extends State<MediaAttachDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _tabs = ['Фото', 'Видео', 'Аудио', 'Документы'];
  final List<String> _mediaTypes = ['photo', 'video', 'audio', 'doc'];

  bool _loading = false;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _loadMedia(_mediaTypes[_tabController.index]);
      }
    });
    _loadMedia(_mediaTypes[0]);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMedia(String type) async {
    setState(() => _loading = true);
    final results = await OpenVKAPIService.instance.getUserMedia(type: type);
    if (mounted) {
      setState(() {
        _items = results;
        _loading = false;
      });
    }
  }

  Future<void> _pickFromPC() async {
    final res = await FilePicker.pickFiles(type: FileType.any);
    if (res.isNotEmpty && mounted) {
      Navigator.pop(context);
      for (final f in res) {
        if (f.path != null) {
          final file = File(f.path!);
          final isPhoto = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heic'].contains(f.extension?.toLowerCase());
          widget.onFileSelected(file, isPhoto);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeManager>();

    return Dialog(
      backgroundColor: theme.getSurfaceColor(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 520,
        height: 560,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Прикрепить медиа',
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

            // Quick actions: From PC & Photos
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: _pickFromPC,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: theme.getSecondarySurfaceColor(context),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.computer, color: theme.accentColor, size: 22),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'С компьютера',
                                style: TextStyle(
                                  color: theme.getTextColor(context),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                'Выбрать любой файл или фото',
                                style: TextStyle(
                                  color: theme.getSecondaryTextColor(context),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Tab bar for account media
            TabBar(
              controller: _tabController,
              indicatorColor: theme.accentColor,
              labelColor: theme.accentColor,
              unselectedLabelColor: theme.getSecondaryTextColor(context),
              tabs: _tabs.map((t) => Tab(text: t)).toList(),
            ),

            // Tab content
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _items.isEmpty
                      ? Center(
                          child: Text(
                            'В вашем профиле нет материалов этого типа',
                            style: TextStyle(color: theme.getSecondaryTextColor(context)),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _items.length,
                          itemBuilder: (ctx, idx) {
                            final item = _items[idx];
                            final title = item['title']?.toString() ?? item['text']?.toString() ?? 'Материал ${idx + 1}';
                            final ownerId = item['owner_id'] ?? 0;
                            final id = item['id'] ?? 0;
                            final type = _mediaTypes[_tabController.index];
                            final attachCode = '$type${ownerId}_$id';

                            String? thumbUrl;
                            if (type == 'photo') {
                              thumbUrl = item['photo_130'] ?? item['photo_75'] ?? item['photo_604'] ?? item['url'];
                            } else if (type == 'video') {
                              thumbUrl = item['photo_320'] ?? item['photo_130'] ?? (item['image'] is List && (item['image'] as List).isNotEmpty ? item['image'].last['url'] : null);
                            }
                            if (thumbUrl != null && !thumbUrl.startsWith('http')) {
                              final base = OpenVKAPIService.instance.serverURL.replaceAll(RegExp(r'/+$'), '');
                              final clean = thumbUrl.replaceAll(RegExp(r'^/+'), '');
                              thumbUrl = '$base/$clean';
                            }
                            String? subtitle;
                            if (type == 'audio') {
                              final artist = item['artist']?.toString() ?? '';
                              subtitle = artist;
                            }

                            return ListTile(
                              dense: true,
                              leading: Icon(
                                type == 'photo'
                                    ? Icons.photo
                                    : (type == 'video' ? Icons.videocam : (type == 'audio' ? Icons.music_note : Icons.insert_drive_file)),
                                color: theme.accentColor,
                              ),
                              title: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: theme.getTextColor(context)),
                              ),
                              subtitle: subtitle != null ? Text(subtitle, style: TextStyle(fontSize: 11, color: theme.getSecondaryTextColor(context))) : null,
                              trailing: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.accentColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                ),
                                onPressed: () {
                                  Navigator.pop(context);
                                  widget.onInstanceMediaSelected(
                                    attachCode,
                                    type: type,
                                    title: title,
                                    thumbnailUrl: thumbUrl,
                                    subtitle: subtitle,
                                  );
                                },
                                child: const Text('Прикрепить', style: TextStyle(fontSize: 12)),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
