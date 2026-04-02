import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'marketing_nav_bar.dart';

const _brand = Color(0xFF2E5C3F);
const _dark = Color(0xFF1F2937);
const _muted = Color(0xFF6B7280);
const _lightBg = Color(0xFFF9FAFB);

// ─── Feature data model ────────────────────────────────────

class _FeatureData {
  final IconData icon;
  final String title;
  final String description;
  final String? imagePath;

  const _FeatureData({
    required this.icon,
    required this.title,
    required this.description,
    this.imagePath,
  });
}

const _features = <_FeatureData>[
  _FeatureData(
    icon: Icons.campaign_outlined,
    title: 'Announcements',
    description:
        'Broadcast community-wide announcements with rich text. Pin important notices and attach images or documents to keep everyone informed.',
    imagePath: 'assets/images/features/announcements.png',
  ),
  _FeatureData(
    icon: Icons.credit_card_outlined,
    title: 'Billing & Payments',
    description:
        'Generate invoices, track payments, upload proof of payment, and let staff verify or reject — all with a complete audit trail.',
    imagePath: 'assets/images/features/billing.png',
  ),
  _FeatureData(
    icon: Icons.home_outlined,
    title: 'Households',
    description:
        'Manage units, households, and residents. Invite members, assign roles, and keep a structured directory of your community.',
    imagePath: 'assets/images/features/households.png',
  ),
  _FeatureData(
    icon: Icons.gavel_outlined,
    title: 'Violations',
    description:
        'Report and track community violations with photos. Staff can review, fine, and resolve cases with clear status tracking.',
    imagePath: 'assets/images/features/violations.png',
  ),
  _FeatureData(
    icon: Icons.confirmation_number_outlined,
    title: 'Tickets',
    description:
        'Resident support ticket system for maintenance requests, complaints, and inquiries — with status updates and staff replies.',
    imagePath: 'assets/images/features/tickets.png',
  ),
  _FeatureData(
    icon: Icons.feedback_outlined,
    title: 'Feedback',
    description:
        'Collect and manage resident feedback. Track open and resolved submissions to continuously improve community services.',
    imagePath: 'assets/images/features/feedback.png',
  ),
  _FeatureData(
    icon: Icons.event_seat_outlined,
    title: 'Amenity Reservations',
    description:
        'Browse community amenities, check availability, and book reservations — from function halls to gyms and courts.',
    imagePath: 'assets/images/features/amenities-reservation.png',
  ),
  _FeatureData(
    icon: Icons.pool_outlined,
    title: 'Pool Access',
    description:
        'Register swimmers, manage pool entry, and track active sessions. Designed for multi-member households and guest access.',
    imagePath: 'assets/images/features/pool-access.png',
  ),
  _FeatureData(
    icon: Icons.qr_code_2_outlined,
    title: 'Security Passes',
    description:
        'Request visitor, gate, contractor, and delivery passes. Staff approve with QR codes — guards scan for instant validation.',
    imagePath: 'assets/images/features/security-pass.png',
  ),
  _FeatureData(
    icon: Icons.account_balance_wallet_outlined,
    title: 'Expense Tracker',
    description:
        'Track community expenses by category with filtering and real-time charts. Maintain full transparency over HOA spending.',
    imagePath: 'assets/images/features/community-expenses.png',
  ),
  _FeatureData(
    icon: Icons.bar_chart_outlined,
    title: 'Financial Reports',
    description:
        'View comprehensive income vs. expense analytics with interactive charts over configurable time periods.',
    imagePath: 'assets/images/features/financial-reports.png',
  ),
  _FeatureData(
    icon: Icons.notifications_outlined,
    title: 'Notifications Hub',
    description:
        'Aggregated view of all pending items — payments, tickets, violations, feedback, bookings, and announcements — in one place.',
    imagePath: 'assets/images/features/notifications.png',
  ),
  _FeatureData(
    icon: Icons.people_outlined,
    title: 'User Management',
    description:
        'Invite and manage community members with role-based access — admins, HOA officers, guards, maintenance, and residents.',
    imagePath: 'assets/images/features/manage-users.png',
  ),
  _FeatureData(
    icon: Icons.settings_outlined,
    title: 'Community Settings',
    description:
        'Configure your community profile, branding, and preferences from a centralized settings dashboard.',
    imagePath: 'assets/images/features/community-settings.png',
  ),
  _FeatureData(
    icon: Icons.phone_iphone_outlined,
    title: 'Mobile App',
    description:
        'Access your community on the go with the HOApp mobile app for iOS and Android — check announcements, pay bills, and scan QR passes from your phone.',
    imagePath: 'assets/images/features/mobile-app.png',
  ),
  _FeatureData(
    icon: Icons.hub_outlined,
    title: 'Multi-Community Support',
    description:
        'Manage or belong to multiple communities from a single account. Easily switch between communities from the portal.',
    imagePath: 'assets/images/features/select-community.png',
  ),
  _FeatureData(
    icon: Icons.qr_code_scanner_outlined,
    title: 'QR Pass Scanner',
    description:
        'Guards and staff can scan QR-coded passes at gates and entry points for instant validation and automated entry logging.',
  ),
  _FeatureData(
    icon: Icons.smart_toy_outlined,
    title: 'AI Chatbot Assistant',
    description:
        'Get instant help with a built-in AI assistant that provides contextual guidance based on your current page and role.',
  ),
  _FeatureData(
    icon: Icons.tour_outlined,
    title: 'Onboarding Tour',
    description:
        'Interactive guided walkthrough for new users. Replay anytime from the menu to learn about all portal features.',
  ),
  _FeatureData(
    icon: Icons.devices_outlined,
    title: 'Mobile Responsive',
    description:
        'The entire web portal is fully responsive — optimized for desktops, tablets, and smartphones so you can manage your community from any device.',
  ),
];

