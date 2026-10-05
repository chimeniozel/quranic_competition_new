import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quranic_competition/features/admin/pages/competition_management/update_version.dart';
import 'package:quranic_competition/features/admin/pages/competition_management/participant_detail_admin_page.dart';
import 'package:quranic_competition/features/admin/pages/media_management/edit_media_page.dart';
import 'package:quranic_competition/features/admin/pages/media_management/batch_add_media_page.dart';
import 'package:quranic_competition/models/archive_media.dart';
import 'package:quranic_competition/features/admin/pages/competition_management/version_detail_page.dart';
import 'package:quranic_competition/features/admin/pages/competition_management/all_rounds_jurys_page.dart';
import 'package:quranic_competition/features/admin/pages/competition_management/version_round_result_page.dart';
import 'package:quranic_competition/features/admin/pages/competition_management/version_result_page.dart';
import 'package:quranic_competition/features/auth/pages/sign_up_page.dart';
import 'package:quranic_competition/features/jury/pages/jury_version_page.dart';
import 'package:quranic_competition/features/jury/pages/jury_version_detail_page.dart';
import 'package:quranic_competition/features/jury/pages/jury_result_page.dart';
import 'package:quranic_competition/features/jury/pages/jury_results_versions_page.dart';
import 'package:quranic_competition/features/participant/pages/home/participant_home_page.dart';
import 'package:quranic_competition/features/participant/pages/home/participant_result_page.dart';
import 'package:quranic_competition/features/participant/pages/home/participant_results_versions_page.dart';
import 'package:quranic_competition/features/participant/pages/benefits/participant_benefits_page.dart';
import 'package:quranic_competition/features/participant/pages/benefits/benefit_detail_page.dart';
import 'package:quranic_competition/models/quranic_benefit.dart';
import 'package:quranic_competition/core/services/permission_service.dart';
import 'package:quranic_competition/models/user_role.dart';
import 'package:quranic_competition/features/participant/pages/participants/participants_list_page.dart';
import 'package:quranic_competition/features/participant/pages/about/about_us_page.dart';
import 'package:quranic_competition/features/shared/pages/access_denied_page.dart';
import 'package:quranic_competition/features/admin/pages/settings/force_update_page.dart';
import 'package:quranic_competition/features/shared/pages/notifications_page.dart';
import 'package:quranic_competition/models/competition_version.dart';
import 'package:quranic_competition/models/jury_evaluation_args.dart';
import 'package:quranic_competition/models/quiz_result.dart';
import 'package:quranic_competition/models/round.dart';
import 'package:quranic_competition/models/tajweed_rule.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../features/auth/pages/login_page.dart';
import '../features/auth/pages/forgot_password_page.dart';
import '../features/auth/pages/reset_password_page.dart';
import '../features/auth/pages/verify_otp_page.dart';
import '../features/auth/pages/change_password_page.dart';
import '../features/auth/pages/waiting_verification_page.dart';
import '../features/shared/pages/user_profile_page.dart';
import '../features/shared/pages/security_settings_page.dart';
import '../features/shared/pages/ui_showcase_page.dart';
import '../features/participant/pages/registration/participant_register_page.dart';
import '../features/jury/pages/jury_home_page.dart';
import '../features/jury/pages/jury_evaluation_page.dart';
import '../features/admin/pages/admin_dashboard_page.dart';
import '../features/admin/pages/user_management/user_management_page.dart';
import '../features/admin/pages/user_management/user_role_management_page.dart';
import '../features/admin/pages/competition_management/version_management_page.dart';
import '../features/admin/pages/content_management/quranic_benefits_page.dart';
import '../features/admin/pages/content_management/quranic_benefit_form_page.dart';
import '../features/admin/pages/content_management/tajweed_rules_page.dart';
import '../features/admin/pages/content_management/tajweed_rule_form_page.dart';
import '../features/participant/pages/tajweed/participant_tajweed_page.dart';
import '../features/participant/pages/tajweed/tajweed_rule_detail_page.dart';
import '../features/admin/pages/quiz_management/quiz_levels_page.dart';
import '../features/admin/pages/quiz_management/quiz_level_form_page.dart';
import '../features/admin/pages/quiz_management/quiz_questions_page.dart';
import '../features/admin/pages/quiz_management/quiz_question_form_page.dart';
import '../features/participant/pages/quiz/quiz_levels_page.dart';
import '../features/participant/pages/quiz/quiz_page.dart';
import '../features/participant/pages/quiz/quiz_result_page.dart';
import '../features/participant/pages/archives/participant_archives_page.dart';
import '../features/participant/pages/archives/participant_competition_archives_page.dart';
import '../features/participant/pages/participants/participant_detail_page.dart'
    as participant_pages;
