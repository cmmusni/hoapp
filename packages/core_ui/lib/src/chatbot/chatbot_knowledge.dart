/// Local knowledge base for the portal help chatbot.
///
/// Each [HelpTopic] maps keywords to an answer and optional navigation route.
/// The matcher picks the topic with the highest keyword overlap.
class HelpTopic {
  final String question;
  final List<String> keywords;
  final String answer;
  final String? route; // optional route suffix e.g. '/announcements'
  final List<String> roles; // empty = all roles

  const HelpTopic({
    required this.question,
    required this.keywords,
    required this.answer,
    this.route,
    this.roles = const [],
  });
}

const List<HelpTopic> helpTopics = [
  // ── General Navigation ──────────────────────────────────────────────
  HelpTopic(
    question: 'How do I navigate the app?',
    keywords: ['navigate', 'menu', 'sidebar', 'find', 'where', 'go', 'page'],
    answer:
        'Use the sidebar (desktop) or hamburger menu (mobile) on the left to switch between pages. '
        'Each icon represents a feature. Your available pages depend on your role and your community\'s plan.',
  ),
  HelpTopic(
    question: 'What features are available to me?',
    keywords: ['features', 'available', 'access', 'what can i', 'role'],
    answer: 'Your available features depend on your role:\n'
        '• **Residents** – Announcements, Billing, Amenities, Pool Access, Security Pass, Feedback, Tickets\n'
        '• **Staff / Admin** – All resident features plus Violations, Households, Manage Users, Expense Tracker, Settings\n'
        '• **Guard** – QR Scanner, Pool Access, Registered Swimmers\n\n'
        'Some features (Amenities, Billing, Pool Access, Expenses) require the Professional plan.',
  ),

  // ── Announcements ───────────────────────────────────────────────────
  HelpTopic(
    question: 'How do I view announcements?',
    keywords: [
      'announcement',
      'announcements',
      'news',
      'notice',
      'view announcement'
    ],
    answer: '1. Tap **Announcements** in the menu.\n'
        '2. You\'ll see a list of all published announcements sorted by date.\n'
        '3. Tap any announcement to read the full details.\n'
        '4. A red badge on the menu icon shows the number of unread announcements.',
    route: '/announcements',
  ),
  HelpTopic(
    question: 'How do I create an announcement?',
    keywords: [
      'create announcement',
      'post announcement',
      'new announcement',
      'publish'
    ],
    answer: '1. Go to the **Announcements** page.\n'
        '2. Click the **+** floating button.\n'
        '3. Fill in the title, body, and optional image.\n'
        '4. Set the publish date (schedule for later or publish now).\n'
        '5. Tap **Save** to publish.',
    route: '/announcements',
    roles: ['admin', 'staff'],
  ),

  // ── Violations ──────────────────────────────────────────────────────
  HelpTopic(
    question: 'How do I report or manage violations?',
    keywords: [
      'violation',
      'violations',
      'report',
      'offense',
      'penalty',
      'infraction'
    ],
    answer: '1. Go to the **Violations** page from the menu.\n'
        '2. Click the **+** button to file a new violation.\n'
        '3. Select the household/unit, violation type, and add details or photos.\n'
        '4. Submit the form. The violation will appear in the list.\n'
        '5. You can update the status (e.g., resolved) later from the detail view.',
    route: '/violations',
    roles: ['admin', 'staff'],
  ),

  // ── Tickets ─────────────────────────────────────────────────────────
  HelpTopic(
    question: 'How do I submit a support ticket?',
    keywords: [
      'ticket',
      'tickets',
      'support',
      'issue',
      'request',
      'concern',
      'help ticket'
    ],
    answer: '1. Navigate to the **Tickets** page.\n'
        '2. Click the **+** button to create a new ticket.\n'
        '3. Enter a subject, description, and optional attachment.\n'
        '4. Submit the ticket. Staff will review and respond.\n'
        '5. You\'ll receive a notification when there\'s an update.',
    route: '/tickets',
  ),

  // ── Amenities ───────────────────────────────────────────────────────
  HelpTopic(
    question: 'How do I book an amenity?',
    keywords: [
      'amenity',
      'amenities',
      'book',
      'reserve',
      'reservation',
      'clubhouse',
      'court',
      'gym'
    ],
    answer: '1. Go to **Amenities** in the menu.\n'
        '2. Browse the list of available amenities.\n'
        '3. Tap an amenity to see its calendar and available slots.\n'
        '4. Pick a date and time, then tap **Book**.\n'
        '5. If approval is required, your booking will show as "pending" until staff confirms it.\n\n'
        '*(Requires Professional plan)*',
    route: '/amenities',
  ),

  // ── Billing & Payments ──────────────────────────────────────────────
  HelpTopic(
    question: 'How do I pay my dues / view my billing?',
    keywords: [
      'billing',
      'payment',
      'pay',
      'dues',
      'invoice',
      'bill',
      'amount',
      'balance'
    ],
    answer: '1. Open the **Billing & Payments** page.\n'
        '2. You\'ll see your outstanding invoices and payment history.\n'
        '3. To pay, tap **Pay** on an invoice.\n'
        '4. Upload proof of payment (receipt or screenshot).\n'
        '5. Staff will verify and mark it as paid.\n\n'
        '*(Requires Professional plan)*',
    route: '/billing',
  ),
  HelpTopic(
    question: 'How do I create invoices for residents?',
    keywords: [
      'create invoice',
      'generate invoice',
      'send bill',
      'billing staff',
      'charge'
    ],
    answer: '1. Go to **Billing & Payments**.\n'
        '2. Switch to the **All Invoices** or staff tab.\n'
        '3. Tap the **+** button to create a new invoice.\n'
        '4. Select the household/unit, set the amount and due date.\n'
        '5. Submit – the resident will see it in their billing page.',
    route: '/billing',
    roles: ['admin', 'staff'],
  ),

  // ── Expense Tracker ─────────────────────────────────────────────────
  HelpTopic(
    question: 'How do I track community expenses?',
    keywords: [
      'expense',
      'expenses',
      'spending',
      'budget',
      'cost',
      'expenditure'
    ],
    answer: '1. Navigate to the **Expense Tracker** page.\n'
        '2. View summarized expenses by category and month.\n'
        '3. Tap **+** to log a new expense with amount, category, and receipt.\n'
        '4. Use the chart view for visual spending trends.\n\n'
        '*(Staff-only, requires Professional plan)*',
    route: '/expenses',
    roles: ['admin', 'staff'],
  ),

  // ── Pool Access ─────────────────────────────────────────────────────
  HelpTopic(
    question: 'How do I request pool access?',
    keywords: ['pool', 'pool access', 'swim', 'swimming', 'pool pass'],
    answer: '1. Go to **Pool Access** in the menu.\n'
        '2. Tap **Request Access** to submit a new pool access request.\n'
        '3. Upload required documents (medical clearance, ID, etc.).\n'
        '4. Staff will review your request and approve or decline.\n'
        '5. Once approved, you can use the pool during allowed hours.\n\n'
        '*(Requires Professional plan)*',
    route: '/pool-access',
  ),

  // ── Registered Swimmers ─────────────────────────────────────────────
  HelpTopic(
    question: 'How do I manage registered swimmers?',
    keywords: ['swimmer', 'swimmers', 'registered swimmer', 'pool member'],
    answer: '1. Open **Registered Swimmers** from the menu.\n'
        '2. View the list of approved swimmers for your community.\n'
        '3. Staff can add, edit, or revoke swimmer registrations.\n\n'
        '*(Staff/Guard only, requires Professional plan)*',
    route: '/registered-swimmers',
    roles: ['admin', 'staff', 'guard'],
  ),

  // ── Households ──────────────────────────────────────────────────────
  HelpTopic(
    question: 'How do I manage households and units?',
    keywords: [
      'household',
      'households',
      'unit',
      'units',
      'resident',
      'member',
      'tenant',
      'owner'
    ],
    answer: '1. Go to the **Households** page.\n'
        '2. Each card represents a unit with its members.\n'
        '3. Tap a unit to see/edit household details and members.\n'
        '4. Use the **+** button to add a new unit or member.\n'
        '5. You can assign roles (owner, tenant) to members.',
    route: '/households',
    roles: ['admin', 'staff'],
  ),

  // ── Manage Users ────────────────────────────────────────────────────
  HelpTopic(
    question: 'How do I manage user roles?',
    keywords: [
      'manage user',
      'user role',
      'assign role',
      'invite',
      'remove user',
      'admin'
    ],
    answer: '1. Navigate to **Manage Users**.\n'
        '2. See all users and their roles in this community.\n'
        '3. Tap a user to edit their role (admin, staff, resident, guard, maintenance).\n'
        '4. Use the invite feature to add new users by email.\n'
        '5. Remove users who should no longer have access.',
    route: '/manage-users',
    roles: ['admin'],
  ),

  // ── Settings ────────────────────────────────────────────────────────
  HelpTopic(
    question: 'How do I change community settings?',
    keywords: [
      'settings',
      'community settings',
      'configure',
      'logo',
      'name',
      'plan',
      'customize'
    ],
    answer: '1. Go to **Settings** (admin only).\n'
        '2. Update your community name, logo, color theme, and contact info.\n'
        '3. Manage your subscription plan (Basic → Professional).\n'
        '4. Configure feature toggles and notification preferences.\n'
        '5. Changes are saved and applied immediately.',
    route: '/settings',
    roles: ['admin'],
  ),

  // ── Security Pass ───────────────────────────────────────────────────
  HelpTopic(
    question: 'How do I generate a security pass / visitor pass?',
    keywords: [
      'security pass',
      'visitor pass',
      'gate pass',
      'qr',
      'guest',
      'visitor'
    ],
    answer: '1. Open the **Security Pass** page.\n'
        '2. Tap **Create Pass** to generate a new visitor/delivery pass.\n'
        '3. Fill in the visitor name, purpose, and expected date/time.\n'
        '4. A QR code is generated for the visitor.\n'
        '5. Share the QR code – the guard can scan it at the gate.\n\n'
        '*(Requires Professional plan)*',
    route: '/security-pass',
  ),

  // ── QR Scanner ──────────────────────────────────────────────────────
  HelpTopic(
    question: 'How do I scan a QR pass?',
    keywords: ['qr scanner', 'scan', 'scan qr', 'validate pass', 'gate'],
    answer: '1. Open the **QR Scanner** page.\n'
        '2. Point your device\'s camera at the QR code.\n'
        '3. The system will validate the pass automatically.\n'
        '4. A green check means the pass is valid; red means expired or invalid.\n\n'
        '*(Guard / Maintenance only, requires Professional plan)*',
    route: '/qr-scanner',
    roles: ['guard', 'maintenance'],
  ),

  // ── Feedback ────────────────────────────────────────────────────────
  HelpTopic(
    question: 'How do I submit feedback?',
    keywords: ['feedback', 'suggestion', 'complaint', 'comment', 'review'],
    answer: '1. Go to the **Feedback** page.\n'
        '2. Tap **+** to submit new feedback.\n'
        '3. Enter your message and category (suggestion, complaint, praise).\n'
        '4. Submit – community staff will review your feedback.\n'
        '5. You\'ll be notified when there\'s a response.',
    route: '/feedback',
  ),

  // ── Notifications ───────────────────────────────────────────────────
  HelpTopic(
    question: 'How do I check my notifications?',
    keywords: ['notification', 'notifications', 'alert', 'updates', 'unread'],
    answer:
        '1. Tap the bell icon in the top-right, or open **Notifications** from the menu.\n'
        '2. You\'ll see all your activity notifications.\n'
        '3. Notifications are also shown as red badges on menu items.',
    route: '/notifications',
  ),

  // ── Account ─────────────────────────────────────────────────────────
  HelpTopic(
    question: 'How do I change my password?',
    keywords: [
      'password',
      'change password',
      'reset password',
      'account',
      'security'
    ],
    answer: '1. Go to **Settings** from the menu.\n'
        '2. Look for the account / password section.\n'
        '3. Enter your new password and confirm it.\n'
        '4. Tap **Update** to save your new password.',
  ),
  HelpTopic(
    question: 'How do I sign out?',
    keywords: ['sign out', 'signout', 'logout', 'log out', 'exit'],
    answer: '1. Open the **Settings** page from the menu.\n'
        '2. Tap **Sign Out** at the bottom.\n'
        '3. You\'ll be redirected to the login screen.',
  ),
  HelpTopic(
    question: 'How do I view my profile?',
    keywords: ['profile', 'my profile', 'account info', 'email', 'user info'],
    answer: '1. Your email and role are shown in the drawer header.\n'
        '2. For more details, go to **Settings**.\n'
        '3. You can view your email, assigned role, community, and unit details.',
  ),
];

