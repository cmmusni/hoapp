import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'marketing_nav_bar.dart';

const _brand = Color(0xFF2E5C3F);
const _dark = Color(0xFF1F2937);
const _muted = Color(0xFF6B7280);
const _green = Color(0xFF10B981);
const _greenLight = Color(0xFFD1FAE5);

class DataSecurityPage extends StatelessWidget {
  const DataSecurityPage({super.key});

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
                        Icon(Icons.shield_outlined,
                            size: isMobile ? 48 : 56, color: Colors.white),
                        const SizedBox(height: 16),
                        Text(
                          'Security and Data Privacy',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: isMobile ? 28 : 40,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Your trust is our priority. We protect your HOA data with enterprise-grade security and privacy measures.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: isMobile ? 14 : 17,
                            color: Colors.white.withOpacity(0.92),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Main Content ──
                  Container(
                    constraints: const BoxConstraints(maxWidth: 900),
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 16 : 32,
                      vertical: isMobile ? 32 : 48,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Commitment Section ──
                        _SectionCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Our Commitment to Security',
                                  style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: _dark)),
                              const SizedBox(height: 12),
                              const Text(
                                'At HOApp, we understand that you\'re entrusting us with sensitive financial and personal data for your homeowners association. Security and data privacy aren\'t just features — they\'re fundamental to everything we build. We implement industry-leading security practices to ensure your data remains safe, private, and accessible only to authorized users.',
                                style: TextStyle(
                                    fontSize: 15, color: _muted, height: 1.7),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),

