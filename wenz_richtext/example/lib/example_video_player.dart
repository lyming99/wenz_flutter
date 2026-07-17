import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// How [ExampleVideoPlayer] resolves its [ExampleVideoSource.uri].
enum ExampleVideoSourceKind {
  /// A Flutter asset registered in `pubspec.yaml`
  /// (e.g. `assets/videos/sample.mp4`).
  asset,

  /// A remote `http(s)://` stream.
  network,

  /// An absolute local file path on the device.
  file,
}

/// Describes a video source for [ExampleVideoPlayer].
///
/// Construct one with [ExampleVideoSource.asset], [.network], or [.file].
/// Equality is by [uri] + [kind] so [ExampleVideoPlayer] can detect a source
/// change in `didUpdateWidget` and reopen onto the new source instead of leaking
/// controllers or double-initializing.
@immutable
class ExampleVideoSource {
  const ExampleVideoSource({required this.uri, required this.kind});

  /// `uri` is a Flutter asset key such as `assets/videos/sample.mp4`.
  const ExampleVideoSource.asset(this.uri)
      : kind = ExampleVideoSourceKind.asset;

  /// `uri` is an `http(s)://` URL.
  const ExampleVideoSource.network(this.uri)
      : kind = ExampleVideoSourceKind.network;

  /// `uri` is an absolute local file path.
  const ExampleVideoSource.file(this.uri)
      : kind = ExampleVideoSourceKind.file;

  final String uri;
  final ExampleVideoSourceKind kind;

  @override
  bool operator ==(Object other) =>
      other is ExampleVideoSource && other.uri == uri && other.kind == kind;

  @override
  int get hashCode => Object.hash(uri, kind);
}

/// Creates the playback backend used by [ExampleVideoPlayer].
///
/// The example app leaves this unset and uses the media_kit implementation.
/// Tests can inject a deterministic backend without loading native decoders or
/// opening a real network source.
typedef ExampleVideoPlaybackFactory = ExampleVideoPlayback Function();

/// Minimal playback contract consumed by [ExampleVideoPlayer].
///
/// Keeping commands explicit (`play` and `pause`, rather than a backend toggle)
/// lets the widget serialize rapid user intent without racing an asynchronous
/// `playing` stream update.
abstract interface class ExampleVideoPlayback {
  Stream<Duration> get positionStream;
  Stream<Duration> get durationStream;
  Stream<bool> get playingStream;
  Stream<bool> get completedStream;
  Stream<bool> get bufferingStream;
  Stream<String> get errorStream;

  Future<void> open(ExampleVideoSource source);
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> setVolume(double volume);
  Widget buildVideoSurface();
  Future<void> dispose();
}

class _MediaKitExampleVideoPlayback implements ExampleVideoPlayback {
  _MediaKitExampleVideoPlayback() : _player = Player();

  final Player _player;
  late final VideoController _controller = VideoController(_player);

  @override
  Stream<Duration> get positionStream => _player.stream.position;

  @override
  Stream<Duration> get durationStream => _player.stream.duration;

  @override
  Stream<bool> get playingStream => _player.stream.playing;

  @override
  Stream<bool> get completedStream => _player.stream.completed;

  @override
  Stream<bool> get bufferingStream => _player.stream.buffering;

  @override
  Stream<String> get errorStream => _player.stream.error;

