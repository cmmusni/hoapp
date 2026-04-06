import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'marketing_nav_bar.dart';

const _brand = Color(0xFF2E5C3F);
const _brandLight = Color(0xFF3A7A50);
const _dark = Color(0xFF1F2937);
const _muted = Color(0xFF6B7280);
const _lightBg = Color(0xFFF9FAFB);

// ─── Feature data model ────────────────────────────────────

class _FeatureData {
  final IconData icon;
  final String title;
  final String description;
  final String? imagePath;
  final String? category;

  const _FeatureData({
    required this.icon,
    required this.title,
    required this.description,
    this.imagePath,
    this.category,
  });
}

const _features = <_FeatureData>[
  // ── Core Operations ──
  _FeatureData(
    icon: Icons.campaign_outlined,
    title: 'Announcements',
    description:
        'Broadcast community-wide announcements with rich text. Pin important notices and attach images or documents to keep everyone informed.',
    imagePath: 'assets/images/features/announcements.png',
    category: 'Core Operations',
  ),
  _FeatureData(
    icon: Icons.credit_card_outlined,
    title: 'Billing & Payments',
    description:
        'Generate invoices, track payments, upload proof of payment, and let staff verify or reject — all with a complete audit trail.',
    imagePath: 'assets/images/features/billing.png',
    category: 'Core Operations',
  ),
  _FeatureData(
    icon: Icons.home_outlined,
    title: 'Households',
    description:
        'Manage units, households, and residents. Invite members, assign roles, and keep a structured directory of your community.',
    imagePath: 'assets/images/features/households.png',
    category: 'Core Operations',
  ),
  _FeatureData(
    icon: Icons.gavel_outlined,
    title: 'Violations',
    description:
        'Report and track community violations with photos. Staff can review, fine, and resolve cases with clear status tracking.',
    imagePath: 'assets/images/features/violations.png',
    category: 'Core Operations',
  ),

  // ── Community Engagement ──
  _FeatureData(
    icon: Icons.confirmation_number_outlined,
    title: 'Tickets',
    description:
        'Resident support ticket system for maintenance requests, complaints, and inquiries — with status updates and staff replies.',
    imagePath: 'assets/images/features/tickets.png',
    category: 'Community Engagement',
  ),
  _FeatureData(
    icon: Icons.feedback_outlined,
    title: 'Feedback',
    description:
        'Collect and manage resident feedback. Track open and resolved submissions to continuously improve community services.',
    imagePath: 'assets/images/features/feedback.png',
    category: 'Community Engagement',
  ),
  _FeatureData(
    icon: Icons.event_seat_outlined,
    title: 'Amenity Reservations',
    description:
        'Browse community amenities, check availability, and book reservations — from function halls to gyms and courts.',
    imagePath: 'assets/images/features/amenities-reservation.png',
    category: 'Community Engagement',
  ),
  _FeatureData(
    icon: Icons.pool_outlined,
    title: 'Pool Access',
    description:
        'Register swimmers, manage pool entry, and track active sessions. Designed for multi-member households and guest access.',
    imagePath: 'assets/images/features/pool-access.png',
    category: 'Community Engagement',
  ),

  // ── Security & Access ──
  _FeatureData(
    icon: Icons.qr_code_2_outlined,
    title: 'Security Passes',
    description:
        'Request visitor, gate, contractor, and delivery passes. Staff approve with QR codes — guards scan for instant validation.',
    imagePath: 'assets/images/features/security-pass.png',
    category: 'Security & Access',
  ),
  _FeatureData(
    icon: Icons.qr_code_scanner_outlined,
    title: 'QR Pass Scanner',
    description:
        'Guards and staff can scan QR-coded passes at gates and entry points for instant validation and automated entry logging.',
    imagePath: 'assets/images/features/qr-scanner.png',
    category: 'Security & Access',
  ),
  _FeatureData(
    icon: Icons.people_outlined,
    title: 'User Management',
    description:
        'Invite and manage community members with role-based access — admins, HOA officers, guards, maintenance, and residents.',
    imagePath: 'assets/images/features/manage-users.png',
    category: 'Security & Access',
  ),
  _FeatureData(
    icon: Icons.notifications_outlined,
    title: 'Notifications Hub',
    description:
        'Aggregated view of all pending items — payments, tickets, violations, feedback, bookings, and announcements — in one place.',
    imagePath: 'assets/images/features/notifications.png',
    category: 'Security & Access',
  ),

  // ── Finance & Analytics ──
  _FeatureData(
    icon: Icons.account_balance_wallet_outlined,
    title: 'Expense Tracker',
    description:
        'Track community expenses by category with filtering and real-time charts. Maintain full transparency over HOA spending.',
    imagePath: 'assets/images/features/community-expenses.png',
    category: 'Finance & Analytics',
  ),
  _FeatureData(
    icon: Icons.bar_chart_outlined,
    title: 'Financial Reports',
    description:
        'View comprehensive income vs. expense analytics with interactive charts over configurable time periods.',
    imagePath: 'assets/images/features/financial-reports.png',
    category: 'Finance & Analytics',
  ),
  _FeatureData(
    icon: Icons.settings_outlined,
    title: 'Community Settings',
    description:
        'Configure your community profile, branding, and preferences from a centralized settings dashboard.',
    imagePath: 'assets/images/features/community-settings.png',
    category: 'Finance & Analytics',
  ),

  // ── Platform & Experience ──
  _FeatureData(
    icon: Icons.phone_iphone_outlined,
    title: 'Mobile App',
    description:
        'Access your community on the go with the HOApp mobile app for iOS and Android — check announcements, pay bills, and scan QR passes from your phone.',
    imagePath: 'assets/images/features/mobile-app.png',
    category: 'Platform & Experience',
  ),
  _FeatureData(
    icon: Icons.hub_outlined,
    title: 'Multi-Community Support',
    description:
        'Manage or belong to multiple communities from a single account. Easily switch between communities from the portal.',
    imagePath: 'assets/images/features/select-community.png',
    category: 'Platform & Experience',
  ),
  _FeatureData(
    icon: Icons.smart_toy_outlined,
    title: 'AI Chatbot Assistant',
    description:
        'Get instant help with a built-in AI assistant that provides contextual guidance based on your current page and role.',
    category: 'Platform & Experience',
    imagePath: 'assets/images/features/ai-chatbot.png',
  ),
  _FeatureData(
    icon: Icons.tour_outlined,
    title: 'Onboarding Tour',
    description:
        'Interactive guided walkthrough for new users. Replay anytime from the menu to learn about all portal features.',
    category: 'Platform & Experience',
    imagePath: 'assets/images/features/guided-tour.png',
  ),
  _FeatureData(
    icon: Icons.devices_outlined,
    title: 'Mobile Responsive',
    description:
        'The entire web portal is fully responsive — optimized for desktops, tablets, and smartphones so you can manage your community from any device.',
    category: 'Platform & Experience',
    imagePath: 'assets/images/features/mobile-responsive.png',
  ),
];

