import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Advanced cookie-consent banner with category toggles, slide-up animation,
/// and a polished glassmorphic design.
class CookieConsentBanner extends StatefulWidget {
  const CookieConsentBanner({super.key});

  @override
  State<CookieConsentBanner> createState() => _CookieConsentBannerState();
}

class _CookieConsentBannerState extends State<CookieConsentBanner>
    with SingleTickerProviderStateMixin {
  static const _consentKey = 'cookie_consent_accepted';
  static const _analyticsKey = 'cookie_analytics';
  static const _marketingKey = 'cookie_marketing';

  bool _ready = false;
  bool _showDetails = false;
  bool _analytics = true;
  bool _marketing = false;

  late final AnimationController _animController;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeIn,
    );
    _checkConsent();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _checkConsent() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_consentKey) && mounted) {
      setState(() => _ready = true);
      // Short delay so the page renders first
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) _animController.forward();
      });
    }
  }

  Future<void> _acceptAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_consentKey, true);
    await prefs.setBool(_analyticsKey, true);
    await prefs.setBool(_marketingKey, true);
    _dismiss();
  }

  Future<void> _acceptSelected() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_consentKey, true);
    await prefs.setBool(_analyticsKey, _analytics);
    await prefs.setBool(_marketingKey, _marketing);
    _dismiss();
  }

  Future<void> _rejectOptional() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_consentKey, true);
    await prefs.setBool(_analyticsKey, false);
    await prefs.setBool(_marketingKey, false);
    _dismiss();
  }

  void _dismiss() {
    _animController.reverse().then((_) {
      if (mounted) setState(() => _ready = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const SizedBox.shrink();

    final isMobile = MediaQuery.of(context).size.width < 600;

    return Positioned(
      left: isMobile ? 8 : 24,
      right: isMobile ? 8 : 24,
      bottom: isMobile ? 8 : 24,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 640),
              decoration: BoxDecoration(
                color: const Color(0xF0FFFFFF),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF2E5C3F).withOpacity(0.15),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: const Color(0xFF2E5C3F).withOpacity(0.06),
                    blurRadius: 40,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: EdgeInsets.all(isMobile ? 20 : 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2E5C3F).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text('🍪',
                                style: TextStyle(fontSize: 22)),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Cookie Preferences',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1F2937),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Manage how we use cookies on this site',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Description
                      const Text(
                        'We use cookies to ensure the best experience on our site. '
                        'Essential cookies are always active. You can choose which '
                        'optional cookies to allow.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6B7280),
                          height: 1.55,
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Categories — always-visible essential + expandable optional
                      _CookieCategory(
                        icon: Icons.shield_outlined,
                        title: 'Essential',
                        subtitle: 'Required for the site to function',
                        enabled: true,
                        locked: true,
                        onChanged: null,
                      ),

                      if (_showDetails) ...[
                        const SizedBox(height: 8),
                        _CookieCategory(
                          icon: Icons.bar_chart_rounded,
                          title: 'Analytics',
                          subtitle: 'Help us understand usage patterns',
                          enabled: _analytics,
                          locked: false,
                          onChanged: (v) => setState(() => _analytics = v),
                        ),
                        const SizedBox(height: 8),
                        _CookieCategory(
                          icon: Icons.campaign_outlined,
                          title: 'Marketing',
                          subtitle: 'Personalized content & ads',
                          enabled: _marketing,
                          locked: false,
                          onChanged: (v) => setState(() => _marketing = v),
                        ),
                      ],

                      const SizedBox(height: 6),

                      // Customize toggle
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () =>
                              setState(() => _showDetails = !_showDetails),
                          icon: Icon(
                            _showDetails
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.tune_rounded,
                            size: 18,
                          ),
                          label: Text(
                            _showDetails ? 'Show less' : 'Customize',
                            style: const TextStyle(fontSize: 13),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF2E5C3F),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Action buttons
                      isMobile
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _acceptAllButton(),
                                const SizedBox(height: 8),
                                if (_showDetails) ...[
                                  _savePreferencesButton(),
                                  const SizedBox(height: 8),
                                ],
                                _rejectButton(),
                              ],
                            )
                          : Row(
                              children: [
                                _rejectButton(),
                                const Spacer(),
                                if (_showDetails) ...[
                                  _savePreferencesButton(),
                                  const SizedBox(width: 10),
                                ],
                                _acceptAllButton(),
                              ],
                            ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _acceptAllButton() {
    return ElevatedButton(
      onPressed: _acceptAll,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF2E5C3F),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
      child: const Text('Accept All',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
    );
  }

  Widget _savePreferencesButton() {
    return OutlinedButton(
      onPressed: _acceptSelected,
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF2E5C3F),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        side: const BorderSide(color: Color(0xFF2E5C3F), width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: const Text('Save Preferences',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
    );
  }

  Widget _rejectButton() {
    return TextButton(
      onPressed: _rejectOptional,
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFF6B7280),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      child: const Text('Essential Only', style: TextStyle(fontSize: 13)),
    );
  }
}

/// A single cookie-category row with a toggle switch.
class _CookieCategory extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final bool locked;
  final ValueChanged<bool>? onChanged;

  const _CookieCategory({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.locked,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: enabled
            ? const Color(0xFF2E5C3F).withOpacity(0.05)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: enabled
              ? const Color(0xFF2E5C3F).withOpacity(0.15)
              : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(icon,
              size: 20,
              color: enabled ? const Color(0xFF2E5C3F) : Colors.grey.shade400),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1F2937))),
                    if (locked) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E5C3F).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('Required',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF2E5C3F))),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(subtitle,
                    style:
                        TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              ],
            ),
          ),
          SizedBox(
            height: 28,
            child: Switch.adaptive(
              value: enabled,
              onChanged: locked ? null : onChanged,
              activeColor: const Color(0xFF2E5C3F),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }
}
