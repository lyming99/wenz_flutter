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

/// A reusable, real video player for the example app, backed by `media_kit`.
///
/// It supports asset / network / local-file sources (see [ExampleVideoSource]),
/// renders inside its parent's finite frame — the media block's overflow
/// boundary — clips to [aspectRatio], and optionally clips to [borderRadius].
/// Use [ExampleVideoPlayer.fullscreen] or pass [BorderRadius.zero] when the
/// player is rendered in a preview/fullscreen surface that must not inherit the
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
  });

  /// Creates a square-corner player for preview/fullscreen surfaces.
  const ExampleVideoPlayer.fullscreen({
    super.key,
    required this.source,
    this.aspectRatio = defaultAspectRatio,
    this.coverUrl,
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
  /// preview/fullscreen presentation.
  final BorderRadius borderRadius;

  @override
  State<ExampleVideoPlayer> createState() => _ExampleVideoPlayerState();
}

class _ExampleVideoPlayerState extends State<ExampleVideoPlayer> {
  Player? _player;
  VideoController? _controller;

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

  @override
  void initState() {
    super.initState();
    // MediaKit.ensureInitialized is idempotent; calling it here keeps this
    // component self-contained (it is also safe if the host already called it
    // in main()).
    unawaited(_initialize(widget.source));
  }

  @override
  void didUpdateWidget(covariant ExampleVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.source != oldWidget.source) {
      unawaited(_reopen(widget.source));
    }
  }

  Future<void> _initialize(ExampleVideoSource source) async {
    if (source.uri.trim().isEmpty) {
      // Nothing to play: fall straight to the error/placeholder state.
      if (mounted) {
        setState(() {
          _initializing = false;
          _hasError = true;
        });
      }
      return;
    }
    try {
      // Synchronous in media_kit 1.2.x (returns void); loads/verifies the
      // libmpv native library. Idempotent, and safe if the host already called
      // it in main().
      MediaKit.ensureInitialized();
      final player = Player();
      final controller = VideoController(player);
      _player = player;
      _controller = controller;

      _positionSub = player.stream.position.listen((position) {
        if (_seeking || !mounted) {
          return;
        }
        final started = _isPlaying || position > Duration.zero;
        setState(() {
          _position = position;
          if (started) {
            _everStarted = true;
          }
        });
      });
      _durationSub = player.stream.duration.listen((duration) {
        if (!mounted) {
          return;
        }
        setState(() => _duration = duration);
      });
      _playingSub = player.stream.playing.listen((playing) {
        if (!mounted) {
          return;
        }
        setState(() {
          _isPlaying = playing;
          if (playing) {
            _everStarted = true;
            _completed = false;
          }
        });
      });
      _completedSub = player.stream.completed.listen((completed) {
        if (!mounted) {
          return;
        }
        setState(() => _completed = completed);
      });
      _bufferingSub = player.stream.buffering.listen((buffering) {
        if (!mounted) {
          return;
        }
        setState(() => _buffering = buffering);
      });
      _errorSub = player.stream.error.listen((_) {
        // A missing/unsupported source surfaces here, not as a thrown
        // exception; flip to the fallback UI so the editor keeps rendering.
        if (!mounted) {
          return;
        }
        setState(() {
          _hasError = true;
          _initializing = false;
        });
      });

      // open() with play:false shows the poster/placeholder until the user taps
      // play, instead of every sample block autoplaying on editor load.
      await player.open(_mediaFor(source), play: false);

      if (mounted) {
        setState(() => _initializing = false);
      }
    } catch (_) {
      // Native init / open failures (e.g. no decoder in a headless test): never
      // propagate — degrade to the fallback UI.
      if (mounted) {
        setState(() {
          _initializing = false;
          _hasError = true;
        });
      }
    }
  }

  Future<void> _reopen(ExampleVideoSource source) async {
    final player = _player;
    if (player == null) {
      // Initialization never completed (or failed); start fresh for the new
      // source rather than spinning up against a half-built controller.
      _cancelSubscriptions();
      await _player?.dispose();
      _player = null;
      _controller = null;
      if (mounted) {
        setState(() {
          _initializing = true;
          _hasError = false;
          _position = Duration.zero;
          _duration = Duration.zero;
          _isPlaying = false;
          _buffering = false;
          _completed = false;
          _everStarted = false;
        });
      }
      await _initialize(source);
      return;
    }
    if (mounted) {
      setState(() {
        _initializing = true;
        _hasError = false;
        _position = Duration.zero;
        _duration = Duration.zero;
        _isPlaying = false;
        _buffering = false;
        _completed = false;
        _everStarted = false;
      });
    }
    try {
      await player.open(_mediaFor(source), play: false);
      if (mounted) {
        setState(() => _initializing = false);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _initializing = false;
          _hasError = true;
        });
      }
    }
  }

  Media _mediaFor(ExampleVideoSource source) {
    switch (source.kind) {
      case ExampleVideoSourceKind.asset:
        // media_kit loads registered Flutter assets via the asset:/// scheme;
        // the path after it is the pubspec asset key.
        return Media('asset:///${source.uri}');
      case ExampleVideoSourceKind.network:
      case ExampleVideoSourceKind.file:
        // mpv accepts http(s):// URLs and raw local paths directly.
        return Media(source.uri);
    }
  }

  void _togglePlay() {
    final player = _player;
    if (player == null || _hasError || _initializing) {
      return;
    }
    if (_completed) {
      unawaited(player.seek(Duration.zero));
    }
    unawaited(player.playOrPause());
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
    final player = _player;
    _seeking = false;
    _dragFraction = null;
    if (player == null || _duration == Duration.zero) {
      if (mounted) {
        setState(() {});
      }
      return;
    }
    final target = Duration(
      milliseconds: (_duration.inMilliseconds * fraction).round(),
    );
    unawaited(player.seek(target));
  }

  void _toggleMute() {
    final player = _player;
    if (player == null) {
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
    final player = _player;
    if (mounted) {
      setState(() => _volume = clamped);
    }
    if (clamped > 0) {
      _preMuteVolume = clamped;
    }
    if (player != null) {
      unawaited(player.setVolume(clamped));
    }
  }

  void _cancelSubscriptions() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _playingSub?.cancel();
    _completedSub?.cancel();
    _bufferingSub?.cancel();
    _errorSub?.cancel();
    _positionSub = null;
    _durationSub = null;
    _playingSub = null;
    _completedSub = null;
    _bufferingSub = null;
    _errorSub = null;
  }

  @override
  void dispose() {
    _cancelSubscriptions();
    // Dispose the player; media_kit tears its native handles down off-thread,
    // so the returned future is intentionally not awaited here. This avoids
    // leaking controllers when the block scrolls off-screen or the editor is
    // rebuilt.
    unawaited(_player?.dispose());
    _player = null;
    _controller = null;
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

  bool get _mediaReady => _controller != null && !_hasError;

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
            if (showVideo)
              Video(
                controller: _controller!,
                fill: Colors.black,
                fit: BoxFit.contain,
                // Disable built-in controls; this widget renders its own.
                controls: (_) => const SizedBox.shrink(),
              ),
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
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _togglePlay,
                  child: Center(
                    child: _PlayBadge(
                      visible: !_isPlaying && !_buffering,
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
      return ClipRect(child: playerSurface);
    }
    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: playerSurface,
    );
  }

  Widget _buildControlsBar() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
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
                    value: (_volume / 100).clamp(0.0, 1.0),
                    onChanged: (value) => _setVolume(value * 100),
                  ),
                ),
              ],
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