  @override
  Future<void> open(ExampleVideoSource source) {
    return _player.open(_mediaFor(source), play: false);
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setVolume(double volume) => _player.setVolume(volume);

  @override
  Widget buildVideoSurface() {
    return Video(
      controller: _controller,
      fill: Colors.black,
      fit: BoxFit.contain,
      controls: (_) => const SizedBox.shrink(),
    );
  }

  @override
  Future<void> dispose() => _player.dispose();

  Media _mediaFor(ExampleVideoSource source) {
    return switch (source.kind) {
      ExampleVideoSourceKind.asset => Media('asset:///${source.uri}'),
      ExampleVideoSourceKind.network || ExampleVideoSourceKind.file =>
        Media(source.uri),
    };
  }
}

ExampleVideoPlayback _createMediaKitPlayback() {
  MediaKit.ensureInitialized();
  return _MediaKitExampleVideoPlayback();
}

/// A reusable, real video player for the example app, backed by `media_kit`.
///
/// It supports asset / network / local-file sources (see [ExampleVideoSource]),
/// renders inside its parent's finite frame — the media block's overflow
/// boundary — clips to [aspectRatio], and optionally clips to [borderRadius].
/// Use [ExampleVideoPlayer.fullscreen] or pass [BorderRadius.zero] when the
/// player is rendered on a fullscreen preview route that must not inherit the
/// embedded editor frame's rounded corners. Initialization failures and
/// unreachable sources are swallowed and shown as a fallback UI, so a bad source
/// degrades gracefully instead of crashing the editor or hanging `pumpAndSettle`
/// in integration tests (per the resolver's "throw tolerated" convention).
///
/// The package core (`wenz_richtext`) stays free of any playback dependency;
/// this widget is the host-side implementation that the example `MediaResolver`
/// hands the video block to.
class ExampleVideoPlayer extends StatefulWidget {
  const ExampleVideoPlayer({
    super.key,
    required this.source,
    this.aspectRatio = defaultAspectRatio,
    this.coverUrl,
    this.borderRadius = defaultBorderRadius,
    this.playbackFactory,
  });

  /// Creates a square-corner player for a fullscreen preview surface.
  const ExampleVideoPlayer.fullscreen({
    super.key,
    required this.source,
    this.aspectRatio = defaultAspectRatio,
    this.coverUrl,
    this.playbackFactory,
  }) : borderRadius = BorderRadius.zero;

  /// Default [aspectRatio] used when the caller omits it (16:9).
  static const double defaultAspectRatio = 16.0 / 9.0;

  /// Default corner radius for embedded editor players.
  static const BorderRadius defaultBorderRadius =
      BorderRadius.all(Radius.circular(8));

  /// What to play. Changing this reopens the existing player onto the new
  /// source; pass a fresh [ExampleVideoPlayer] instance for a full rebuild.
  final ExampleVideoSource source;

  /// Width / height the video frame is clipped to. Must be positive.
  final double aspectRatio;

  /// Optional poster URL shown until the first real frame is displayed.
  final String? coverUrl;

  /// Corner clipping applied by this player. Pass [BorderRadius.zero] for
  /// fullscreen preview presentation.
  final BorderRadius borderRadius;

  /// Optional playback backend factory. The example app uses media_kit when
  /// omitted; deterministic widget tests inject a fake implementation.
  final ExampleVideoPlaybackFactory? playbackFactory;

  @override
  State<ExampleVideoPlayer> createState() => _ExampleVideoPlayerState();
}

class _ExampleVideoPlayerState extends State<ExampleVideoPlayer> {
  ExampleVideoPlayback? _playback;

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<bool>? _completedSub;
  StreamSubscription<bool>? _bufferingSub;
  StreamSubscription<String>? _errorSub;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _volume = 100;
  double _preMuteVolume = 100;

  bool _isPlaying = false;
  bool _buffering = false;
  bool _completed = false;
  bool _everStarted = false;

  // True while the user is dragging the progress slider; suppresses position
  // stream updates so the thumb tracks the finger instead of snapping back.
  bool _seeking = false;
  double? _dragFraction;

  bool _initializing = true;
  bool _hasError = false;

  int _sourceGeneration = 0;
  Future<void> _sourceOpenQueue = Future<void>.value();

  bool _playbackTarget = false;
  bool _restartBeforePlay = false;
  bool _userControlsPlayback = false;
  int _playbackRevision = 0;
  int _lastAppliedPlaybackRevision = 0;
  Future<void>? _playbackSyncFuture;

  @override
  void initState() {
    super.initState();
    _startOpening(widget.source, notify: false);
  }

  @override
  void didUpdateWidget(covariant ExampleVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    final replacePlayback =
        !identical(widget.playbackFactory, oldWidget.playbackFactory);
    if (widget.source != oldWidget.source || replacePlayback) {
      _startOpening(widget.source, replacePlayback: replacePlayback);
    }
  }

