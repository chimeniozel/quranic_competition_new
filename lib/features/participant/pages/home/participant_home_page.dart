import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/competition_version_service.dart';
import '../../../../core/services/eid_session_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/loading_states.dart';
import '../../../../core/widgets/modern_navigation.dart';
import '../../../../core/widgets/ui_components.dart';
import '../../../../models/competition_version.dart';
import '../../../../models/eid_session.dart';

class ParticipantHomePage extends StatefulWidget {
  const ParticipantHomePage({super.key});

  @override
  State<ParticipantHomePage> createState() => _ParticipantHomePageState();
}

class _ParticipantHomePageState extends State<ParticipantHomePage> {
  bool _isLoading = false;
  bool _hasActiveCompetition = false;
  CompetitionVersion? _activeVersion;
  bool _adultsRegistrationOpen = true;
  bool _childrenRegistrationOpen = true;
  final _competitionService = CompetitionVersionService();
  final _eidService = EidSessionService();
  StreamSubscription<List<CompetitionVersion>>? _competitionSubscription;
  EidSession? _activeEidSession;

  @override
  void initState() {
    super.initState();
    _startListeningToCompetitionChanges();
    _loadEidSession();
  }

  Future<void> _loadEidSession() async {
    try {
      final session = await _eidService.getActiveSession();
      if (mounted) {
        setState(() => _activeEidSession = session);
      }
    } catch (e) {
      print('❌ Erreur lors du chargement de la session Eid: $e');
    }
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
            _updateCompetitionData(activeVersions);
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

  Future<void> _updateCompetitionData(
    List<CompetitionVersion> activeVersions,
  ) async {
    try {
      bool hasActiveCompetition = activeVersions.isNotEmpty;
      CompetitionVersion? activeVersion =
          activeVersions.isNotEmpty ? activeVersions.first : null;

      // Vérifier les limites de participants si une compétition est active
      if (activeVersion != null) {
        await _checkParticipantLimits(activeVersion);
      }

      if (mounted) {
        setState(() {
          _hasActiveCompetition = hasActiveCompetition;
          _activeVersion = activeVersion;
          _isLoading = false;
        });
        print(
          '🏠 État mis à jour: hasActiveCompetition=$_hasActiveCompetition',
        );
      }
    } catch (e) {
      print('❌ Erreur lors de la mise à jour des données: $e');
      if (mounted) {
        setState(() {
          _hasActiveCompetition = false;
          _activeVersion = null;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _checkParticipantLimits(CompetitionVersion version) async {
    try {
      // Récupérer le nombre de participants par groupe d'âge
      final participantCounts = await _competitionService
          .getParticipantCountsByAgeGroup(version.id);

      final adultsCount = participantCounts['adults'] ?? 0;
      final childrenCount = participantCounts['children'] ?? 0;

      print(
        '📊 Nombre de participants: Adultes=$adultsCount/${version.maxAdults}, Enfants=$childrenCount/${version.maxChildren}',
      );

      if (mounted) {
        setState(() {
          _adultsRegistrationOpen = adultsCount < version.maxAdults;
          _childrenRegistrationOpen = childrenCount < version.maxChildren;
        });
      }
    } catch (e) {
      print('❌ Erreur lors de la vérification des limites: $e');
      if (mounted) {
        setState(() {
          _adultsRegistrationOpen = true;
          _childrenRegistrationOpen = true;
        });
      }
    }
  }

  Future<void> _checkActiveCompetition() async {
    // Cette méthode est maintenant remplacée par le stream en temps réel
    // mais on la garde pour le pull-to-refresh
    setState(() => _isLoading = true);
    try {
      final activeVersions =
          await _competitionService.fetchActiveVersionsWithOpenRegistration();
      await _updateCompetitionData(activeVersions);
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
        title: 'مسابقة أهل القرآن الواتسابية الواتسابية',
        actions: [
          IconButton(
            icon: const Icon(Icons.login),
            tooltip: 'تسجيل الدخول',
            onPressed: () async {
              // Déconnexion si connecté, sinon aller sur login
              final user = Supabase.instance.client.auth.currentUser;
              if (user != null) {
                await Supabase.instance.client.auth.signOut();
                // Nettoyer les permissions si besoin, par exemple :
                // PermissionService().clearPermissions();
              }
              context.push('/login');
            },
          ),
        ],
      ),

      body:
          _isLoading
              ? const ModernLoadingIndicator(
                message: 'جاري تحميل البيانات...',
                size: 50,
              )
              : ModernPullToRefresh(
                onRefresh: _loadVersions,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppTheme.spacingXS),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section session Eid (si active)
                      if (_activeEidSession != null) ...[
                        ModernCard(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.green.shade400,
                                  Colors.green.shade600,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusM,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(AppTheme.spacingXS),
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
                                          color: Colors.white.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(
                                            AppTheme.radiusM,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.celebration,
                                          color: Colors.white,
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: AppTheme.spacingXS),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _activeEidSession!.name,
                                              style: AppTheme.headingSmall
                                                  .copyWith(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                            ),
                                            if (_activeEidSession!
                                                    .description !=
                                                null) ...[
                                              const SizedBox(
                                                height: AppTheme.spacingXS,
                                              ),
                                              Text(
                                                _activeEidSession!.description!,
                                                style: AppTheme.bodyMedium
                                                    .copyWith(
                                                      color: Colors.white
                                                          .withOpacity(0.9),
                                                    ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: AppTheme.spacingXS),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        context.push(
                                          '/participant/eid-session',
                                          extra: _activeEidSession,
                                        );
                                      },
                                      icon: Icon(
                                        _activeEidSession!.isOpen
                                            ? Icons.person_add
                                            : Icons.emoji_events,
                                        color: Colors.white,
                                      ),
                                      label: Text(
                                        _activeEidSession!.isOpen
                                            ? 'التسجيل في الفسحة'
                                            : 'عرض الفائزين',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white
                                            .withOpacity(0.2),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: AppTheme.spacingS,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            AppTheme.radiusM,
                                          ),
                                          side: const BorderSide(
                                            color: Colors.white,
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacingXS),
                      ],

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
                                    'التسجيل في النسخة',
                                    style: AppTheme.labelLarge.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppTheme.spacingXS),

                              // Boutons d'inscription ou message d'information
                              if (_hasActiveCompetition &&
                                  _activeVersion != null) ...[
                                Row(
                                  children: [
                                    Expanded(
                                      child: PrimaryButton(
                                        onPressed:
                                            _childrenRegistrationOpen
                                                ? () {
                                                  context.push(
                                                    '/participant/register',
                                                    extra: {
                                                      'versionId':
                                                          _activeVersion!.id,
                                                      'ageGroup': 'صغار',
                                                    },
                                                  );
                                                }
                                                : null,
                                        text: 'فرع الصغار',
                                      ),
                                    ),
                                    const SizedBox(width: AppTheme.spacingXS),
                                    Expanded(
                                      child: PrimaryButton(
                                        onPressed:
                                            _adultsRegistrationOpen
                                                ? () {
                                                  context.push(
                                                    '/participant/register',
                                                    extra: {
                                                      'versionId':
                                                          _activeVersion!.id,
                                                      'ageGroup': 'كبار',
                                                    },
                                                  );
                                                }
                                                : null,
                                        text: 'فرع الكبار',
                                      ),
                                    ),
                                  ],
                                ),

                                // Message d'information si un groupe est complet
                                if (!_childrenRegistrationOpen ||
                                    !_adultsRegistrationOpen) ...[
                                  const SizedBox(height: AppTheme.spacingXS),
                                  Container(
                                    padding: const EdgeInsets.all(
                                      AppTheme.spacingS,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.warningColor.withOpacity(
                                        0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(
                                        AppTheme.radiusM,
                                      ),
                                      border: Border.all(
                                        color: AppTheme.warningColor
                                            .withOpacity(0.3),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.info_outline,
                                          color: AppTheme.warningColor,
                                          size: 16,
                                        ),
                                        const SizedBox(
                                          width: AppTheme.spacingXS,
                                        ),
                                        Expanded(
                                          child: Text(
                                            !_childrenRegistrationOpen &&
                                                    !_adultsRegistrationOpen
                                                ? 'تم الوصول للحد الأقصى من المشاركين في كلا الفرعين'
                                                : !_childrenRegistrationOpen
                                                ? 'تم الوصول للحد الأقصى من المشاركين في فرع الصغار'
                                                : 'تم الوصول للحد الأقصى من المشاركين في فرع الكبار',
                                            style: AppTheme.bodySmall.copyWith(
                                              color: AppTheme.warningColor,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
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
                                          'مرحبا بكم في تطبيق مسابقة أهل القرآن الواتسابية التسجيل غير متاح حاليا',
                                          style: AppTheme.labelLarge.copyWith(
                                            color: Colors.orange,
                                            fontWeight: FontWeight.w600,
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

                      // Section des résultats (toujours visible)
                      ModernCard(
                        child: Padding(
                          padding: const EdgeInsets.all(AppTheme.spacingXS),
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
                                    'نتائج النسخة',
                                    style: AppTheme.labelLarge.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppTheme.spacingXS),
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
                          padding: const EdgeInsets.all(AppTheme.spacingXS),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // const SizedBox(height: AppTheme.spacingS),

                              // Grille des services
                              Column(
                                children: [
                                  // Ligne 1: فوائد قرآنية et أحكام التجويد
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildServiceCard(
                                          title: 'الفوائد القرآنية',
                                          imagePath:
                                              'assets/images/فوائد قرآنية.png',
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
                                          imagePath:
                                              'assets/images/tejweed.png',
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
                                          title: 'أسئلة و أجوبة في القرآن',
                                          imagePath:
                                              'assets/images/أسئلة_وأجوبة_عن_القرآن_الكريم.png',
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
                                          imagePath:
                                              'assets/images/archive.png',
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

                                  // Ligne 3: من نحن et قائمة المشاركين
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildServiceCard(
                                          title: 'من نحن',
                                          imagePath:
                                              'assets/images/about-us.png',
                                          color: Colors.teal,
                                          onTap: () {
                                            context.push(
                                              '/participant/about-us',
                                            );
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: AppTheme.spacingS),
                                      Expanded(
                                        child: _buildServiceCard(
                                          title: 'قائمة المشاركين',
                                          icon: Icons.people,
                                          color: Colors.blue,
                                          onTap: () {
                                            // Utiliser une version par défaut ou la version active
                                            final versionId =
                                                _activeVersion?.id ?? 'default';
                                            context.push(
                                              '/participant/list/$versionId',
                                            );
                                          },
                                        ),
                                      ),
                                    ],
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
                                              'يمكنك الآن الاطلاع على قائمة المشاركين في هذه النسخة النشطة',
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
                                    Container(),
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
    IconData? icon,
    String? imagePath,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 130,
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingS,
          vertical: AppTheme.spacingM,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
          border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (imagePath != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
                child: Image.asset(
                  imagePath,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppTheme.radiusM),
                      ),
                      child:
                          icon != null
                              ? Icon(icon, color: color, size: 24)
                              : const SizedBox.shrink(),
                    );
                  },
                ),
              )
            else if (icon != null)
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
            const SizedBox(height: AppTheme.spacingXS),
            Flexible(
              child: Text(
                title,
                style: AppTheme.labelMedium.copyWith(
                  color: AppTheme.textPrimaryColor,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
