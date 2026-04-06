import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'marketing_nav_bar.dart';
import 'cookie_consent_banner.dart';

const _brand = Color(0xFF2E5C3F);
const _brandLight = Color(0xFF3A7A50);
const _dark = Color(0xFF1F2937);
const _muted = Color(0xFF6B7280);

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideUp;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeIn = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 600;
    final isNarrow = width < 900;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage(
                    'assets/images/hoap-landing-buildings-background.png'),
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 72),

                  // ═══ HERO ═══
                  FadeTransition(
                    opacity: _fadeIn,
                    child: SlideTransition(
                      position: _slideUp,
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 20 : 48,
                          vertical: isMobile ? 48 : 80,
                        ),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF2E5C3F), Color(0xFF3A7A50)],
                          ),
                        ),
                        child: Column(
                          children: [
                            Image.asset(
                              'assets/images/hoapp-logo.png',
                              height: isMobile ? 64 : 90,
                              color: Colors.white,
                              errorBuilder: (_, __, ___) => Text(
                                'HOApp',
                                style: TextStyle(
                                  fontSize: isMobile ? 40 : 56,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Smart HOA Management\nfor Modern Communities',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: isMobile ? 28 : 44,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Announcements, billing, violations, amenities, security passes — all in one platform.\nSimplify operations and delight your residents.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: isMobile ? 14 : 17,
                                color: Colors.white.withOpacity(0.9),
                                height: 1.6,
                              ),
                            ),
                            const SizedBox(height: 32),
                            Wrap(
                              spacing: 16,
                              runSpacing: 12,
                              alignment: WrapAlignment.center,
                              children: [
                                ElevatedButton(
                                  onPressed: () => context.go('/pricing'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: _brand,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: isMobile ? 28 : 36,
                                      vertical: isMobile ? 14 : 18,
                                    ),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(30)),
                                    elevation: 4,
                                  ),
                                  child: const Text(
                                    'Get Started Free',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ),
                                OutlinedButton(
                                  onPressed: () => context.go('/features'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: isMobile ? 28 : 36,
                                      vertical: isMobile ? 14 : 18,
                                    ),
                                    side: const BorderSide(
                                        color: Colors.white70, width: 2),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(30)),
                                  ),
                                  child: const Text(
                                    'Explore Features',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ═══ STATS BAR ═══
                  Container(
                    width: double.infinity,
                    color: const Color(0xFF243F2F),
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 16 : 48,
                      vertical: isMobile ? 20 : 28,
                    ),
                    child: Wrap(
                      alignment: WrapAlignment.spaceEvenly,
                      spacing: isMobile ? 24 : 60,
                      runSpacing: 16,
                      children: const [
                        _StatItem(value: '99.9%', label: 'Uptime'),
                        _StatItem(value: '256-bit', label: 'Encryption'),
                        _StatItem(value: '24/7', label: 'Monitoring'),
                        _StatItem(value: '20+', label: 'Features'),
                      ],
                    ),
                  ),

                  // ═══ FEATURE CARDS ═══
                  Container(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 16 : 32,
                      vertical: isMobile ? 40 : 64,
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Everything Your HOA Needs',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: isMobile ? 24 : 32,
                            fontWeight: FontWeight.bold,
                            color: _dark,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'From daily operations to resident engagement — we\'ve got you covered.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: isMobile ? 14 : 16,
                            color: _muted,
                          ),
                        ),
                        const SizedBox(height: 48),

                        // ── Core Operations ──
                        _FeatureCategoryHeader(
                          icon: Icons.dashboard_outlined,
                          title: 'Core Operations',
                          isMobile: isMobile,
                        ),
                        const SizedBox(height: 20),
                        ..._buildFeatureGrid(
                          isMobile: isMobile,
                          isNarrow: isNarrow,
                          features: _coreFeatures,
                        ),
                        const SizedBox(height: 40),

                        // ── Community Engagement ──
                        _FeatureCategoryHeader(
                          icon: Icons.people_outline,
                          title: 'Community Engagement',
                          isMobile: isMobile,
                        ),
                        const SizedBox(height: 20),
                        ..._buildFeatureGrid(
                          isMobile: isMobile,
                          isNarrow: isNarrow,
                          features: _engagementFeatures,
                        ),
                        const SizedBox(height: 40),

                        // ── Security & Access ──
                        _FeatureCategoryHeader(
                          icon: Icons.shield_outlined,
                          title: 'Security & Access',
                          isMobile: isMobile,
                        ),
                        const SizedBox(height: 20),
                        ..._buildFeatureGrid(
                          isMobile: isMobile,
                          isNarrow: isNarrow,
                          features: _securityFeatures,
                        ),
                        const SizedBox(height: 40),

                        // ── Finance & Analytics ──
                        _FeatureCategoryHeader(
                          icon: Icons.insights_outlined,
                          title: 'Finance & Analytics',
                          isMobile: isMobile,
                        ),
                        const SizedBox(height: 20),
                        ..._buildFeatureGrid(
                          isMobile: isMobile,
                          isNarrow: isNarrow,
                          features: _financeFeatures,
                        ),
                        const SizedBox(height: 40),

                        // ── Platform & Experience ──
                        _FeatureCategoryHeader(
                          icon: Icons.devices_outlined,
                          title: 'Platform & Experience',
                          isMobile: isMobile,
                        ),
                        const SizedBox(height: 20),
                        ..._buildFeatureGrid(
                          isMobile: isMobile,
                          isNarrow: isNarrow,
                          features: _platformFeatures,
                        ),
                        const SizedBox(height: 36),

                        OutlinedButton.icon(
                          onPressed: () => context.go('/features'),
                          icon: const Icon(Icons.arrow_forward, size: 18),
                          label: const Text('Explore Features in Detail'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _brand,
                            padding: EdgeInsets.symmetric(
                              horizontal: isMobile ? 24 : 32,
                              vertical: isMobile ? 12 : 16,
                            ),
                            side: const BorderSide(color: _brand, width: 2),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30)),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ═══ HOW IT WORKS ═══
                  Container(
                    width: double.infinity,
                    color: const Color(0xFFF7FAF8),
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 16 : 32,
                      vertical: isMobile ? 40 : 64,
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Get Started in 3 Easy Steps',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: isMobile ? 24 : 32,
                            fontWeight: FontWeight.bold,
                            color: _dark,
                          ),
                        ),
                        const SizedBox(height: 36),
                        Container(
                          constraints: const BoxConstraints(maxWidth: 1000),
                          child: isMobile
                              ? Column(
                                  children: const [
                                    _StepCard(
                                      step: '1',
                                      icon: Icons.person_add_outlined,
                                      title: 'Sign Up',
                                      description:
                                          'Create your free account in seconds. No credit card required.',
                                    ),
                                    SizedBox(height: 16),
                                    _StepCard(
                                      step: '2',
                                      icon: Icons.domain_add_outlined,
                                      title: 'Set Up Your Community',
                                      description:
                                          'Add your HOA details, invite board members, and configure billing.',
                                    ),
                                    SizedBox(height: 16),
                                    _StepCard(
                                      step: '3',
                                      icon: Icons.rocket_launch_outlined,
                                      title: 'Manage & Grow',
                                      description:
                                          'Post announcements, collect dues, manage amenities — all in one place.',
                                    ),
                                  ],
                                )
                              : IntrinsicHeight(
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: const [
                                      Expanded(
                                        child: _StepCard(
                                          step: '1',
                                          icon: Icons.person_add_outlined,
                                          title: 'Sign Up',
                                          description:
                                              'Create your free account in seconds. No credit card required.',
                                        ),
                                      ),
                                      SizedBox(width: 20),
                                      Expanded(
                                        child: _StepCard(
                                          step: '2',
                                          icon: Icons.domain_add_outlined,
                                          title: 'Set Up Your Community',
                                          description:
                                              'Add your HOA details, invite board members, and configure billing.',
                                        ),
                                      ),
                                      SizedBox(width: 20),
                                      Expanded(
                                        child: _StepCard(
                                          step: '3',
                                          icon: Icons.rocket_launch_outlined,
                                          title: 'Manage & Grow',
                                          description:
                                              'Post announcements, collect dues, manage amenities — all in one place.',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),

                  // ═══ TESTIMONIAL ═══
                  Container(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 16 : 32,
                      vertical: isMobile ? 40 : 64,
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Trusted By Communities',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: isMobile ? 24 : 32,
                            fontWeight: FontWeight.bold,
                            color: _dark,
                          ),
                        ),
                        const SizedBox(height: 32),
                        Container(
                          padding: EdgeInsets.all(isMobile ? 24 : 36),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.92),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.07),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.format_quote_rounded,
                                  size: 40, color: _brand.withOpacity(0.25)),
                              const SizedBox(height: 16),
                              Text(
                                '"HOApp transformed the way we manage our community. Billing collection improved, announcements reach everyone instantly, and residents love the mobile access. It\'s the all-in-one solution we\'ve been looking for."',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: isMobile ? 15 : 18,
                                  color: _dark,
                                  fontStyle: FontStyle.italic,
                                  height: 1.7,
                                ),
                              ),
                              const SizedBox(height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(30),
                                    child: Image.asset(
                                      'assets/images/trusted-by-eleve.png',
                                      width: 48,
                                      height: 48,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          CircleAvatar(
                                        backgroundColor:
                                            _brand.withOpacity(0.1),
                                        radius: 24,
                                        child: const Icon(Icons.business,
                                            color: _brand),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Elevé Homes Camarin',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: _dark,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Caloocan City, Philippines',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: _muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ═══ FINAL CTA ═══
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 20 : 48,
                      vertical: isMobile ? 48 : 72,
                    ),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF2E5C3F), Color(0xFF3A7A50)],
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Ready to Simplify Your Community?',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: isMobile ? 24 : 36,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Join homeowners associations who trust HOApp to manage their communities. Start free today.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: isMobile ? 14 : 17,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                        const SizedBox(height: 28),
                        Wrap(
                          spacing: 16,
                          runSpacing: 12,
                          alignment: WrapAlignment.center,
                          children: [
                            ElevatedButton(
                              onPressed: () => context.go('/pricing'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: _brand,
                                padding: EdgeInsets.symmetric(
                                  horizontal: isMobile ? 28 : 40,
                                  vertical: isMobile ? 14 : 18,
                                ),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30)),
                                elevation: 4,
                              ),
                              child: const Text('Get Started Free',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700)),
                            ),
                            OutlinedButton(
                              onPressed: () => context.go('/login'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(
                                  horizontal: isMobile ? 28 : 40,
                                  vertical: isMobile ? 14 : 18,
                                ),
                                side: const BorderSide(
                                    color: Colors.white70, width: 2),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30)),
                              ),
                              child: const Text('Login',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Footer
                  const MarketingFooter(),
                ],
              ),
            ),
          ),

          // Fixed navigation bar at top
          const MarketingNavBar(activePage: 'Home'),

          // Cookie consent banner
          const CookieConsentBanner(),

          // Chatbot
          ChatbotWidget(
            currentPage: 'landing',
            onNavigate: (route) => context.go(route),
          ),
        ],
      ),
    );
  }
}