  void _startOpening(
    ExampleVideoSource source, {
    bool replacePlayback = false,
    bool notify = true,
  }) {
    final generation = ++_sourceGeneration;
    _playbackRevision++;
    _lastAppliedPlaybackRevision = _playbackRevision;
    _playbackTarget = false;
    _restartBeforePlay = false;
    _userControlsPlayback = false;

    void resetState() {
      _initializing = true;
      _hasError = false;
      _position = Duration.zero;
      _duration = Duration.zero;
      _isPlaying = false;
      _buffering = false;
      _completed = false;
      _everStarted = false;
      _seeking = false;
      _dragFraction = null;
    }

    if (notify && mounted) {
      setState(resetState);
    } else {
      resetState();
    }

    final previous = _sourceOpenQueue;
    final next = _openSourceAfter(
      previous,
      source,
      generation,
      replacePlayback: replacePlayback,
    );
    _sourceOpenQueue = next;
    unawaited(next);
  }

  Future<void> _openSourceAfter(
    Future<void> previous,
    ExampleVideoSource source,
    int generation, {
    required bool replacePlayback,
  }) async {
    try {
      await previous;
    } catch (_) {
      // Every source operation is guarded, but keep the queue recoverable if a
      // future backend implementation unexpectedly leaks an error.
    }
    await _openSource(
      source,
      generation,
      replacePlayback: replacePlayback,
    );
  }

  Future<void> _openSource(
    ExampleVideoSource source,
    int generation, {
    required bool replacePlayback,
  }) async {
    final pendingPlayback = _playbackSyncFuture;
    if (pendingPlayback != null) {
      await pendingPlayback;
    }
    if (!_isCurrentSource(generation)) {
      return;
    }
    if (source.uri.trim().isEmpty) {
      final previous = _playback;
      _playback = null;
      await _cancelSubscriptions();
      await _disposePlayback(previous);
      _showSourceError(generation);
      return;
    }

    if (replacePlayback) {
      final previous = _playback;
      _playback = null;
      await _cancelSubscriptions();
      await _disposePlayback(previous);
      if (!_isCurrentSource(generation)) {
        return;
      }
    }

    var playback = _playback;
    if (playback == null) {
      try {
        playback = (widget.playbackFactory ?? _createMediaKitPlayback)();
      } catch (_) {
        _showSourceError(generation);
        return;
      }
      if (!_isCurrentSource(generation)) {
        await _disposePlayback(playback);
        return;
      }
      _playback = playback;
      try {
        _listenToPlayback(playback);
      } catch (_) {
        _playback = null;
        await _cancelSubscriptions();
        await _disposePlayback(playback);
        _showSourceError(generation);
        return;
      }
    }

    try {
      await playback.open(source);
      if (_isCurrentSource(generation)) {
        setState(() => _initializing = false);
      }
    } catch (_) {
      _showSourceError(generation);
    }
  }

  bool _isCurrentSource(int generation) {
    return mounted && generation == _sourceGeneration;
  }

  void _listenToPlayback(ExampleVideoPlayback playback) {
    void onStreamError(Object _, StackTrace __) {
      if (identical(_playback, playback)) {
        _showSourceError(_sourceGeneration);
      }
    }

    _positionSub = playback.positionStream.listen((position) {
      if (_seeking || !mounted) {
        return;
      }
      setState(() {
        _position = position;
        if (_isPlaying || position > Duration.zero) {
          _everStarted = true;
        }
      });
    }, onError: onStreamError);
    _durationSub = playback.durationStream.listen((duration) {
      if (mounted) {
        setState(() => _duration = duration);
      }
    }, onError: onStreamError);
    _playingSub = playback.playingStream.listen((playing) {
      if (!mounted) {
        return;
      }
      setState(() {
        if (playing) {
          _everStarted = true;
          _completed = false;
        }
        if (!_userControlsPlayback || playing == _playbackTarget) {
          _isPlaying = playing;
          _playbackTarget = playing;
        }
      });
    }, onError: onStreamError);
    _completedSub = playback.completedStream.listen((completed) {
      if (!mounted) {
        return;
      }
      setState(() {
        _completed = completed;
        if (completed) {
          _isPlaying = false;
          _playbackTarget = false;
          _playbackRevision++;
          if (_playbackSyncFuture == null) {
            _lastAppliedPlaybackRevision = _playbackRevision;
          }
        }
      });
    }, onError: onStreamError);
    _bufferingSub = playback.bufferingStream.listen((buffering) {
      if (mounted) {
        setState(() => _buffering = buffering);
      }
    }, onError: onStreamError);
    _errorSub = playback.errorStream.listen((_) {
      if (identical(_playback, playback)) {
        _showSourceError(_sourceGeneration);
      }
    }, onError: onStreamError);
  }

