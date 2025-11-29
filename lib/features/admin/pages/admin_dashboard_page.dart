import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quranic_competition/core/services/auth_service.dart';
import 'package:quranic_competition/core/widgets/role_info_widget.dart';
import 'package:quranic_competition/core/services/confirmation_service.dart';
import 'package:quranic_competition/core/widgets/modern_navigation.dart';
import 'package:quranic_competition/core/widgets/modern_dashboard.dart';
import 'package:quranic_competition/core/widgets/loading_states.dart';
import 'package:quranic_competition/core/theme/app_theme.dart';
import 'package:quranic_competition/core/widgets/ui_components.dart';
import 'package:quranic_competition/core/services/evaluation_stats_service.dart';
import 'package:quranic_competition/core/services/user_service.dart';
import 'package:quranic_competition/models/app_user.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  bool _isLoading = false; // بدء بـ false لعرض الصفحة فوراً
  List<EvaluationStats> _evaluationStats = [];
  final EvaluationStatsService _statsService = EvaluationStatsService();

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
      // Charger les statistiques d'évaluation réelles
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

  Future<void> _showLogoutConfirmation(BuildContext context) async {
    final confirmed = await ConfirmationService.showDeleteConfirmation(
      context,
      title: 'تأكيد تسجيل الخروج',
      message: 'هل أنت متأكد من رغبتك في تسجيل الخروج؟',
      confirmText: 'تسجيل الخروج',
      cancelText: 'إلغاء',
      isDestructive: false,
    );

    if (confirmed) {
      await AuthService().signOut();
      if (context.mounted) {
        context.go('/login');
      }
    }
  }

  List<Widget> _buildEvaluationProgressCards() {
    if (_evaluationStats.isEmpty) {
      // Afficher des cartes par défaut si aucune donnée n'est disponible
      return [
        _buildDefaultProgressCard(
          'تقييم المشاركين - الكبار',
          'كبار',
          Icons.people_alt,
          AppTheme.primaryColor,
          0,
          0,
        ),
        const SizedBox(height: AppTheme.spacingS),
        _buildDefaultProgressCard(
          'تقييم المشاركين - الصغار',
          'صغار',
          Icons.school,
          AppTheme.infoColor,
          0,
          0,
        ),
      ];
    }

    final cards = <Widget>[];

    for (int i = 0; i < _evaluationStats.length; i++) {
      final stat = _evaluationStats[i];

      cards.add(
        _buildProgressCard(
          'تقييم المشاركين - ${stat.ageGroup}',
          stat.ageGroup,
          Icons.people_alt,
          AppTheme.primaryColor,
          stat.evaluatedParticipants,
          stat.totalParticipants,
          stat.progressPercentage,
          stat.progressText,
        ),
      );

      if (i < _evaluationStats.length - 1) {
        cards.add(const SizedBox(height: AppTheme.spacingS));
      }
    }

    return cards;
  }

  Widget _buildProgressCard(
    String title,
    String ageGroup,
    IconData icon,
    Color color,
    int evaluated,
    int total,
    double progress,
    String progressText,
  ) {
    return ModernCard(
      child: Container(
        height: 80,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
              ),
              child: Icon(icon, color: color, size: 25),
            ),
            const SizedBox(width: AppTheme.spacingS),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: AppTheme.bodyLarge.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    progressText,
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textSecondaryColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  ModernProgressIndicator(
                    value: progress,
                    color: color,
                    height: 6,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppTheme.spacingS),
            Text(
              '${(progress * 100).toInt()}%',
              style: AppTheme.headingSmall.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultProgressCard(
    String title,
    String ageGroup,
    IconData icon,
    Color color,
    int evaluated,
    int total,
  ) {
    return ModernCard(
      child: Container(
        height: 80,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
              ),
              child: Icon(icon, color: color, size: 25),
            ),
            const SizedBox(width: AppTheme.spacingS),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: AppTheme.bodyLarge.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'لا توجد بيانات متاحة',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textSecondaryColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  ModernProgressIndicator(value: 0.0, color: color, height: 6),
                ],
              ),
            ),
            const SizedBox(width: AppTheme.spacingS),
            Text(
              '0%',
              style: AppTheme.headingSmall.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ModernAppBar(
        title: 'لوحة التحكم',
        actions: [
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.spacingS),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome message
              FutureBuilder<AppUser?>(
                future: UserService().getCurrentUserProfile(),
                builder: (context, snapshot) {
                  final username = snapshot.data?.fullName ?? 'مدير النظام';
                  return Container(
                    padding: const EdgeInsets.all(AppTheme.spacingM),
                    margin: const EdgeInsets.only(bottom: AppTheme.spacingS),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusM),
                      border: Border.all(
                        color: AppTheme.primaryColor.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          FontAwesomeIcons.hand,
                          color: AppTheme.primaryColor,
                          size: 24,
                        ),
                        const SizedBox(width: AppTheme.spacingS),
                        Expanded(
                          child: Text(
                            'مرحبا بكم $username',
                            style: AppTheme.headingSmall.copyWith(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: AppTheme.spacingS),
              // Informations de l'utilisateur
              RoleInfoWidget(),
              // const SizedBox(height: AppTheme.spacingL),

              // Actions rapides
              DashboardSection(
                title: 'إجراءات سريعة',
                subtitle: 'الوصول السريع للوظائف الأساسية',
                child: QuickActionGrid(
                  actions: [
                    QuickAction(
                      title: 'إدارة المستخدمين',
                      imagePath: 'assets/images/admin.png',
                      color: AppTheme.primaryColor,
                      onTap: () => context.push('/admin/users'),
                    ),
                    QuickAction(
                      title: 'إدارة المسابقات',
                      imagePath: 'assets/images/competition.png',
                      color: AppTheme.successColor,
                      onTap: () => context.push('/admin/versions'),
                    ),
                    QuickAction(
                      title: 'أحكام التجويد',
                      imagePath: 'assets/images/tejweed.png',
                      color: AppTheme.warningColor,
                      onTap: () => context.push('/admin/tajweed-rules'),
                    ),
                    QuickAction(
                      title: 'إدارة الفوائد القرآنية',
                      imagePath: 'assets/images/فوائد قرآنية.png',
                      color: Colors.deepOrange,
                      onTap: () => context.push('/admin/quranic-benefits'),
                    ),
                    QuickAction(
                      title: 'أسئلة و أجوبة في القرآن',
                      imagePath: 'assets/images/أسئلة_وأجوبة_عن_القرآن_الكريم.png',
                      color: AppTheme.infoColor,
                      onTap: () => context.push('/admin/quiz/levels'),
                    ),
                    QuickAction(
                      title: 'أرشيف المسابقات',
                      imagePath: 'assets/images/archive.png',
                      color: AppTheme.secondaryColor,
                      onTap: () => context.push('/admin/archives'),
                    ),
                    QuickAction(
                      title: 'فسحة العيد',
                      icon: Icons.celebration,
                      color: Colors.green,
                      onTap: () => context.push('/admin/eid-sessions'),
                    ),
                    QuickAction(
                      title: 'من نحن',
                      imagePath: 'assets/images/about-us.png',
                      color: Colors.teal,
                      onTap: () => context.push('/admin/about-us'),
                    ),
                  ],
                  crossAxisCount: 2,
                ),
              ),

              // const SizedBox(height: AppTheme.spacingL),

              // Progression des activités (sans titre de section)
              _isLoading
                  ? const Padding(
                    padding: EdgeInsets.all(AppTheme.spacingL),
                    child: Center(child: CircularProgressIndicator()),
                  )
                  : Column(children: _buildEvaluationProgressCards()),

              // const SizedBox(height: AppTheme.spacingL),
            ],
          ),
        ),
      ),
    );
  }
}
