import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/audio_player_service.dart';
import '../../services/theme_manager.dart';

/// Pixel-perfect Flutter port of TelegramAudioMiniplayerView.swift
class AudioMiniplayer extends StatefulWidget {
  const AudioMiniplayer({super.key});

  @override
  State<AudioMiniplayer> createState() => _AudioMiniplayerState();
}

class _AudioMiniplayerState extends State<AudioMiniplayer> {
  bool _isDragging = false;
  double _dragFraction = 0.0;

  String _formatSeconds(int secs) {
    final m = secs ~/ 60;
    final s = secs % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<AudioPlayerService>();
    if (player.activeId == null && player.currentUrl == null) {
      return const SizedBox.shrink();
    }

    final theme = context.watch<ThemeManager>();
    final isDark = theme.isDark(context);

    final curSec = _isDragging
        ? (_dragFraction * (player.duration.inSeconds > 0 ? player.duration.inSeconds : 1)).toInt()
        : player.position.inSeconds;
    final durSec = player.duration.inSeconds;
    final timeStr = '${_formatSeconds(curSec)} / ${_formatSeconds(durSec)}';

    final progress = durSec > 0
        ? (_isDragging ? _dragFraction : (player.position.inMilliseconds / player.duration.inMilliseconds)).clamp(0.0, 1.0)
        : 0.0;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: (isDark ? const Color(0xFF1E1E1F) : Colors.white).withValues(alpha: 0.85),
            border: Border(
              bottom: BorderSide(
                color: theme.getSeparatorColor(context).withValues(alpha: 0.6),
                width: 0.8,
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: Row(
            children: [
              // Play / Pause Circle Button (matching Mac Swift)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: player.toggleCurrentPlayback,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: theme.accentColor,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: player.isLoading
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Prev Track Button (matching Mac Swift)
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                icon: Icon(
                  Icons.skip_previous_rounded,
                  size: 18,
                  color: player.hasPreviousTrack
                      ? theme.getTextColor(context)
                      : theme.getSecondaryTextColor(context).withValues(alpha: 0.35),
                ),
                tooltip: 'Предыдущий трек',
                onPressed: player.hasPreviousTrack ? player.previousTrack : null,
              ),

              // Next Track Button (matching Mac Swift)
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                icon: Icon(
                  Icons.skip_next_rounded,
                  size: 18,
                  color: player.hasNextTrack
                      ? theme.getTextColor(context)
                      : theme.getSecondaryTextColor(context).withValues(alpha: 0.35),
                ),
                tooltip: 'Следующий трек',
                onPressed: player.hasNextTrack ? player.nextTrack : null,
              ),

              const SizedBox(width: 10),

              // Track Title & Artist + Capsule Progress Scrubber
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Single row: Title — Artist
                    RichText(
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: player.currentTitle.isNotEmpty ? player.currentTitle : 'Аудиозапись',
                            style: TextStyle(
                              color: theme.getTextColor(context),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (player.currentArtist.isNotEmpty) ...[
                            TextSpan(
                              text: ' — ',
                              style: TextStyle(
                                color: theme.getSecondaryTextColor(context),
                                fontSize: 11,
                              ),
                            ),
                            TextSpan(
                              text: player.currentArtist,
                              style: TextStyle(
                                color: theme.getSecondaryTextColor(context),
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 5),

                    // Progress Scrubber Bar
                    LayoutBuilder(
                      builder: (ctx, constraints) {
                        final totalWidth = constraints.maxWidth;
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onHorizontalDragStart: (details) {
                            setState(() {
                              _isDragging = true;
                              _dragFraction = (details.localPosition.dx / totalWidth).clamp(0.0, 1.0);
                            });
                          },
                          onHorizontalDragUpdate: (details) {
                            setState(() {
                              _dragFraction = (details.localPosition.dx / totalWidth).clamp(0.0, 1.0);
                            });
                          },
                          onHorizontalDragEnd: (details) {
                            if (player.duration > Duration.zero) {
                              final targetMs = (_dragFraction * player.duration.inMilliseconds).toInt();
                              player.seek(Duration(milliseconds: targetMs));
                            }
                            setState(() {
                              _isDragging = false;
                            });
                          },
                          onTapDown: (details) {
                            if (player.duration > Duration.zero) {
                              final frac = (details.localPosition.dx / totalWidth).clamp(0.0, 1.0);
                              final targetMs = (frac * player.duration.inMilliseconds).toInt();
                              player.seek(Duration(milliseconds: targetMs));
                            }
                          },
                          child: Container(
                            height: 10,
                            alignment: Alignment.center,
                            child: Stack(
                              children: [
                                // Background track
                                Container(
                                  height: 3,
                                  decoration: BoxDecoration(
                                    color: theme.getSeparatorColor(context).withValues(alpha: 0.8),
                                    borderRadius: BorderRadius.circular(1.5),
                                  ),
                                ),
                                // Active progress
                                FractionallySizedBox(
                                  widthFactor: progress,
                                  child: Container(
                                    height: 3,
                                    decoration: BoxDecoration(
                                      color: theme.accentColor,
                                      borderRadius: BorderRadius.circular(1.5),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // Time Display (monospaced)
              Text(
                timeStr,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  color: theme.getSecondaryTextColor(context),
                ),
              ),

              const SizedBox(width: 10),

              // Close Button (✕ circle)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: player.stop,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: theme.getSecondarySurfaceColor(context).withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.close_rounded,
                      size: 13,
                      color: theme.getSecondaryTextColor(context),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
