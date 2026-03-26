import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

const _brand = Color(0xFF2E5C3F);

/// Shows a beta access dialog before allowing the user to proceed to the signup page.
void showBetaAccessDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.science_outlined,
                size: 48, color: Colors.amber.shade700),
          ),
          const SizedBox(height: 16),
          const Text(
            'Beta Testing Phase',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'HOApp is currently in beta testing. You can request early access or continue to explore the signup page.',
            textAlign: TextAlign.center,
            style:
                TextStyle(fontSize: 14, color: Color(0xFF6B7280), height: 1.5),
          ),
          const SizedBox(height: 24),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                context.go('/contact');
              },
              icon: const Icon(Icons.mail_outline, size: 18),
              label: const Text('Request Access'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _brand,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            // const SizedBox(height: 8),
            // OutlinedButton(
            //   onPressed: () {
            //     Navigator.pop(ctx);
            //     context.go('/signup');
            //   },
            //   style: OutlinedButton.styleFrom(
            //     foregroundColor: _brand,
            //     padding: const EdgeInsets.symmetric(vertical: 14),
            //     side: const BorderSide(color: _brand),
            //     shape: RoundedRectangleBorder(
            //         borderRadius: BorderRadius.circular(12)),
            //   ),
            //   child: const Text('Continue to Signup'),
            // ),
          ],
        ),
      ],
    ),
  );
}

/// Shared navigation bar for all marketing pages (Home, Features, Pricing, Support, Contact).
class MarketingNavBar extends StatelessWidget {
  final String activePage;

  const MarketingNavBar({super.key, this.activePage = ''});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 768;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : 32,
          vertical: isMobile ? 10 : 16,
        ),
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
            GestureDetector(
              onTap: () => context.go('/'),
              child: Image.asset(
                'assets/images/hoapp-icon.png',
                height: isMobile ? 32 : 40,
                errorBuilder: (context, error, stackTrace) =>
                    SizedBox(height: isMobile ? 32 : 40),
              ),
            ),
            const Spacer(),
            if (isMobile)
              _MobileMenuButton(activePage: activePage)
            else ...[
              _NavItem(label: 'Home', route: '/', active: activePage == 'Home'),
              const SizedBox(width: 32),
              _NavItem(
                  label: 'Features',
                  route: '/features',
                  active: activePage == 'Features'),
              const SizedBox(width: 32),
              _NavItem(
                  label: 'Pricing',
                  route: '/pricing',
                  active: activePage == 'Pricing'),
              const SizedBox(width: 32),
              _NavItem(
                  label: 'Support',
                  route: '/support',
                  active: activePage == 'Support'),
              const SizedBox(width: 32),
              _NavItem(
                  label: 'Contact',
                  route: '/contact',
                  active: activePage == 'Contact'),
              const SizedBox(width: 32),
              TextButton(
                onPressed: () => context.go('/login'),
                style: TextButton.styleFrom(
                  backgroundColor: _brand,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24)),
                ),
                child: const Text('Login',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MobileMenuButton extends StatelessWidget {
  final String activePage;
  const _MobileMenuButton({required this.activePage});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.menu, color: _brand, size: 28),
      onPressed: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.white,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                _MobileNavTile('Home', '/', activePage == 'Home', ctx),
                _MobileNavTile(
                    'Features', '/features', activePage == 'Features', ctx),
                _MobileNavTile(
                    'Pricing', '/pricing', activePage == 'Pricing', ctx),
                _MobileNavTile(
                    'Support', '/support', activePage == 'Support', ctx),
                _MobileNavTile(
                    'Contact', '/contact', activePage == 'Contact', ctx),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.login, color: _brand),
                  title: const Text('Login',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, color: _brand)),
                  onTap: () {
                    Navigator.pop(ctx);
                    context.go('/login');
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  static Widget _MobileNavTile(
      String label, String route, bool active, BuildContext ctx) {
    return ListTile(
      title: Text(
        label,
        style: TextStyle(
          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          color: active ? _brand : const Color(0xFF1F2937),
        ),
      ),
      trailing:
          active ? const Icon(Icons.circle, size: 8, color: _brand) : null,
      onTap: active
          ? null
          : () {
              Navigator.pop(ctx);
              ctx.go(route);
            },
    );
  }
}

class _NavItem extends StatelessWidget {
  final String label;
  final String route;
  final bool active;

  const _NavItem({
    required this.label,
    required this.route,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: active ? null : () => context.go(route),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 16,
          color: active ? _brand : const Color(0xFF1F2937),
          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }
}

/// Shared footer for all marketing pages.
class MarketingFooter extends StatelessWidget {
  const MarketingFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 600;
    final year = DateTime.now().year;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
      ),
      child: Column(
        children: [
          // Main footer content
          Container(
            constraints: const BoxConstraints(maxWidth: 1200),
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 20 : 40,
              vertical: isMobile ? 32 : 48,
            ),
            child: isMobile ? _buildMobileLayout(context) : _buildDesktopLayout(context),
          ),

          // Divider
          Container(
            width: double.infinity,
            height: 1,
            color: Colors.white.withOpacity(0.1),
          ),

          // Bottom bar
          Container(
            constraints: const BoxConstraints(maxWidth: 1200),
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 20 : 40,
              vertical: 16,
            ),
            child: isMobile
                ? Column(
                    children: [
                      Text(
                        '\u00a9 $year HOApp. All rights reserved.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Developed by Clifford Mark Musni',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '\u00a9 $year HOApp. All rights reserved.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        'Developed by Clifford Mark Musni',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Brand column
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _brand,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.home_work_outlined, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'HOApp',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Efficient Management,\nEffortless Community.',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),

        // Quick Links
        Expanded(
          child: _buildLinkColumn(
            context,
            'Product',
            {
              'Features': '/features',
              'Pricing': '/pricing',
              'Support': '/support',
            },
          ),
        ),

        // Company
        Expanded(
          child: _buildLinkColumn(
            context,
            'Company',
            {
              'Contact': '/contact',
              'Login': '/login',
            },
          ),
        ),

        // Contact info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Get in Touch',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              _buildContactRow(Icons.email_outlined, 'support@hoapp.net'),
              const SizedBox(height: 10),
              _buildContactRow(Icons.language_outlined, 'hoapp.net'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return Column(
      children: [
        // Brand
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _brand,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.home_work_outlined, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'HOApp',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Efficient Management, Effortless Community.',
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 13,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),

        // Links row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLinkColumn(
              context,
              'Product',
              {
                'Features': '/features',
                'Pricing': '/pricing',
                'Support': '/support',
              },
            ),
            _buildLinkColumn(
              context,
              'Company',
              {
                'Contact': '/contact',
                'Login': '/login',
              },
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Contact
        _buildContactRow(Icons.email_outlined, 'support@hoapp.net'),
        const SizedBox(height: 8),
        _buildContactRow(Icons.language_outlined, 'hoapp.net'),
      ],
    );
  }

  Widget _buildLinkColumn(BuildContext context, String title, Map<String, String> links) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        ...links.entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: () => context.go(e.value),
                child: Text(
                  e.key,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 13,
                  ),
                ),
              ),
            )),
      ],
    );
  }

  static Widget _buildContactRow(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.white.withOpacity(0.5)),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}
