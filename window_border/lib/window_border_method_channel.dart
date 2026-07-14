import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'src/window_border_types.dart';
import 'window_border_platform_interface.dart';

/// An implementation of [WindowBorderPlatform] that uses method channels.
class MethodChannelWindowBorder extends WindowBorderPlatform {
  MethodChannelWindowBorder({MethodChannel? channel})
      : methodChannel = channel ?? const MethodChannel('window_border') {
    methodChannel.setMethodCallHandler(_handleNativeMethodCall);
  }

  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final MethodChannel methodChannel;

  final StreamController<WindowState> _stateController =
      StreamController<WindowState>.broadcast();

  @override
  Stream<WindowState> get stateChanges => _stateController.stream;

  Future<void> _handleNativeMethodCall(MethodCall call) async {
    if (call.method == 'windowStateChanged') {
      _stateController.add(WindowState.fromNative(call.arguments as String?));
    }
  }

  @override
  Future<void> initialize(WindowBorderStyle style, {bool enabled = true}) {
    return methodChannel.invokeMethod<void>('initialize', <String, Object>{
      ...style.toMap(),
      'enabled': enabled,
    });
  }

  @override
  Future<void> setEnabled(bool enabled) {
    return methodChannel.invokeMethod<void>('setEnabled', enabled);
  }

  @override
  Future<void> setStyle(WindowBorderStyle style) {
    return methodChannel.invokeMethod<void>('setStyle', style.toMap());
  }

  @override
  Future<void> startDragging() {
    return methodChannel.invokeMethod<void>('startDragging');
  }

  @override
  Future<void> startResizing(WindowResizeEdge edge) {
    return methodChannel.invokeMethod<void>('startResizing', edge.name);
  }

  @override
  Future<void> minimize() {
    return methodChannel.invokeMethod<void>('minimize');
  }

  @override
  Future<void> maximize() {
    return methodChannel.invokeMethod<void>('maximize');
  }

  @override
  Future<void> restore() {
    return methodChannel.invokeMethod<void>('restore');
  }

  @override
  Future<void> toggleMaximize() {
    return methodChannel.invokeMethod<void>('toggleMaximize');
  }

  @override
  Future<void> close() {
    return methodChannel.invokeMethod<void>('close');
  }

  @override
  Future<bool> isMaximized() async {
    return await methodChannel.invokeMethod<bool>('isMaximized') ?? false;
  }

  @override
  Future<WindowState> getState() async {
    final state = await methodChannel.invokeMethod<String>('getState');
    return WindowState.fromNative(state);
  }
}