                        // ── Security Features Grid ──
                        const Text('Security Features',
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: _dark)),
                        const SizedBox(height: 20),
                        ..._buildEqualHeightGrid(
                          isMobile: isMobile,
                          isNarrow: isNarrow,
                          children: [
                            const _SecurityCard(
                              icon: Icons.lock_outline,
                              title: 'End-to-End Encryption',
                              description:
                                  'All data transmitted between your browser and our servers is encrypted using industry-standard TLS/SSL protocols.',
                            ),
                            const _SecurityCard(
                              icon: Icons.shield_outlined,
                              title: 'Data Encryption at Rest',
                              description:
                                  'Your data is encrypted when stored in our databases, adding an extra layer of protection against unauthorized access.',
                            ),
                            const _SecurityCard(
                              icon: Icons.vpn_key_outlined,
                              title: 'Secure Authentication',
                              description:
                                  'Password-based authentication with bcrypt hashing, session management, and secure password reset mechanisms.',
                            ),
                            const _SecurityCard(
                              icon: Icons.apartment_outlined,
                              title: 'Multi-Tenant Isolation',
                              description:
                                  'Complete data separation between HOAs ensures your data is never mixed with or visible to other organizations.',
                            ),
                            const _SecurityCard(
                              icon: Icons.fingerprint_outlined,
                              title: 'Row-Level Security (RLS)',
                              description:
                                  'Database-level security policies ensure users can only access data they\'re authorized to see.',
                            ),
                            const _SecurityCard(
                              icon: Icons.history_outlined,
                              title: 'Activity Logging',
                              description:
                                  'Comprehensive audit trails track all data access and modifications for accountability and compliance.',
                            ),
                            const _SecurityCard(
                              icon: Icons.backup_outlined,
                              title: 'Regular Backups',
                              description:
                                  'Automated daily backups with point-in-time recovery ensure your data can be restored in case of any issues.',
                            ),
                            const _SecurityCard(
                              icon: Icons.admin_panel_settings_outlined,
                              title: 'Role-Based Access Control',
                              description:
                                  'Granular permissions system allows you to control exactly what each user can see and do within your HOA.',
                            ),
                          ],
                        ),
                        const SizedBox(height: 40),

                        // ── Infrastructure Security ──
                        _SectionCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Infrastructure Security',
                                  style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: _dark)),
                              const SizedBox(height: 12),
                              RichText(
                                text: const TextSpan(
                                  style: TextStyle(
                                      fontSize: 15, color: _muted, height: 1.7),
                                  children: [
                                    TextSpan(text: 'HOApp is built on '),
                                    TextSpan(
                                        text: 'Supabase',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    TextSpan(
                                        text:
                                            ', a secure and reliable platform that provides enterprise-grade infrastructure:'),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              _bulletPoint('Cloud Infrastructure:',
                                  'Hosted on secure, SOC 2 compliant cloud infrastructure with 99.9% uptime guarantee'),
                              _bulletPoint('PostgreSQL Database:',
                                  'Powered by enterprise-grade PostgreSQL with automatic backups and point-in-time recovery'),
                              _bulletPoint('Row Level Security (RLS):',
                                  'Database-level security policies built into PostgreSQL ensure complete data isolation'),
                              _bulletPoint('DDoS Protection:',
                                  'Advanced protection against distributed denial-of-service attacks'),
                              _bulletPoint('Firewall Protection:',
                                  'Network-level security to prevent unauthorized access'),
                              _bulletPoint('Regular Security Updates:',
                                  'Automatic security patches and updates to protect against vulnerabilities'),
                              _bulletPoint('Monitoring and Alerts:',
                                  '24/7 system monitoring with automatic alerts for suspicious activity'),
                              _bulletPoint('Edge Functions:',
                                  'Secure serverless functions for handling sensitive operations'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // ── Data Sovereignty Highlight ──
                        _HighlightBox(
                          title: 'Data Sovereignty',
                          description:
                              'Your data is stored securely within your region and is never shared with third parties. You maintain full ownership and control of your HOA data at all times.',
                        ),
                        const SizedBox(height: 32),

                        // ── Privacy Protection ──
                        _SectionCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Privacy Protection',
                                  style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: _dark)),
                              const SizedBox(height: 16),
                              const Text('Data Collection and Usage',
                                  style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                      color: _dark)),
                              const SizedBox(height: 8),
                              const Text(
                                'We only collect data necessary to provide our services to you:',
                                style: TextStyle(
                                    fontSize: 15, color: _muted, height: 1.7),
                              ),
                              const SizedBox(height: 8),
                              _simpleBullet(
                                  'HOA and property information for management purposes'),
                              _simpleBullet(
                                  'User account information for authentication and access control'),
                              _simpleBullet(
                                  'Financial transaction data for billing and payment processing'),
                              _simpleBullet(
                                  'Usage analytics to improve our platform (anonymized and aggregated)'),
                              const SizedBox(height: 24),
                              const Text('We Never:',
                                  style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                      color: _dark)),
                              const SizedBox(height: 8),
                              _simpleBullet('Sell your data to third parties'),
                              _simpleBullet(
                                  'Use your data for advertising purposes'),
                              _simpleBullet(
                                  'Share your data with other HOAs or organizations'),
                              _simpleBullet(
                                  'Access your data without authorization or valid legal requirement'),
                              const SizedBox(height: 24),
                              const Text('Your Rights',
                                  style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                      color: _dark)),
                              const SizedBox(height: 8),
                              const Text(
                                'You have complete control over your data:',
                                style: TextStyle(
                                    fontSize: 15, color: _muted, height: 1.7),
                              ),
                              const SizedBox(height: 8),
                              _bulletPoint('Access:',
                                  'View all data we have about your HOA at any time'),
                              _bulletPoint('Export:',
                                  'Download complete copies of your data in standard formats'),
                              _bulletPoint('Delete:',
                                  'Request permanent deletion of your HOA data'),
                              _bulletPoint('Correct:',
                                  'Update or correct any inaccurate information'),
                              _bulletPoint('Portability:',
                                  'Transfer your data to another platform if needed'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),

                        // ── Compliance ──
                        _SectionCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Compliance and Standards',
                                  style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: _dark)),
                              const SizedBox(height: 8),
                              const Text(
                                'HOApp adheres to international security and privacy standards:',
                                style: TextStyle(
                                    fontSize: 15, color: _muted, height: 1.7),
                              ),
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: const [
                                  _ComplianceBadge('SSL/TLS Encrypted'),
                                  _ComplianceBadge('SOC 2 Infrastructure'),
                                  _ComplianceBadge('GDPR Aligned'),
                                  _ComplianceBadge('ISO 27001 Standards'),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),

                        // ── Best Practices ──
                        _SectionCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Security Best Practices for Users',
                                  style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: _dark)),
                              const SizedBox(height: 8),
                              const Text(
                                'While we implement strong security measures, we recommend following these best practices:',
                                style: TextStyle(
                                    fontSize: 15, color: _muted, height: 1.7),
                              ),
                              const SizedBox(height: 12),
                              _simpleBullet(
                                  'Use strong, unique passwords for your HOApp account'),
                              _simpleBullet(
                                  'Never share your login credentials with others'),
                              _simpleBullet(
                                  'Log out when using shared computers'),
                              _simpleBullet(
                                  'Regularly review user access and remove inactive accounts'),
                              _simpleBullet(
                                  'Enable all available security features for your HOA'),
                              _simpleBullet(
                                  'Report any suspicious activity immediately to our support team'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // ── Incident Response Highlight ──
                        _HighlightBox(
                          title: 'Incident Response',
                          description:
                              'In the unlikely event of a security incident, we have a comprehensive response plan to immediately contain, investigate, and resolve the issue. All affected users are notified promptly with clear information about the incident and recommended actions.',
                        ),
                        const SizedBox(height: 32),

                        // ── Contact ──
                        _SectionCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Questions About Security?',
                                  style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: _dark)),
                              const SizedBox(height: 12),
                              const Text(
                                'If you have questions about our security practices, need to report a security concern, or want to learn more about how we protect your data, please contact our team.',
                                style: TextStyle(
                                    fontSize: 15, color: _muted, height: 1.7),
                              ),
                              const SizedBox(height: 8),
                              SelectableText(
                                'security@hoapp.net',
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: _brand,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 48),

                        // ── CTA ──
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(isMobile ? 28 : 40),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFF2E5C3F),
                                Color(0xFF3A7A50),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'Secure HOA Management You Can Trust',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: isMobile ? 22 : 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Join homeowners associations who trust HOApp to protect their sensitive data. Start your free plan today.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: isMobile ? 14 : 16,
                                  color: Colors.white.withOpacity(0.92),
                                ),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton(
                                onPressed: () => context.go('/signup'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: _brand,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isMobile ? 28 : 36,
                                    vertical: isMobile ? 14 : 18,
                                  ),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30)),
                                  elevation: 4,
                                ),
                                child: const Text('Get Started Free',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ),
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
          const MarketingNavBar(activePage: 'Security'),
        ],
      ),
    );
  }
}

