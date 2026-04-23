import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/firebase_messaging_service.dart';

/// Debug-only screen for verifying FCM push notification setup on physical
/// devices without needing adb. Shows:
///   - Current notification permission status
///   - The FCM token (with copy button)
///   - Whether a matching row exists in `notification_tokens`
///   - Last error from initialization, if any
class PushDebugScreen extends StatefulWidget {
  const PushDebugScreen({super.key});

  @override
  State<PushDebugScreen> createState() => _PushDebugScreenState();
}

class _PushDebugScreenState extends State<PushDebugScreen> {
  bool _loading = false;
  bool? _dbRowExists;
  String? _dbError;
  DateTime? _dbCreatedAt;
  String? _dbPlatform;

  @override
  void initState() {
    super.initState();
    _checkDbRow();
  }

  Future<void> _checkDbRow() async {
    setState(() {
      _loading = true;
      _dbError = null;
    });
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      final token = FirebaseMessagingService().currentToken;
      if (userId == null || token == null) {
        setState(() {
          _dbRowExists = false;
          _loading = false;
        });
        return;
      }
      final row = await client
          .from('notification_tokens')
          .select('platform, created_at')
          .eq('user_id', userId)
          .eq('token', token)
          .maybeSingle();
      setState(() {
        _dbRowExists = row != null;
        _dbPlatform = row?['platform'] as String?;
        final createdAt = row?['created_at'] as String?;
        _dbCreatedAt = createdAt != null ? DateTime.tryParse(createdAt) : null;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _dbError = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _refreshAll() async {
    await FirebaseMessagingService().refresh();
    await _checkDbRow();
  }

  @override
  Widget build(BuildContext context) {
    final svc = FirebaseMessagingService();
    final token = svc.currentToken;
    final perm = svc.permissionStatus?.name ?? 'unknown';
    final lastErr = svc.lastError;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Push Notifications Debug'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Re-register token',
            onPressed: _loading ? null : _refreshAll,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _StatusTile(
            label: 'Notification permission',
            value: perm,
            ok: perm == 'authorized' || perm == 'provisional',
          ),
          const SizedBox(height: 8),
          _StatusTile(
            label: 'FCM token obtained',
            value: token == null ? 'No' : 'Yes',
            ok: token != null,
          ),
          const SizedBox(height: 8),
          _StatusTile(
            label: 'Saved in notification_tokens',
            value: _loading
                ? 'Checking...'
                : (_dbRowExists == true ? 'Yes' : 'No'),
            ok: _dbRowExists == true,
          ),
          if (_dbPlatform != null) ...[
            const SizedBox(height: 4),
            Text('  platform: $_dbPlatform',
                style: Theme.of(context).textTheme.bodySmall),
          ],
          if (_dbCreatedAt != null) ...[
            const SizedBox(height: 4),
            Text('  created_at: ${_dbCreatedAt!.toLocal()}',
                style: Theme.of(context).textTheme.bodySmall),
          ],
          if (_dbError != null) ...[
            const SizedBox(height: 8),
            Text('DB lookup error: $_dbError',
                style: const TextStyle(color: Colors.red)),
          ],
          const Divider(height: 32),
          Text('FCM Token', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: SelectableText(
              token ?? '(no token yet — tap refresh)',
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.copy),
                label: const Text('Copy token'),
                onPressed: token == null
                    ? null
                    : () async {
                        await Clipboard.setData(ClipboardData(text: token));
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Token copied to clipboard')),
                        );
                      },
              ),
            ],
          ),
          if (lastErr != null) ...[
            const Divider(height: 32),
            Text('Last error', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: SelectableText(lastErr,
                  style: const TextStyle(color: Colors.red)),
            ),
          ],
          const Divider(height: 32),
          const Text(
            'If "Saved in notification_tokens" is No on the Play Store install '
            'but Yes on a sideloaded build, the Play App Signing SHA-1/SHA-256 '
            'is most likely missing from your Firebase Android app. Add both '
            'fingerprints in Firebase Console → Project settings → Your app, '
            'then clear app data and log in again.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class _StatusTile extends StatelessWidget {
  final String label;
  final String value;
  final bool ok;
  const _StatusTile(
      {required this.label, required this.value, required this.ok});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(ok ? Icons.check_circle : Icons.cancel,
            color: ok ? Colors.green : Colors.red),
        const SizedBox(width: 8),
        Expanded(child: Text(label)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}