// ─── Features Page ─────────────────────────────────────────

class FeaturesPage extends StatelessWidget {
  const FeaturesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 600;

    // Group features by category, preserving order
    final categories = <String>[];
    final grouped = <String, List<_FeatureData>>{};
    for (final f in _features) {
      final cat = f.category ?? 'More';
      if (!grouped.containsKey(cat)) {
        categories.add(cat);
        grouped[cat] = [];
      }
      grouped[cat]!.add(f);
    }

    // Category icons
    const categoryIcons = <String, IconData>{
      'Core Operations': Icons.dashboard_outlined,
      'Community Engagement': Icons.people_outline,
      'Security & Access': Icons.shield_outlined,
      'Finance & Analytics': Icons.insights_outlined,
      'Platform & Experience': Icons.devices_outlined,
    };

    // Category subtitles
    const categorySubs = <String, String>{
      'Core Operations':
          'Essential tools for managing announcements, billing, households, and violations.',
      'Community Engagement':
          'Keep residents connected with tickets, feedback, amenities, and pool access.',
      'Security & Access':
          'Protect your community with QR passes, role-based access, and real-time notifications.',
      'Finance & Analytics':
          'Full transparency with expense tracking, financial reports, and community settings.',
      'Platform & Experience':
          'Access HOApp anywhere — mobile apps, AI assistance, and responsive design.',
    };

    int showcaseIndex = 0;

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

                  // ── Hero Header ──
                  _HeroHeader(
                      isMobile: isMobile, featureCount: _features.length),

