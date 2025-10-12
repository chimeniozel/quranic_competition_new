import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/modern_navigation.dart';
import '../../../core/widgets/ui_components.dart';
import '../../../core/widgets/loading_states.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/competition_version_service.dart';
import '../../../models/competition_version.dart';

class ParticipantHomePage extends StatefulWidget {
  const ParticipantHomePage({super.key});

  @override
  State<ParticipantHomePage> createState() => _ParticipantHomePageState();
}

class _ParticipantHomePageState extends State<ParticipantHomePage> {
  bool _isLoading = false;
  bool _hasActiveCompetition = false;
  CompetitionVersion? _activeVersion;
  final _competitionService = CompetitionVersionService();
  StreamSubscription<List<CompetitionVersion>>? _competitionSubscription;

  @override
  void initState() {
    super.initState();
    _startListeningToCompetitionChanges();
  }

  @override
  void dispose() {
    _competitionSubscription?.cancel();
    super.dispose();
  }

  void _startListeningToCompetitionChanges() {
    print('🏠 Début de l\'écoute des changements de compétitions');
    setState(() => _isLoading = true);

    _competitionSubscription = _competitionService
        .listenToActiveVersionsWithOpenRegistration()
        .listen(
          (activeVersions) {
            print('🏠 Compétitions reçues: ${activeVersions.length}');
            if (mounted) {
              setState(() {
                _hasActiveCompetition = activeVersions.isNotEmpty;
                _activeVersion =
                    activeVersions.isNotEmpty ? activeVersions.first : null;
                _isLoading = false;
              });
              print(
                '🏠 État mis à jour: hasActiveCompetition=$_hasActiveCompetition',
              );
            }
          },
          onError: (error) {
            print('❌ Erreur dans l\'écoute des compétitions: $error');
            if (mounted) {
              setState(() {
                _hasActiveCompetition = false;
                _activeVersion = null;
                _isLoading = false;
              });
            }
          },
        );
  }

  Future<void> _checkActiveCompetition() async {
    // Cette méthode est maintenant remplacée par le stream en temps réel
    // mais on la garde pour le pull-to-refresh
    setState(() => _isLoading = true);
    try {
      final activeVersions =
          await _competitionService.fetchActiveVersionsWithOpenRegistration();
      setState(() {
        _hasActiveCompetition = activeVersions.isNotEmpty;
        _activeVersion =
            activeVersions.isNotEmpty ? activeVersions.first : null;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _hasActiveCompetition = false;
        _activeVersion = null;
        _isLoading = false;
      });
      print('Erreur lors de la vérification des compétitions: $e');
    }
  }