  void _showSourceError(int generation) {
    if (!_isCurrentSource(generation)) {
      return;
    }
    setState(() {
      _initializing = false;
      _hasError = true;
      _isPlaying = false;
      _playbackTarget = false;
    });
  }

  void _togglePlay() {
    if (_playback == null || _hasError || _initializing) {
      return;
    }
    final target = !_playbackTarget;
    _playbackTarget = target;
    _userControlsPlayback = true;
    if (target && _completed) {
      _restartBeforePlay = true;
      _completed = false;
    }
    _playbackRevision++;
    setState(() {
      _isPlaying = target;
      if (target) {
        _everStarted = true;
      }
    });
    _schedulePlaybackSync();
  }

  void _schedulePlaybackSync() {
    if (_playbackSyncFuture != null) {
      return;
    }
    late final Future<void> sync;
    sync = _synchronizePlayback(_sourceGeneration);
    _playbackSyncFuture = sync;
    unawaited(sync.whenComplete(() {
      if (identical(_playbackSyncFuture, sync)) {
        _playbackSyncFuture = null;
      }
      if (mounted &&
          !_initializing &&
          !_hasError &&
          _lastAppliedPlaybackRevision != _playbackRevision) {
        _schedulePlaybackSync();
      }
    }));
  }

  Future<void> _synchronizePlayback(int generation) async {
    while (_isCurrentSource(generation) && !_initializing && !_hasError) {
      final playback = _playback;
      if (playback == null) {
        return;
      }
      final revision = _playbackRevision;
      final target = _playbackTarget;
      try {
        if (target && _restartBeforePlay) {
          await playback.seek(Duration.zero);
          if (!_isCurrentSource(generation)) {
            return;
          }
          _restartBeforePlay = false;
          if (mounted) {
            setState(() => _position = Duration.zero);
          }
          if (revision != _playbackRevision) {
            continue;
          }
        }
        if (target) {
          await playback.play();
        } else {
          await playback.pause();
        }
      } catch (_) {
        _lastAppliedPlaybackRevision = _playbackRevision;
        _showSourceError(generation);
        return;
      }
      if (!_isCurrentSource(generation)) {
        return;
      }
      _lastAppliedPlaybackRevision = revision;
      if (target == _playbackTarget) {
        // Several rapid taps may return to the state this command just applied
        // (play → pause intent → play intent). Treat the latest revision as
        // satisfied instead of issuing a duplicate play/pause command.
        _lastAppliedPlaybackRevision = _playbackRevision;
        return;
      }
    }
  }

  void _onSeekStart() {
    _seeking = true;
    final total = _duration.inMilliseconds;
    _dragFraction = total <= 0
        ? 0
        : (_position.inMilliseconds / total).clamp(0.0, 1.0);
    if (mounted) {
      setState(() {});
    }
  }

  void _onSeekChanged(double fraction) {
    _dragFraction = fraction.clamp(0.0, 1.0);
    if (mounted) {
      setState(() {});
    }
  }

  void _onSeekEnd(double fraction) {
    final playback = _playback;
    _seeking = false;
    _dragFraction = null;
    if (playback == null || _duration == Duration.zero) {
      if (mounted) {
        setState(() {});
      }
      return;
    }
    final target = Duration(
      milliseconds: (_duration.inMilliseconds * fraction).round(),
    );
    _completed = false;
    _restartBeforePlay = false;
    _runPlaybackSideEffect(() => playback.seek(target));
  }

  void _toggleMute() {
    if (_playback == null) {
      return;
    }
    if (_volume > 0) {
      _preMuteVolume = _volume;
      _setVolume(0);
    } else {
      _setVolume(_preMuteVolume <= 0 ? 100 : _preMuteVolume);
    }
  }

  void _setVolume(double value) {
    final clamped = value.clamp(0.0, 100.0);
    final playback = _playback;
    if (mounted) {
      setState(() => _volume = clamped);
    }
    if (clamped > 0) {
      _preMuteVolume = clamped;
    }
    if (playback != null) {
      _runPlaybackSideEffect(() => playback.setVolume(clamped));
    }
  }

