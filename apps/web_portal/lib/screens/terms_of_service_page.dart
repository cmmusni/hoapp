import 'package:flutter/material.dart';

import 'marketing_nav_bar.dart';

const _brand = Color(0xFF2E5C3F);
const _dark = Color(0xFF1F2937);
const _muted = Color(0xFF6B7280);

class TermsOfServicePage extends StatelessWidget {
  const TermsOfServicePage({super.key});

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

                  // ── Hero ──
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
                        Icon(Icons.gavel_outlined,
                            size: isMobile ? 48 : 56, color: Colors.white),
                        const SizedBox(height: 16),
                        Text(
                          'Terms of Service',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: isMobile ? 28 : 40,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Last Updated: April 7, 2026',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: isMobile ? 13 : 15,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Please read these terms carefully before using HOApp.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: isMobile ? 14 : 17,
                            color: Colors.white.withOpacity(0.92),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Content ──
                  Container(
                    width: double.infinity,
                    color: Colors.white,
                    child: Center(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 860),
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 20 : 48,
                          vertical: isMobile ? 32 : 56,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _section(
                              '1. Acceptance of Terms',
                              'By creating an account or using HOApp, you acknowledge that you have read, understood, and agree to these Terms of Service, as well as our Privacy Policy. If you do not agree, you may not use our services.',
                            ),
                            _section(
                              '2. Description of Service',
                              'HOApp provides a cloud-based HOA management platform for homeowners associations, condominiums, and residential communities. Our services include:',
                              bullets: [
                                'Property and household management.',
                                'Billing, invoicing, and dues collection.',
                                'Community announcements and notifications.',
                                'Violation tracking and reporting.',
                                'Amenity booking and reservation systems.',
                                'Pool access management.',
                                'QR-code security passes.',
                                'Support ticketing system.',
                              ],
                            ),
                            _section(
                              '3. User Accounts',
                              null,
                              subsections: [
                                _sub(
                                  '3.1 Registration',
                                  'To use HOApp, you must create an account by providing accurate and complete information. You are responsible for maintaining the confidentiality of your account credentials.',
                                ),
                                _sub(
                                  '3.2 Account Security',
                                  null,
                                  bullets: [
                                    'You are solely responsible for all activities under your account.',
                                    'Notify us immediately of any unauthorized access.',
                                    'We are not liable for losses resulting from unauthorized account use.',
                                    'You may not share your account or allow multiple users to access a single account unless authorized by your subscription plan.',
                                  ],
                                ),
                                _sub(
                                  '3.3 Account Termination',
                                  'We reserve the right to suspend or terminate accounts that violate these Terms, engage in fraudulent activity, or pose a security risk.',
                                ),
                              ],
                            ),
                            _section(
                              '4. Subscription and Payment',
                              null,
                              subsections: [
                                _sub(
                                  '4.1 Subscription Plans',
                                  'HOApp offers various subscription tiers. A free Starter plan is available for small communities. Premium plans with advanced features are available at competitive pricing.',
                                ),
                                _sub(
                                  '4.2 Payment Terms',
                                  null,
                                  bullets: [
                                    'Subscriptions are billed monthly or annually in advance.',
                                    'Payments are processed through our secure payment partners.',
                                    'Failed payments may result in service suspension.',
                                    'Refunds are provided on a case-by-case basis for service issues.',
                                  ],
                                ),
                                _sub(
                                  '4.3 Price Changes',
                                  'We reserve the right to modify subscription pricing with 30 days\' advance notice. Existing subscriptions maintain their current rate until renewal.',
                                ),
                              ],
                            ),
                            _section(
                              '5. User Responsibilities',
                              'You agree to:',
                              bullets: [
                                'Use HOApp only for lawful purposes.',
                                'Provide accurate and up-to-date information.',
                                'Comply with all applicable laws and regulations.',
                                'Not attempt to hack, disrupt, or compromise platform security.',
                                'Not upload malicious code, viruses, or harmful content.',
                                'Not use the platform to spam or harass other users.',
                                'Respect intellectual property rights.',
                                'Maintain proper backups of your critical data.',
                              ],
                            ),
                            _section(
                              '6. Data Ownership',
                              null,
                              subsections: [
                                _sub(
                                  '6.1 Your Data',
                                  'You retain all rights to data you input into HOApp. We do not claim ownership of your HOA data, property information, or financial records.',
                                ),
                                _sub(
                                  '6.2 Our License',
                                  'By using HOApp, you grant us a limited license to host, store, and process your data solely for the purpose of providing our services.',
                                ),
                                _sub(
                                  '6.3 Data Backup',
                                  null,
                                  bullets: [
                                    'We perform regular automated backups.',
                                    'You can export your data at any time.',
                                    'Deleted data may be recoverable for up to 30 days.',
                                    'We are not responsible for data loss due to user error or third-party failures.',
                                  ],
                                ),
                              ],
                            ),
                            _section(
                              '7. Intellectual Property',
                              'HOApp and all related trademarks, logos, designs, and content are owned by us or our licensors. You may not copy, modify, distribute, reverse engineer, or remove branding from our software without permission.',
                            ),
                            _section(
                              '8. Service Availability',
                              null,
                              subsections: [
                                _sub(
                                  '8.1 Uptime',
                                  'We strive for 99.9% uptime but do not guarantee uninterrupted service. Planned maintenance will be announced in advance when possible.',
                                ),
                                _sub(
                                  '8.2 Modifications',
                                  'We may modify, suspend, or discontinue features with reasonable notice. We are not liable for service interruptions or feature changes.',
                                ),
                              ],
                            ),
                            _section(
                              '9. Limitation of Liability',
                              'To the maximum extent permitted by law:',
                              bullets: [
                                'HOApp is provided "as is" without warranties of any kind.',
                                'We are not liable for indirect, incidental, or consequential damages.',
                                'Our total liability shall not exceed the amount you paid in the past 12 months.',
                                'We are not responsible for third-party services or integrations.',
                              ],
                            ),
                            _section(
                              '10. Indemnification',
                              'You agree to indemnify and hold HOApp harmless from any claims, losses, or damages arising from your violation of these Terms, misuse of the platform, infringement of third-party rights, or violation of applicable laws.',
                            ),
                            _section(
                              '11. Termination',
                              null,
                              subsections: [
                                _sub(
                                  'By You',
                                  'You may cancel your subscription at any time. Upon cancellation, your account enters read-only mode for 7 days, and data is archived for 90 days before permanent deletion.',
                                ),
                                _sub(
                                  'By Us',
                                  'We may terminate accounts for violations of these Terms, non-payment, or fraudulent activity. We will provide notice when possible.',
                                ),
                              ],
                            ),
                            _section(
                              '12. Dispute Resolution',
                              'Before pursuing legal action, parties agree to attempt good-faith resolution through direct communication. These Terms are governed by applicable law in the jurisdiction where our services operate.',
                            ),
                            _section(
                              '13. Changes to Terms',
                              'We may update these Terms periodically. Material changes will be communicated via email, in-platform announcements, or website notice. Continued use after changes constitutes acceptance.',
                            ),
                            _section(
                              '14. Contact',
                              'For questions about these Terms, please contact us:',
                              bullets: [
                                'Email: support@hoapp.net',
                                'Website: hoapp.net/contact',
                              ],
                            ),
                            const SizedBox(height: 16),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: _brand.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: _brand.withOpacity(0.15)),
                              ),
                              child: const Text(
                                'By using HOApp, you acknowledge that you have read, understood, and agree to be bound by these Terms of Service.',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: _dark,
                                  height: 1.6,
                                ),
                                textAlign: TextAlign.center,
                              ),
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
          const MarketingNavBar(activePage: 'terms'),
        ],
      ),
    );
  }

  Widget _section(String title, String? body,
      {List<String>? bullets, List<Widget>? subsections}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: _dark)),
          const SizedBox(height: 12),
          if (body != null)
            Text(body,
                style:
                    const TextStyle(fontSize: 15, height: 1.7, color: _muted)),
          if (bullets != null) ...[
            if (body != null) const SizedBox(height: 8),
            ...bullets.map((b) => Padding(
                  padding: const EdgeInsets.only(left: 16, bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ',
                          style: TextStyle(color: _brand, fontSize: 15)),
                      Expanded(
                        child: Text(b,
                            style: const TextStyle(
                                fontSize: 15, height: 1.6, color: _muted)),
                      ),
                    ],
                  ),
                )),
          ],
          if (subsections != null) ...subsections,
        ],
      ),
    );
  }

  Widget _sub(String title, String? body, {List<String>? bullets}) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600, color: _dark)),
          const SizedBox(height: 8),
          if (body != null)
            Text(body,
                style:
                    const TextStyle(fontSize: 15, height: 1.6, color: _muted)),
          if (bullets != null) ...[
            if (body != null) const SizedBox(height: 6),
            ...bullets.map((b) => Padding(
                  padding: const EdgeInsets.only(left: 16, bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ',
                          style: TextStyle(color: _brand, fontSize: 15)),
                      Expanded(
                        child: Text(b,
                            style: const TextStyle(
                                fontSize: 15, height: 1.6, color: _muted)),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }
}
