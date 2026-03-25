import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // backgroundColor: const Color(0xFFE8E0D5), // Beige background
      body: Stack(
        children: [
          // Background and scrollable content
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
                  // Spacing for fixed navigation bar
                  const SizedBox(height: 72),

                  // Main content
                  Container(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 60),
                    child: Column(
                      children: [
                        // Large logo and tagline
                        Image.asset(
                          'assets/images/hoapp-logo.png',
                          height: 120,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 120,
                              alignment: Alignment.center,
                              child: const Text(
                                'HOApp',
                                style: TextStyle(
                                  fontSize: 64,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2E5C3F),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        const SizedBox(height: 32),
                        RichText(
                          textAlign: TextAlign.center,
                          text: const TextSpan(
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF1F2937),
                            ),
                            children: [
                              TextSpan(
                                  text: 'Efficient ',
                                  style: TextStyle(color: Color(0xFF2E5C3F))),
                              TextSpan(
                                text: '— ',
                                style: TextStyle(color: Color(0xFF6B7280)),
                              ),
                              TextSpan(
                                  text: 'Management, Effortless Community.',
                                  style: TextStyle(color: Color(0xFF2E5C3F))),
                            ],
                          ),
                        ),
                        const SizedBox(height: 60),

                        // Feature cards grid
                        Wrap(
                          spacing: 24,
                          runSpacing: 24,
                          alignment: WrapAlignment.center,
                          children: [
                            _FeatureCard(
                              icon: Icons.campaign_outlined,
                              title: 'Announcements',
                              description: 'Keep your community informed',
                              onLearnMore: () {},
                            ),
                            _FeatureCard(
                              icon: Icons.credit_card_outlined,
                              title: 'Billing & Payments',
                              description: 'Streamlined payment processing',
                              onLearnMore: () {},
                            ),
                            _FeatureCard(
                              icon: Icons.home_outlined,
                              title: 'Households',
                              description: 'Manage households efficiently',
                              onLearnMore: () {},
                            ),
                            _FeatureCard(
                              icon: Icons.gavel_outlined,
                              title: 'Violations & Tickets',
                              description: 'Manage community rules and fines',
                              onLearnMore: () {},
                            ),
                            _FeatureCard(
                              icon: Icons.house_outlined,
                              title: 'Amenity Reservations',
                              description: 'Reserve community amenities easily',
                              onLearnMore: () {},
                            ),
                            _FeatureCard(
                              icon: Icons.pool_outlined,
                              title: 'Pool Management',
                              description: 'Manage pool access efficiently',
                              onLearnMore: () {},
                            ),
                          ],
                        ),

                        const SizedBox(height: 60),

                        // Call to action
                        const Text(
                          'Ready to unify your community? Choose an action:',
                          style: TextStyle(
                            fontSize: 20,
                            color: Color(0xFF1F2937),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton(
                              onPressed: () => context.go('/signup'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2E5C3F),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 48,
                                  vertical: 20,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                elevation: 4,
                              ),
                              child: const Text(
                                'Get Started',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            OutlinedButton(
                              onPressed: () => context.go('/login'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF2E5C3F),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 48,
                                  vertical: 20,
                                ),
                                side: const BorderSide(
                                  color: Color(0xFF2E5C3F),
                                  width: 2,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              child: const Text(
                                'Login',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 60),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Fixed navigation bar at top
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Logo
                  Image.asset(
                    'assets/images/hoapp-icon.png',
                    height: 40,
                    errorBuilder: (context, error, stackTrace) {
                      return const SizedBox(height: 40);
                    },
                  ),
                  const Spacer(),
                  // Navigation items
                  _NavItem(label: 'Features', onTap: () {}),
                  const SizedBox(width: 32),
                  _NavItem(label: 'Pricing', onTap: () {}),
                  const SizedBox(width: 32),
                  _NavItem(label: 'Support', onTap: () {}),
                  const SizedBox(width: 32),
                  _NavItem(label: 'Contact', onTap: () {}),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _NavItem({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 16,
          color: Color(0xFF1F2937),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onLearnMore;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onLearnMore,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      height: 245,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.90),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF2E5C3F).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 48,
              color: const Color(0xFF2E5C3F),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF6B7280),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
