import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'marketing_nav_bar.dart';

const _brand = Color(0xFF2E5C3F);

class SupportPage extends StatelessWidget {
  const SupportPage({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 600;

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
                  Container(
                    constraints: const BoxConstraints(maxWidth: 900),
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 16 : 32,
                      vertical: isMobile ? 32 : 48,
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Support Center',
                          style: TextStyle(
                            fontSize: isMobile ? 28 : 36,
                            fontWeight: FontWeight.bold,
                            color: _brand,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'We\'re here to help. Find answers or reach out to our team.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: isMobile ? 14 : 16,
                            color: const Color(0xFF6B7280),
                          ),
                        ),
                        const SizedBox(height: 48),

                        // Support options
                        Wrap(
                          spacing: isMobile ? 16 : 24,
                          runSpacing: isMobile ? 16 : 24,
                          alignment: WrapAlignment.center,
                          children: [
                            _SupportCard(
                              icon: Icons.menu_book_outlined,
                              title: 'Documentation',
                              description:
                                  'Browse guides, tutorials, and API references to get the most out of HOApp.',
                              isMobile: isMobile,
                            ),
                            _SupportCard(
                              icon: Icons.help_outline,
                              title: 'FAQ',
                              description:
                                  'Quick answers to the most common questions about setup, billing, and features.',
                              isMobile: isMobile,
                            ),
                            _SupportCard(
                              icon: Icons.chat_bubble_outline,
                              title: 'Live Chat',
                              description:
                                  'Chat with our support team in real-time during business hours (Mon–Fri, 9 AM – 6 PM).',
                              isMobile: isMobile,
                            ),
                            _SupportCard(
                              icon: Icons.email_outlined,
                              title: 'Email Support',
                              description:
                                  'Send us an email at support@hoapp.net and we\'ll respond within 24 hours.',
                              isMobile: isMobile,
                            ),
                            _SupportCard(
                              icon: Icons.video_library_outlined,
                              title: 'Video Tutorials',
                              description:
                                  'Watch step-by-step video guides for onboarding, billing setup, and more.',
                              isMobile: isMobile,
                            ),
                            _SupportCard(
                              icon: Icons.bug_report_outlined,
                              title: 'Report a Bug',
                              description:
                                  'Found an issue? Let us know and our engineering team will investigate it promptly.',
                              isMobile: isMobile,
                            ),
                          ],
                        ),

                        const SizedBox(height: 60),

                        // FAQ section
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(isMobile ? 20 : 32),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.92),
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
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Common Questions',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1F2937),
                                ),
                              ),
                              const SizedBox(height: 24),
                              _faqItem(
                                'How do I reset my password?',
                                'Click "Forgot Password" on the login page, enter your email, and follow the link sent to your inbox.',
                              ),
                              _faqItem(
                                'How do I invite residents to my community?',
                                'Go to Manage Users, click "Invite", enter their email and role, then they\'ll receive an email invitation.',
                              ),
                              _faqItem(
                                'Can I use HOApp on my phone?',
                                'Yes! HOApp has a native mobile app for iOS and Android with full community access.',
                              ),
                              _faqItem(
                                'How do I upgrade my community plan?',
                                'Contact your community admin or reach out to our sales team at support@hoapp.net.',
                              ),
                              _faqItem(
                                'Is my data secure?',
                                'Absolutely. HOApp uses enterprise-grade encryption, row-level security, and is hosted on Supabase with SOC2-compliant infrastructure.',
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 48),

                        Wrap(
                          spacing: 16,
                          runSpacing: 12,
                          alignment: WrapAlignment.center,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () => context.go('/contact'),
                              icon: const Icon(Icons.mail_outline,
                                  color: Colors.white),
                              label: const Text('Contact Us'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _brand,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(
                                  horizontal: isMobile ? 28 : 36,
                                  vertical: isMobile ? 14 : 18,
                                ),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30)),
                                elevation: 4,
                              ),
                            ),
                            OutlinedButton(
                              onPressed: () => context.go('/'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _brand,
                                padding: EdgeInsets.symmetric(
                                  horizontal: isMobile ? 28 : 36,
                                  vertical: isMobile ? 14 : 18,
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
          const MarketingNavBar(activePage: 'Support'),
        ],
      ),
    );
  }

  static Widget _faqItem(String question, String answer) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(question,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1F2937))),
          const SizedBox(height: 4),
          Text(answer,
              style: const TextStyle(
                  fontSize: 14, color: Color(0xFF6B7280), height: 1.5)),
        ],
      ),
    );
  }
}

// ─── Support Card ──────────────────────────────────────────

class _SupportCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool isMobile;

  const _SupportCard({
    required this.icon,
    required this.title,
    required this.description,
    this.isMobile = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: isMobile ? double.infinity : 260,
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
            child: Icon(icon, size: 28, color: _brand),
          ),
          const SizedBox(height: 16),
          Text(title,
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937))),
          const SizedBox(height: 8),
          Text(description,
              style: const TextStyle(
                  fontSize: 14, color: Color(0xFF6B7280), height: 1.5)),
        ],
      ),
    );
  }
}
