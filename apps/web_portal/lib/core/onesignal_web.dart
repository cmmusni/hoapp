// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:js' as js;

/// Thin wrapper around the OneSignal Web SDK v16.
/// Call [loginUser] after the user authenticates so we can target
/// notifications by Supabase user-id and community.
class OneSignalWeb {
  OneSignalWeb._();

  /// Tag the current browser with the Supabase user ID so the Edge Function
  /// can target notifications to this user.
  static void loginUser(String userId) {
    _pushDeferred((js.JsObject oneSignal) {
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

  // ── internal helpers ──────────────────────────────────────────────

  static void _pushDeferred(void Function(js.JsObject oneSignal) callback) {
    final deferred = js.context['OneSignalDeferred'] as js.JsArray?;
    if (deferred == null) {
      print('OneSignal: OneSignalDeferred not found on window');
      return;
    }
    print('OneSignal: pushing to deferred queue');
    deferred.add(js.JsFunction.withThis((thisArg, oneSignal) {
      callback(oneSignal as js.JsObject);
    }));
  }
}
