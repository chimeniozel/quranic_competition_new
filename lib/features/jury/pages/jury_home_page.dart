import 'package:flutter/material.dart';
import 'package:quranic_competition/core/widgets/logout_dialog.dart';
import '../../../core/widgets/notification_bell.dart';
import 'package:go_router/go_router.dart';
import 'package:quranic_competition/core/services/auth_service.dart';
import 'package:quranic_competition/core/services/competition_version_service.dart';
import 'package:quranic_competition/core/services/evaluation_service.dart';
import 'package:quranic_competition/models/app_user.dart';
import 'package:quranic_competition/models/competition_version.dart';
import '../../../core/widgets/modern_navigation.dart';
import '../../../core/widgets/loading_states.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_ui.dart';

class JuryHomePage extends StatefulWidget {
  const JuryHomePage({super.key});

  @override
  State<JuryHomePage> createState() => _JuryHomePageState();
}

class _JuryHomePageState extends State<JuryHomePage> {
  AppUser? appUser;
  bool isLoading = true;
  List<CompetitionVersion> _myVersions = [];
  Map<String, dynamic> _statistics = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _showLogoutConfirmation() => confirmAndSignOut(context);

  Future<void> _loadData() async {
    // Au rafraîchissement, le contenu reste affiché
    setState(() => isLoading = appUser == null);

    try {
      final versionService = CompetitionVersionService();
      final userFuture = AuthService().getUserProfile();
      final versionsFuture = versionService.fetchMyVersions();
      final user = await userFuture;
      final versions = await versionsFuture;

      // Évaluations comptées pour toutes les versions en parallèle
      var totalEvaluations = 0;
      if (user != null && versions.isNotEmpty) {
        try {
          final perVersion = await Future.wait(
            versions.map(
              (v) => EvaluationService().getEvaluationsByJuryInVersion(
                juryId: user.id,
                versionId: v.id,
              ),
            ),
          );
          totalEvaluations = perVersion.fold(0, (sum, l) => sum + l.length);
        } catch (e) {
          debugPrint('Erreur lors du comptage des évaluations: $e');
        }
      }

      if (!mounted) return;
      setState(() {
        appUser = user;
        _myVersions = versions;
        _statistics = {
          'total_evaluations': totalEvaluations,
          'active_versions': versions.where((v) => v.isActive).length,
          'all_versions': versions.length,
        };
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Erreur lors du chargement de l\'accueil jury: $e');
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ModernAppBar(
        title: 'لوحة التحكيم',
        actions: [
          const NotificationBell(),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تحديث',
            onPressed: _loadData,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle_rounded),
            tooltip: 'حسابي',
            onSelected: (value) {
              if (value == 'profile') context.push('/profile');
              if (value == 'logout') _showLogoutConfirmation();
            },
            itemBuilder:
                (context) => const [
                  PopupMenuItem(
                    value: 'profile',
                    child: ListTile(
                      leading: Icon(Icons.person_rounded),
                      title: Text('الملف الشخصي'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'logout',
                    child: ListTile(
                      leading: Icon(
                        Icons.logout_rounded,
                        color: AppTheme.errorColor,
                      ),
                      title: Text('تسجيل الخروج'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
          ),
        ],
      ),
      body:
          isLoading
              ? const ModernLoadingIndicator()
              : ModernPullToRefresh(
                onRefresh: _loadData,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  children: [
                    _buildWelcomeHeader(),
                    Padding(
                      padding: const EdgeInsets.all(AppTheme.spacingM),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildStatisticsRow(),
                          const SizedBox(height: AppTheme.spacingM),
                          _buildVersionsSection(),
                          const SizedBox(height: AppTheme.spacingM),
                          AppListCard(
                            onTap: () => context.push('/jury/results'),
                            leading: const AppIconBadge(
                              icon: Icons.leaderboard_rounded,
                              color: AppTheme.secondaryColor,
                            ),
                            title: 'نتائج المسابقة',
                            subtitle: 'عرض النتائج المنشورة لكل نسخة',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
    );
  }

  Widget _buildWelcomeHeader() {
    return AppGradientHeader(
      leading: CircleAvatar(
        radius: 34,
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Image.asset('assets/images/logos/logo.png'),
        ),
      ),
      title: 'أهلاً وسهلاً، ${appUser?.fullName ?? 'عضو لجنة التحكيم'}',
      subtitle: 'لوحة تحكيم مسابقة أهل القرآن الواتسابية',
      badges: const [
        AppHeaderBadge(icon: Icons.gavel_rounded, text: 'عضو لجنة التحكيم'),
      ],
    );
  }

  Widget _buildStatisticsRow() {
    return Row(
      children: [
        Expanded(
          child: AppStatTile(
            label: 'تقييماتي',
            value: '${_statistics['total_evaluations'] ?? 0}',
            icon: Icons.rate_review_rounded,
            color: AppTheme.infoColor,
          ),
        ),
        const SizedBox(width: AppTheme.spacingS),
        Expanded(
          child: AppStatTile(
            label: 'نسخ نشطة',
            value: '${_statistics['active_versions'] ?? 0}',
            icon: Icons.event_available_rounded,
            color: AppTheme.successColor,
          ),
        ),
        const SizedBox(width: AppTheme.spacingS),
        Expanded(
          child: AppStatTile(
            label: 'كل النسخ',
            value: '${_statistics['all_versions'] ?? 0}',
            icon: Icons.history_rounded,
            color: AppTheme.primaryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildVersionsSection() {
    return AppSection(
      icon: Icons.emoji_events_rounded,
      title: 'النسخ المحكمة من طرفي',
      trailing:
          _myVersions.length > 3
              ? TextButton(
                onPressed: () => context.push('/jury/version_page'),
                child: const Text('عرض الكل'),
              )
              : null,
      child:
          _myVersions.isEmpty
              ? const AppNotice(
                text: 'لم يتم تعيين أي نسخة للتحكيم بعد',
                icon: Icons.event_busy_rounded,
              )
              : Column(
                children: [
                  for (final version in _myVersions.take(3))
                    _buildVersionCard(version),
                ],
              ),
    );
  }

  Widget _buildVersionCard(CompetitionVersion version) {
    final color =
        version.isActive ? AppTheme.successColor : AppTheme.textSecondaryColor;

    return AppListCard(
      onTap: () => context.push('/jury/version_detail_page', extra: version),
      highlightColor: version.isActive ? AppTheme.successColor : null,
      leading: AppIconBadge(icon: Icons.emoji_events_rounded, color: color),
      title: version.name,
      subtitle: 'السنة ${version.year}',
      tags: [
        AppTag(
          text: version.isActive ? 'نشطة' : 'منتهية',
          color: color,
          icon:
              version.isActive
                  ? Icons.check_circle_rounded
                  : Icons.history_rounded,
        ),
        if (version.isActive)
          AppTag(
            text:
                version.juryEvaluationEnabled
                    ? 'التقييم مفتوح'
                    : 'التقييم مغلق',
            color:
                version.juryEvaluationEnabled
                    ? AppTheme.infoColor
                    : AppTheme.textSecondaryColor,
            icon: Icons.gavel_rounded,
          ),
      ],
    );
  }
}
