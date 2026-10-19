import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class PhotoViewerItem {
  final String id;
  final String url;
  final String? localPath;
  final String caption;
  final String authorName;
  final DateTime? date;

  PhotoViewerItem({
    String? id,
    required this.url,
    this.localPath,
    this.caption = '',
    this.authorName = '',
    this.date,
  }) : id = id ?? url;
}

class PhotoViewerDialog extends StatefulWidget {
  final List<PhotoViewerItem> items;
  final int initialIndex;

  const PhotoViewerDialog({
    super.key,
    required this.items,
    this.initialIndex = 0,
  });

  static Future<void> show(
    BuildContext context, {
    required List<PhotoViewerItem> items,
    int initialIndex = 0,
  }) {
    return showDialog(
      context: context,
      barrierColor: Colors.black,
      builder: (ctx) => PhotoViewerDialog(
        items: items,
        initialIndex: initialIndex,
      ),
    );
  }

  // Convenience constructor for single photo
  PhotoViewerDialog.single({
    super.key,
    required String imageUrl,
    String? title,
    DateTime? date,
    String? authorName,
  })  : items = [
          PhotoViewerItem(
            id: imageUrl,
            url: imageUrl,
            caption: title ?? '',
            authorName: authorName ?? '',
            date: date,
          ),
        ],
        initialIndex = 0;

  @override
  State<PhotoViewerDialog> createState() => _PhotoViewerDialogState();
}

class _PhotoViewerDialogState extends State<PhotoViewerDialog> {
  late int _currentIndex;
  final TransformationController _transformationController = TransformationController();
  bool _isZoomed = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.items.isEmpty ? 0 : widget.items.length - 1);
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
    setState(() => _isZoomed = false);
  }

  void _toggleZoom() {
    if (_isZoomed) {
      _resetZoom();
    } else {
      _transformationController.value = Matrix4.diagonal3Values(2.0, 2.0, 1.0);
      setState(() => _isZoomed = true);
    }
  }

  void _prev() {
    if (_currentIndex > 0) {
      _resetZoom();
      setState(() => _currentIndex--);
    }
  }

  void _next() {
    if (_currentIndex < widget.items.length - 1) {
      _resetZoom();
      setState(() => _currentIndex++);
    }
  }

  Future<void> _savePhoto(BuildContext context, PhotoViewerItem item) async {
    try {
      Uint8List bytes;
      if (item.localPath != null && File(item.localPath!).existsSync()) {
        bytes = await File(item.localPath!).readAsBytes();
      } else {
        final res = await http.get(Uri.parse(item.url));
        if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
        bytes = res.bodyBytes;
      }

      final uri = await FilePicker.saveFile(
        dialogTitle: 'Сохранить изображение',
        fileName: 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg',
        bytes: bytes,
      );
      if (uri != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Изображение сохранено')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка сохранения: $e')),
        );
      }
    }
  }

  Future<void> _copyPhoto(BuildContext context, PhotoViewerItem item) async {
    try {
      await Clipboard.setData(ClipboardData(text: item.url));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ссылка на фото скопирована'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {}
  }

  Widget _buildActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 0.8,
            ),
          ),
          child: Icon(
            icon,
            size: 15,
            color: Colors.white.withValues(alpha: 0.95),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return const SizedBox();
    }

    final item = widget.items[_currentIndex];
    final dateStr = item.date != null ? DateFormat('d MMM, HH:mm').format(item.date!) : '';

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            _prev();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            _next();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.escape) {
            Navigator.pop(context);
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Center Zoomable Image (padded from top and bottom bars)
            Padding(
              padding: const EdgeInsets.only(top: 40, bottom: 74),
              child: Center(
                child: GestureDetector(
                onDoubleTap: _toggleZoom,
                child: InteractiveViewer(
                  transformationController: _transformationController,
                  minScale: 0.5,
                  maxScale: 5.0,
                  onInteractionEnd: (_) {
                    final scale = _transformationController.value.getMaxScaleOnAxis();
                    if (scale > 1.05 != _isZoomed) {
                      setState(() => _isZoomed = scale > 1.05);
                    }
                  },
                  child: item.localPath != null && File(item.localPath!).existsSync()
                      ? Image.file(File(item.localPath!), fit: BoxFit.contain)
                      : CachedNetworkImage(
                          imageUrl: item.url,
                          fit: BoxFit.contain,
                          placeholder: (ctx, url) => const Center(
                            child: CircularProgressIndicator(color: Colors.white),
                          ),
                          errorWidget: (ctx, url, err) => const Center(
                            child: Icon(Icons.broken_image, size: 64, color: Colors.white54),
                          ),
                        ),
                ),
              ),
            ),
            ),

            // Navigation Left Button (<)
            if (_currentIndex > 0)
              Positioned(
                left: 16,
                top: 0,
                bottom: 0,
                child: Center(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: _prev,
                    child: Container(
                      width: 44,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 36),
                    ),
                  ),
                ),
              ),

            // Navigation Right Button (>)
            if (_currentIndex < widget.items.length - 1)
              Positioned(
                right: 16,
                top: 0,
                bottom: 0,
                child: Center(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: _next,
                    child: Container(
                      width: 44,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 36),
                    ),
                  ),
                ),
              ),

            // macOS Top Bar Gradient with Close Button
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.75),
                      Colors.black.withValues(alpha: 0.0),
                    ],
                  ),
                ),
                alignment: Alignment.centerRight,
                child: _buildActionButton(
                  icon: Icons.close_rounded,
                  tooltip: 'Закрыть (Esc)',
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),

            // macOS Bottom Info Bar (Solid dock with high contrast text)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 60,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFF161618).withValues(alpha: 0.96),
                  border: const Border(
                    top: BorderSide(color: Color(0x2EFFFFFF), width: 0.8),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black87,
                      blurRadius: 16,
                      offset: Offset(0, -4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Photo author, date & counter with crisp contrast
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item.authorName.isNotEmpty ? item.authorName : 'Фотография',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.items.length > 1 ? "Фото ${_currentIndex + 1} из ${widget.items.length}  •  " : ""}$dateStr',
                          style: const TextStyle(
                            color: Color(0xFFB8B8B8),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),

                    // Center Caption Pill
                    if (item.caption.isNotEmpty) ...[
                      const Spacer(),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                          decoration: BoxDecoration(
                            color: const Color(0xFF28282A),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.16),
                              width: 0.8,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.4),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: Text(
                            item.caption,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],

                    const Spacer(),

                    // Action buttons (Zoom, Copy, Download, Close)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildActionButton(
                          icon: _isZoomed ? Icons.zoom_out : Icons.zoom_in,
                          tooltip: 'Масштаб',
                          onPressed: _toggleZoom,
                        ),
                        const SizedBox(width: 8),
                        _buildActionButton(
                          icon: Icons.copy_rounded,
                          tooltip: 'Скопировать ссылку',
                          onPressed: () => _copyPhoto(context, item),
                        ),
                        const SizedBox(width: 8),
                        _buildActionButton(
                          icon: Icons.download_rounded,
                          tooltip: 'Сохранить на диск',
                          onPressed: () => _savePhoto(context, item),
                        ),
                        const SizedBox(width: 8),
                        _buildActionButton(
                          icon: Icons.close_rounded,
                          tooltip: 'Закрыть (Esc)',
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