                  // ── Stats Bar ──
                  Container(
                    width: double.infinity,
                    color: const Color(0xFF243F2F),
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 16 : 48,
                      vertical: isMobile ? 16 : 22,
                    ),
                    child: Wrap(
                      alignment: WrapAlignment.spaceEvenly,
                      spacing: isMobile ? 24 : 60,
                      runSpacing: 12,
                      children: [
                        _MiniStat(
                            value: '${_features.length}', label: 'Features'),
                        _MiniStat(
                            value: '${categories.length}', label: 'Categories'),
                        const _MiniStat(
                            value: 'Web + Mobile', label: 'Platforms'),
                        const _MiniStat(value: 'Free', label: 'Starter Plan'),
                      ],
                    ),
                  ),

                  // ── Category Sections ──
                  for (int ci = 0; ci < categories.length; ci++) ...[
                    // Category Header
                    _CategoryHeader(
                      icon: categoryIcons[categories[ci]] ?? Icons.star_outline,
                      title: categories[ci],
                      subtitle: categorySubs[categories[ci]] ?? '',
                      isMobile: isMobile,
                      index: ci,
                    ),

                    // Features in this category
                    for (final feature in grouped[categories[ci]]!)
                      Builder(builder: (context) {
                        final idx = showcaseIndex++;
                        if (feature.imagePath != null) {
                          return _FeatureShowcaseRow(
                            data: feature,
                            imageOnLeft: idx.isEven,
                            isMobile: isMobile,
                            index: idx,
                          );
                        } else {
                          return _FeatureCardRow(
                            data: feature,
                            isMobile: isMobile,
                            index: idx,
                          );
                        }
                      }),
                  ],

                  // ── CTA Section ──
                  _CtaSection(isMobile: isMobile),

                  const MarketingFooter(),
                ],
              ),
            ),
          ),
          const MarketingNavBar(activePage: 'Features'),
        ],
      ),
    );
  }
}

// ─── Hero Header ───────────────────────────────────────────

class _HeroHeader extends StatelessWidget {
  final bool isMobile;
  final int featureCount;
  const _HeroHeader({required this.isMobile, required this.featureCount});