import '../models/participant.dart';
import '../features/admin/pages/media_management/new_competition_archives_page.dart';
import '../features/admin/pages/media_management/new_competition_media_management_page.dart';
import '../features/admin/pages/eid_management/eid_sessions_page.dart';
import '../features/admin/pages/content_management/about_us_management_page.dart';
import '../features/admin/pages/eid_management/eid_session_form_page.dart';
import '../features/admin/pages/eid_management/eid_session_detail_page.dart';
import '../features/participant/pages/eid/eid_session_page.dart';
import '../models/eid_session.dart';

String _normalizeRole(String? rawRole) {
  if (rawRole == null || rawRole.isEmpty) {
    return 'guest';
  }

  final normalized = rawRole.trim().toLowerCase().replaceAll(
    RegExp(r'[\s\-]+'),
    '_',
  );

  if (normalized.contains('super')) {
    return 'super_admin';
  }

  if (normalized == 'admin') {
    return 'admin';
  }

  if (normalized.contains('jury')) {
    return 'jury';
  }

  if (normalized.contains('participant') ||
      normalized.contains('member') ||
      normalized.contains('membre')) {
    return 'membre';
  }

  return 'guest';
}

bool _pathStartsWith(String path, String prefix) {
  return path == prefix || path.startsWith('$prefix/');
}

bool _isAdminPath(String path) {
  return _pathStartsWith(path, '/admin');
}

bool _isJuryPath(String path) {
  return _pathStartsWith(path, '/jury');
}

bool _isMemberRole(String role) {
  return role == 'membre';
}