/// Searches the knowledge base and returns the best-matching topics.
List<HelpTopic> searchTopics(String query,
    {String? userRole, int maxResults = 3}) {
  if (query.trim().isEmpty) return [];

  final words = query.toLowerCase().split(RegExp(r'\s+'));

  final scored = <MapEntry<HelpTopic, int>>[];
  for (final topic in helpTopics) {
    if (topic.roles.isNotEmpty &&
        userRole != null &&
        !topic.roles.contains(userRole.toLowerCase())) {
      continue;
    }

    int score = 0;
    for (final keyword in topic.keywords) {
      for (final word in words) {
        if (word.length < 2) continue;
        if (keyword.contains(word) || word.contains(keyword)) {
          score += 2;
        }
      }
    }
    final qLower = topic.question.toLowerCase();
    for (final word in words) {
      if (word.length < 2) continue;
      if (qLower.contains(word)) {
        score += 1;
      }
    }

    if (score > 0) {
      scored.add(MapEntry(topic, score));
    }
  }

  scored.sort((a, b) => b.value.compareTo(a.value));
  return scored.take(maxResults).map((e) => e.key).toList();
}

/// Returns suggested quick-action topics based on context.
List<HelpTopic> suggestionsForContext({String? currentPage, String? userRole}) {
  final suggestions = <HelpTopic>[];

  if (currentPage != null) {
    for (final topic in helpTopics) {
      if (topic.roles.isNotEmpty &&
          userRole != null &&
          !topic.roles.contains(userRole.toLowerCase())) {
        continue;
      }
      if (topic.route != null && currentPage.contains(topic.route!)) {
        suggestions.add(topic);
      }
    }
  }

  if (suggestions.isEmpty) {
    return helpTopics
        .where((t) {
          if (t.roles.isNotEmpty &&
              userRole != null &&
              !t.roles.contains(userRole.toLowerCase())) {
            return false;
          }
          return t.route == null;
        })
        .take(3)
        .toList();
  }

  return suggestions.take(4).toList();
}