  Future<void> _loadVersions() async {
    await _checkActiveCompetition();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ModernAppBar(
        title: 'الصفحة الرئيسة',
        actions: [
          IconButton(
            icon: const Icon(Icons.login),
            tooltip: 'تسجيل الدخول',
            onPressed: () {
              context.push('/login');
            },
          ),
        ],
      ),

      body:
          _isLoading
              ? const LoadingOverlay(child: SizedBox())
              : ModernPullToRefresh(
                onRefresh: _loadVersions,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppTheme.spacingS),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section d'inscription
                      ModernCard(
                        child: Padding(
                          padding: const EdgeInsets.all(AppTheme.spacingS),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(
                                      AppTheme.spacingS,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(
                                        AppTheme.radiusM,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.person_add,
                                      color: AppTheme.primaryColor,
                                      size: 16,
                                    ),
                                  ),
                                  const SizedBox(width: AppTheme.spacingS),
                                  Text(
                                    'التسجيل في المسابقة',
                                    style: AppTheme.labelLarge.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppTheme.spacingS),

                              // Boutons d'inscription ou message d'information
                              if (_hasActiveCompetition &&
                                  _activeVersion != null) ...[
                                Row(
                                  children: [
                                    Expanded(
                                      child: PrimaryButton(
                                        onPressed: () {
                                          context.push(
                                            '/participant/register',
                                            extra: {
                                              'versionId': _activeVersion!.id,
                                              'ageGroup': 'صغار',
                                            },
                                          );
                                        },
                                        text: 'فرع الصغار',
                                      ),
                                    ),
                                    const SizedBox(width: AppTheme.spacingS),
                                    Expanded(
                                      child: PrimaryButton(
                                        onPressed: () {
                                          context.push(
                                            '/participant/register',
                                            extra: {
                                              'versionId': _activeVersion!.id,
                                              'ageGroup': 'كبار',
                                            },
                                          );
                                        },
                                        text: 'فرع الكبار',
                                      ),
                                    ),
                                  ],
                                ),
                              ] else ...[
                                SizedBox(
                                  width: double.infinity,
                                  child: Container(
                                    padding: const EdgeInsets.all(
                                      AppTheme.spacingS,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(
                                        AppTheme.radiusM,
                                      ),
                                      border: Border.all(
                                        color: Colors.orange.withValues(
                                          alpha: 0.3,
                                        ),
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.info_outline,
                                          color: Colors.orange,
                                          size: 24,
                                        ),
                                        const SizedBox(
                                          height: AppTheme.spacingS,
                                        ),
                                        Text(
                                          'التسجيل غير متاح حالياً',
                                          style: AppTheme.labelLarge.copyWith(
                                            color: Colors.orange,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(
                                          height: AppTheme.spacingS,
                                        ),
                                        Text(
                                          _activeVersion == null
                                              ? 'لا توجد مسابقة نشطة حالياً'
                                              : 'المسابقة الحالية مغلقة للتسجيل',
                                          style: AppTheme.labelMedium.copyWith(
                                            color: Colors.orange[700],
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),

                      // Section des résultats
                      ModernCard(
                        child: Padding(
                          padding: const EdgeInsets.all(AppTheme.spacingS),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(
                                      AppTheme.spacingS,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.successColor.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(
                                        AppTheme.radiusM,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.emoji_events,
                                      color: AppTheme.successColor,
                                      size: 16,
                                    ),
                                  ),
                                  const SizedBox(width: AppTheme.spacingS),
                                  Text(
                                    'نتائج المسابقة',
                                    style: AppTheme.labelLarge.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppTheme.spacingS),
                              SizedBox(
                                width: double.infinity,
                                child: SecondaryButton(
                                  onPressed: () {
                                    context.push('/participant_result_page');
                                  },
                                  text: 'عرض النتائج',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Section des services
                      ModernCard(
                        child: Padding(
                          padding: const EdgeInsets.all(AppTheme.spacingS),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // const SizedBox(height: AppTheme.spacingM),

                              // Grille des services
                              Column(
                                children: [
                                  // Ligne 1: فوائد قرآنية et أحكام التجويد
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildServiceCard(
                                          title: 'الفوائد القرآنية',
                                          icon: Icons.menu_book,
                                          color: AppTheme.successColor,
                                          onTap: () {
                                            context.push(
                                              '/participant/benefits',
                                            );
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: AppTheme.spacingS),
                                      Expanded(
                                        child: _buildServiceCard(
                                          title: 'أحكام التجويد',
                                          icon: Icons.auto_stories,
                                          color: AppTheme.primaryColor,
                                          onTap: () {
                                            context.push(
                                              '/participant/tajweed',
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: AppTheme.spacingS),

                                  // Ligne 2: مسابقات التجويد et أرشيف المسابقات
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildServiceCard(
                                          title: 'مسابقات التجويد',
                                          icon: Icons.quiz,
                                          color: AppTheme.warningColor,
                                          onTap: () {
                                            context.push('/participant/quiz');
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: AppTheme.spacingS),
                                      Expanded(
                                        child: _buildServiceCard(
                                          title: 'أرشيف المسابقات',
                                          icon: Icons.archive,
                                          color: AppTheme.secondaryColor,
                                          onTap: () {
                                            context.push(
                                              '/participant/archives',
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: AppTheme.spacingS),

                                  // Ligne 3: قائمة المشاركين (toujours visible)
                                  _buildServiceCard(
                                    title: 'قائمة المشاركين',
                                    icon: Icons.people,
                                    color: Colors.blue,
                                    onTap: () {
                                      // Utiliser une version par défaut ou la version active
                                      final versionId =
                                          _activeVersion?.id ?? 'default';
                                      print(
                                        '🚀 Navigation vers: /participant/list/$versionId',
                                      );
                                      print(
                                        '🚀 Version active: $_activeVersion',
                                      );
                                      print('🚀 Version ID: $versionId');

                                      try {
                                        context.push(
                                          '/participant/list/$versionId',
                                        );
                                        print('✅ Navigation réussie');
                                      } catch (e) {
                                        print('❌ Erreur de navigation: $e');
                                      }
                                    },
                                  ),

                                  // Ligne 4: Message informatif (si compétition active)
                                  if (_hasActiveCompetition &&
                                      _activeVersion != null) ...[
                                    const SizedBox(height: AppTheme.spacingS),
                                    Container(
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: AppTheme.spacingS,
                                        vertical: AppTheme.spacingXS,
                                      ),
                                      padding: const EdgeInsets.all(
                                        AppTheme.spacingS,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(
                                          AppTheme.radiusS,
                                        ),
                                        border: Border.all(
                                          color: Colors.blue.withOpacity(0.3),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.info_outline,
                                            color: Colors.blue,
                                            size: 20,
                                          ),
                                          const SizedBox(
                                            width: AppTheme.spacingS,
                                          ),
                                          Expanded(
                                            child: Text(
                                              'يمكنك الآن الاطلاع على قائمة المشاركين في هذه المسابقة النشطة',
                                              style: AppTheme.bodySmall
                                                  .copyWith(
                                                    color: Colors.blue[700],
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ] else ...[
                                    const SizedBox(height: AppTheme.spacingS),
                                    Container(
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: AppTheme.spacingS,
                                        vertical: AppTheme.spacingXS,
                                      ),
                                      padding: const EdgeInsets.all(
                                        AppTheme.spacingS,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(
                                          AppTheme.radiusS,
                                        ),
                                        border: Border.all(
                                          color: Colors.grey.withOpacity(0.3),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.info_outline,
                                            color: Colors.grey,
                                            size: 20,
                                          ),
                                          const SizedBox(
                                            width: AppTheme.spacingS,
                                          ),
                                          Expanded(
                                            child: Text(
                                              'قائمة المشاركين من المسابقات السابقة',
                                              style: AppTheme.bodySmall
                                                  .copyWith(
                                                    color: Colors.grey[700],
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _buildServiceCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacingS),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingS),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: AppTheme.spacingS),
            Text(
              title,
              style: AppTheme.labelMedium.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