  @override
  Widget build(BuildContext context) {
    return Container(
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$featureCount BUILT-IN FEATURES',
              style: TextStyle(
                fontSize: isMobile ? 11 : 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 2,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Everything Your\nCommunity Needs',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isMobile ? 32 : 48,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 48),
            child: Text(
              'From billing to security passes, manage every aspect of your HOA with a single, beautiful platform.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isMobile ? 15 : 18,
                color: Colors.white.withOpacity(0.9),
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 28),
          Container(
            width: 48,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Feature Showcase Row (image + text, alternating) ──────

class _FeatureShowcaseRow extends StatefulWidget {
  final _FeatureData data;
  final bool imageOnLeft;
  final bool isMobile;
  final int index;

  const _FeatureShowcaseRow({
    required this.data,
    required this.imageOnLeft,
    required this.isMobile,
    required this.index,
  });

  @override
  State<_FeatureShowcaseRow> createState() => _FeatureShowcaseRowState();
}

class _FeatureShowcaseRowState extends State<_FeatureShowcaseRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final useAltBg = widget.index.isOdd;

    final imageWidget = MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        transform: _hovered
            ? (Matrix4.identity()..translate(0.0, -6.0))
            : Matrix4.identity(),
        child: Center(
          child: Container(
            constraints: BoxConstraints(maxHeight: widget.isMobile ? 400 : 500),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: _hovered
                      ? _brand.withOpacity(0.2)
                      : Colors.black.withOpacity(0.1),
                  blurRadius: _hovered ? 32 : 20,
                  offset: Offset(0, _hovered ? 12 : 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                widget.data.imagePath!,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );

    final textWidget = Column(
      crossAxisAlignment: widget.isMobile
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _brand.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(widget.data.icon, size: 28, color: _brand),
        ),
        const SizedBox(height: 18),
        Text(
          widget.data.title,
          textAlign: widget.isMobile ? TextAlign.center : TextAlign.start,
          style: TextStyle(
            fontSize: widget.isMobile ? 24 : 28,
            fontWeight: FontWeight.w800,
            color: _dark,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          widget.data.description,
          textAlign: widget.isMobile ? TextAlign.center : TextAlign.start,
          style: TextStyle(
            fontSize: widget.isMobile ? 14 : 16,
            color: _muted,
            height: 1.7,
          ),
        ),
      ],
    );

    final content = widget.isMobile
        ? Column(
            children: [
              imageWidget,
              const SizedBox(height: 28),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: textWidget,
              ),
            ],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: widget.imageOnLeft
                ? [
                    Expanded(flex: 6, child: imageWidget),
                    const SizedBox(width: 48),
                    Expanded(flex: 4, child: textWidget),
                  ]
                : [
                    Expanded(flex: 4, child: textWidget),
                    const SizedBox(width: 48),
                    Expanded(flex: 6, child: imageWidget),
                  ],
          );

    return Container(
      width: double.infinity,
      color: useAltBg ? _lightBg.withOpacity(0.7) : Colors.transparent,
      padding: EdgeInsets.symmetric(
        horizontal: widget.isMobile ? 20 : 48,
        vertical: widget.isMobile ? 40 : 64,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: content,
        ),
      ),
    );
  }
}

// ─── Category Header ───────────────────────────────────────

class _CategoryHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isMobile;
  final int index;

  const _CategoryHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isMobile,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        left: isMobile ? 20 : 48,
        right: isMobile ? 20 : 48,
        top: isMobile ? 40 : 56,
        bottom: isMobile ? 16 : 24,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (index > 0) ...[
                Container(
                  width: double.infinity,
                  height: 1,
                  color: _brand.withOpacity(0.1),
                ),
                SizedBox(height: isMobile ? 32 : 48),
              ],
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_brand, _brandLight],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, size: 22, color: Colors.white),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: isMobile ? 20 : 24,
                            fontWeight: FontWeight.w800,
                            color: _dark,
                          ),
                        ),
                        if (subtitle.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: isMobile ? 13 : 15,
                              color: _muted,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Feature Card Row (for features without screenshots) ───

class _FeatureCardRow extends StatefulWidget {
  final _FeatureData data;
  final bool isMobile;
  final int index;

  const _FeatureCardRow({
    required this.data,
    required this.isMobile,
    required this.index,
  });

  @override
  State<_FeatureCardRow> createState() => _FeatureCardRowState();
}

class _FeatureCardRowState extends State<_FeatureCardRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final useAltBg = widget.index.isOdd;

    return Container(
      width: double.infinity,
      color: useAltBg ? _lightBg.withOpacity(0.7) : Colors.transparent,
      padding: EdgeInsets.symmetric(
        horizontal: widget.isMobile ? 20 : 48,
        vertical: widget.isMobile ? 28 : 40,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: MouseRegion(
            onEnter: (_) => setState(() => _hovered = true),
            onExit: (_) => setState(() => _hovered = false),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              transform: _hovered
                  ? (Matrix4.identity()..translate(0.0, -3.0))
                  : Matrix4.identity(),
              padding: EdgeInsets.all(widget.isMobile ? 24 : 36),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color:
                      _hovered ? _brand.withOpacity(0.2) : Colors.transparent,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _hovered
                        ? _brand.withOpacity(0.12)
                        : Colors.black.withOpacity(0.06),
                    blurRadius: _hovered ? 24 : 12,
                    offset: Offset(0, _hovered ? 8 : 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          _brand.withOpacity(0.1),
                          _brand.withOpacity(0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(widget.data.icon,
                        size: widget.isMobile ? 28 : 32, color: _brand),
                  ),
                  SizedBox(width: widget.isMobile ? 16 : 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.data.title,
                          style: TextStyle(
                            fontSize: widget.isMobile ? 18 : 22,
                            fontWeight: FontWeight.w800,
                            color: _dark,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.data.description,
                          style: TextStyle(
                            fontSize: widget.isMobile ? 14 : 16,
                            color: _muted,
                            height: 1.6,
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

// ─── Mini Stat ─────────────────────────────────────────────

class _MiniStat extends StatelessWidget {
  final String value;
  final String label;
  const _MiniStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.7),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ─── CTA Section ───────────────────────────────────────────

class _CtaSection extends StatelessWidget {
  final bool isMobile;
  const _CtaSection({required this.isMobile});

  @override
  Widget build(BuildContext context) {
    return Container(
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
            'Ready to get started?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isMobile ? 24 : 32,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Set up your community in minutes. No credit card required.',
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
                    horizontal: isMobile ? 32 : 48,
                    vertical: isMobile ? 16 : 20,
                  ),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                  elevation: 4,
                ),
                child: const Text('Get Started Free',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              OutlinedButton(
                onPressed: () => context.go('/'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 32 : 48,
                    vertical: isMobile ? 16 : 20,
                  ),
                  side: const BorderSide(color: Colors.white70, width: 2),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                ),
                child: const Text('Back to Home',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// end of file