// ─── Features Page ─────────────────────────────────────────

class FeaturesPage extends StatelessWidget {
  const FeaturesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 600;

    final withImage = _features.where((f) => f.imagePath != null).toList();
    final withoutImage = _features.where((f) => f.imagePath == null).toList();

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
                  // ── Hero Header ──
                  _HeroHeader(isMobile: isMobile),

                  // ── Alternating Feature Showcases ──
                  ...List.generate(withImage.length, (i) {
                    final isEven = i.isEven;
                    return _FeatureShowcaseRow(
                      data: withImage[i],
                      imageOnLeft: isEven,
                      isMobile: isMobile,
                      index: i,
                    );
                  }),

                  // ── "And More" Section ──
                  if (withoutImage.isNotEmpty)
                    _MoreFeaturesSection(
                      features: withoutImage,
                      isMobile: isMobile,
                    ),

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
  const _HeroHeader({required this.isMobile});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(top: isMobile ? 100 : 120, bottom: 48),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _brand.withOpacity(0.08),
            Colors.white.withOpacity(0.0),
          ],
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: _brand.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'FEATURES',
              style: TextStyle(
                fontSize: isMobile ? 12 : 13,
                fontWeight: FontWeight.w700,
                color: _brand,
                letterSpacing: 2,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Everything Your\nCommunity Needs',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isMobile ? 32 : 48,
              fontWeight: FontWeight.w800,
              color: _dark,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 24 : 48),
            child: Text(
              'From billing to security passes, manage every aspect of your HOA with a single, beautiful platform.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isMobile ? 15 : 18,
                color: _muted,
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 28),
          Container(
            width: 48,
            height: 4,
            decoration: BoxDecoration(
              color: _brand.withOpacity(0.3),
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
            width: double.infinity,
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

// ─── More Features Section ─────────────────────────────────

class _MoreFeaturesSection extends StatelessWidget {
  final List<_FeatureData> features;
  final bool isMobile;

  const _MoreFeaturesSection({
    required this.features,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: _lightBg.withOpacity(0.5),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 48,
        vertical: isMobile ? 40 : 64,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: _brand.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'AND MORE',
                  style: TextStyle(
                    fontSize: isMobile ? 11 : 12,
                    fontWeight: FontWeight.w700,
                    color: _brand,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Even More Built-In',
                style: TextStyle(
                  fontSize: isMobile ? 24 : 32,
                  fontWeight: FontWeight.w800,
                  color: _dark,
                ),
              ),
              const SizedBox(height: 32),
              Wrap(
                spacing: isMobile ? 12 : 20,
                runSpacing: isMobile ? 12 : 20,
                alignment: WrapAlignment.center,
                children: features
                    .map((f) => _IconFeatureTile(data: f, isMobile: isMobile))
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── CTA Section ───────────────────────────────────────────

class _CtaSection extends StatelessWidget {
  final bool isMobile;
  const _CtaSection({required this.isMobile});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 48,
        vertical: isMobile ? 40 : 64,
      ),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 700),
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 24 : 48,
            vertical: isMobile ? 32 : 48,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _brand.withOpacity(0.06),
                _brand.withOpacity(0.12),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _brand.withOpacity(0.15)),
          ),
          child: Column(
            children: [
              Text(
                'Ready to get started?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: isMobile ? 22 : 28,
                  fontWeight: FontWeight.w800,
                  color: _dark,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Set up your community in minutes.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: isMobile ? 14 : 16,
                  color: _muted,
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
                      backgroundColor: _brand,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 32 : 48,
                        vertical: isMobile ? 16 : 20,
                      ),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                      elevation: 4,
                    ),
                    child: const Text('Get Started',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                  OutlinedButton(
                    onPressed: () => context.go('/'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _brand,
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 32 : 48,
                        vertical: isMobile ? 16 : 20,
                      ),
                      side: const BorderSide(color: _brand, width: 2),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                    ),
                    child: const Text('Back to Home',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
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

// ─── Icon-only Feature Tile ────────────────────────────────

class _IconFeatureTile extends StatefulWidget {
  final _FeatureData data;
  final bool isMobile;

  const _IconFeatureTile({
    required this.data,
    this.isMobile = false,
  });

  @override
  State<_IconFeatureTile> createState() => _IconFeatureTileState();
}

class _IconFeatureTileState extends State<_IconFeatureTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        width: widget.isMobile ? double.infinity : 260,
        transform: _hovered
            ? (Matrix4.identity()..translate(0.0, -3.0))
            : Matrix4.identity(),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _hovered ? _brand.withOpacity(0.25) : Colors.transparent,
          ),
          boxShadow: [
            BoxShadow(
              color: _hovered
                  ? _brand.withOpacity(0.12)
                  : Colors.black.withOpacity(0.06),
              blurRadius: _hovered ? 20 : 10,
              offset: Offset(0, _hovered ? 6 : 3),
            ),
          ],
        ),
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _brand.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(widget.data.icon, size: 26, color: _brand),
            ),
            const SizedBox(height: 16),
            Text(
              widget.data.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _dark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.data.description,
              style: const TextStyle(
                fontSize: 13,
                color: _muted,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
