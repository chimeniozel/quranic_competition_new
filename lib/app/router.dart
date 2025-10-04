import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quranic_competition/features/admin/pages/update_version.dart';
import 'package:quranic_competition/features/admin/pages/version_detail_page.dart';
import 'package:quranic_competition/features/admin/pages/version_jurys_page.dart';
import 'package:quranic_competition/features/admin/pages/version_results_page.dart';
import 'package:quranic_competition/features/auth/pages/sign_up_page.dart';
import 'package:quranic_competition/features/jury/pages/jury_version_page.dart';
import 'package:quranic_competition/features/jury/pages/jury_version_detail_page.dart';
import 'package:quranic_competition/features/participant/pages/participant_home_page.dart';
import 'package:quranic_competition/features/participant/pages/participant_result_page.dart';
import 'package:quranic_competition/features/participant/pages/participant_benefits_page.dart';
import 'package:quranic_competition/models/competition_version.dart';
import 'package:quranic_competition/models/jury_evaluation_args.dart';
import 'package:quranic_competition/models/tajweed_rule.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/auth/pages/login_page.dart';
import '../features/auth/pages/forgot_password_page.dart';
import '../features/auth/pages/waiting_verification_page.dart';

import '../features/participant/pages/participant_register_page.dart';

import '../features/jury/pages/jury_home_page.dart';
import '../features/jury/pages/jury_evaluation_page.dart';

import '../features/admin/pages/admin_dashboard_page.dart';
import '../features/admin/pages/user_manage_page.dart';
import '../features/admin/pages/version_management_page.dart';
import '../features/admin/pages/quranic_benefits_page.dart';
import '../features/admin/pages/quranic_benefit_form_page.dart';
import '../features/admin/pages/tajweed_rules_page.dart';
import '../features/admin/pages/tajweed_rule_form_page.dart';
import '../features/participant/pages/participant_tajweed_page.dart';
import '../features/participant/pages/tajweed_rule_detail_page.dart';

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
      '/participant_result_page',
      '/participant/benefits',
      '/participant/tajweed',
      '/participant/tajweed/detail',
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
      path: '/participant_result_page',
      builder: (context, state) => ParticipantResultPage(),
    ),
    GoRoute(
      path: '/participant/benefits',
      builder: (context, state) => const ParticipantBenefitsPage(),
    ),
    GoRoute(
      path: '/participant/tajweed',
      builder: (context, state) => const ParticipantTajweedPage(),
    ),
    GoRoute(
      path: '/participant/tajweed/detail',
      builder: (context, state) {
        final rule = state.extra as TajweedRule?;
        if (rule == null) {
          return const Scaffold(
            body: Center(child: Text('Erreur : règle manquante')),
          );
        }
        return TajweedRuleDetailPage(rule: rule);
      },
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
          participant: args.participant,
          appUser: args.appUser,
          version: args.version,
        );
      },
    ),

    GoRoute(
      name: 'jury-version-jurys',
      path: '/jury/version_jurys',
      builder: (context, state) {
        final version = state.extra as CompetitionVersion;
        return VersionJurysPage(version: version);
      },
    ),

    // Admin / Super Admin
    GoRoute(path: '/admin/dashboard', builder: (_, __) => AdminDashboardPage()),
    GoRoute(path: '/admin/users', builder: (_, __) => UserManagePage()),
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
    GoRoute(
      path: '/admin/version_results',
      builder: (context, state) {
        final version = state.extra as CompetitionVersion;
        return VersionResultsPage(version: version);
      },
    ),

    // Quranic Benefits Management
    GoRoute(
      path: '/admin/quranic-benefits',
      builder: (_, __) => const QuranicBenefitsPage(),
    ),
    GoRoute(
      path: '/admin/quranic-benefits/add',
      builder: (_, __) => const QuranicBenefitFormPage(),
    ),
    GoRoute(
      path: '/admin/quranic-benefits/edit/:id',
      builder: (context, state) {
        final benefitId = state.pathParameters['id'];
        if (benefitId == null) {
          return const Scaffold(
            body: Center(child: Text('Erreur : ID de la faveur manquant')),
          );
        }
        return QuranicBenefitFormPage(benefitId: benefitId);
      },
    ),

    // Tajweed Rules Management
    GoRoute(
      path: '/admin/tajweed-rules',
      builder: (_, __) => const TajweedRulesPage(),
    ),
    GoRoute(
      path: '/admin/tajweed-rules/add',
      builder: (_, __) => const TajweedRuleFormPage(),
    ),
    GoRoute(
      path: '/admin/tajweed-rules/edit/:id',
      builder: (context, state) {
        final ruleId = state.pathParameters['id'];
        if (ruleId == null) {
          return const Scaffold(
            body: Center(child: Text('Erreur : ID de la règle manquant')),
          );
        }
        return TajweedRuleFormPage(ruleId: ruleId);
      },
    ),
  ],
);
