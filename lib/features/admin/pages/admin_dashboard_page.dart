import 'package:flutter/material.dart';
import 'package:quranic_competition/core/widgets/logout_dialog.dart';
import '../../../core/widgets/notification_bell.dart';
import 'package:go_router/go_router.dart';
import 'package:quranic_competition/core/widgets/app_ui.dart';
import 'package:quranic_competition/core/widgets/modern_navigation.dart';
import 'package:quranic_competition/core/widgets/modern_dashboard.dart';
import 'package:quranic_competition/core/widgets/loading_states.dart';
import 'package:quranic_competition/core/theme/app_theme.dart';
import 'package:quranic_competition/core/services/evaluation_stats_service.dart';
import 'package:quranic_competition/core/services/user_service.dart';
import 'package:quranic_competition/core/services/competition_version_service.dart';
import 'package:quranic_competition/models/app_user.dart';
import 'package:quranic_competition/models/competition_version.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  bool _isLoading = false; // بدء بـ false لعرض الصفحة فوراً
  List<EvaluationStats> _evaluationStats = [];
  final EvaluationStatsService _statsService = EvaluationStatsService();
  final CompetitionVersionService _versionService = CompetitionVersionService();
  CompetitionVersion? _activeVersion;
  // Chargé une seule fois (le FutureBuilder relançait la requête à chaque
  // reconstruction de l'écran)
  late final Future<AppUser?> _profileFuture =
      UserService().getCurrentUserProfile();

  @override
  void initState() {
    super.initState();
    // تحميل البيانات في الخلفية بعد عرض الصفحة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDashboardData();
    });
  }

  Future<void> _loadDashboardData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      // Charger la version active uniquement
      final version = await _versionService.getActiveOrLatestVersion();

      // Ne garder que si elle est vraiment active
      if (version != null && version.isActive) {
        _activeVersion = version;

        // Charger les statistiques d'évaluation réelles seulement si une version active existe
        _evaluationStats =
            await _statsService.getEvaluationStatsForAllActiveVersions();
        print(
          '📊 Statistiques chargées: ${_evaluationStats.length} groupes d\'âge',
        );

        for (final stat in _evaluationStats) {
          print(
            '📊 ${stat.ageGroup}: ${stat.evaluatedParticipants}/${stat.totalParticipants} (${(stat.progressPercentage * 100).toInt()}%)',
          );
        }
      } else {
        _activeVersion = null;
        _evaluationStats = [];
      }
    } catch (e) {
      print('❌ Erreur lors du chargement des statistiques: $e');
      _evaluationStats = [];
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _showLogoutConfirmation(BuildContext context) =>
      confirmAndSignOut(context);

  Widget _buildWelcomeHeader() {
    return FutureBuilder<AppUser?>(
      future: _profileFuture,
      builder: (context, snapshot) {
        final user = snapshot.data;
        final name =
            user?.fullName.trim().isNotEmpty == true
                ? user!.fullName.trim()
                : 'مدير النظام';
        final isSuperAdmin = user?.role == 'super_admin';

        return AppGradientHeader(
          leading: CircleAvatar(
            radius: 34,
            backgroundColor: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Image.asset('assets/images/logos/logo.png'),
            ),
          ),
          title: 'مرحباً بكم، $name',
          subtitle: 'لوحة تحكم مسابقة أهل القرآن',
          badges: [
            AppHeaderBadge(
              icon: Icons.admin_panel_settings_rounded,
              text: isSuperAdmin ? 'مدير عام' : 'مدير',
            ),
            if (_activeVersion != null)
              AppHeaderBadge(
                icon: Icons.emoji_events_rounded,
                text: _activeVersion!.name,
                highlightColor: AppTheme.secondaryColor,
              ),
          ],
        );
      },
    );
  }

  Widget _buildProgressSection() {
    final stats =
        _evaluationStats.isNotEmpty
            ? _evaluationStats
                .map(
                  (s) => (
                    label: s.ageGroup,
                    progress: s.progressPercentage,
                    text: s.progressText,
                  ),
                )
                .toList()
            : [
              (label: 'كبار', progress: 0.0, text: 'لا توجد بيانات متاحة'),
              (label: 'صغار', progress: 0.0, text: 'لا توجد بيانات متاحة'),
            ];

    return AppSection(
      icon: Icons.insights_rounded,
      color: AppTheme.successColor,
      title: 'تقدم تقييمات المشاركين',
      subtitle: _activeVersion?.name,
      child:
          _isLoading
              ? const Padding(
                padding: EdgeInsets.all(AppTheme.spacingM),
                child: Center(child: CircularProgressIndicator()),
              )
              : Column(
                children: [
                  for (var i = 0; i < stats.length; i++) ...[
                    if (i > 0) const SizedBox(height: AppTheme.spacingM),
                    _buildProgressRow(
                      stats[i].label == 'صغار' ? 'فرع الصغار' : 'فرع الكبار',
                      stats[i].text,
                      stats[i].progress,
                      stats[i].label == 'صغار'
                          ? AppTheme.secondaryColor
                          : AppTheme.primaryColor,
                    ),
                  ],
                ],
              ),
    );
  }

  Widget _buildProgressRow(
    String title,
    String detail,
    double progress,
    Color color,
  ) {
    final value = progress.clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.textPrimaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              '${(value * 100).toInt()}%',
              style: AppTheme.bodyLarge.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusS),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 8,
            color: color,
            backgroundColor: color.withOpacity(0.12),
          ),
        ),
        const SizedBox(height: 4),
        Text(detail, style: AppTheme.bodySmall),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ModernAppBar(
        title: 'لوحة التحكم',
        actions: [
          const NotificationBell(),
          ProfileMenuButton(
            userName: 'مدير النظام',
            userRole: 'admin',
            onProfileTap: () => context.push('/profile'),
            onLogoutTap: () => _showLogoutConfirmation(context),
          ),
        ],
      ),
      body: ModernPullToRefresh(
        onRefresh: _loadDashboardData,
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
                  AppSection(
                    icon: Icons.apps_rounded,
                    title: 'إجراءات سريعة',
                    subtitle: 'الوصول السريع للوظائف الأساسية',
                    child: QuickActionGrid(
                      actions: [
                        QuickAction(
                          title: 'إدارة المستخدمين',
                          icon: Icons.manage_accounts_rounded,
                          color: AppTheme.primaryColor,
                          onTap: () => context.push('/admin/users'),
                        ),
                        QuickAction(
                          title: 'إدارة المسابقات',
                          icon: Icons.emoji_events_rounded,
                          color: AppTheme.successColor,
                          onTap: () => context.push('/admin/versions'),
                        ),
                        QuickAction(
                          title: 'أحكام التجويد',
                          icon: Icons.record_voice_over_rounded,
                          color: AppTheme.warningColor,
                          onTap: () => context.push('/admin/tajweed-rules'),
                        ),
                        QuickAction(
                          title: 'إدارة الفوائد القرآنية',
                          icon: Icons.menu_book_rounded,
                          color: AppTheme.warningColor,
                          onTap: () => context.push('/admin/quranic-benefits'),
                        ),
                        QuickAction(
                          title: 'أسئلة و أجوبة في القرآن',
                          icon: Icons.quiz_rounded,
                          color: AppTheme.infoColor,
                          onTap: () => context.push('/admin/quiz/levels'),
                        ),
                        QuickAction(
                          title: 'أرشيف المسابقات',
                          icon: Icons.photo_library_rounded,
                          color: AppTheme.secondaryColor,
                          onTap: () => context.push('/admin/archives'),
                        ),
                        QuickAction(
                          title: 'فسحة العيد',
                          icon: Icons.celebration_rounded,
                          color: AppTheme.successColor,
                          onTap: () => context.push('/admin/eid-sessions'),
                        ),
                        QuickAction(
                          title: 'من نحن',
                          icon: Icons.info_rounded,
                          color: AppTheme.primaryColor,
                          onTap: () => context.push('/admin/about-us'),
                        ),
                        QuickAction(
                          title: 'التحديث الإجباري',
                          icon: Icons.system_update_rounded,
                          color: AppTheme.warningColor,
                          onTap: () => context.push('/admin/force-update'),
                        ),
                      ],
                      crossAxisCount: 2,
                    ),
                  ),
                  // Progression des évaluations : seulement si une version
                  // est active
                  if (_activeVersion != null && _activeVersion!.isActive) ...[
                    const SizedBox(height: AppTheme.spacingM),
                    _buildProgressSection(),
                  ],
                  const SizedBox(height: AppTheme.spacingL),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
