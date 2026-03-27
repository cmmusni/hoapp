import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/landing_page.dart';
import 'screens/login_page.dart';
import 'screens/signup_page.dart';
import 'screens/create_community_page.dart';
import 'screens/auth_callback_page.dart';
import 'screens/portal/portal_shell.dart';
import 'screens/portal/announcements_page.dart';
import 'app.dart';
import 'screens/portal/violations_page.dart';
import 'screens/portal/tickets_page.dart';
import 'screens/portal/amenities_page.dart';
import 'screens/portal/billing_page.dart';
import 'screens/portal/pool_access_page.dart';
import 'screens/portal/registered_swimmers_page.dart';
import 'screens/portal/households_page.dart';
import 'screens/portal/manage_users_page.dart';
import 'screens/portal/settings_page.dart';
import 'screens/portal/security_pass_page.dart';
import 'screens/portal/qr_scanner_page.dart';
import 'screens/portal/platform_admin_shell.dart';
import 'screens/portal/plan_gate.dart';
import 'screens/portal/feedback_page.dart';
import 'screens/portal/notifications_page.dart';
import 'screens/features_page.dart';
import 'screens/pricing_page.dart';
import 'screens/support_page.dart';
import 'screens/contact_page.dart';

GoRouter createRouter({String? lastCommunitySlug}) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      // Auth callback route (post email-verification)
      GoRoute(
        path: '/auth-callback',
        builder: (context, state) => const AuthCallbackPage(),
      ),
      GoRoute(
        path: '/auth/callback',
        builder: (context, state) => const AuthCallbackPage(),
      ),
      // Marketing & SaaS routes
      GoRoute(
        path: '/',
        builder: (context, state) {
          // Supabase email verification redirects here with ?code=...
          // The SDK may also strip ?code= during initialize(), leaving
          // the user on / with a fresh session. Detect both cases.
          final code = state.uri.queryParameters['code'];
          if (code != null && code.isNotEmpty) {
            return const AuthCallbackPage();
          }
          return const LandingPage();
        },
        redirect: (context, state) {
          final code = state.uri.queryParameters['code'];
          if (code != null && code.isNotEmpty) {
            return '/auth-callback';
          }
          // If user has an active session, restore them to their
          // last community instead of showing the landing page.
          final session = Supabase.instance.client.auth.currentSession;
          if (session != null &&
              lastCommunitySlug != null &&
              lastCommunitySlug.isNotEmpty) {
            return '/$lastCommunitySlug/announcements';
          }
          return null;
        },
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) {
          final inviteToken = state.uri.queryParameters['invite'];
          return LoginPage(inviteToken: inviteToken);
        },
      ),
      GoRoute(
          path: '/signup',
          builder: (context, state) {
            return const ContactPage();
          },
          redirect: (context, state) {
            return '/contact';
          }),
      // GoRoute(
      //   path: '/signup',
      //   builder: (context, state) {
      //     final inviteToken = state.uri.queryParameters['invite'];
      //     final encodedEmail = state.uri.queryParameters['email'];
      //     String? inviteEmail;
      //     if (encodedEmail != null) {
      //       try {
      //         // Restore base64 padding and decode
      //         final padded =
      //             encodedEmail.replaceAll('-', '+').replaceAll('_', '/');
      //         final remainder = padded.length % 4;
      //         final base64 =
      //             remainder > 0 ? padded + '=' * (4 - remainder) : padded;
      //         inviteEmail = utf8.decode(base64Decode(base64));
      //       } catch (_) {}
      //     }
      //     return SignupPage(inviteToken: inviteToken, inviteEmail: inviteEmail);
      //   },
      // ),
      GoRoute(
        path: '/features',
        builder: (context, state) => const FeaturesPage(),
      ),
      GoRoute(
        path: '/pricing',
        builder: (context, state) => const PricingPage(),
      ),
      GoRoute(
        path: '/support',
        builder: (context, state) => const SupportPage(),
      ),
      GoRoute(
        path: '/contact',
        builder: (context, state) => const ContactPage(),
      ),
      GoRoute(
        path: '/create-community',
        builder: (context, state) => const CreateCommunityPage(),
      ),
      // Platform admin (cross-community management)
      GoRoute(
        path: '/admin',
        redirect: (context, state) {
          final session = Supabase.instance.client.auth.currentSession;
          if (session == null) return '/login';
          return null;
        },
        builder: (context, state) => const PlatformAdminShell(),
      ),

      // Demo scaffolding route (UI showcase with mock data)
      GoRoute(
        path: '/demo',
        builder: (context, state) => const DemoShell(),
      ),

      // Community portal routes
      GoRoute(
        path: '/:community/login.html',
        builder: (context, state) {
          final community = state.pathParameters['community']!;
          final inviteToken = state.uri.queryParameters['invite'];
          return LoginPage(
            communitySlug: community,
            inviteToken: inviteToken,
          );
        },
      ),
      GoRoute(
        path: '/:community/login',
        builder: (context, state) {
          final community = state.pathParameters['community']!;
          final inviteToken = state.uri.queryParameters['invite'];
          return LoginPage(
            communitySlug: community,
            inviteToken: inviteToken,
          );
        },
      ),
      GoRoute(
        path: '/:community/signup',
        builder: (context, state) {
          final community = state.pathParameters['community']!;
          final inviteToken = state.uri.queryParameters['invite'];
          final encodedEmail = state.uri.queryParameters['email'];
          String? inviteEmail;
          if (encodedEmail != null) {
            try {
              final padded =
                  encodedEmail.replaceAll('-', '+').replaceAll('_', '/');
              final remainder = padded.length % 4;
              final base64 =
                  remainder > 0 ? padded + '=' * (4 - remainder) : padded;
              inviteEmail = utf8.decode(base64Decode(base64));
            } catch (_) {}
          }
          return SignupPage(
            communitySlug: community,
            inviteToken: inviteToken,
            inviteEmail: inviteEmail,
          );
        },
      ),

      // Portal shell with nested routes
      ShellRoute(
        builder: (context, state, child) {
          final community = state.pathParameters['community']!;
          return PortalShell(communitySlug: community, child: child);
        },
        routes: [
          GoRoute(
            path: '/:community',
            redirect: (context, state) {
              final community = state.pathParameters['community']!;
              final session = Supabase.instance.client.auth.currentSession;
              if (session == null) return '/$community/login';
              return '/$community/announcements';
            },
          ),
          GoRoute(
            path: '/:community/announcements',
            redirect: (context, state) {
              final session = Supabase.instance.client.auth.currentSession;
              if (session == null) {
                final community = state.pathParameters['community']!;
                return '/$community/login';
              }
              return null;
            },
            builder: (context, state) => const AnnouncementsPage(),
          ),
          GoRoute(
            path: '/:community/violations',
            redirect: (context, state) {
              final session = Supabase.instance.client.auth.currentSession;
              if (session == null) {
                final community = state.pathParameters['community']!;
                return '/$community/login';
              }
              return null;
            },
            builder: (context, state) => const ViolationsPage(),
          ),
          GoRoute(
            path: '/:community/tickets',
            redirect: (context, state) {
              final session = Supabase.instance.client.auth.currentSession;
              if (session == null) {
                final community = state.pathParameters['community']!;
                return '/$community/login';
              }
              return null;
            },
            builder: (context, state) => const TicketsPage(),
          ),
          GoRoute(
            path: '/:community/amenities',
            redirect: (context, state) {
              final session = Supabase.instance.client.auth.currentSession;
              if (session == null) {
                final community = state.pathParameters['community']!;
                return '/$community/login';
              }
              return null;
            },
            builder: (context, state) => const PlanGate(
              feature: 'Amenities',
              child: AmenitiesPage(),
            ),
          ),
          GoRoute(
            path: '/:community/billing',
            redirect: (context, state) {
              final session = Supabase.instance.client.auth.currentSession;
              if (session == null) {
                final community = state.pathParameters['community']!;
                return '/$community/login';
              }
              return null;
            },
            builder: (context, state) => const PlanGate(
              feature: 'Billing & Payments',
              child: BillingPage(),
            ),
          ),
          GoRoute(
            path: '/:community/pool-access',
            redirect: (context, state) {
              final session = Supabase.instance.client.auth.currentSession;
              if (session == null) {
                final community = state.pathParameters['community']!;
                return '/$community/login';
              }
              return null;
            },
            builder: (context, state) => const PlanGate(
              feature: 'Pool Access',
              child: PoolAccessPage(),
            ),
          ),
          GoRoute(
            path: '/:community/registered-swimmers',
            redirect: (context, state) {
              final session = Supabase.instance.client.auth.currentSession;
              if (session == null) {
                final community = state.pathParameters['community']!;
                return '/$community/login';
              }
              return null;
            },
            builder: (context, state) => const PlanGate(
              feature: 'Pool Access',
              child: RegisteredSwimmersPage(),
            ),
          ),
          GoRoute(
            path: '/:community/households',
            redirect: (context, state) {
              final session = Supabase.instance.client.auth.currentSession;
              if (session == null) {
                final community = state.pathParameters['community']!;
                return '/$community/login';
              }
              return null;
            },
            builder: (context, state) => const HouseholdsPage(),
          ),
          GoRoute(
            path: '/:community/manage-users',
            redirect: (context, state) {
              final session = Supabase.instance.client.auth.currentSession;
              if (session == null) {
                final community = state.pathParameters['community']!;
                return '/$community/login';
              }
              return null;
            },
            builder: (context, state) => const ManageUsersPage(),
          ),
          GoRoute(
            path: '/:community/settings',
            redirect: (context, state) {
              final session = Supabase.instance.client.auth.currentSession;
              if (session == null) {
                final community = state.pathParameters['community']!;
                return '/$community/login';
              }
              return null;
            },
            builder: (context, state) => const SettingsPage(),
          ),
          GoRoute(
            path: '/:community/security-pass',
            redirect: (context, state) {
              final session = Supabase.instance.client.auth.currentSession;
              if (session == null) {
                final community = state.pathParameters['community']!;
                return '/$community/login';
              }
              return null;
            },
            builder: (context, state) => const PlanGate(
              feature: 'Security Pass',
              child: SecurityPassPage(),
            ),
          ),
          GoRoute(
            path: '/:community/feedback',
            redirect: (context, state) {
              final session = Supabase.instance.client.auth.currentSession;
              if (session == null) {
                final community = state.pathParameters['community']!;
                return '/$community/login';
              }
              return null;
            },
            builder: (context, state) => const FeedbackPage(),
          ),
          GoRoute(
            path: '/:community/notifications',
            redirect: (context, state) {
              final session = Supabase.instance.client.auth.currentSession;
              if (session == null) {
                final community = state.pathParameters['community']!;
                return '/$community/login';
              }
              return null;
            },
            builder: (context, state) => NotificationsPage(key: ValueKey(state.uri.toString())),
          ),
          GoRoute(
            path: '/:community/qr-scanner',
            redirect: (context, state) {
              final session = Supabase.instance.client.auth.currentSession;
              if (session == null) {
                final community = state.pathParameters['community']!;
                return '/$community/login';
              }
              return null;
            },
            builder: (context, state) => const PlanGate(
              feature: 'QR Scanner',
              child: QrScannerPage(),
            ),
          ),
        ],
      ),
    ],
  );
}
