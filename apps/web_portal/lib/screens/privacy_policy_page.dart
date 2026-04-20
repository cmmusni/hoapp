import 'package:flutter/material.dart';

import 'marketing_nav_bar.dart';

const _brand = Color(0xFF2E5C3F);
const _dark = Color(0xFF1F2937);
const _muted = Color(0xFF6B7280);

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

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
                        Icon(Icons.privacy_tip_outlined,
                            size: isMobile ? 48 : 56, color: Colors.white),
                        const SizedBox(height: 16),
                        Text(
                          'Privacy Policy',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: isMobile ? 28 : 40,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Last Updated: April 20, 2026',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: isMobile ? 13 : 15,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'At HOApp, we respect your privacy and are committed to protecting your personal data.',
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
                              '1. Information We Collect',
                              null,
                              subsections: [
                                _sub(
                                  '1.1 Information You Provide',
                                  [
                                    'Account Information: Name, email address, phone number, and organization details when you register.',
                                    'HOA Data: Property information, homeowner details, financial records, and other data you input into the platform.',
                                    'Payment Information: Billing details for subscription payments, processed securely through third-party payment processors.',
                                    'Communications: Messages sent through our contact forms or support channels.',
                                  ],
                                ),
                                _sub(
                                  '1.2 Information Collected Automatically',
                                  [
                                    'Usage Data: Information about how you use our platform, including pages visited and features accessed.',
                                    'Device Information: IP address, browser type, operating system, and device identifiers.',
                                    'Cookies and Similar Technologies: We use cookies to enhance your experience and analyze platform usage.',
                                  ],
                                ),
                              ],
                            ),
                            _section(
                              '2. How We Use Your Information',
                              null,
                              bullets: [
                                'Providing and maintaining our HOA management services.',
                                'Processing transactions and managing subscriptions.',
                                'Sending important updates, security alerts, and support messages.',
                                'Improving our platform based on usage patterns and feedback.',
                                'Ensuring platform security and preventing fraud.',
                                'Complying with legal obligations and enforcing our Terms of Service.',
                              ],
                            ),
                            _section(
                              '3. Data Sharing and Disclosure',
                              'We do not sell your personal information. We may share your data in the following circumstances:',
                              bullets: [
                                'Service Providers: Third-party vendors who assist in operating our platform (hosting, payment processing, email services).',
                                'Legal Requirements: When required by law or to protect our rights and the safety of our users.',
                                'Business Transfers: In connection with a merger, acquisition, or sale of assets.',
                                'With Your Consent: When you explicitly authorize us to share specific information.',
                              ],
                            ),
                            _section(
                              '4. Data Security',
                              'We implement industry-standard security measures to protect your data:',
                              bullets: [
                                'Encryption of data in transit (TLS/SSL) and at rest (AES-256).',
                                'Regular security audits and vulnerability assessments.',
                                'Role-based access controls and multi-factor authentication.',
                                'Secure, automated backup and disaster recovery procedures.',
                                'Infrastructure hosted on Supabase with ISO 27001 and SOC 2 compliance.',
                              ],
                            ),
                            _section(
                              '5. Data Retention',
                              'We retain your personal data only as long as necessary to provide our services and comply with legal obligations.',
                              bullets: [
                                'Active subscriptions: Data retained throughout the subscription period.',
                                'Cancelled accounts: Data accessible in read-only mode for 7 days, then archived for 90 days.',
                                'Deleted accounts: Data permanently removed within 30 days unless required by law.',
                              ],
                            ),
                            _section(
                              '6. Your Rights',
                              'You have the following rights regarding your personal data:',
                              bullets: [
                                'Access: Request a copy of your personal data.',
                                'Correction: Update or correct inaccurate information.',
                                'Deletion: Request deletion of your personal data (subject to legal obligations).',
                                'Export: Download your data in a portable format.',
                                'Opt-Out: Unsubscribe from marketing communications at any time.',
                              ],
                            ),
                            _section(
                              '7. How to Request Account Deletion',
                              'You can request deletion of your HOApp account and associated personal data at any time. Follow these steps:',
                              bullets: [
                                'Send an email to support@hoapp.net from the email address associated with your HOApp account.',
                                'Use the subject line: "Account Deletion Request".',
                                'Include your registered email and the name of your community for verification.',
                                'We will verify the request and confirm receipt within 5 business days.',
                                'Your account and associated personal data will be permanently deleted within 30 days of verification.',
                                'Data we may retain after deletion: financial and billing records required by law (e.g., tax records), and anonymized usage logs that no longer identify you.',
                                'Once deleted, your account cannot be recovered. You will lose access to your community data, payment history, and uploaded files.',
                              ],
                            ),
                            _section(
                              '8. Cookies',
                              'We use cookies and similar technologies to remember your preferences, maintain your session, and analyze platform usage. You can control cookies through your browser settings, but disabling them may affect platform functionality.',
                            ),
                            _section(
                              '9. Third-Party Services',
                              'Our platform may integrate with third-party services (e.g., payment processors, analytics). We are not responsible for the privacy practices of these external services and encourage you to review their privacy policies.',
                            ),
                            _section(
                              '10. Children\'s Privacy',
                              'HOApp is not intended for individuals under 18 years of age. We do not knowingly collect personal information from children.',
                            ),
                            _section(
                              '11. Changes to This Policy',
                              'We may update this Privacy Policy periodically. We will notify you of significant changes via email or platform notification. Your continued use of HOApp after changes indicates acceptance of the updated policy.',
                            ),
                            _section(
                              '12. Contact Us',
                              'If you have questions about this Privacy Policy, please contact us:',
                              bullets: [
                                'Email: support@hoapp.net',
                                'Website: hoapp.net/contact',
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
          const MarketingNavBar(activePage: 'privacy'),
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

  Widget _sub(String title, List<String> bullets) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600, color: _dark)),
          const SizedBox(height: 8),
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
      ),
    );
  }
}
