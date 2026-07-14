import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'src/window_border_types.dart';
import 'window_border_method_channel.dart';

abstract class WindowBorderPlatform extends PlatformInterface {
  /// Constructs a WindowBorderPlatform.
  WindowBorderPlatform() : super(token: _token);

  static final Object _token = Object();

  static WindowBorderPlatform _instance = MethodChannelWindowBorder();

  /// The default instance of [WindowBorderPlatform] to use.
  ///
  /// Defaults to [MethodChannelWindowBorder].
  static WindowBorderPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [WindowBorderPlatform] when
  /// they register themselves.
  static set instance(WindowBorderPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<void> initialize(WindowBorderStyle style, {bool enabled = true}) {
    throw UnimplementedError('initialize() has not been implemented.');
  }

  Future<void> setEnabled(bool enabled) {
    throw UnimplementedError('setEnabled() has not been implemented.');
  }

  Future<void> setStyle(WindowBorderStyle style) {
    throw UnimplementedError('setStyle() has not been implemented.');
  }

  Future<void> startDragging() {
    throw UnimplementedError('startDragging() has not been implemented.');
  }

  Future<void> startResizing(WindowResizeEdge edge) {
    throw UnimplementedError('startResizing() has not been implemented.');
  }

  Future<void> minimize() {
    throw UnimplementedError('minimize() has not been implemented.');
  }

  Future<void> maximize() {
    throw UnimplementedError('maximize() has not been implemented.');
  }

  Future<void> restore() {
    throw UnimplementedError('restore() has not been implemented.');
  }

  Future<void> toggleMaximize() {
    throw UnimplementedError('toggleMaximize() has not been implemented.');
  }

  Future<void> close() {
    throw UnimplementedError('close() has not been implemented.');
  }

  Future<bool> isMaximized() {
    throw UnimplementedError('isMaximized() has not been implemented.');
  }

  Future<WindowState> getState() {
    throw UnimplementedError('getState() has not been implemented.');
  }

  Stream<WindowState> get stateChanges => const Stream<WindowState>.empty();
}