// ═══ Feature Data (All 20 features, categorized) ══════════

class _FeatureData {
  final IconData icon;
  final String title;
  final String description;
  const _FeatureData(this.icon, this.title, this.description);
}

const _coreFeatures = <_FeatureData>[
  _FeatureData(Icons.campaign_outlined, 'Announcements',
      'Broadcast community-wide news with rich text, pinned notices, and attached images or documents.'),
  _FeatureData(Icons.credit_card_outlined, 'Billing & Payments',
      'Generate invoices, track payments, upload proof of payment, and verify — with a complete audit trail.'),
  _FeatureData(Icons.home_outlined, 'Household Management',
      'Manage units, residents, and move-in/move-out records with a structured community directory.'),
  _FeatureData(Icons.gavel_outlined, 'Violation Tracking',
      'Report violations with photos, assign fines, and track resolution status end-to-end.'),
];

const _engagementFeatures = <_FeatureData>[
  _FeatureData(Icons.confirmation_number_outlined, 'Support Tickets',
      'Residents submit maintenance requests and complaints — staff track, reply, and resolve.'),
  _FeatureData(Icons.feedback_outlined, 'Feedback',
      'Collect, manage, and resolve resident feedback to continuously improve community services.'),
  _FeatureData(Icons.event_seat_outlined, 'Amenity Booking',
      'Browse amenities, check availability, and book reservations for function halls, courts, and more.'),
  _FeatureData(Icons.pool_outlined, 'Pool Access',
      'Register swimmers, manage pool entry sessions, and handle multi-member household access.'),
];

