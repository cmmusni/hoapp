import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


/// Tour step model
class _TourStep {
  final IconData icon;
  final String title;
  final String description;

  const _TourStep({
    required this.icon,
    required this.title,
    required this.description,
  });
}

/// Full-screen overlay tour shown on first login.
/// Call [OnboardingTour.shouldShow] to check, then push the overlay.
class OnboardingTour extends StatefulWidget {
  final bool isStaff;
  final bool isAdmin;
  final bool isPro;
  final bool isGuard;
  final String communityName;
  final VoidCallback onDismiss;

  const OnboardingTour({
    super.key,
    required this.isStaff,
    required this.isAdmin,
    required this.isPro,
    required this.isGuard,
    required this.communityName,
    required this.onDismiss,
  });

  /// Returns the SharedPreferences key for a given user.
  static String _prefKey(String userId) => 'tour_completed_$userId';

  /// Check if the tour should be shown for this user.
  /// Checks local cache first, then falls back to database.
  static Future<bool> shouldShow(String userId) async {
    // Fast local check first
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_prefKey(userId)) ?? false) return false;

    // Check database
    try {
      final data = await Supabase.instance.client
          .from('user_preferences')
          .select('tour_completed_at')
          .eq('user_id', userId)
          .maybeSingle();

      if (data != null && data['tour_completed_at'] != null) {
        // Sync to local cache so future checks are fast
        await prefs.setBool(_prefKey(userId), true);
        return false;
      }
    } catch (_) {
      // If DB check fails, fall back to local-only
    }
    return true;
  }

  /// Mark the tour as completed for this user (saves to DB + local cache).
  static Future<void> markCompleted(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey(userId), true);

    try {
      await Supabase.instance.client.from('user_preferences').upsert({
        'user_id': userId,
        'tour_completed_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (_) {
      // Local cache already set — DB will sync next time
    }
  }

  /// Reset tour flag (for "Replay Tour").
  static Future<void> reset(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKey(userId));

    try {
      await Supabase.instance.client
          .from('user_preferences')
          .update({'tour_completed_at': null}).eq('user_id', userId);
    } catch (_) {
      // Local cache already cleared
    }
  }

  @override
  State<OnboardingTour> createState() => _OnboardingTourState();
}

class _OnboardingTourState extends State<OnboardingTour>
    with SingleTickerProviderStateMixin {
  int _currentStep = 0;
  late final List<_TourStep> _steps;
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _steps = _buildSteps();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  List<_TourStep> _buildSteps() {
    final steps = <_TourStep>[
      _TourStep(
        icon: Icons.waving_hand,
        title: 'Welcome to ${widget.communityName}!',
        description:
            'Let\'s take a quick tour of your community portal. This will only take a moment.',
      ),
      const _TourStep(
        icon: Icons.announcement_outlined,
        title: 'Announcements',
        description:
            'Stay updated with community-wide announcements. Important notices and updates from your HOA will appear here.',
      ),
      const _TourStep(
        icon: Icons.report_outlined,
        title: 'Violations',
        description:
            'View and report community violations. Track the status of reported issues and any associated fines.',
      ),
      const _TourStep(
        icon: Icons.support_outlined,
        title: 'Tickets',
        description:
            'Submit support tickets for maintenance requests, complaints, or general inquiries. Track responses from staff.',
      ),
    ];

    if (!widget.isGuard && widget.isPro) {
      steps.addAll(const [
        _TourStep(
          icon: Icons.pool_outlined,
          title: 'Amenity Reservations',
          description:
              'Browse and book community amenities — function halls, gyms, courts, and more. Check availability in real-time.',
        ),
        _TourStep(
          icon: Icons.payment_outlined,
          title: 'Billing & Payments',
          description:
              'View your invoices, upload proof of payment, and track payment history. Staff can verify and manage billing.',
        ),
      ]);
    }

    if (widget.isPro) {
      steps.addAll(const [
        _TourStep(
          icon: Icons.accessibility_outlined,
          title: 'Pool Access',
          description:
              'Register swimmers, manage pool entry, and track active sessions for your household.',
        ),
        _TourStep(
          icon: Icons.badge_outlined,
          title: 'Security Passes',
          description:
              'Request visitor, gate, contractor, and delivery passes. Approved passes come with QR codes for easy validation.',
        ),
      ]);
    }

    if (widget.isGuard && widget.isPro) {
      steps.add(const _TourStep(
        icon: Icons.qr_code_scanner,
        title: 'QR Scanner',
        description:
            'Scan and validate security pass QR codes at entry points. Instantly verify pass authenticity and status.',
      ));
    }

    if (widget.isStaff) {
      steps.addAll(const [
        _TourStep(
          icon: Icons.family_restroom_outlined,
          title: 'Households',
          description:
              'Manage units, households, and residents. View the community directory and household details.',
        ),
        _TourStep(
          icon: Icons.people_outlined,
          title: 'Manage Users',
          description:
              'Invite new members, assign roles, and manage user access across your community.',
        ),
      ]);
    }

    if (widget.isAdmin) {
      steps.add(const _TourStep(
        icon: Icons.settings_outlined,
        title: 'Settings',
        description:
            'Configure your community profile, preferences, and plan settings from the admin dashboard.',
      ));
    }

    steps.add(const _TourStep(
      icon: Icons.rocket_launch_outlined,
      title: 'You\'re All Set!',
      description:
          'That\'s the tour! You can replay it anytime from the user menu in the top-right corner. Enjoy managing your community!',
    ));

    return steps;
  }

  void _next() {
    if (_currentStep < _steps.length - 1) {
      setState(() => _currentStep++);
    } else {
      widget.onDismiss();
    }
  }

  void _prev() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  void _skip() {
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_currentStep];
    final isFirst = _currentStep == 0;
    final isLast = _currentStep == _steps.length - 1;
    final progress = (_currentStep + 1) / _steps.length;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Material(
        color: Colors.black54,
        child: Center(
          child: Container(
            constraints:
                BoxConstraints(maxWidth: isMobile ? screenWidth - 32 : 480),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Progress bar
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
                    minHeight: 4,
                  ),

                  Padding(
                    padding: EdgeInsets.all(isMobile ? 24 : 32),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: Column(
                        key: ValueKey(_currentStep),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Icon
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(step.icon, size: 48, color: Theme.of(context).colorScheme.primary),
                          ),
                          const SizedBox(height: 24),

                          // Title
                          Text(
                            step.title,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: isMobile ? 20 : 24,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1F2937),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Description
                          Text(
                            step.description,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: isMobile ? 14 : 15,
                              color: const Color(0xFF6B7280),
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Step counter
                          Text(
                            '${_currentStep + 1} of ${_steps.length}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade400,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Navigation buttons
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(24)),
                    ),
                    child: Row(
                      children: [
                        // Skip button
                        if (!isLast)
                          TextButton(
                            onPressed: _skip,
                            child: const Text('Skip Tour',
                                style: TextStyle(color: Color(0xFF9CA3AF))),
                          )
                        else
                          const SizedBox.shrink(),

                        const Spacer(),

                        // Back button
                        if (!isFirst)
                          TextButton(
                            onPressed: _prev,
                            child: Text('Back',
                                style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                          ),

                        const SizedBox(width: 8),

                        // Next / Finish button
                        ElevatedButton(
                          onPressed: _next,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 28, vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(
                            isLast
                                ? 'Get Started'
                                : isFirst
                                    ? 'Start Tour'
                                    : 'Next',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
