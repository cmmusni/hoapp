// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:js' as js;

/// Thin wrapper around the OneSignal Web SDK v16.
/// Call [loginUser] after the user authenticates so we can target
/// notifications by Supabase user-id and community.
class OneSignalWeb {
  OneSignalWeb._();

  /// Returns true when running on localhost — OneSignal SDK is
  /// domain-restricted to hoapp.net and will not initialise locally.
  static bool get _isLocalhost {
    final host = html.window.location.hostname ?? '';
    return host == 'localhost' || host == '127.0.0.1';
  }

  /// Tag the current browser with the Supabase user ID so the Edge Function
  /// can target notifications to this user.
  /// Calls logout first to release any stale external_id alias and avoid
  /// 409 "Alias claimed by another User" conflicts.
  static void loginUser(String userId) {
    _pushDeferred((js.JsObject oneSignal) {
      oneSignal.callMethod('logout', []);
      oneSignal.callMethod('login', [userId]);
    });
  }

  /// Remove the external user ID on sign-out.
  static void logoutUser() {
    _pushDeferred((js.JsObject oneSignal) {
      oneSignal.callMethod('logout', []);
    });
  }

  /// Store arbitrary tags (e.g. community_id, role) on the subscription.
  static void setTags(Map<String, String> tags) {
    _pushDeferred((js.JsObject oneSignal) {
      final user = oneSignal['User'] as js.JsObject;
      user.callMethod('addTags', [js.JsObject.jsify(tags)]);
    });
  }

  /// Request push notification permission from the browser.
  static void requestPermission() {
    _pushDeferred((js.JsObject oneSignal) {
      final notifications = oneSignal['Notifications'] as js.JsObject;
      notifications.callMethod('requestPermission', []);
    });
  }

  /// Check if the user has granted notification permission.
  static bool get permissionGranted {
    if (_isLocalhost) return false;
    try {
      final oneSignal = js.context['OneSignal'];
      if (oneSignal == null) return false;
      final notifications =
          (oneSignal as js.JsObject)['Notifications'] as js.JsObject?;
      if (notifications == null) return false;
      final permission = notifications['permission'];
      return permission == true;
    } catch (_) {
      return false;
    }
  }

  // ── internal helpers ──────────────────────────────────────────────

  static void _pushDeferred(void Function(js.JsObject oneSignal) callback) {
    if (_isLocalhost) {
      print('OneSignal: skipped on localhost');
      return;
    }
    final deferred = js.context['OneSignalDeferred'] as js.JsArray?;
    if (deferred == null) {
      print('OneSignal: OneSignalDeferred not found on window');
      return;
    }
    print('OneSignal: pushing to deferred queue');
    deferred.add(js.JsFunction.withThis((thisArg, [dynamic osArg]) {
      try {
        // Prefer the callback argument; fall back to window.OneSignal
        final oneSignal =
            (osArg as js.JsObject?) ?? js.context['OneSignal'] as js.JsObject?;
        if (oneSignal == null) {
          print('OneSignal: SDK not available');
          return;
        }
        callback(oneSignal);
      } catch (e) {
        print('OneSignal deferred callback error: $e');
      }
    }));
  }
}