/// Récupère le rôle de l'utilisateur depuis la table profiles (source de vérité)
/// Toujours récupéré depuis la base de données pour garantir la cohérence
Future<String?> _getUserRoleFromProfiles(String userId) async {
  try {
    // Toujours récupérer depuis la base de données (pas de cache)
    final response =
        await Supabase.instance.client
            .from('profiles')
            .select('role')
            .eq('id', userId)
            .maybeSingle();

    if (response != null) {
      return response['role'] as String?;
    }
    return null;
  } catch (e) {
    print('Erreur lors de la récupération du rôle: $e');
    return null;
  }
}

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  redirect: (context, state) async {
    final user = Supabase.instance.client.auth.currentUser;
    final path = state.matchedLocation;

    // 1. 🔐 L'utilisateur non connecté peut accéder à certaines pages
    final isPublicRoute =
        [
          '/login',
          '/register',
          '/forgot-password',
          '/verify-otp',
          '/reset-password',
          '/participant/register',
          '/participant_home_page',
          '/participant_result_page',
          '/participant/benefits',
          '/participant/tajweed',
          '/participant/tajweed/detail',
          '/participant/quiz',
          '/participant/quiz/result',
          '/participant/archives',
          '/participant/eid-session',
          '/participant/about-us',
          // Les notifications publiques sont destinées à tous, y compris aux
          // visiteurs non connectés : sans cette entrée, la cloche renvoyait
          // simplement vers l'accueil.
          '/notifications',
          '/access-denied',
          '/ui-showcase',
        ].contains(path) ||
        path.startsWith('/participant/quiz/level/') ||
        path.startsWith('/participant/benefits/') ||
        path.startsWith('/participant/archives/competition/') ||
        path.startsWith('/participant/list/') ||
        path.startsWith('/participant/detail/') ||
        path.startsWith('/participant/results/');

    if (user == null && !isPublicRoute) {
      if (_isAdminPath(path) || _isJuryPath(path)) {
        return '/login';
      }
      return '/participant_home_page';
    }

    // 2. 📄 Récupérer le rôle (استخدام metadata أولاً للسرعة)
    String? userRole;
    if (user != null) {
      // استخدام metadata أولاً (متوفر فوراً، لا يحتاج انتظار)
      userRole = user.userMetadata?['role'] as String?;

      // إذا لم يكن متوفراً في metadata، استخدام cache
      if (userRole == null) {
        final cachedRole = PermissionService().currentUserRoleSync;
        userRole = cachedRole?.code;
      }

      // تحديث cache من قاعدة البيانات في الخلفية (للاستخدام المستقبلي)
      // هذا لا يمنع عرض الصفحة
      _getUserRoleFromProfiles(user.id)
          .then((role) {
            if (role != null && role != userRole) {
              final permissionService = PermissionService();
              permissionService.setUserRole(UserRole.fromString(role));
            }
          })
          .catchError((e) {
            // تجاهل الأخطاء في التحديث الخلفي
          });
    }

    final normalizedRole = _normalizeRole(userRole);
    final isVerified = user?.userMetadata?['email_verified'] == true;

    // 3. ⏳ Redirection si email non vérifié (sauf participants)
    if (user != null && !isVerified && !_isMemberRole(normalizedRole)) {
      return '/waiting-verification';
    }

    // 4. 🧭 Redirection initiale en fonction du rôle
    if (user != null && (path == '/' || path == '/login')) {
      switch (normalizedRole) {
        case 'membre':
          return '/participant_home_page';
        case 'jury':
          return '/jury/home';
        case 'admin':
        case 'super_admin':
          return '/admin/dashboard';
        default:
          return '/login';
      }
    }

    if (user != null) {
      final isAccessDeniedRoute = path == '/access-denied';

      final canAccessJurySection =
          normalizedRole == 'jury' ||
          normalizedRole == 'admin' ||
          normalizedRole == 'super_admin';

      if (_isJuryPath(path) && !canAccessJurySection) {
        return isAccessDeniedRoute ? null : '/access-denied';
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
      path: '/verify-otp',
      builder: (context, state) {
        final email = state.extra as String? ?? '';
        return VerifyOtpPage(email: email);
      },
    ),
    GoRoute(
      path: '/reset-password',
      builder: (context, state) {
        final email = state.extra as String?;
        return ResetPasswordPage(email: email);
      },
    ),
    GoRoute(
      path: '/change-password',
      builder: (context, state) => ChangePasswordPage(),
    ),
    GoRoute(path: '/profile', builder: (context, state) => UserProfilePage()),
    GoRoute(
      path: '/admin/force-update',
      builder: (context, state) => const ForceUpdatePage(),
    ),
    GoRoute(
      path: '/notifications',
      builder: (context, state) => const NotificationsPage(),
    ),
    GoRoute(
      path: '/security-settings',
      builder: (context, state) => SecuritySettingsPage(),
    ),
    GoRoute(
      path: '/ui-showcase',
      builder: (context, state) => UIShowcasePage(),
    ),
    GoRoute(
      path: '/waiting-verification',
      builder: (context, state) => WaitingVerificationPage(),
    ),
    GoRoute(
      path: '/access-denied',
      builder: (context, state) => const AccessDeniedPage(),
    ),

    // Participant
    GoRoute(
      path: '/participant_home_page',
      builder: (context, state) => ParticipantHomePage(),
    ),
    GoRoute(
      path: '/participant_result_page',
      builder: (context, state) => const ParticipantResultsVersionsPage(),
    ),
    GoRoute(
      path: '/participant/results/:versionId',
      builder: (context, state) {
        final versionId = state.pathParameters['versionId'];
        return ParticipantResultPage(versionId: versionId);
      },
    ),
    GoRoute(
      path: '/participant/benefits',
      builder: (context, state) => const ParticipantBenefitsPage(),
    ),
    // Détail d'une فائدة : depuis la liste (فائدة passée en extra) ou depuis
    // une notification (identifiant seul, la فائدة est alors chargée)
    GoRoute(
      path: '/participant/benefits/:benefitId',
      builder: (context, state) {
        final benefit = state.extra as QuranicBenefit?;
        return BenefitDetailPage(
          benefitId: state.pathParameters['benefitId']!,
          benefit: benefit,
        );
      },
    ),
    GoRoute(
      path: '/participant/about-us',
      builder: (context, state) => const AboutUsPage(),
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
      path: '/participant/quiz',
      builder: (context, state) => const ParticipantQuizLevelsPage(),
    ),
    GoRoute(
      path: '/participant/quiz/level/:levelId',
      builder: (context, state) {
        final levelId = state.pathParameters['levelId'];
        if (levelId == null) {
          return const Scaffold(
            body: Center(child: Text('Erreur : ID du niveau manquant')),
          );
        }
        return QuizPage(levelId: levelId);
      },
    ),
    GoRoute(
      path: '/participant/quiz/result',
      builder: (context, state) {
        final result = state.extra as QuizResult?;
        if (result == null) {
          return const Scaffold(
            body: Center(child: Text('Erreur : résultat manquant')),
          );
        }
        return QuizResultPage(result: result);
      },
    ),
    GoRoute(
      path: '/participant/archives',
      builder: (context, state) => const ParticipantArchivesPage(),
    ),
    GoRoute(
      path: '/participant/archives/competition',
      builder: (context, state) => const ParticipantArchivesPage(),
    ),
    GoRoute(
      path: '/participant/archives/competition/:versionId',
      builder: (context, state) {
        final versionId = state.pathParameters['versionId'];
        if (versionId == null) {
          return const Scaffold(
            body: Center(child: Text('Erreur : ID de la version manquant')),
          );
        }
        return ParticipantCompetitionArchivesPage(versionId: versionId);
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

    // Liste des participants
    GoRoute(
      path: '/participant/list/:versionId',
      builder: (context, state) {
        final versionId = state.pathParameters['versionId']!;

        return ParticipantsListPage(versionId: versionId);
      },
    ),
    GoRoute(
      path: '/participant/list/:versionId/:ageGroup',
      builder: (context, state) {
        final versionId = state.pathParameters['versionId']!;
        final ageGroup = state.pathParameters['ageGroup']!;

        return ParticipantsListPage(versionId: versionId, ageGroup: ageGroup);
      },
    ),

    // Détails d'un participant
    GoRoute(
      path: '/participant/detail/:participantId',
      builder: (context, state) {
        final participant = state.extra as Participant?;

        if (participant == null) {
          return const Scaffold(
            body: Center(child: Text('Erreur : participant manquant')),
          );
        }

        return participant_pages.ParticipantDetailPage(
          participant: participant,
        );
      },
    ),

    // Session Eid pour participants
    GoRoute(
      path: '/participant/eid-session',
      builder: (context, state) {
        final session = state.extra as EidSession?;
        if (session == null) {
          return const Scaffold(
            body: Center(child: Text('Erreur : session manquante')),
          );
        }
        return EidSessionPage(session: session);
      },
    ),

    // Jury
    GoRoute(path: '/jury/home', builder: (_, __) => JuryHomePage()),
    GoRoute(path: '/jury/version_page', builder: (_, __) => JuryVersionPage()),
    GoRoute(
      path: '/jury/results',
      builder: (_, __) => JuryResultsVersionsPage(),
    ),
    GoRoute(
      path: '/jury/results/:versionId',
      builder: (context, state) {
        final versionId = state.pathParameters['versionId'];
        return JuryResultPage(versionId: versionId);
      },
    ),
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

        return JuryEvaluationPage(args: args);
      },
    ),

    GoRoute(
      name: 'jury-version-jurys',
      path: '/jury/version_jurys',
      builder: (context, state) {
        final version = state.extra as CompetitionVersion;
        return AllRoundsJurysPage(version: version);
      },
    ),

    // Admin / Super Admin
    GoRoute(path: '/admin/dashboard', builder: (_, __) => AdminDashboardPage()),
    GoRoute(path: '/admin/users', builder: (_, __) => UserManagementPage()),
    GoRoute(
      path: '/admin/users/:userId/manage',
      builder: (context, state) {
        final userId = state.pathParameters['userId'];
        if (userId == null) {
          return const AccessDeniedPage();
        }
        return UserRoleManagementPage(userId: userId);
      },
    ),
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
        return VersionRoundResultPage(version: version);
      },
    ),
    GoRoute(
      name: 'admin-version-jurys',
      path: '/admin/version_jurys',
      builder: (context, state) {
        final version = state.extra as CompetitionVersion?;
        if (version == null) {
          return const Scaffold(
            body: Center(child: Text('Erreur : version manquante')),
          );
        }
        return AllRoundsJurysPage(version: version);
      },
    ),
    GoRoute(
      path: '/admin/version_result/:roundId',
      builder: (context, state) {
        final roundId = state.pathParameters['roundId'];
        final extra = state.extra as Map<String, dynamic>?;

        if (roundId == null || extra == null) {
          return const Scaffold(
            body: Center(child: Text('Erreur : données manquantes')),
          );
        }

        final version = extra['version'] as CompetitionVersion;
        final round = extra['round'] as Round;

        return VersionResultPage(version: version, round: round);
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

    // About Us Management
    GoRoute(
      path: '/admin/about-us',
      builder: (_, __) => const AboutUsManagementPage(),
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

    // Quiz Management
    GoRoute(
      path: '/admin/quiz/levels',
      builder: (_, __) => const QuizLevelsPage(),
    ),
    GoRoute(
      path: '/admin/quiz/levels/add',
      builder: (_, __) => const QuizLevelFormPage(),
    ),
    GoRoute(
      path: '/admin/quiz/levels/edit/:id',
      builder: (context, state) {
        final levelId = state.pathParameters['id'];
        if (levelId == null) {
          return const Scaffold(
            body: Center(child: Text('Erreur : ID du niveau manquant')),
          );
        }
        return QuizLevelFormPage(levelId: levelId);
      },
    ),
    GoRoute(
      path: '/admin/quiz/levels/:levelId/questions',
      builder: (context, state) {
        final levelId = state.pathParameters['levelId'];
        if (levelId == null) {
          return const Scaffold(
            body: Center(child: Text('Erreur : ID du niveau manquant')),
          );
        }
        return QuizQuestionsPage(levelId: levelId);
      },
    ),
    GoRoute(
      path: '/admin/quiz/questions/add',
      builder: (context, state) {
        final levelId = state.uri.queryParameters['levelId'];
        return QuizQuestionFormPage(levelId: levelId);
      },
    ),
    GoRoute(
      path: '/admin/quiz/questions/edit/:id',
      builder: (context, state) {
        final questionId = state.pathParameters['id'];
        if (questionId == null) {
          return const Scaffold(
            body: Center(child: Text('Erreur : ID de la question manquant')),
          );
        }
        return QuizQuestionFormPage(questionId: questionId);
      },
    ),

    // Route pour l'ajout en lot de médias
    GoRoute(
      path: '/admin/archives/batch-add',
      builder: (context, state) {
        return const BatchAddMediaPage();
      },
    ),
    GoRoute(
      path: '/admin/media/edit',
      builder: (context, state) {
        final media = state.extra as ArchiveMedia?;
        if (media == null) {
          return const Scaffold(
            body: Center(child: Text('Erreur : Données du média manquantes')),
          );
        }
        return EditMediaPage(media: media);
      },
    ),
    GoRoute(
      path: '/admin/archives/add/:versionId',
      builder: (context, state) {
        final versionId = state.pathParameters['versionId'];
        if (versionId == null) {
          return const Scaffold(
            body: Center(child: Text('Erreur : ID de la version manquant')),
          );
        }
        // Créer un média temporaire pour la création
        final newMedia = ArchiveMedia(
          id: '', // Sera généré par la base de données
          versionId: versionId,
          type: MediaType.image, // Type par défaut
          url: '',
          title: null,
          description: null,
          order: 1, // Sera ajusté par le service
          isActive: true,
          createdAt: DateTime.now(),
        );
        return EditMediaPage(media: newMedia);
      },
    ),

    // New Competition Archives Structure
    GoRoute(
      path: '/admin/archives',
      builder: (_, __) => const NewCompetitionArchivesPage(),
    ),
    GoRoute(
      path: '/admin/archives/new',
      builder: (_, __) => const NewCompetitionArchivesPage(),
    ),
    GoRoute(
      path: '/admin/archives/competition',
      builder: (_, __) => const NewCompetitionArchivesPage(),
    ),
    GoRoute(
      path: '/admin/archives/competition/:versionId',
      builder: (context, state) {
        final versionId = state.pathParameters['versionId'];
        if (versionId == null) {
          return const Scaffold(
            body: Center(child: Text('Erreur : ID de la version manquant')),
          );
        }
        return NewCompetitionMediaManagementPage(versionId: versionId);
      },
    ),
    GoRoute(
      path: '/admin/archives/competition/new/:versionId',
      builder: (context, state) {
        final versionId = state.pathParameters['versionId'];
        if (versionId == null) {
          return const Scaffold(
            body: Center(child: Text('Erreur : ID de la version manquant')),
          );
        }
        return NewCompetitionMediaManagementPage(versionId: versionId);
      },
    ),
    // Eid Sessions Management
    GoRoute(
      path: '/admin/eid-sessions',
      builder: (context, state) => const EidSessionsPage(),
    ),
    GoRoute(
      path: '/admin/eid-sessions/create',
      builder: (context, state) {
        final session = state.extra as EidSession?;
        return EidSessionFormPage(session: session);
      },
    ),
    GoRoute(
      path: '/admin/eid-sessions/:id',
      builder: (context, state) {
        final session = state.extra as EidSession?;
        if (session == null) {
          return const Scaffold(
            body: Center(child: Text('Erreur : session manquante')),
          );
        }
        return EidSessionDetailPage(session: session);
      },
    ),
    GoRoute(
      path: '/admin/eid-sessions/:id/edit',
      builder: (context, state) {
        final session = state.extra as EidSession?;
        if (session == null) {
          return const Scaffold(
            body: Center(child: Text('Erreur : session manquante')),
          );
        }
        return EidSessionFormPage(session: session);
      },
    ),

    GoRoute(
      path: '/admin/participant/:participantId',
      name: 'participant-detail',
      builder: (context, state) {
        final participantId = state.pathParameters['participantId'];
        final participantData = state.extra as Map<String, dynamic>?;
        if (participantId == null || participantData == null) {
          return const Scaffold(
            body: Center(
              child: Text('Erreur : Données du participant manquantes'),
            ),
          );
        }
        return ParticipantDetailPage(
          participant: participantData['participant'],
          version: participantData['version'],
        );
      },
    ),
  ],
);
