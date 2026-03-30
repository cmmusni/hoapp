import 'dart:js_interop';
import 'dart:ui';

@JS('window.EyeDropper')
external JSFunction? get _eyeDropperConstructor;

bool get isEyeDropperAvailable {
  try {
    return _eyeDropperConstructor != null;
  } catch (_) {
    return false;
  }
}

@JS('EyeDropper')
@staticInterop
class _EyeDropper {
  external factory _EyeDropper();
}

extension _EyeDropperExt on _EyeDropper {
  external JSPromise open();
}

@JS()
@staticInterop
class _DropperResult {}

extension _DropperResultExt on _DropperResult {
  external String get sRGBHex;
}

Future<Color?> pickColorFromScreen() async {
  if (!isEyeDropperAvailable) return null;
  try {
    final eyeDropper = _EyeDropper();
    final jsAny = await eyeDropper.open().toDart;
    final result = jsAny as _DropperResult;
    final hex = result.sRGBHex;
    final colorValue =
        int.parse(hex.replaceFirst('#', ''), radix: 16) | 0xFF000000;
    return Color(colorValue);
  } catch (_) {
    return null;
  }
}
