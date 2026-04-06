import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

const _brand = Color(0xFF2E5C3F);

/// Shows a beautified beta access request dialog with an inline form.
void showBetaAccessDialog(BuildContext context) {
  final nameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final orgCtrl = TextEditingController();
  final formKey = GlobalKey<FormState>();

  showDialog(
    context: context,
    builder: (ctx) {
      var sending = false;
      var sent = false;
      String? error;

      return StatefulBuilder(
        builder: (ctx, setDialogState) {
          if (sent) {
            return Dialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 420),
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.green.shade50,
                            Colors.green.shade100,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.check_circle_outline_rounded,
                          size: 52, color: Colors.green.shade600),
                    ),
                    const SizedBox(height: 20),
                    const Text('Request Submitted!',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    const Text(
                      'Thank you for your interest! We\'ll review your request and send you an invite shortly.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Color(0xFF6B7280), fontSize: 14, height: 1.5),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _brand,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Done',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return Dialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 440),
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header icon
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.amber.shade50,
                          Colors.orange.shade50,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.science_rounded,
                        size: 44, color: Colors.amber.shade700),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Request Beta Access',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'HOApp is currently in beta. Fill out the form below and we\'ll send you an invite.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 14, color: Color(0xFF6B7280), height: 1.5),
                  ),
                  const SizedBox(height: 24),

                  // Form
                  Form(
                    key: formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: nameCtrl,
                          decoration: InputDecoration(
                            labelText: 'Full Name',
                            hintText: 'Juan Dela Cruz',
                            prefixIcon: const Icon(Icons.person_outline),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  const BorderSide(color: _brand, width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                          validator: (v) =>
                              (v?.trim().isEmpty ?? true) ? 'Required' : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: emailCtrl,
                          decoration: InputDecoration(
                            labelText: 'Email Address',
                            hintText: 'you@example.com',
                            prefixIcon: const Icon(Icons.email_outlined),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  const BorderSide(color: _brand, width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty)
                              return 'Required';
                            if (!v.contains('@')) return 'Enter a valid email';
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: orgCtrl,
                          decoration: InputDecoration(
                            labelText: 'Community / Organization',
                            hintText: 'e.g. Greenfield Village HOA',
                            prefixIcon: const Icon(Icons.apartment_outlined),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  const BorderSide(color: _brand, width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty)
                              return 'Required';
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),

                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline,
                              size: 18, color: Colors.red.shade600),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(error!,
                                style: TextStyle(
                                    color: Colors.red.shade700, fontSize: 13)),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: sending ? null : () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF6B7280),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Cancel',
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w500)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: sending
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;
                                  setDialogState(() {
                                    sending = true;
                                    error = null;
                                  });
                                  try {
                                    final response = await Supabase
                                        .instance.client.functions
                                        .invoke(
                                      'request_access',
                                      body: {
                                        'name': nameCtrl.text.trim(),
                                        'email': emailCtrl.text.trim(),
                                        'organization': orgCtrl.text.trim(),
                                      },
                                    );
                                    if (response.status != 200) {
                                      final data = response.data
                                          as Map<String, dynamic>?;
                                      throw Exception(data?['error'] ??
                                          'Failed to submit request');
                                    }
                                    setDialogState(() => sent = true);
                                  } catch (e) {
                                    setDialogState(() {
                                      error = e
                                          .toString()
                                          .replaceFirst('Exception: ', '');
                                      sending = false;
                                    });
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _brand,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: _brand.withOpacity(0.6),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: sending
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Submit Request',
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
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
                  label: 'Security',
                  route: '/security',
                  active: activePage == 'Security'),
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
                _MobileNavTile(
                    'Security', '/security', activePage == 'Security', ctx),
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
            child: isMobile
                ? _buildMobileLayout(context)
                : _buildDesktopLayout(context),
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
            child: Text(
              '\u00a9 $year HOApp. All rights reserved.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
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
                    child: const Icon(Icons.home_work_outlined,
                        color: Colors.white, size: 20),
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
                'Smart HOA Management for Modern Communities.',
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
              'Data Security': '/security',
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
              const SizedBox(height: 16),
              _buildFacebookLink(),
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
              child: const Icon(Icons.home_work_outlined,
                  color: Colors.white, size: 20),
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
          'Smart HOA Management for Modern Communities.',
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
                'Data Security': '/security',
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
        const SizedBox(height: 16),
        _buildFacebookLink(),
      ],
    );
  }

  Widget _buildLinkColumn(
      BuildContext context, String title, Map<String, String> links) {
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

  static Widget _buildFacebookLink() {
    return InkWell(
      onTap: () => launchUrl(
        Uri.parse('https://www.facebook.com/profile.php?id=61576472196862'),
        mode: LaunchMode.externalApplication,
      ),
      borderRadius: BorderRadius.circular(6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.facebook, size: 18, color: Colors.white.withOpacity(0.6)),
          const SizedBox(width: 8),
          Text(
            'Follow us on Facebook',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
