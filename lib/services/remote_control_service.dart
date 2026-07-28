import 'package:flutter/services.dart';

/// Buttons sent by the Android host when a native WebView owns input focus.
///
/// Android platform views can consume TV remote key events before Flutter's
/// focus system sees them. The host activity forwards navigation keys through
/// this service so the browser controls remain usable after a real WebView tap.
enum RemoteButton {
  up,
  down,
  left,
  right,
  activate,
  back,
  menu,
  unknown;

  static RemoteButton fromAndroidKeyCode(int keyCode) {
    switch (keyCode) {
      // KEYCODE_DPAD_UP / DOWN / LEFT / RIGHT
      case 19:
        return RemoteButton.up;
      case 20:
        return RemoteButton.down;
      case 21:
        return RemoteButton.left;
      case 22:
        return RemoteButton.right;

      // KEYCODE_DPAD_CENTER, ENTER, BUTTON_A, BUTTON_SELECT, NUMPAD_ENTER
      case 23:
      case 66:
      case 96:
      case 109:
      case 160:
        return RemoteButton.activate;

      // KEYCODE_BACK, ESCAPE, BUTTON_B
      case 4:
      case 97:
      case 111:
        return RemoteButton.back;

      // KEYCODE_MENU, SEARCH. Some Fire TV/OEM remotes expose their menu
      // button as SEARCH, so both should open the browser toolbar.
      case 82:
      case 84:
      case 256:
      case 257:
        return RemoteButton.menu;
      default:
        return RemoteButton.unknown;
    }
  }
}

class NativeRemoteKeyEvent {
  const NativeRemoteKeyEvent({
    required this.button,
    required this.isDown,
    required this.repeatCount,
  });

  final RemoteButton button;
  final bool isDown;
  final int repeatCount;

  bool get isRepeat => isDown && repeatCount > 0;
}

typedef NativeRemoteKeyHandler = bool Function(NativeRemoteKeyEvent event);

/// Bidirectional bridge to the Android activity.
///
/// Native -> Dart forwards remote keys captured by a focused WebView.
/// Dart -> native sends real pointer/hover events to that WebView. A real
/// Android touch event works on players and JavaScript apps that reject
/// synthetic `element.click()` calls.
class RemoteControlService {
  RemoteControlService._() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  static final RemoteControlService instance = RemoteControlService._();
  static const MethodChannel _channel = MethodChannel('tvbrowser/remote');

  NativeRemoteKeyHandler? keyHandler;

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    if (call.method != 'key') return false;
    final args = Map<Object?, Object?>.from(call.arguments as Map);
    final keyCode = (args['keyCode'] as num?)?.toInt() ?? -1;
    final action = (args['action'] as num?)?.toInt() ?? 1;
    final repeatCount = (args['repeatCount'] as num?)?.toInt() ?? 0;
    final event = NativeRemoteKeyEvent(
      button: RemoteButton.fromAndroidKeyCode(keyCode),
      isDown: action == 0,
      repeatCount: repeatCount,
    );
    return keyHandler?.call(event) ?? false;
  }

  /// Sends a native hover event at a normalized point in the visible WebView.
  Future<bool> movePointer(double x, double y) => _invokePointerMethod(
        'moveWebPointer',
        x,
        y,
      );

  /// Sends a native DOWN/UP touch sequence at a normalized point.
  Future<bool> tap(double x, double y) => _invokePointerMethod(
        'tapWebView',
        x,
        y,
      );

  /// Moves Android input focus back from a platform WebView to Flutter.
  Future<bool> focusFlutter() async {
    try {
      return await _channel.invokeMethod<bool>('focusFlutter') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<bool> _invokePointerMethod(String method, double x, double y) async {
    try {
      return await _channel.invokeMethod<bool>(method, <String, double>{
            'x': x.clamp(0.0, 1.0).toDouble(),
            'y': y.clamp(0.0, 1.0).toDouble(),
          }) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
