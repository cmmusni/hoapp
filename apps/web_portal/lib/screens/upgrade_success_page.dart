import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Shown after a successful PayMongo plan upgrade or renewal payment.
class UpgradeSuccessPage extends StatelessWidget {
  const UpgradeSuccessPage({super.key});

  @override
  Widget build(BuildContext context) {
    final primary = const Color(0xFF2E5C3F);
    final session = Supabase.instance.client.auth.currentSession;
    final uri = GoRouterState.of(context).uri;
    final isRenewal = uri.queryParameters['renewal'] == 'true';

    return Scaffold(
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child:
                    Icon(Icons.check_circle_outline, color: primary, size: 64),
              ),
              const SizedBox(height: 24),
              Text(
                isRenewal ? 'Renewal Successful!' : 'Payment Successful!',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                isRenewal
                    ? 'Your Professional plan has been renewed for another 30 days. '
                        'All premium features will continue uninterrupted.'
                    : 'Your community has been upgraded to the Professional plan. '
                        'All premium features are now available.',
                style: const TextStyle(
                  fontSize: 15,
                  color: Color(0xFF6B7280),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  if (session != null) {
                    context.go('/select-community');
                  } else {
                    context.go('/login');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  session != null ? 'Go to Dashboard' : 'Login',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