  void _runPlaybackSideEffect(Future<void> Function() command) {
    unawaited(() async {
      try {
        await command();
      } catch (_) {
        // Slider and volume commands are best-effort controls. Playback errors
        // still arrive through errorStream; never leak a detached future error.
      }
    }());
  }

  Future<void> _cancelSubscriptions() async {
    final subscriptions = <StreamSubscription<dynamic>>[
      if (_positionSub != null) _positionSub!,
      if (_durationSub != null) _durationSub!,
      if (_playingSub != null) _playingSub!,
      if (_completedSub != null) _completedSub!,
      if (_bufferingSub != null) _bufferingSub!,
      if (_errorSub != null) _errorSub!,
    ];
    _positionSub = null;
    _durationSub = null;
    _playingSub = null;
    _completedSub = null;
    _bufferingSub = null;
    _errorSub = null;
    for (final subscription in subscriptions) {
      try {
        await subscription.cancel();
      } catch (_) {
        // A failing stream teardown must not escape widget disposal/reopen.
      }
    }
  }

  Future<void> _disposePlayback(ExampleVideoPlayback? playback) async {
    if (playback == null) {
      return;
    }
    try {
      await playback.dispose();
    } catch (_) {
      // Native teardown is best effort and may race process/app shutdown.
    }
  }

  @override
  void dispose() {
    _sourceGeneration++;
    _playbackRevision++;
    final playback = _playback;
    _playback = null;
    unawaited(() async {
      await _cancelSubscriptions();
      await _disposePlayback(playback);
    }());
    super.dispose();
  }

  double get _positionFraction {
    if (_dragFraction != null) {
      return _dragFraction!;
    }
    final total = _duration.inMilliseconds;
    if (total <= 0) {
      return 0;
    }
    return (_position.inMilliseconds / total).clamp(0.0, 1.0);
  }

  Duration get _displayPosition =>
      _dragFraction == null || _duration == Duration.zero
          ? _position
          : Duration(
              milliseconds:
                  (_duration.inMilliseconds * _dragFraction!).round(),
            );

  bool get _mediaReady => _playback != null && !_hasError;

