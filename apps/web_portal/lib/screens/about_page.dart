import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'marketing_nav_bar.dart';

const _brand = Color(0xFF2E5C3F);
const _dark = Color(0xFF1F2937);
const _muted = Color(0xFF6B7280);

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

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

                  // ── Hero ──
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 20 : 48,
                      vertical: isMobile ? 48 : 64,
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
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(Icons.home_work_outlined,
                              size: isMobile ? 48 : 56, color: Colors.white),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'About HOApp',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: isMobile ? 28 : 42,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Empowering homeowners associations with modern, efficient management tools.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: isMobile ? 14 : 18,
                            color: Colors.white.withOpacity(0.92),
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Mission ──
                  Container(
                    width: double.infinity,
                    color: Colors.white,
                    child: Center(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 960),
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 20 : 48,
                          vertical: isMobile ? 36 : 56,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionTitle('Our Mission'),
                            const SizedBox(height: 16),
                            const Text(
                              'At HOApp, we\'re dedicated to transforming how homeowners associations operate. '
                              'We believe that managing an HOA shouldn\'t be complicated, time-consuming, or expensive. '
                              'Our mission is to provide accessible, powerful, and user-friendly tools that enable '
                              'HOA administrators to focus on building thriving communities rather than struggling '
                              'with paperwork and manual processes.',
                              style: TextStyle(
                                fontSize: 16,
                                height: 1.8,
                                color: _muted,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'We understand the unique challenges faced by HOAs — from diverse property types and '
                              'complex billing structures to the need for transparency, security, and efficient communication. '
                              'That\'s why we\'ve built a platform specifically designed with features that address real-world '
                              'community management needs.',
                              style: TextStyle(
                                fontSize: 16,
                                height: 1.8,
                                color: _muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ── Our Story ──
                  Container(
                    width: double.infinity,
                    color: const Color(0xFFF9FAFB),
                    child: Center(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 960),
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 20 : 48,
                          vertical: isMobile ? 36 : 56,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionTitle('Our Story'),
                            const SizedBox(height: 16),
                            const Text(
                              'HOApp was born from firsthand experience with the challenges of HOA management. '
                              'Having witnessed the struggles of manual processes, outdated spreadsheets, and disconnected '
                              'systems, we knew there had to be a better way.',
                              style: TextStyle(
                                fontSize: 16,
                                height: 1.8,
                                color: _muted,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'We set out to create a comprehensive platform that would automate routine tasks, '
                              'improve financial transparency, and make HOA management accessible to communities of all sizes. '
                              'Today, HOApp serves homeowners associations — from small subdivisions to large condominium complexes '
                              '— helping them operate more efficiently and transparently.',
                              style: TextStyle(
                                fontSize: 16,
                                height: 1.8,
                                color: _muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ── Values ──
                  Container(
                    width: double.infinity,
                    color: Colors.white,
                    child: Center(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 960),
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 20 : 48,
                          vertical: isMobile ? 36 : 56,
                        ),
                        child: Column(
                          children: [
                            _sectionTitle('Our Values'),
                            const SizedBox(height: 32),
                            Wrap(
                              spacing: 24,
                              runSpacing: 24,
                              children: [
                                _valueCard(
                                  Icons.touch_app_outlined,
                                  'Simplicity',
                                  'We believe powerful software should be easy to use. Every feature is designed with user experience in mind.',
                                  isMobile,
                                  isNarrow,
                                ),
                                _valueCard(
                                  Icons.shield_outlined,
                                  'Security',
                                  'Your data security is our top priority. We use enterprise-grade encryption and infrastructure to keep your information safe.',
                                  isMobile,
                                  isNarrow,
                                ),
                                _valueCard(
                                  Icons.lightbulb_outlined,
                                  'Innovation',
                                  'We continuously improve our platform based on user feedback and emerging technologies to keep you ahead.',
                                  isMobile,
                                  isNarrow,
                                ),
                                _valueCard(
                                  Icons.handshake_outlined,
                                  'Transparency',
                                  'We promote financial and operational transparency in every community we serve, building trust among residents.',
                                  isMobile,
                                  isNarrow,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ── Why Choose HOApp ──
                  Container(
                    width: double.infinity,
                    color: const Color(0xFFF9FAFB),
                    child: Center(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 960),
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 20 : 48,
                          vertical: isMobile ? 36 : 56,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionTitle('Why Choose HOApp?'),
                            const SizedBox(height: 24),
                            _reasonItem(
                              'Comprehensive Solution',
                              'From billing and payments to property management, announcements, violations, amenity booking, and security passes — HOApp handles all aspects of HOA operations in one integrated platform.',
                            ),
                            _reasonItem(
                              'Web + Mobile',
                              'Available as both a full web portal for administrators and a mobile app for residents on Android and iOS. Manage your community from anywhere.',
                            ),
                            _reasonItem(
                              'Affordable for All',
                              'We believe every HOA deserves access to professional tools, which is why we offer a free Starter plan and competitive pricing for growing communities.',
                            ),
                            _reasonItem(
                              'Enterprise-Grade Security',
                              'Built on Supabase with 256-bit AES encryption, row-level security, automated backups, and SOC 2 / ISO 27001 compliant infrastructure.',
                            ),
                            _reasonItem(
                              'Always Evolving',
                              'We regularly release new features and improvements based on feedback from our community of users. Your needs drive our roadmap.',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ── CTA ──
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 20 : 48,
                      vertical: isMobile ? 40 : 56,
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
                          'Ready to Transform Your HOA?',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: isMobile ? 22 : 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Join communities already using HOApp to simplify management and improve transparency.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: isMobile ? 14 : 16,
                            color: Colors.white.withOpacity(0.9),
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton(
                              onPressed: () => context.go('/signup'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: _brand,
                                padding: EdgeInsets.symmetric(
                                  horizontal: isMobile ? 24 : 32,
                                  vertical: isMobile ? 14 : 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                elevation: 0,
                              ),
                              child: const Text('Get Started Free',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w600)),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton(
                              onPressed: () => context.go('/features'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Colors.white54),
                                padding: EdgeInsets.symmetric(
                                  horizontal: isMobile ? 24 : 32,
                                  vertical: isMobile ? 14 : 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Text('View Features',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // ── Contact ──
                  Container(
                    width: double.infinity,
                    color: Colors.white,
                    child: Center(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 960),
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 20 : 48,
                          vertical: isMobile ? 32 : 48,
                        ),
                        child: Column(
                          children: [
                            _sectionTitle('Get in Touch'),
                            const SizedBox(height: 24),
                            Wrap(
                              spacing: 40,
                              runSpacing: 20,
                              alignment: WrapAlignment.center,
                              children: [
                                _contactItem(
                                    Icons.email_outlined, 'support@hoapp.net'),
                                _contactItem(
                                    Icons.language_outlined, 'hoapp.net'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const MarketingFooter(),
                ],
              ),
            ),
          ),
          const MarketingNavBar(activePage: 'about'),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: _dark,
      ),
    );
  }

  Widget _valueCard(
      IconData icon, String title, String desc, bool isMobile, bool isNarrow) {
    final cardWidth = isMobile ? double.infinity : (isNarrow ? 280.0 : 210.0);
    return SizedBox(
      width: cardWidth,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _brand.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 32, color: _brand),
          ),
          const SizedBox(height: 14),
          Text(title,
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.bold, color: _dark)),
          const SizedBox(height: 8),
          Text(desc,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, height: 1.6, color: _muted)),
        ],
      ),
    );
  }

  Widget _reasonItem(String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: _brand.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.check, size: 16, color: _brand),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _dark)),
                const SizedBox(height: 4),
                Text(desc,
                    style: const TextStyle(
                        fontSize: 15, height: 1.6, color: _muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _contactItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: _brand),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(fontSize: 15, color: _dark)),
      ],
    );
  }
}
