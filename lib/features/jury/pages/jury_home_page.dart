import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quranic_competition/core/services/auth_service.dart';
import 'package:quranic_competition/core/services/competition_version_service.dart';
import 'package:quranic_competition/core/services/evaluation_service.dart';
import 'package:quranic_competition/models/app_user.dart';
import 'package:quranic_competition/models/competition_version.dart';
import '../../../core/widgets/modern_navigation.dart';
import '../../../core/widgets/ui_components.dart';
import '../../../core/widgets/loading_states.dart';
import '../../../core/theme/app_theme.dart';

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

  Future<void> _showLogoutConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('تأكيد تسجيل الخروج'),
          content: const Text('هل أنت متأكد من رغبتك في تسجيل الخروج؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('تسجيل الخروج'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await AuthService().signOut();
      if (mounted) {
        context.go('/login');
      }
    }
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);

    try {
      // Charger le profil utilisateur
    final user = await AuthService().getUserProfile();

      // Charger les versions assignées au jury
      final versions = await CompetitionVersionService().fetchMyVersions();

      // Charger les statistiques d'évaluation
      Map<String, dynamic> stats = {};
      if (user != null) {
        try {
          // Compter toutes les évaluations du jury
          int totalEvaluations = 0;
          for (final version in versions) {
            final evaluations = await EvaluationService()
                .getEvaluationsByJuryInVersion(
                  juryId: user.id,
                  versionId: version.id,
                );
            totalEvaluations += evaluations.length;
          }

          stats = {
            'total_evaluations': totalEvaluations,
            'completed_versions': versions.where((v) => v.isActive).length,
            'pending_evaluations': 0, // À calculer selon la logique métier
          };
        } catch (e) {
          stats = {
            'total_evaluations': 0,
            'completed_versions': 0,
            'pending_evaluations': 0,
          };
        }
      }

    setState(() {
      appUser = user;
        _myVersions = versions;
        _statistics = stats;
      isLoading = false;
    });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ModernAppBar(
        title:
            isLoading
                ? 'جارٍ التحميل...'
                : 'مرحباً ${appUser?.fullName ?? 'عضو لجنة التحكيم'}',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.surfaceColor),
            tooltip: 'تحديث',
            onPressed: _loadData,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppTheme.surfaceColor),
            onSelected: (value) {
              switch (value) {
                case 'profile':
                  context.push('/profile');
                  break;
                case 'security':
                  context.push('/security-settings');
                  break;
                case 'logout':
                  _showLogoutConfirmation();
                  break;
              }
            },
            itemBuilder:
                (context) => [
                  PopupMenuItem(
                    value: 'profile',
                    child: Row(
                      children: [
                        Icon(
                          Icons.person,
                          size: 20,
                          color: AppTheme.primaryColor,
                        ),
                        const SizedBox(width: AppTheme.spacingS),
                        const Text('الملف الشخصي'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'security',
                    child: Row(
                      children: [
                        Icon(
                          Icons.security,
                          size: 20,
                          color: AppTheme.primaryColor,
                        ),
                        const SizedBox(width: AppTheme.spacingS),
                        const Text('الأمان'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'divider',
                    enabled: false,
                    child: Divider(),
                  ),
                  PopupMenuItem(
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(
                          Icons.logout,
                          size: 20,
                          color: AppTheme.errorColor,
                        ),
                        const SizedBox(width: AppTheme.spacingS),
                        const Text('تسجيل الخروج'),
                      ],
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
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppTheme.spacingM),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Carte de bienvenue
                      _buildWelcomeCard(),
                      const SizedBox(height: AppTheme.spacingL),

                      // Statistiques
                      _buildStatisticsSection(),
                      const SizedBox(height: AppTheme.spacingL),

                      // Versions assignées
                      _buildVersionsSection(),
                      const SizedBox(height: AppTheme.spacingL),

                      // Actions rapides
                      _buildQuickActionsSection(),
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _buildWelcomeCard() {
    return ModernCard(
      child: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
        ),
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingM),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  ),
                  child: const Icon(Icons.gavel, color: Colors.white, size: 32),
                ),
                const SizedBox(width: AppTheme.spacingM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'أهلاً وسهلاً',
                        style: AppTheme.headingSmall.copyWith(
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingXS),
                      Text(
                        appUser?.fullName ?? 'عضو لجنة التحكيم',
                        style: AppTheme.bodyLarge.copyWith(
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingM),
            Text(
              'مرحباً بك في لوحة تحكيم مسابقة أهل القرآن',
              style: AppTheme.bodyMedium.copyWith(
                color: Colors.white.withOpacity(0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'إحصائيات التقييم',
          style: AppTheme.headingSmall.copyWith(
            color: AppTheme.textPrimaryColor,
          ),
        ),
        const SizedBox(height: AppTheme.spacingM),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'إجمالي التقييمات',
                '${_statistics['total_evaluations'] ?? 0}',
                Icons.rate_review,
                AppTheme.infoColor,
              ),
            ),
            const SizedBox(width: AppTheme.spacingM),
            Expanded(
              child: _buildStatCard(
                'النسخ النشطة',
                '${_statistics['completed_versions'] ?? 0}',
                Icons.event,
                AppTheme.successColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return ModernCard(
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingS),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: AppTheme.spacingM),
            Text(
              value,
              style: AppTheme.headingMedium.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spacingXS),
            Text(
              title,
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.textSecondaryColor,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVersionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'النسخ المحكمة من طرفي',
              style: AppTheme.headingSmall.copyWith(
                color: AppTheme.textPrimaryColor,
              ),
            ),
            SecondaryButton(
              text: 'عرض الكل',
              icon: Icons.arrow_forward,
              onPressed: () => context.push('/jury/version_page'),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacingM),
        if (_myVersions.isEmpty)
          EmptyState(
            icon: Icons.event_available,
            title: 'لا توجد نسخ محكمة حالياً',
            subtitle: 'لم يتم تعيين أي نسخ للتحكيم بعد',
          )
        else
          ...(_myVersions.take(3).map((version) => _buildVersionCard(version))),
      ],
    );
  }

  Widget _buildVersionCard(CompetitionVersion version) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingS),
      child: ModernCard(
        child: InkWell(
          onTap:
              () => context.push('/jury/version_detail_page', extra: version),
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor:
                      version.isActive
                          ? AppTheme.successColor.withOpacity(0.1)
                          : AppTheme.textSecondaryColor.withOpacity(0.1),
                  child: Icon(
                    Icons.event,
                    color:
                        version.isActive
                            ? AppTheme.successColor
                            : AppTheme.textSecondaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: AppTheme.spacingM),
                Expanded(
              child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                      Text(
                        version.name,
                        style: AppTheme.labelLarge.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingXS),
                      Text(
                        'السنة: ${version.year}',
                        style: AppTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingM,
                    vertical: AppTheme.spacingXS,
                  ),
                  decoration: BoxDecoration(
                    color:
                        version.isActive
                            ? AppTheme.successColor.withOpacity(0.1)
                            : AppTheme.textSecondaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusS),
                    border: Border.all(
                      color:
                          version.isActive
                              ? AppTheme.successColor
                              : AppTheme.textSecondaryColor,
                    ),
                  ),
                  child: Text(
                    version.isActive ? 'نشطة' : 'منتهية',
                    style: AppTheme.bodySmall.copyWith(
                      color:
                          version.isActive
                              ? AppTheme.successColor
                              : AppTheme.textSecondaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'الإجراءات السريعة',
          style: AppTheme.headingSmall.copyWith(
            color: AppTheme.textPrimaryColor,
          ),
        ),
        const SizedBox(height: AppTheme.spacingM),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                'النسخ المحكمة',
                Icons.event,
                AppTheme.primaryColor,
                () => context.push('/jury/version_page'),
              ),
            ),
            const SizedBox(width: AppTheme.spacingM),
            Expanded(
              child: _buildActionCard(
                'النتائج',
                Icons.assessment,
                AppTheme.warningColor,
                () => context.push('/jury/results'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return ModernCard(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        child: Container(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingS),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: AppTheme.spacingM),
              Text(
                title,
                style: AppTheme.labelMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimaryColor,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
              ),
            ),
    );
  }
}
