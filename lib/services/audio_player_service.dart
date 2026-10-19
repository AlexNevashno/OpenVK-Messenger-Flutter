import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class AudioTrackItem {
  final String id;
  final String title;
  final String artist;
  final Duration duration;
  final String url;
  final bool isVoice;

  AudioTrackItem({
    required this.id,
    required this.title,
    this.artist = '',
    this.duration = Duration.zero,
    required this.url,
    this.isVoice = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudioTrackItem && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class AudioPlayerService extends ChangeNotifier {
  static final AudioPlayerService instance = AudioPlayerService._internal();
  AudioPlayerService._internal() {
    _init();
  }

  final AudioPlayer _player = AudioPlayer();

  String? _activeId;
  String? get activeId => _activeId;

  String? _currentUrl;
  String? get currentUrl => _currentUrl;

  String _currentTitle = '';
  String get currentTitle => _currentTitle;

  String _currentArtist = '';
  String get currentArtist => _currentArtist;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  PlayerState _state = PlayerState.stopped;
  PlayerState get state => _state;
  bool get isPlaying => _state == PlayerState.playing;

  Duration _position = Duration.zero;
  Duration get position => _position;

  Duration _duration = Duration.zero;
  Duration get duration => _duration;

  List<AudioTrackItem> _playlist = [];
  List<AudioTrackItem> get playlist => _playlist;

  int _currentTrackIndex = 0;
  int get currentTrackIndex => _currentTrackIndex;

  bool get hasNextTrack => _playlist.isNotEmpty && _currentTrackIndex < _playlist.length - 1;
  bool get hasPreviousTrack => _playlist.isNotEmpty && (_currentTrackIndex > 0 || _position.inSeconds > 3);

  StreamSubscription? _stateSub;
  StreamSubscription? _posSub;
  StreamSubscription? _durSub;
  StreamSubscription? _compSub;

  void _init() {
    _player.setVolume(1.0);
    _stateSub = _player.onPlayerStateChanged.listen((state) {
      _state = state;
      if (state == PlayerState.playing) {
        _isLoading = false;
      }
      notifyListeners();
    });

    _posSub = _player.onPositionChanged.listen((pos) {
      _position = pos;
      if (_isLoading && pos.inMilliseconds > 0) {
        _isLoading = false;
      }
      notifyListeners();
    });

    _durSub = _player.onDurationChanged.listen((dur) {
      if (dur > Duration.zero) {
        _duration = dur;
        notifyListeners();
      }
    });

    // Auto-advance to next track in playlist on completion (matching Mac Swift version)
    _compSub = _player.onPlayerComplete.listen((_) {
      if (hasNextTrack) {
        nextTrack();
      } else {
        _state = PlayerState.stopped;
        _position = Duration.zero;
        notifyListeners();
      }
    });
  }

  void playTrack(AudioTrackItem item, {List<AudioTrackItem> inPlaylist = const []}) {
    if (inPlaylist.isNotEmpty) {
      _playlist = List<AudioTrackItem>.from(inPlaylist);
      _currentTrackIndex = _playlist.indexWhere((t) => t.id == item.id);
      if (_currentTrackIndex == -1) _currentTrackIndex = 0;
    } else if (_playlist.isEmpty) {
      _playlist = [item];
      _currentTrackIndex = 0;
    }

    _activeId = item.id;
    _currentTitle = item.title;
    _currentArtist = item.artist;
    _currentUrl = item.url;
    _position = Duration.zero;
    _duration = item.duration;
    _isLoading = true;
    _state = PlayerState.playing;
    notifyListeners();

    _playDirect(item.url);
  }

  void togglePlay({
    required String id,
    required String url,
    String title = '',
    String artist = '',
    Duration duration = Duration.zero,
    bool isVoice = false,
    List<AudioTrackItem> inPlaylist = const [],
  }) {
    if (_activeId == id) {
      if (isPlaying) {
        pause();
      } else {
        resume();
      }
    } else {
      final item = AudioTrackItem(
        id: id,
        title: title.isNotEmpty ? title : (isVoice ? 'Голосовое сообщение' : 'Аудиозапись'),
        artist: artist,
        duration: duration,
        url: url,
        isVoice: isVoice,
      );
      playTrack(item, inPlaylist: inPlaylist);
    }
  }

  Future<void> playAudio({
    required String url,
    String? title,
    String? artist,
    bool isLocal = false,
  }) async {
    final item = AudioTrackItem(
      id: url,
      title: title ?? 'Аудиозапись',
      artist: artist ?? '',
      url: url,
    );
    playTrack(item);
  }

  Future<void> _playDirect(String url) async {
    try {
      await _player.setVolume(1.0);
      if (url.startsWith('http://') || url.startsWith('https://')) {
        await _player.play(UrlSource(url));
      } else {
        await _player.play(DeviceFileSource(url));
      }
    } catch (e) {
      debugPrint('[AudioPlayerService] Play error: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  void nextTrack() {
    if (!hasNextTrack) return;
    _currentTrackIndex++;
    final next = _playlist[_currentTrackIndex];
    playTrack(next, inPlaylist: _playlist);
  }

  void previousTrack() {
    if (_position.inSeconds > 3) {
      seek(Duration.zero);
      return;
    }
    if (_currentTrackIndex > 0) {
      _currentTrackIndex--;
      final prev = _playlist[_currentTrackIndex];
      playTrack(prev, inPlaylist: _playlist);
    } else {
      seek(Duration.zero);
    }
  }

  void toggleCurrentPlayback() {
    if (isPlaying) {
      pause();
    } else {
      resume();
    }
  }

  Future<void> pause() async {
    await _player.pause();
    _state = PlayerState.paused;
    notifyListeners();
  }

  Future<void> resume() async {
    await _player.setVolume(1.0);
    await _player.resume();
    _state = PlayerState.playing;
    notifyListeners();
  }

  Future<void> stop() async {
    await _player.stop();
    _activeId = null;
    _currentUrl = null;
    _currentTitle = '';
    _currentArtist = '';
    _position = Duration.zero;
    _duration = Duration.zero;
    _playlist = [];
    _currentTrackIndex = 0;
    _state = PlayerState.stopped;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> seek(Duration position) async {
    _position = position;
    notifyListeners();
    await _player.seek(position);
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _posSub?.cancel();
    _durSub?.cancel();
    _compSub?.cancel();
    _player.dispose();
    super.dispose();
  }
}
