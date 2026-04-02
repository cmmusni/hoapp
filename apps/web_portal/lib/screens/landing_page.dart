import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'marketing_nav_bar.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 600;

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
                  const SizedBox(height: 96),

                  // Main content
                  Container(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 16 : 32,
                      vertical: isMobile ? 32 : 60,
                    ),
                    child: Column(
                      children: [
                        // Large logo and tagline
                        Image.asset(
                          'assets/images/hoapp-logo.png',
                          height: isMobile ? 80 : 120,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: isMobile ? 80 : 120,
                              alignment: Alignment.center,
                              child: Text(
                                'HOApp',
                                style: TextStyle(
                                  fontSize: isMobile ? 40 : 64,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF2E5C3F),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 32),
                        RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: TextStyle(
                              fontSize: isMobile ? 22 : 32,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF1F2937),
                            ),
                            children: const [
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
                        const SizedBox(height: 30),

                        // Feature cards grid
                        Wrap(
                          spacing: isMobile ? 16 : 24,
                          runSpacing: isMobile ? 16 : 24,
                          alignment: WrapAlignment.center,
                          children: [
                            _FeatureCard(
                              icon: Icons.campaign_outlined,
                              title: 'Announcements',
                              description: 'Keep your community informed',
                              onLearnMore: () {},
                              isMobile: isMobile,
                            ),
                            _FeatureCard(
                              icon: Icons.credit_card_outlined,
                              title: 'Billing & Payments',
                              description: 'Streamlined payment processing',
                              onLearnMore: () {},
                              isMobile: isMobile,
                            ),
                            _FeatureCard(
                              icon: Icons.home_outlined,
                              title: 'Households',
                              description: 'Manage community units efficiently',
                              onLearnMore: () {},
                              isMobile: isMobile,
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // View More button
                        OutlinedButton.icon(
                          onPressed: () => context.go('/features'),
                          icon: const Icon(Icons.arrow_forward),
                          label: const Text('View All Features'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF2E5C3F),
                            padding: EdgeInsets.symmetric(
                              horizontal: isMobile ? 24 : 32,
                              vertical: isMobile ? 12 : 16,
                            ),
                            side: const BorderSide(
                                color: Color(0xFF2E5C3F), width: 2),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30)),
                          ),
                        ),

                        const SizedBox(height: 60),

                        // Trusted By section
                        Text(
                          'Trusted By',
                          style: TextStyle(
                            fontSize: isMobile ? 16 : 18,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF6B7280),
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 24 : 40,
                            vertical: isMobile ? 20 : 28,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.85),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.asset(
                                  'assets/images/trusted-by-eleve.png',
                                  width: isMobile ? 48 : 56,
                                  height: isMobile ? 48 : 56,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Elevé Homes Camarin',
                                    style: TextStyle(
                                      fontSize: isMobile ? 18 : 20,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF1F2937),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Caloocan City, Philippines',
                                    style: TextStyle(
                                      fontSize: isMobile ? 13 : 14,
                                      color: const Color(0xFF6B7280),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 60),

                        // Call to action
                        Text(
                          'Ready to unify your community? Choose an action:',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: isMobile ? 17 : 20,
                            color: const Color(0xFF1F2937),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Wrap(
                          spacing: 16,
                          runSpacing: 12,
                          alignment: WrapAlignment.center,
                          children: [
                            ElevatedButton(
                              onPressed: () => context.go('/pricing'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2E5C3F),
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(
                                  horizontal: isMobile ? 32 : 48,
                                  vertical: isMobile ? 16 : 20,
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
                            OutlinedButton(
                              onPressed: () => context.go('/login'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF2E5C3F),
                                padding: EdgeInsets.symmetric(
                                  horizontal: isMobile ? 32 : 48,
                                  vertical: isMobile ? 16 : 20,
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

                  // Footer
                  const MarketingFooter(),
                ],
              ),
            ),
          ),

          // Fixed navigation bar at top
          const MarketingNavBar(activePage: 'Home'),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onLearnMore;
  final bool isMobile;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onLearnMore,
    this.isMobile = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: isMobile ? double.infinity : 300,
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
      padding: EdgeInsets.all(isMobile ? 24 : 32),
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
              size: isMobile ? 36 : 48,
              color: const Color(0xFF2E5C3F),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: TextStyle(
              fontSize: isMobile ? 18 : 20,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1F2937),
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
