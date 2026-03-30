import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'marketing_nav_bar.dart';

const _brand = Color(0xFF2E5C3F);

class FeaturesPage extends StatelessWidget {
  const FeaturesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 600;

    return Scaffold(
      body: Stack(
        children: [
          // Background
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
                  Container(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 16 : 32,
                      vertical: isMobile ? 32 : 48,
                    ),
                    child: Column(
                      children: [
                        // Header
                        Text(
                          'All Features',
                          style: TextStyle(
                            fontSize: isMobile ? 28 : 36,
                            fontWeight: FontWeight.bold,
                            color: _brand,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Everything you need to manage your community — all in one platform.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: isMobile ? 14 : 16,
                            color: const Color(0xFF6B7280),
                          ),
                        ),
                        const SizedBox(height: 48),

                        // Feature grid
                        Wrap(
                          spacing: isMobile ? 16 : 24,
                          runSpacing: isMobile ? 16 : 24,
                          alignment: WrapAlignment.center,
                          children: [
                            _FeatureTile(
                              icon: Icons.campaign_outlined,
                              title: 'Announcements',
                              description:
                                  'Broadcast community-wide announcements with rich text. Pin important notices and attach images to keep everyone informed.',
                              isMobile: isMobile,
                            ),
                            _FeatureTile(
                              icon: Icons.credit_card_outlined,
                              title: 'Billing & Payments',
                              description:
                                  'Generate invoices, track payments, upload proof of payment, and let staff verify or reject — all with a complete audit trail.',
                              isMobile: isMobile,
                            ),
                            _FeatureTile(
                              icon: Icons.home_outlined,
                              title: 'Households',
                              description:
                                  'Manage units, households, and residents. Invite members, assign roles, and keep a structured directory of your community.',
                              isMobile: isMobile,
                            ),
                            _FeatureTile(
                              icon: Icons.gavel_outlined,
                              title: 'Violations',
                              description:
                                  'Report and track community violations with photos. Staff can review, fine, and resolve cases with clear status tracking.',
                              isMobile: isMobile,
                            ),
                            _FeatureTile(
                              icon: Icons.confirmation_number_outlined,
                              title: 'Tickets',
                              description:
                                  'Resident support ticket system for maintenance requests, complaints, and inquiries — with status updates and staff replies.',
                              isMobile: isMobile,
                            ),
                            _FeatureTile(
                              icon: Icons.feedback_outlined,
                              title: 'Feedback',
                              description:
                                  'Collect and manage resident feedback. Track open and resolved submissions to continuously improve community services.',
                              isMobile: isMobile,
                            ),
                            _FeatureTile(
                              icon: Icons.event_seat_outlined,
                              title: 'Amenity Reservations',
                              description:
                                  'Browse community amenities, check availability, and book reservations — from function halls to gyms and courts.',
                              isMobile: isMobile,
                            ),
                            _FeatureTile(
                              icon: Icons.pool_outlined,
                              title: 'Pool Access',
                              description:
                                  'Register swimmers, manage pool entry, and track active sessions. Designed for multi-member households and guest access.',
                              isMobile: isMobile,
                            ),
                            _FeatureTile(
                              icon: Icons.qr_code_2_outlined,
                              title: 'Security Passes',
                              description:
                                  'Request visitor, gate, contractor, and delivery passes. Staff approve with QR codes — guards scan for instant validation.',
                              isMobile: isMobile,
                            ),
                            _FeatureTile(
                              icon: Icons.qr_code_scanner_outlined,
                              title: 'QR Pass Scanner',
                              description:
                                  'Guards and staff can scan QR-coded passes at gates and entry points for instant validation and automated entry logging.',
                              isMobile: isMobile,
                            ),
                            _FeatureTile(
                              icon: Icons.account_balance_wallet_outlined,
                              title: 'Expense Tracker',
                              description:
                                  'Track community expenses by category with filtering and real-time charts. Maintain full transparency over HOA spending.',
                              isMobile: isMobile,
                            ),
                            _FeatureTile(
                              icon: Icons.bar_chart_outlined,
                              title: 'Financial Reports',
                              description:
                                  'View comprehensive income vs. expense analytics with interactive charts over configurable time periods.',
                              isMobile: isMobile,
                            ),
                            _FeatureTile(
                              icon: Icons.notifications_outlined,
                              title: 'Notifications Hub',
                              description:
                                  'Aggregated view of all pending items — payments, tickets, violations, feedback, bookings, and announcements — in one place.',
                              isMobile: isMobile,
                            ),
                            _FeatureTile(
                              icon: Icons.people_outlined,
                              title: 'User Management',
                              description:
                                  'Invite and manage community members with role-based access — admins, HOA officers, guards, maintenance, and residents.',
                              isMobile: isMobile,
                            ),
                            _FeatureTile(
                              icon: Icons.settings_outlined,
                              title: 'Community Settings',
                              description:
                                  'Configure your community profile, branding, and preferences from a centralized settings dashboard.',
                              isMobile: isMobile,
                            ),
                            _FeatureTile(
                              icon: Icons.smart_toy_outlined,
                              title: 'AI Chatbot Assistant',
                              description:
                                  'Get instant help with a built-in AI assistant that provides contextual guidance based on your current page and role.',
                              isMobile: isMobile,
                            ),
                            _FeatureTile(
                              icon: Icons.tour_outlined,
                              title: 'Onboarding Tour',
                              description:
                                  'Interactive guided walkthrough for new users. Replay anytime from the menu to learn about all portal features.',
                              isMobile: isMobile,
                            ),
                            _FeatureTile(
                              icon: Icons.phone_iphone_outlined,
                              title: 'Mobile App',
                              description:
                                  'Access your community on the go with the HOApp mobile app for iOS and Android — check announcements, pay bills, and scan QR passes from your phone.',
                              isMobile: isMobile,
                            ),
                            _FeatureTile(
                              icon: Icons.devices_outlined,
                              title: 'Mobile Responsive',
                              description:
                                  'The entire web portal is fully responsive — optimized for desktops, tablets, and smartphones so you can manage your community from any device.',
                              isMobile: isMobile,
                            ),
                          ],
                        ),

                        const SizedBox(height: 60),

                        // CTA
                        const Text(
                          'Ready to get started?',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Wrap(
                          spacing: 16,
                          runSpacing: 12,
                          alignment: WrapAlignment.center,
                          children: [
                            ElevatedButton(
                              onPressed: () => context.go('/signup'),
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
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600)),
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
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 60),
                      ],
                    ),
                  ),

                  // Footer
                  const MarketingFooter(),
                ],
              ),
            ),
          ),

          // Fixed nav bar
          const MarketingNavBar(activePage: 'Features'),
        ],
      ),
    );
  }
}

// ─── Feature Tile ──────────────────────────────────────────

class _FeatureTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool isMobile;

  const _FeatureTile({
    required this.icon,
    required this.title,
    required this.description,
    this.isMobile = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: isMobile ? double.infinity : 330,
      height: 255,
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
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _brand.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 32, color: _brand),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF6B7280),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
