import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../../models/attachment.dart';
import '../../services/audio_player_service.dart';
import '../../services/memory_manager.dart';
import '../../services/openvk_api.dart';

class VKVideoPlayerDialog extends StatefulWidget {
  final VKVideoAttachment video;

  const VKVideoPlayerDialog({
    super.key,
    required this.video,
  });

  static Future<void> show(BuildContext context, {required VKVideoAttachment video}) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.88),
      builder: (ctx) => VKVideoPlayerDialog(video: video),
    );
  }

  @override
  State<VKVideoPlayerDialog> createState() => _VKVideoPlayerDialogState();
}

class _VKVideoPlayerDialogState extends State<VKVideoPlayerDialog> {
  VideoPlayerController? _controller;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  String _statusText = 'Загрузка видео...';
  bool _showControls = true;
  Timer? _hideControlsTimer;
  double _volume = 1.0;
  bool _isMuted = false;
  bool _isLooping = false;
  bool _isSeeking = false;
  double _seekPositionSec = 0;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    try {
      AudioPlayerService.instance.pause();
    } catch (_) {}
    _initPlayer();
  }

  static Future<void> _fixMp3AudioInMp4(File file) async {
    try {
      if (!await file.exists() || await file.length() < 64) return;
      final bytes = await file.readAsBytes();
      bool modified = false;

      // Scan for 'mp4a' FourCC in stsd
      for (int i = 0; i < bytes.length - 30; i++) {
        if (bytes[i] == 0x6d &&
            bytes[i + 1] == 0x70 &&
            bytes[i + 2] == 0x34 &&
            bytes[i + 3] == 0x61) {
          // Check for 'esds' atom within next 120 bytes
          final limit = (i + 120 < bytes.length) ? i + 120 : bytes.length;
          for (int j = i + 4; j < limit - 8; j++) {
            if (bytes[j] == 0x65 &&
                bytes[j + 1] == 0x73 &&
                bytes[j + 2] == 0x64 &&
                bytes[j + 3] == 0x73) {
              // Found 'esds'. Search for DecoderConfigDescriptor tag 0x04
              for (int k = j + 4; k < limit - 4; k++) {
                if (bytes[k] == 0x04) {
                  int p = k + 1;
                  // skip ASN.1 / MPEG-4 variable-length length bytes (0x80..0x82)
                  while (p < limit && (bytes[p] == 0x80 || bytes[p] == 0x81 || bytes[p] == 0x82)) {
                    p++;
                  }
                  p++; // skip length byte
                  if (p < limit && bytes[p] == 0x6b) {
                    // ObjectType 0x6b is MP3! Apple AVFoundation drops mp4a with 0x6b,
                    // but fully supports .mp3 fourcc. Replace 'mp4a' with '.mp3'.
                    bytes[i] = 0x2e; // '.'
                    bytes[i + 1] = 0x6d; // 'm'
                    bytes[i + 2] = 0x70; // 'p'
                    bytes[i + 3] = 0x33; // '3'
                    modified = true;
                    break;
                  }
                }
              }
              break;
            }
          }
        }
      }

      if (modified) {
        await file.writeAsBytes(bytes, flush: true);
        debugPrint('[VKVideoPlayerDialog] Successfully patched MP3-in-MP4 audio track to .mp3 for AVFoundation');
      }
    } catch (e) {
      debugPrint('[VKVideoPlayerDialog] Error patching MP4 audio: $e');
    }
  }

  Future<void> _initPlayer() async {
    final video = widget.video;
    final tempDir = await getTemporaryDirectory();
    final cacheDir = Directory('${tempDir.path}/openvk_videos');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    final cacheFile = File('${cacheDir.path}/video_${video.ownerId}_${video.id}.mp4');

    // 1. Check if video is already downloaded and cached locally
    if (await cacheFile.exists() && (await cacheFile.length()) > 0) {
      await _fixMp3AudioInMp4(cacheFile);
      try {
        final controller = VideoPlayerController.file(
          cacheFile,
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
        );
        _controller = controller;

        await controller.initialize();
        await controller.setVolume(1.0);
        controller.addListener(_onControllerUpdate);
        await controller.play();
        await controller.setVolume(1.0);

        if (mounted) {
          setState(() {
            _isLoading = false;
            _volume = 1.0;
            _isMuted = false;
          });
          _resetHideTimer();
        }
        return;
      } catch (e) {
        debugPrint('[VKVideoPlayerDialog] Cache playback error: $e');
        try {
          await _controller?.dispose();
        } catch (_) {}
        _controller = null;
      }
    }

    // 2. Resolve stream URL
    String? streamUrl = video.directVideoURL;

    if (streamUrl == null || streamUrl.isEmpty) {
      if (video.ownerId != 0 && video.id != 0) {
        if (mounted) {
          setState(() {
            _statusText = 'Получение ссылки на видеозапись...';
          });
        }
        final details = await OpenVKApi.instance.getVideoDetails(
          ownerId: video.ownerId,
          videoId: video.id,
          accessKey: video.accessKey,
        );
        if (details != null) {
          final files = details['files'] as Map?;
          final base = OpenVKApi.instance.serverURL.replaceAll(RegExp(r'/+$'), '');
          if (files != null) {
            for (final k in ['mp4_1080', '1080', 'mp4_720', '720', 'mp4_480', '480', 'mp4_360', '360', 'mp4_240', '240', 'external', 'src', 'url']) {
              if (files[k] != null && files[k].toString().isNotEmpty) {
                var u = files[k].toString();
                if (!u.startsWith('http') && base.isNotEmpty) {
                  u = '$base/${u.replaceFirst(RegExp(r'^/+'), '')}';
                }
                streamUrl = u;
                break;
              }
            }
            if (streamUrl == null) {
              for (final entry in files.entries) {
                final val = entry.value?.toString() ?? '';
                if (val.isNotEmpty && (val.endsWith('.mp4') || val.contains('.mp4?'))) {
                  var u = val;
                  if (!u.startsWith('http') && base.isNotEmpty) {
                    u = '$base/${u.replaceFirst(RegExp(r'^/+'), '')}';
                  }
                  streamUrl = u;
                  break;
                }
              }
            }
          }
          if (streamUrl == null && details['direct_url'] != null) {
            var u = details['direct_url'].toString();
            if (!u.startsWith('http') && base.isNotEmpty) {
              u = '$base/${u.replaceFirst(RegExp(r'^/+'), '')}';
            }
            streamUrl = u;
          }
          if (streamUrl == null && details['player'] != null) {
            final p = details['player'].toString();
            if (p.endsWith('.mp4') || p.contains('.mp4?')) {
              streamUrl = p;
            }
          }
        }
      }
    }

    if (streamUrl == null || streamUrl.isEmpty) {
      if (video.playerURL != null &&
          (video.playerURL!.endsWith('.mp4') ||
              video.playerURL!.endsWith('.m3u8') ||
              video.playerURL!.contains('.mp4?'))) {
        streamUrl = video.playerURL;
      }
    }

    if (streamUrl == null || streamUrl.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'Прямая ссылка на видеопоток недоступна.\nВозможно, видео встроено со стороннего сервиса.';
        });
      }
      return;
    }

    // Strip URL fragments like #vkuservideo
    final cleanUrl = streamUrl.split('#').first;

    // 3. Download and patch MP4 for AVFoundation (guarantees audio decoding & prevents range errors)
    try {
      if (mounted) {
        setState(() {
          _statusText = 'Загрузка видео...';
        });
      }

      final client = http.Client();
      final req = http.Request('GET', Uri.parse(cleanUrl));
      req.headers['User-Agent'] = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
      final resp = await client.send(req);

      if (resp.statusCode == 200 || resp.statusCode == 206) {
        final total = resp.contentLength ?? 0;
        int received = 0;
        final sink = cacheFile.openWrite();
        await for (final chunk in resp.stream) {
          sink.add(chunk);
          received += chunk.length;
          if (mounted && total > 0) {
            final progress = (received / total * 100).toInt();
            setState(() {
              _statusText = 'Загрузка видео: $progress%';
            });
          }
        }
        await sink.flush();
        await sink.close();
      }

      final fileLen = await cacheFile.exists() ? await cacheFile.length() : 0;
      if (fileLen == 0) {
        try {
          await cacheFile.delete();
        } catch (_) {}
        if (mounted) {
          setState(() {
            _isLoading = false;
            _hasError = true;
            _errorMessage = 'Видеофайл пуст или повреждён на сервере OpenVK (размер 0 байт).';
          });
        }
        return;
      }

      // Patch MP3-in-MP4 headers so Apple AVFoundation enables the audio track
      await _fixMp3AudioInMp4(cacheFile);

      final controller = VideoPlayerController.file(
        cacheFile,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      _controller = controller;

      await controller.initialize();
      await controller.setVolume(1.0);
      controller.addListener(_onControllerUpdate);
      await controller.play();
      await controller.setVolume(1.0);

      if (mounted) {
        setState(() {
          _isLoading = false;
          _volume = 1.0;
          _isMuted = false;
        });
        _resetHideTimer();
      }
      return;
    } catch (e) {
      debugPrint('[VKVideoPlayerDialog] Local download error: $e');
      try {
        await _controller?.dispose();
      } catch (_) {}
      _controller = null;
    }

    // 4. Fallback to online streaming
    try {
      final uri = Uri.parse(cleanUrl);
      final controller = VideoPlayerController.networkUrl(
        uri,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      _controller = controller;

      await controller.initialize();
      await controller.setVolume(1.0);
      controller.addListener(_onControllerUpdate);
      await controller.play();
      await controller.setVolume(1.0);

      if (mounted) {
        setState(() {
          _isLoading = false;
          _volume = 1.0;
          _isMuted = false;
        });
        _resetHideTimer();
      }
      return;
    } catch (e) {
      debugPrint('[VKVideoPlayerDialog] Network stream fallback error: $e');
      try {
        await _controller?.dispose();
      } catch (_) {}
      _controller = null;
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Не удалось воспроизвести видеофайл.\nСервер OpenVK не поддерживает потоковое воспроизведение для этого формата.';
      });
    }
  }

  void _onControllerUpdate() {
    if (mounted && !_isSeeking) {
      setState(() {});
    }
  }

  void _resetHideTimer() {
    _hideControlsTimer?.cancel();
    if (_controller != null && _controller!.value.isPlaying) {
      _hideControlsTimer = Timer(const Duration(seconds: 3), () {
        if (mounted && _controller != null && _controller!.value.isPlaying && !_isSeeking) {
          setState(() {
            _showControls = false;
          });
        }
      });
    }
  }

  void _togglePlayPause() {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_controller!.value.isPlaying) {
      _controller!.pause();
      setState(() {
        _showControls = true;
      });
      _hideControlsTimer?.cancel();
    } else {
      _controller!.play();
      _resetHideTimer();
    }
  }

  void _seekRelative(int seconds) {
    if (_controller == null || !_controller!.value.isInitialized) return;
    final current = _controller!.value.position;
    final duration = _controller!.value.duration;
    final newPos = current + Duration(seconds: seconds);
    final clamped = newPos < Duration.zero
        ? Duration.zero
        : (newPos > duration ? duration : newPos);
    _controller!.seekTo(clamped);
    _resetHideTimer();
  }

  void _toggleMute() {
    if (_controller == null) return;
    setState(() {
      _isMuted = !_isMuted;
      _controller!.setVolume(_isMuted ? 0.0 : _volume);
    });
  }

  void _changeVolume(double delta) {
    if (_controller == null) return;
    setState(() {
      _volume = (_volume + delta).clamp(0.0, 1.0);
      _isMuted = _volume == 0.0;
      _controller!.setVolume(_volume);
    });
  }

  void _toggleLoop() {
    if (_controller == null) return;
    setState(() {
      _isLooping = !_isLooping;
      _controller!.setLooping(_isLooping);
    });
  }

  void _openInBrowser() {
    final target = widget.video.directVideoURL ?? widget.video.playerURL;
    if (target != null && target.isNotEmpty) {
      final uri = Uri.tryParse(target);
      if (uri != null) {
        launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _controller?.removeListener(_onControllerUpdate);
    _controller?.pause();
    _controller?.dispose();
    _focusNode.dispose();
    MemoryManager.instance.trimMemory();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.space) {
            _togglePlayPause();
          } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            _seekRelative(-5);
          } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            _seekRelative(5);
          } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            _changeVolume(0.1);
          } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            _changeVolume(-0.1);
          } else if (event.logicalKey == LogicalKeyboardKey.keyM) {
            _toggleMute();
          } else if (event.logicalKey == LogicalKeyboardKey.escape) {
            Navigator.of(context).pop();
          }
        }
      },
      child: MouseRegion(
        onHover: (_) {
          if (!_showControls) {
            setState(() {
              _showControls = true;
            });
          }
          _resetHideTimer();
        },
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1080, maxHeight: 720),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 32,
                  spreadRadius: 8,
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Video Screen Area
                GestureDetector(
                  onTap: _togglePlayPause,
                  child: Container(
                    color: Colors.black,
                    width: double.infinity,
                    height: double.infinity,
                    alignment: Alignment.center,
                    child: _buildVideoContent(),
                  ),
                ),

                // Center Play Icon Overlay (when paused)
                if (_controller != null &&
                    _controller!.value.isInitialized &&
                    !_controller!.value.isPlaying &&
                    !_isLoading &&
                    !_hasError)
                  Center(
                    child: GestureDetector(
                      onTap: _togglePlayPause,
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 2),
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          size: 46,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                // Top Header Overlay
                AnimatedOpacity(
                  opacity: _showControls || _hasError ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.8),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24),
                            tooltip: 'Назад (Esc)',
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  widget.video.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (widget.video.description.isNotEmpty)
                                  Text(
                                    widget.video.description,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.7),
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.open_in_new_rounded, color: Colors.white, size: 20),
                            tooltip: 'Открыть в браузере',
                            onPressed: _openInBrowser,
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                            tooltip: 'Закрыть',
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Bottom Controls Bar
                AnimatedOpacity(
                  opacity: (_showControls && !_hasError && !_isLoading) ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.85),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildProgressBar(),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              // Play / Pause
                              IconButton(
                                icon: Icon(
                                  (_controller != null && _controller!.value.isPlaying)
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 28,
                                ),
                                onPressed: _togglePlayPause,
                              ),

                              // Replay 5 sec
                              IconButton(
                                icon: const Icon(Icons.replay_5_rounded, color: Colors.white70, size: 20),
                                tooltip: '-5 сек',
                                onPressed: () => _seekRelative(-5),
                              ),

                              // Forward 5 sec
                              IconButton(
                                icon: const Icon(Icons.forward_5_rounded, color: Colors.white70, size: 20),
                                tooltip: '+5 сек',
                                onPressed: () => _seekRelative(5),
                              ),

                              const SizedBox(width: 8),

                              // Time duration
                              Text(
                                '${_formatDuration(_controller?.value.position ?? Duration.zero)} / ${_formatDuration(_controller?.value.duration ?? Duration(seconds: widget.video.duration))}',
                                style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
                              ),

                              const Spacer(),

                              // Volume button
                              IconButton(
                                icon: Icon(
                                  _isMuted || _volume == 0
                                      ? Icons.volume_off_rounded
                                      : (_volume < 0.5 ? Icons.volume_down_rounded : Icons.volume_up_rounded),
                                  color: Colors.white70,
                                  size: 22,
                                ),
                                tooltip: _isMuted ? 'Включить звук (M)' : 'Выключить звук (M)',
                                onPressed: _toggleMute,
                              ),

                              // Mini Volume Slider
                              SizedBox(
                                width: 75,
                                child: SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    trackHeight: 3,
                                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                                    activeTrackColor: Colors.white,
                                    inactiveTrackColor: Colors.white24,
                                    thumbColor: Colors.white,
                                  ),
                                  child: Slider(
                                    value: _isMuted ? 0.0 : _volume,
                                    min: 0.0,
                                    max: 1.0,
                                    onChanged: (val) {
                                      setState(() {
                                        _volume = val;
                                        _isMuted = val == 0.0;
                                        _controller?.setVolume(val);
                                      });
                                    },
                                  ),
                                ),
                              ),

                              const SizedBox(width: 8),

                              // Loop button
                              IconButton(
                                icon: Icon(
                                  Icons.loop_rounded,
                                  color: _isLooping ? const Color(0xFF2D81E0) : Colors.white70,
                                  size: 22,
                                ),
                                tooltip: 'Зациклить видео',
                                onPressed: _toggleLoop,
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
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    final position = _controller?.value.position.inMilliseconds.toDouble() ?? 0.0;
    final duration = _controller?.value.duration.inMilliseconds.toDouble() ??
        (widget.video.duration > 0 ? widget.video.duration * 1000.0 : 1.0);

    final displayPos = _isSeeking ? _seekPositionSec * 1000.0 : position;

    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
        activeTrackColor: const Color(0xFF2D81E0),
        inactiveTrackColor: Colors.white24,
        thumbColor: Colors.white,
      ),
      child: Slider(
        value: displayPos.clamp(0.0, duration),
        min: 0.0,
        max: duration > 0 ? duration : 1.0,
        onChangeStart: (_) {
          setState(() {
            _isSeeking = true;
          });
        },
        onChanged: (val) {
          setState(() {
            _seekPositionSec = val / 1000.0;
          });
        },
        onChangeEnd: (val) {
          _controller?.seekTo(Duration(milliseconds: val.toInt()));
          setState(() {
            _isSeeking = false;
          });
          _resetHideTimer();
        },
      ),
    );
  }

  Widget _buildVideoContent() {
    if (_isLoading) {
      return Stack(
        alignment: Alignment.center,
        children: [
          if (widget.video.imageURL != null)
            Opacity(
              opacity: 0.4,
              child: Image.network(
                widget.video.imageURL!,
                fit: BoxFit.contain,
                errorBuilder: (ctx, err, stack) => const SizedBox(),
              ),
            ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
              const SizedBox(height: 16),
              Text(
                _statusText,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ],
      );
    }

    if (_hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.orangeAccent, size: 48),
              const SizedBox(height: 14),
              Text(
                widget.video.title,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 13),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2D81E0),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: const Text('Открыть в веб-плеере'),
                onPressed: _openInBrowser,
              ),
            ],
          ),
        ),
      );
    }

    if (_controller != null && _controller!.value.isInitialized) {
      return Center(
        child: AspectRatio(
          aspectRatio: _controller!.value.aspectRatio,
          child: VideoPlayer(_controller!),
        ),
      );
    }

    return const SizedBox();
  }
}
