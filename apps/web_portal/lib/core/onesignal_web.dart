// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:js_interop';

/// Thin wrapper around the OneSignal Web SDK v16.
/// Call [loginUser] after the user authenticates so we can target
/// notifications by Supabase user-id and community.
class OneSignalWeb {
  OneSignalWeb._();

  /// Tag the current browser with the Supabase user ID so the Edge Function
  /// can target notifications to this user.
  static void loginUser(String userId) {
    _callOneSignal('login'.toJS, userId.toJS);
  }

  /// Remove the external user ID on sign-out.
  static void logoutUser() {
    _callOneSignal('logout'.toJS);
  }

  /// Store arbitrary tags (e.g. community_id, role) on the subscription.
  static void setTags(Map<String, String> tags) {
    final jsObj = tags.jsify();
    _callOneSignalUser('addTags'.toJS, jsObj);
  }

  // ── internal helpers ──────────────────────────────────────────────

  static void _callOneSignal(JSAny method, [JSAny? arg]) {
    _pushDeferred((JSAny oneSignal) {
      if (arg != null) {
        _jsCall2(oneSignal, method, arg);
      } else {
        _jsCall1(oneSignal, method);
      }
    }.toJS);
  }

  static void _callOneSignalUser(JSAny method, [JSAny? arg]) {
    _pushDeferred((JSAny oneSignal) {
      if (arg != null) {
        _jsCallUser2(oneSignal, method, arg);
      } else {
        _jsCallUser1(oneSignal, method);
      }
    }.toJS);
  }
}

@JS('window.OneSignalDeferred.push')
external void _pushDeferred(JSFunction callback);

@JS()
@staticInterop
class _OS {}

extension on _OS {
  // ignore: unused_element
  external void login(JSAny id);
  // ignore: unused_element
  external void logout();
}

// Simple eval-style calls through the deferred queue
void _jsCall1(JSAny os, JSAny method) {
  _eval1(os, method);
}

void _jsCall2(JSAny os, JSAny method, JSAny arg) {
  _eval2(os, method, arg);
}

void _jsCallUser1(JSAny os, JSAny method) {
  _evalUser1(os, method);
}

void _jsCallUser2(JSAny os, JSAny method, JSAny arg) {
  _evalUser2(os, method, arg);
}

@JS('Function("os","m","os[m]()")')
external JSFunction get _fn1;
void _eval1(JSAny os, JSAny m) => _fn1.callAsFunction(null, os, m);

@JS('Function("os","m","a","os[m](a)")')
external JSFunction get _fn2;
void _eval2(JSAny os, JSAny m, JSAny a) => _fn2.callAsFunction(null, os, m, a);

@JS('Function("os","m","os.User[m]()")')
external JSFunction get _fnU1;
void _evalUser1(JSAny os, JSAny m) => _fnU1.callAsFunction(null, os, m);

@JS('Function("os","m","a","os.User[m](a)")')
external JSFunction get _fnU2;
void _evalUser2(JSAny os, JSAny m, JSAny a) =>
    _fnU2.callAsFunction(null, os, m, a);
