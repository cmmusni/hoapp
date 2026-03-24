import 'dart:convert';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/landing_page.dart';
import 'screens/login_page.dart';
import 'screens/signup_page.dart';
import 'screens/create_community_page.dart';
import 'screens/auth_callback_page.dart';
import 'screens/portal/portal_shell.dart';
import 'screens/portal/announcements_page.dart';
import 'screens/portal/violations_page.dart';
import 'screens/portal/tickets_page.dart';
import 'screens/portal/amenities_page.dart';
import 'screens/portal/billing_page.dart';
import 'screens/portal/pool_access_page.dart';
import 'screens/portal/households_page.dart';
import 'screens/portal/manage_users_page.dart';
import 'screens/portal/settings_page.dart';

GoRouter createRouter() {
  return GoRouter(
    initialLocation: '/',
    routes: [
      // Auth callback route (post email-verification)
      GoRoute(
        path: '/auth-callback',
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
          // If user lands on / with an active session (e.g. after email
          // verification where SDK already exchanged the code), route
          // them through auth-callback to accept invites & navigate.
          final session = Supabase.instance.client.auth.currentSession;
          if (session != null) {
            return '/auth-callback';
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
          final inviteToken = state.uri.queryParameters['invite'];
          final encodedEmail = state.uri.queryParameters['email'];
          String? inviteEmail;
          if (encodedEmail != null) {
            try {
              // Restore base64 padding and decode
              final padded =
                  encodedEmail.replaceAll('-', '+').replaceAll('_', '/');
              final remainder = padded.length % 4;
              final base64 =
                  remainder > 0 ? padded + '=' * (4 - remainder) : padded;
              inviteEmail = utf8.decode(base64Decode(base64));
            } catch (_) {}
          }
          return SignupPage(inviteToken: inviteToken, inviteEmail: inviteEmail);
        },
      ),
      GoRoute(
        path: '/create-community',
        builder: (context, state) => const CreateCommunityPage(),
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
              return '/$community/announcements';
            },
          ),
          GoRoute(
            path: '/:community/announcements',
            builder: (context, state) => const AnnouncementsPage(),
          ),
          GoRoute(
            path: '/:community/violations',
            builder: (context, state) => const ViolationsPage(),
          ),
          GoRoute(
            path: '/:community/tickets',
            builder: (context, state) => const TicketsPage(),
          ),
          GoRoute(
            path: '/:community/amenities',
            builder: (context, state) => const AmenitiesPage(),
          ),
          GoRoute(
            path: '/:community/billing',
            builder: (context, state) => const BillingPage(),
          ),
          GoRoute(
            path: '/:community/pool-access',
            builder: (context, state) => const PoolAccessPage(),
          ),
          GoRoute(
            path: '/:community/households',
            builder: (context, state) => const HouseholdsPage(),
          ),
          GoRoute(
            path: '/:community/manage-users',
            builder: (context, state) => const ManageUsersPage(),
          ),
          GoRoute(
            path: '/:community/settings',
            builder: (context, state) => const SettingsPage(),
          ),
        ],
      ),
    ],
  );
}