const _securityFeatures = <_FeatureData>[
  _FeatureData(Icons.qr_code_2_outlined, 'Security QR Passes',
      'Request visitor, gate, and delivery passes. Staff approve with QR codes — guards scan instantly.'),
  _FeatureData(Icons.qr_code_scanner_outlined, 'QR Pass Scanner',
      'Guards and staff scan QR-coded passes at gates for instant validation and automated entry logging.'),
  _FeatureData(Icons.people_outlined, 'User Management',
      'Invite and manage members with role-based access — admins, officers, guards, and residents.'),
  _FeatureData(Icons.notifications_outlined, 'Notifications Hub',
      'Aggregated view of all pending items — payments, tickets, violations, and bookings — in one place.'),
];

const _financeFeatures = <_FeatureData>[
  _FeatureData(Icons.account_balance_wallet_outlined, 'Expense Tracker',
      'Track community expenses by category with filtering and real-time charts for full spending transparency.'),
  _FeatureData(Icons.bar_chart_outlined, 'Financial Reports',
      'View comprehensive income vs. expense analytics with interactive charts over configurable periods.'),
  _FeatureData(Icons.settings_outlined, 'Community Settings',
      'Configure community profile, branding colors, and preferences from a centralized dashboard.'),
];

const _platformFeatures = <_FeatureData>[
  _FeatureData(Icons.phone_iphone_outlined, 'Mobile App',
      'Access your community on the go with native iOS and Android apps — pay bills, scan passes, and more.'),
  _FeatureData(Icons.hub_outlined, 'Multi-Community Support',
      'Manage or belong to multiple communities from a single account. Switch between them instantly.'),
  _FeatureData(Icons.smart_toy_outlined, 'AI Chatbot Assistant',
      'Get instant help with a built-in AI assistant that provides contextual guidance based on your role.'),
  _FeatureData(Icons.tour_outlined, 'Guided Onboarding',
      'Interactive walkthrough for new users. Replay anytime to learn about all portal features.'),
  _FeatureData(Icons.devices_outlined, 'Fully Responsive',
      'The entire portal is optimized for desktops, tablets, and smartphones — manage from any device.'),
];