  @override
  Widget build(BuildContext context) {
    final aspectRatio = widget.aspectRatio > 0
        ? widget.aspectRatio
        : ExampleVideoPlayer.defaultAspectRatio;
    final showVideo = _mediaReady && !_initializing;
    final showLoading = (_initializing || _buffering) && !_hasError;
    final showTapLayer = _mediaReady && !_initializing;

    final playerSurface = AspectRatio(
      aspectRatio: aspectRatio,
      child: ColoredBox(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // 1. Real video texture (bottom layer).
            if (showVideo) _playback!.buildVideoSurface(),
            // 2. Poster / placeholder until a real frame has been shown, or
            //    when the source has no usable URL.
            if (!_everStarted && !_hasError) _CoverImage(url: widget.coverUrl),
            // 3. Error fallback (covers everything below).
            if (_hasError) const _ErrorFallback(),
            // 4. Loading / buffering spinner.
            if (showLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                ),
              ),
            // 5. Tap-to-toggle play layer + center badge (below the controls
            //    bar so the slider keeps its own gestures).
            if (showTapLayer)
              Positioned.fill(
                child: Semantics(
                  button: true,
                  label: _isPlaying ? '暂停视频' : '播放视频',
                  child: GestureDetector(
                    key: const ValueKey<String>(
                      'example-video-player-tap-layer',
                    ),
                    behavior: HitTestBehavior.opaque,
                    onTap: _togglePlay,
                    child: Center(
                      child: _PlayBadge(
                        visible: !_isPlaying && !_buffering,
                      ),
                    ),
                  ),
                ),
              ),
            // 6. Bottom controls bar (top layer).
            if (showTapLayer) _buildControlsBar(),
          ],
        ),
      ),
    );
    if (widget.borderRadius == BorderRadius.zero) {
      return ClipRect(
        key: const ValueKey<String>('example-video-player-square-clip'),
        child: playerSurface,
      );
    }
    return ClipRRect(
      key: const ValueKey<String>('example-video-player-rounded-clip'),
      borderRadius: widget.borderRadius,
      child: playerSurface,
    );
  }

  Widget _buildControlsBar() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Listener(
        key: const ValueKey<String>('example-video-player-controls'),
        // Claim the whole controls strip so slider/button gestures and gaps
        // never fall through to the video tap layer underneath.
        behavior: HitTestBehavior.opaque,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                Colors.transparent,
                Colors.black.withAlpha(140),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 18, 8, 4),
            child: Theme(
              data: Theme.of(context).copyWith(
                sliderTheme: _videoSliderTheme(Theme.of(context).sliderTheme),
              ),
              child: Row(
                children: <Widget>[
                  Text(
                    _formatDuration(_displayPosition),
                    style: _timeTextStyle(),
                  ),
                  Expanded(
                    child: Slider(
                      key: const ValueKey<String>(
                        'example-video-player-progress',
                      ),
                      value: _positionFraction,
                      onChanged: _onSeekChanged,
                      onChangeStart: (_) => _onSeekStart(),
                      onChangeEnd: _onSeekEnd,
                    ),
                  ),
                  Text(
                    _formatDuration(_duration),
                    style: _timeTextStyle(),
                  ),
                  IconButton(
                    key: const ValueKey<String>(
                      'example-video-player-play-button',
                    ),
                    tooltip: _isPlaying ? '暂停' : '播放',
                    iconSize: 20,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    color: Colors.white,
                    onPressed: _togglePlay,
                    icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                  ),
                  IconButton(
                    key: const ValueKey<String>(
                      'example-video-player-mute-button',
                    ),
                    tooltip: _volume > 0 ? '静音' : '取消静音',
                    iconSize: 20,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    color: Colors.white,
                    onPressed: _toggleMute,
                    icon: Icon(
                      _volume > 0 ? Icons.volume_up : Icons.volume_off,
                    ),
                  ),
                  SizedBox(
                    width: 56,
                    child: Slider(
                      key: const ValueKey<String>(
                        'example-video-player-volume',
                      ),
                      value: (_volume / 100).clamp(0.0, 1.0),
                      onChanged: (value) => _setVolume(value * 100),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  TextStyle _timeTextStyle() {
    return const TextStyle(
      color: Colors.white,
      fontSize: 11,
      height: 1.2,
      fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
    );
  }

  SliderThemeData _videoSliderTheme(SliderThemeData base) {
    return base.copyWith(
      trackHeight: 3,
      activeTrackColor: Colors.white,
      inactiveTrackColor: Colors.white.withAlpha(70),
      thumbColor: Colors.white,
      overlayColor: Colors.white.withAlpha(40),
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
    );
  }
}

String _formatDuration(Duration duration) {
  final totalSeconds = duration.inSeconds;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  String two(int value) => value.toString().padLeft(2, '0');
  if (hours > 0) {
    return '$hours:${two(minutes)}:${two(seconds)}';
  }
  return '$minutes:${two(seconds)}';
}

/// Poster shown until the first real frame is displayed (or a neutral dark
/// tile when no cover is available). Network failures fall back silently.
class _CoverImage extends StatelessWidget {
  const _CoverImage({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final resolved = url?.trim() ?? '';
    if (!resolved.startsWith('http')) {
      return const ColoredBox(color: Colors.black);
    }
    return Image.network(
      resolved,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : const ColoredBox(color: Colors.black),
      errorBuilder: (context, error, stackTrace) =>
          const ColoredBox(color: Colors.black),
    );
  }
}

class _PlayBadge extends StatelessWidget {
  const _PlayBadge({required this.visible});

  final bool visible;

  @override
  Widget build(BuildContext context) {
    if (!visible) {
      return const SizedBox.shrink();
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(110),
        shape: BoxShape.circle,
      ),
      child: const Padding(
        padding: EdgeInsets.all(12),
        child: Icon(
          Icons.play_arrow,
          color: Colors.white,
          size: 40,
        ),
      ),
    );
  }
}

class _ErrorFallback extends StatelessWidget {
  const _ErrorFallback();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withAlpha(220),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.error_outline,
              color: Colors.white70,
              size: 32,
            ),
            SizedBox(height: 6),
            Text(
              '视频无法播放',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
