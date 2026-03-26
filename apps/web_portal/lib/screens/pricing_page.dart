import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'marketing_nav_bar.dart';

const _brand = Color(0xFF2E5C3F);

class PricingPage extends StatelessWidget {
  const PricingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isNarrow = screenWidth < 900;
    final isMobile = screenWidth < 600;

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
                          'Simple, Transparent Pricing',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: isMobile ? 28 : 36,
                            fontWeight: FontWeight.bold,
                            color: _brand,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Choose the plan that fits your community. No hidden fees.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: isMobile ? 14 : 16,
                            color: const Color(0xFF6B7280),
                          ),
                        ),
                        const SizedBox(height: 48),

                        // Pricing cards
                        isNarrow
                            ? Column(
                                children: [
                                  _PricingCard(
                                    title: 'Starter',
                                    price: 'Free',
                                    period: '',
                                    description:
                                        'Perfect for small communities getting started.',
                                    features: const [
                                      'Up to 50 units',
                                      'Announcements',
                                      'Violations & Tickets',
                                      'Household Directory',
                                      'Community support',
                                    ],
                                    ctaLabel: 'Get Started',
                                    onCta: () => showBetaAccessDialog(context),
                                  ),
                                  const SizedBox(height: 24),
                                  _PricingCard(
                                    title: 'Professional',
                                    price: '₱2,499',
                                    period: '/month',
                                    description:
                                        'For growing communities that need more.',
                                    highlighted: true,
                                    features: const [
                                      'Up to 300 units',
                                      'Everything in Starter',
                                      'Billing & Payments',
                                      'Amenity Reservations',
                                      'Pool Access Management',
                                      'Security Passes & QR',
                                      'Mobile App',
                                      'Priority support',
                                    ],
                                    ctaLabel: 'Get Started',
                                    onCta: () => showBetaAccessDialog(context),
                                  ),
                                  const SizedBox(height: 24),
                                  _PricingCard(
                                    title: 'Enterprise',
                                    price: 'Custom',
                                    period: '',
                                    description:
                                        'For large-scale HOAs and property managers.',
                                    features: const [
                                      'Unlimited units',
                                      'Everything in Professional',
                                      'Multi-community dashboard',
                                      'Custom Features',
                                      'Dedicated account manager',
                                      'SLA & uptime guarantee',
                                    ],
                                    ctaLabel: 'Contact Sales',
                                    onCta: () {},
                                  ),
                                ],
                              )
                            : Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: _PricingCard(
                                      title: 'Starter',
                                      price: 'Free',
                                      period: '',
                                      description:
                                          'Perfect for small communities getting started.',
                                      features: const [
                                        'Up to 50 units',
                                        'Announcements',
                                        'Violations & Tickets',
                                        'Household Directory',
                                        'Community support',
                                      ],
                                      ctaLabel: 'Get Started',
                                      onCta: () =>
                                          showBetaAccessDialog(context),
                                    ),
                                  ),
                                  const SizedBox(width: 24),
                                  Expanded(
                                    child: _PricingCard(
                                      title: 'Professional',
                                      price: '₱2,499',
                                      period: '/month',
                                      description:
                                          'For growing communities that need more.',
                                      highlighted: true,
                                      features: const [
                                        'Up to 300 units',
                                        'Everything in Starter',
                                        'Billing & Payments',
                                        'Amenity Reservations',
                                        'Pool Access Management',
                                        'Security Passes & QR',
                                        'Mobile App',
                                        'Priority support',
                                      ],
                                      ctaLabel: 'Get Started',
                                      onCta: () =>
                                          showBetaAccessDialog(context),
                                    ),
                                  ),
                                  const SizedBox(width: 24),
                                  Expanded(
                                    child: _PricingCard(
                                      title: 'Enterprise',
                                      price: 'Custom',
                                      period: '',
                                      description:
                                          'For large-scale HOAs and property managers.',
                                      features: const [
                                        'Unlimited units',
                                        'Everything in Professional',
                                        'Multi-community dashboard',
                                        'Custom Features',
                                        'Dedicated account manager',
                                        'SLA & uptime guarantee',
                                      ],
                                      ctaLabel: 'Contact Sales',
                                      onCta: () {},
                                    ),
                                  ),
                                ],
                              ),

                        const SizedBox(height: 60),

                        // FAQ teaser
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
                            children: [
                              const Text(
                                'Frequently Asked Questions',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1F2937),
                                ),
                              ),
                              const SizedBox(height: 24),
                              _faqItem(
                                'Can I switch plans later?',
                                'Yes — you can upgrade or downgrade anytime. Changes take effect on your next billing cycle.',
                              ),
                              _faqItem(
                                'Is there a setup fee?',
                                'No. All plans include free onboarding and community setup assistance.',
                              ),
                              _faqItem(
                                'What payment methods do you accept?',
                                'We accept credit/debit cards, GCash, Maya, and bank transfers.',
                              ),
                              _faqItem(
                                'Can I try Professional features for free?',
                                'Yes — every new community gets a 30-day free trial of Professional features.',
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 48),

                        // CTA
                        Wrap(
                          spacing: 16,
                          runSpacing: 12,
                          alignment: WrapAlignment.center,
                          children: [
                            ElevatedButton(
                              onPressed: () => showBetaAccessDialog(context),
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
                              child: const Text('Get Started Free',
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
          const MarketingNavBar(activePage: 'Pricing'),
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
          Text(
            question,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            answer,
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

// ─── Pricing Card ──────────────────────────────────────────

class _PricingCard extends StatelessWidget {
  final String title;
  final String price;
  final String period;
  final String description;
  final List<String> features;
  final String ctaLabel;
  final VoidCallback onCta;
  final bool highlighted;

  const _PricingCard({
    required this.title,
    required this.price,
    required this.period,
    required this.description,
    required this.features,
    required this.ctaLabel,
    required this.onCta,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: highlighted ? _brand : Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(20),
        border: highlighted ? null : Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(highlighted ? 0.15 : 0.06),
            blurRadius: highlighted ? 20 : 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (highlighted)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Most Popular',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: highlighted ? Colors.white : const Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                price,
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: highlighted ? Colors.white : _brand,
                ),
              ),
              if (period.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6, left: 2),
                  child: Text(
                    period,
                    style: TextStyle(
                      fontSize: 15,
                      color: highlighted
                          ? Colors.white70
                          : const Color(0xFF6B7280),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              fontSize: 14,
              color: highlighted ? Colors.white70 : const Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 20),
          Divider(color: highlighted ? Colors.white24 : Colors.grey.shade200),
          const SizedBox(height: 16),
          ...features.map(
            (f) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Icon(Icons.check_circle,
                      size: 18, color: highlighted ? Colors.white : _brand),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      f,
                      style: TextStyle(
                        fontSize: 14,
                        color: highlighted
                            ? Colors.white
                            : const Color(0xFF374151),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onCta,
              style: ElevatedButton.styleFrom(
                backgroundColor: highlighted ? Colors.white : _brand,
                foregroundColor: highlighted ? _brand : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: Text(
                ctaLabel,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