// ─── Helper Widgets ────────────────────────────────────────

Widget _bulletPoint(String label, String description) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8, left: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('• ',
            style: TextStyle(fontSize: 15, color: _muted, height: 1.7)),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 15, color: _muted, height: 1.7),
              children: [
                TextSpan(
                    text: '$label ',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(text: description),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _simpleBullet(String text) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 6, left: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('• ',
            style: TextStyle(fontSize: 15, color: _muted, height: 1.7)),
        Expanded(
          child: Text(text,
              style: const TextStyle(fontSize: 15, color: _muted, height: 1.7)),
        ),
      ],
    ),
  );
}

// ─── Section Card ──────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
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
      child: child,
    );
  }
}

// ─── Equal-Height Grid Builder ─────────────────────────────

List<Widget> _buildEqualHeightGrid({
  required bool isMobile,
  required bool isNarrow,
  required List<Widget> children,
}) {
  final columns = isMobile
      ? 1
      : isNarrow
          ? 2
          : 3;
  final rows = <Widget>[];

  for (var i = 0; i < children.length; i += columns) {
    final rowChildren = <Widget>[];
    for (var j = 0; j < columns && i + j < children.length; j++) {
      if (j > 0) rowChildren.add(const SizedBox(width: 16));
      rowChildren.add(Expanded(child: children[i + j]));
    }
    // Fill remaining slots to keep column widths consistent
    for (var j = children.length - i; j < columns; j++) {
      rowChildren.add(const SizedBox(width: 16));
      rowChildren.add(const Expanded(child: SizedBox()));
    }
    if (i > 0) rows.add(const SizedBox(height: 16));
    rows.add(IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: rowChildren,
      ),
    ));
  }
  return rows;
}

// ─── Security Feature Card ─────────────────────────────────

class _SecurityCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _SecurityCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
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
              color: _greenLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 24, color: _green),
          ),
          const SizedBox(height: 14),
          Text(title,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: _dark)),
          const SizedBox(height: 8),
          Text(description,
              style: const TextStyle(fontSize: 14, color: _muted, height: 1.5)),
        ],
      ),
    );
  }
}

// ─── Highlight Box ─────────────────────────────────────────

class _HighlightBox extends StatelessWidget {
  final String title;
  final String description;
  const _HighlightBox({required this.title, required this.description});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _greenLight,
        borderRadius: BorderRadius.circular(12),
        border: const Border(
          left: BorderSide(color: _green, width: 4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w600, color: _green)),
          const SizedBox(height: 8),
          Text(description,
              style: const TextStyle(fontSize: 15, color: _dark, height: 1.6)),
        ],
      ),
    );
  }
}

// ─── Compliance Badge ──────────────────────────────────────

class _ComplianceBadge extends StatelessWidget {
  final String label;
  const _ComplianceBadge(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: _greenLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: _green,
        ),
      ),
    );
  }
}
