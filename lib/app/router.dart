import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quranic_competition/features/admin/pages/update_version.dart';
import 'package:quranic_competition/features/admin/pages/version_detail_page.dart';
import 'package:quranic_competition/features/auth/pages/sign_up_page.dart';
import 'package:quranic_competition/features/jury/pages/jury_version_page.dart';
import 'package:quranic_competition/features/jury/pages/jury_version_detail_page.dart';
import 'package:quranic_competition/features/participant/pages/participant_home_page.dart';
import 'package:quranic_competition/models/competition_version.dart';
import 'package:quranic_competition/models/jury_evaluation_args.dart';
import 'package:quranic_competition/models/participant.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/auth/pages/login_page.dart';
import '../features/auth/pages/forgot_password_page.dart';
import '../features/auth/pages/waiting_verification_page.dart';

import '../features/participant/pages/participant_register_page.dart';

import '../features/jury/pages/jury_home_page.dart';
import '../features/jury/pages/jury_evaluation_page.dart';

import '../features/admin/pages/admin_dashboard_page.dart';
import '../features/admin/pages/user_verification_page.dart';
import '../features/admin/pages/version_management_page.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    final user = Supabase.instance.client.auth.currentUser;
    final path = state.matchedLocation;

    // 1. 🔐 L'utilisateur non connecté peut accéder à certaines pages
    final isPublicRoute = [
      '/login',
      '/register',
      '/forgot-password',
      '/participant/register',
      '/participant_home_page',
    ].contains(path);

    if (user == null && !isPublicRoute) {
      return '/participant_home_page'; // redirige les utilisateurs non connectés
    }

    // 2. 📄 Métadonnées
    final role = user?.userMetadata?['role'] as String?;
    final isVerified = user?.userMetadata?['email_verified'] == true;

    // 3. ⏳ Redirection si email non vérifié (sauf participants)
    if (user != null && !isVerified && role != 'participant') {
      return '/waiting-verification';
    }

    // 4. 🧭 Redirection initiale en fonction du rôle
    if (user != null && (path == '/' || path == '/login')) {
      switch (role) {
        case 'participant':
          return '/participant/status';
        case 'jury':
          return '/jury/home';
        case 'admin':
        case 'super_admin':
          return '/admin/dashboard';
        default:
          return '/login';
      }
    }

    // 5. ✅ Pas de redirection nécessaire
    return null;
  },

  routes: [
    // Auth pages
    GoRoute(path: '/login', builder: (context, state) => LoginPage()),
    GoRoute(path: '/register', builder: (context, state) => SignUpPage()),
    GoRoute(
      path: '/forgot-password',
      builder: (context, state) => ForgotPasswordPage(),
    ),
    GoRoute(
      path: '/waiting-verification',
      builder: (context, state) => WaitingVerificationPage(),
    ),

    // Participant
    GoRoute(
      path: '/participant_home_page',
      builder: (context, state) => ParticipantHomePage(),
    ),
    GoRoute(
      path: '/participant/register',
      builder: (context, state) {
        final extra = state.extra as Map<String, String>?;

        final versionId = extra?['versionId'];
        final ageGroup = extra?['ageGroup'];

        if (versionId == null || ageGroup == null) {
          return const Scaffold(
            body: Center(child: Text('Erreur : données manquantes')),
          );
        }

        return ParticipantRegisterPage(
          versionId: versionId,
          ageGroup: ageGroup,
        );
      },
    ),

    // Jury
    GoRoute(path: '/jury/home', builder: (_, __) => JuryHomePage()),
    GoRoute(path: '/jury/version_page', builder: (_, __) => JuryVersionPage()),
    GoRoute(
      path: '/jury/version_detail_page',
      builder: (context, state) {
        final version = state.extra as CompetitionVersion?;
        if (version == null) {
          return const Scaffold(
            body: Center(child: Text('Erreur : version manquante')),
          );
        }
        return JuryVersionDetailPage(version: version);
      },
    ),
    GoRoute(
  path: '/jury/participant',
  builder: (context, state) {
    final args = state.extra as JuryEvaluationArgs?;

    if (args == null) {
      return const Scaffold(
        body: Center(child: Text('Erreur : données manquantes')),
      );
    }

    return JuryEvaluationPage(
      participant: args.participant!,
      appUser: args.appUser,
      round: args.round,
      version: args.version,
    );
  },
),


    // Admin / Super Admin
    GoRoute(path: '/admin/dashboard', builder: (_, __) => AdminDashboardPage()),
    GoRoute(path: '/admin/users', builder: (_, __) => UserVerificationPage()),
    GoRoute(
      path: '/admin/versions',
      builder: (_, __) => VersionManagementPage(),
    ),
    GoRoute(
      path: '/admin/version_update',
      builder: (context, state) {
        final version = state.extra as CompetitionVersion?;
        if (version == null) {
          return const Scaffold(
            body: Center(child: Text('Erreur : version manquante')),
          );
        }
        return UpdateVersionPage(version: version);
      },
    ),
    GoRoute(
      path: '/admin/version_detail',
      builder: (context, state) {
        final version = state.extra as CompetitionVersion?;
        if (version == null) {
          return const Scaffold(
            body: Center(child: Text('Erreur : version manquante')),
          );
        }
        return VersionDetailPage(version: version);
      },
    ),
  ],
);