List<Widget> _buildFeatureGrid({
  required bool isMobile,
  required bool isNarrow,
  required List<_FeatureData> features,
}) {
  final columns = isMobile
      ? 1
      : isNarrow
          ? 2
          : 3;
  final rows = <Widget>[];

  for (var i = 0; i < features.length; i += columns) {
    final rowChildren = <Widget>[];
    for (var j = 0; j < columns && i + j < features.length; j++) {
      if (j > 0) rowChildren.add(const SizedBox(width: 20));
      final f = features[i + j];
      rowChildren.add(Expanded(
        child: _FeatureCard(
            icon: f.icon, title: f.title, description: f.description),
      ));
    }
    for (var j = features.length - i; j < columns; j++) {
      rowChildren.add(const SizedBox(width: 20));
      rowChildren.add(const Expanded(child: SizedBox()));
    }
    if (i > 0) rows.add(const SizedBox(height: 20));
    rows.add(IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: rowChildren,
      ),
    ));
  }
  return rows;
}

// ═══ Feature Card ══════════════════════════════════════════

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _brand.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 28, color: _brand),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: _dark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              fontSize: 14,
              color: _muted,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══ Stat Item ═════════════════════════════════════════════

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  const _StatItem({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.white.withOpacity(0.7),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ═══ Feature Category Header ═══════════════════════════════

class _FeatureCategoryHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isMobile;

  const _FeatureCategoryHeader({
    required this.icon,
    required this.title,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_brand, _brandLight],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: isMobile ? 18 : 22,
            fontWeight: FontWeight.w800,
            color: _dark,
          ),
        ),
      ],
    );
  }
}

// ═══ Step Card ═════════════════════════════════════════════

class _StepCard extends StatelessWidget {
  final String step;
  final IconData icon;
  final String title;
  final String description;

  const _StepCard({
    required this.step,
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_brand, _brandLight],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                step,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Icon(icon, size: 36, color: _brand),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _dark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: _muted,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
