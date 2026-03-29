/// Local knowledge base for the mobile help chatbot.
///
/// Each [HelpTopic] maps keywords to an answer and optional navigation label.
/// The matcher picks the topic with the highest keyword overlap.
class HelpTopic {
  final String question;
  final List<String> keywords;
  final String answer;
  final String?
      navLabel; // drawer menu label to navigate to, e.g. 'Billing & Payments'
  final List<String> roles; // empty = all roles

  const HelpTopic({
    required this.question,
    required this.keywords,
    required this.answer,
    this.navLabel,
    this.roles = const [],
  });
}

const List<HelpTopic> helpTopics = [
  // ── General Navigation ──────────────────────────────────────────────
  HelpTopic(
    question: 'How do I navigate the app?',
    keywords: ['navigate', 'menu', 'drawer', 'find', 'where', 'go', 'page'],
    answer: 'Tap the hamburger menu (☰) on the top-left to open the drawer. '
        'Each item represents a feature. Your available pages depend on your role and your community\'s plan.',
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
    answer: '1. Tap **Announcements** in the drawer menu.\n'
        '2. You\'ll see a list of all published announcements sorted by date.\n'
        '3. Tap any announcement to read the full details.',
    navLabel: 'Announcements',
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
        '2. Tap the **+** floating button.\n'
        '3. Fill in the title, body, and optional image.\n'
        '4. Set the publish date or publish now.\n'
        '5. Tap **Save** to publish.',
    navLabel: 'Announcements',
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
    answer: '1. Open **Violations** from the drawer.\n'
        '2. Tap the **+** button to file a new violation.\n'
        '3. Select the household/unit, violation type, and add details or photos.\n'
        '4. Submit the form.\n'
        '5. You can update the status later from the detail view.',
    navLabel: 'Violations',
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
    answer: '1. Go to **Tickets** in the drawer.\n'
        '2. Tap the **+** button to create a new ticket.\n'
        '3. Enter a subject, description, and optional attachment.\n'
        '4. Submit the ticket. Staff will review and respond.\n'
        '5. You\'ll receive a notification when there\'s an update.',
    navLabel: 'Tickets',
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
    answer: '1. Go to **Amenities** from the drawer.\n'
        '2. Browse the list of available amenities.\n'
        '3. Tap an amenity to see its calendar and available slots.\n'
        '4. Pick a date and time, then tap **Book**.\n'
        '5. If approval is required, your booking will show as "pending" until staff confirms it.\n\n'
        '*(Requires Professional plan)*',
    navLabel: 'Amenities',
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
    answer: '1. Open **Billing & Payments** from the drawer.\n'
        '2. You\'ll see your outstanding invoices and payment history.\n'
        '3. To pay, tap **Pay** on an invoice.\n'
        '4. Upload proof of payment (receipt or screenshot).\n'
        '5. Staff will verify and mark it as paid.\n\n'
        '*(Requires Professional plan)*',
    navLabel: 'Billing & Payments',
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
        '2. Switch to the staff tab.\n'
        '3. Tap the **+** button to create a new invoice.\n'
        '4. Select the household/unit, set the amount and due date.\n'
        '5. Submit – the resident will see it in their billing page.',
    navLabel: 'Billing & Payments',
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
    answer: '1. Go to **Community Expenses** from the drawer.\n'
        '2. View summarized expenses by category and month.\n'
        '3. Tap **+** to log a new expense with amount, category, and receipt.\n\n'
        '*(Staff-only, requires Professional plan)*',
    navLabel: 'Community Expenses',
    roles: ['admin', 'staff'],
  ),

  // ── Pool Access ─────────────────────────────────────────────────────
  HelpTopic(
    question: 'How do I request pool access?',
    keywords: ['pool', 'pool access', 'swim', 'swimming', 'pool pass'],
    answer: '1. Open **Pool Access** from the drawer.\n'
        '2. Tap **Request Access** to submit a new pool access request.\n'
        '3. Upload required documents (medical clearance, ID, etc.).\n'
        '4. Staff will review your request and approve or decline.\n'
        '5. Once approved, you can use the pool during allowed hours.\n\n'
        '*(Requires Professional plan)*',
    navLabel: 'Pool Access',
  ),

  // ── Registered Swimmers ─────────────────────────────────────────────
  HelpTopic(
    question: 'How do I manage registered swimmers?',
    keywords: ['swimmer', 'swimmers', 'registered swimmer', 'pool member'],
    answer: '1. Open **Registered Swimmers** from the drawer.\n'
        '2. View the list of approved swimmers for your community.\n'
        '3. Staff can add, edit, or revoke swimmer registrations.\n\n'
        '*(Staff/Guard only, requires Professional plan)*',
    navLabel: 'Registered Swimmers',
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
    answer: '1. Open **Households** from the drawer.\n'
        '2. Each card represents a unit with its members.\n'
        '3. Tap a unit to see/edit household details and members.\n'
        '4. Use the **+** button to add a new unit or member.\n'
        '5. You can assign roles (owner, tenant) to members.',
    navLabel: 'Households',
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
    answer: '1. Go to **Manage Users** from the drawer.\n'
        '2. See all users and their roles in this community.\n'
        '3. Tap a user to edit their role.\n'
        '4. Use the invite feature to add new users by email.\n'
        '5. Remove users who should no longer have access.',
    navLabel: 'Manage Users',
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
    answer: '1. Open **Settings** from the drawer (admin only).\n'
        '2. Update your community name, logo, color theme, and contact info.\n'
        '3. Manage your subscription plan (Basic → Professional).\n'
        '4. Configure feature toggles and notification preferences.\n'
        '5. Changes are saved and applied immediately.',
    navLabel: 'Settings',
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
    answer: '1. Open **Security Pass** from the drawer.\n'
        '2. Tap **Create Pass** to generate a new visitor/delivery pass.\n'
        '3. Fill in the visitor name, purpose, and expected date/time.\n'
        '4. A QR code is generated for the visitor.\n'
        '5. Share the QR code – the guard can scan it at the gate.\n\n'
        '*(Requires Professional plan)*',
    navLabel: 'Security Pass',
  ),

  // ── QR Scanner ──────────────────────────────────────────────────────
  HelpTopic(
    question: 'How do I scan a QR pass?',
    keywords: ['qr scanner', 'scan', 'scan qr', 'validate pass', 'gate'],
    answer: '1. Open **QR Scanner** from the drawer.\n'
        '2. Point your device\'s camera at the QR code.\n'
        '3. The system will validate the pass automatically.\n'
        '4. A green check means the pass is valid; red means expired or invalid.\n\n'
        '*(Guard / Maintenance only, requires Professional plan)*',
    navLabel: 'QR Scanner',
    roles: ['guard', 'maintenance'],
  ),

  // ── Feedback ────────────────────────────────────────────────────────
  HelpTopic(
    question: 'How do I submit feedback?',
    keywords: ['feedback', 'suggestion', 'complaint', 'comment', 'review'],
    answer: '1. Open **Feedback** from the drawer.\n'
        '2. Tap **+** to submit new feedback.\n'
        '3. Enter your message and category (suggestion, complaint, praise).\n'
        '4. Submit – community staff will review your feedback.\n'
        '5. You\'ll be notified when there\'s a response.',
    navLabel: 'Feedback',
  ),

  // ── Notifications ───────────────────────────────────────────────────
  HelpTopic(
    question: 'How do I check my notifications?',
    keywords: ['notification', 'notifications', 'alert', 'updates', 'unread'],
    answer: '1. Tap the bell icon (🔔) on the top-right of the app bar.\n'
        '2. You\'ll see all your activity notifications.\n'
        '3. Tap a notification to go to the related page.',
  ),

  // ── Account ─────────────────────────────────────────────────────────
  HelpTopic(
    question: 'How do I sign out?',
    keywords: ['sign out', 'signout', 'logout', 'log out', 'exit'],
    answer: '1. Open the drawer menu.\n'
        '2. Scroll to the bottom.\n'
        '3. Tap **Sign Out**.\n'
        '4. You\'ll be redirected to the login screen.',
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

/// Returns suggested quick-action topics based on the current page label.
List<HelpTopic> suggestionsForPage(String currentLabel, {String? userRole}) {
  final suggestions = <HelpTopic>[];

  for (final topic in helpTopics) {
    if (topic.roles.isNotEmpty &&
        userRole != null &&
        !topic.roles.contains(userRole.toLowerCase())) {
      continue;
    }
    if (topic.navLabel != null &&
        currentLabel.toLowerCase().contains(topic.navLabel!.toLowerCase())) {
      suggestions.add(topic);
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
          return t.navLabel == null;
        })
        .take(3)
        .toList();
  }

  return suggestions.take(4).toList();
}
