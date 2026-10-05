import 'dart:async';
import '../../../../core/widgets/notification_bell.dart';
import 'package:flutter/material.dart';
import 'package:quranic_competition/core/widgets/logout_dialog.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/competition_version_service.dart';
import '../../../../core/services/eid_session_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_ui.dart';
import '../../../../core/widgets/modern_dashboard.dart';
import '../../../../core/widgets/loading_states.dart';
import '../../../../core/widgets/modern_navigation.dart';
import '../../../../models/competition_version.dart';
import '../../../../models/eid_session.dart';

class ParticipantHomePage extends StatefulWidget {
  const ParticipantHomePage({super.key});

  @override
  State<ParticipantHomePage> createState() => _ParticipantHomePageState();
}

class _ParticipantHomePageState extends State<ParticipantHomePage>
    with WidgetsBindingObserver {
  bool _isLoading = false;
  bool _hasActiveCompetition = false;
  CompetitionVersion? _activeVersion;
  bool _adultsRegistrationOpen = true;
  bool _childrenRegistrationOpen = true;
  bool _isCheckingPlaces = false;
  final _competitionService = CompetitionVersionService();
  final _eidService = EidSessionService();
  StreamSubscription<List<CompetitionVersion>>? _competitionSubscription;
  RealtimeChannel? _registrationChannel;
  RealtimeChannel? _eidSessionChannel;
  EidSession? _activeEidSession;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startListeningToCompetitionChanges();
    _subscribeToRegistrationChanges();
    _loadEidSession();
  }

  /// Le serveur prévient dès qu'une inscription est enregistrée ou qu'une
  /// version change : l'écran se met à jour en moins d'une seconde, sans
  /// attendre la vérification périodique.
  void _subscribeToRegistrationChanges() {
    _unsubscribeFromRegistrationChanges();
    _registrationChannel = _competitionService.subscribeToRegistrationChanges(
      // Rafraîchissement silencieux : pas d'indicateur de chargement, la
      // mise à jour doit passer inaperçue tant qu'elle ne change rien.
      onChange: () => _checkActiveCompetition(showLoader: false),
    );

    // Sans cet abonnement, une فسحة désactivée ou supprimée restait affichée
    // tant que l'application n'était pas relancée ou mise en arrière-plan.
    _eidSessionChannel = _eidService.subscribeToSessionChanges(
      onChange: _loadEidSession,
    );
  }

  void _unsubscribeFromRegistrationChanges() {
    final channel = _registrationChannel;
    if (channel != null) {
      _registrationChannel = null;
      _competitionService.unsubscribe(channel);
    }

    final eidChannel = _eidSessionChannel;
    if (eidChannel != null) {
      _eidSessionChannel = null;
      _eidService.unsubscribe(eidChannel);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Inutile d'interroger la base pendant que l'application est en
    // arrière-plan ; au retour, le flux réémet immédiatement une valeur
    // à jour.
    if (state == AppLifecycleState.resumed) {
      if (_competitionSubscription == null) {
        _startListeningToCompetitionChanges();
        _subscribeToRegistrationChanges();
        _loadEidSession();
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _stopListeningToCompetitionChanges();
      _unsubscribeFromRegistrationChanges();
    }
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
    WidgetsBinding.instance.removeObserver(this);
    _competitionSubscription?.cancel();
    _unsubscribeFromRegistrationChanges();
    super.dispose();
  }

  void _stopListeningToCompetitionChanges() {
    _competitionSubscription?.cancel();
    _competitionSubscription = null;
  }

  void _startListeningToCompetitionChanges() {
    print('🏠 Début de l\'écoute des changements de compétitions');
    _competitionSubscription?.cancel();

    // Le flux émet sa première valeur tout de suite : l'indicateur de
    // chargement ne dure plus que le temps de la requête.
    if (mounted) setState(() => _isLoading = true);

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

  Future<void> _checkActiveCompetition({bool showLoader = true}) async {
    // Utilisée par le tirer-pour-rafraîchir et par les événements temps réel
    if (showLoader && mounted) setState(() => _isLoading = true);
    try {
      final activeVersions =
          await _competitionService.fetchActiveVersionsWithOpenRegistration();
      await _updateCompetitionData(activeVersions);
    } catch (e) {
      print('Erreur lors de la vérification des compétitions: $e');
      if (!mounted) return;
      setState(() {
        _hasActiveCompetition = false;
        _activeVersion = null;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadVersions() async {
    await Future.wait([_checkActiveCompetition(), _loadEidSession()]);
  }

  /// Ouvre le formulaire d'inscription après une vérification fraîche des
  /// places disponibles.
  ///
  /// Garantit qu'on n'envoie jamais quelqu'un remplir un formulaire pour un
  /// groupe déjà complet, même si l'écran affichait une information périmée
  /// (temps réel indisponible, appareil hors ligne un instant...).
  Future<void> _openRegistration(String ageGroup) async {
    final version = _activeVersion;
    if (version == null) return;

    setState(() => _isCheckingPlaces = true);
    try {
      await _checkParticipantLimits(version);
    } finally {
      if (mounted) setState(() => _isCheckingPlaces = false);
    }

    if (!mounted) return;

    final isOpen =
        ageGroup == 'صغار'
            ? _childrenRegistrationOpen
            : _adultsRegistrationOpen;

    if (!isOpen) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('اكتمل العدد في فرع $ageGroup'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }

    context.push(
      '/participant/register',
      extra: {'versionId': version.id, 'ageGroup': ageGroup},
    );
  }

  /// Visiteur : bouton de connexion. Membre connecté : menu « حسابي » donnant
  /// accès au profil (et à la suppression du compte) et à la déconnexion.
  /// Auparavant, ce bouton déconnectait le membre sans prévenir.
  Widget _buildAccountButton() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return IconButton(
        icon: const Icon(Icons.login_rounded),
        tooltip: 'تسجيل الدخول',
        onPressed: () => context.push('/login'),
      );
    }

    return PopupMenuButton<String>(
      icon: const Icon(Icons.account_circle_rounded),
      tooltip: 'حسابي',
      onSelected: (value) async {
        if (value == 'profile') {
          context.push('/profile');
        } else if (value == 'logout') {
          await _confirmLogout();
        }
      },
      itemBuilder:
          (context) => const [
            PopupMenuItem(
              value: 'profile',
              child: ListTile(
                leading: Icon(Icons.person_rounded),
                title: Text('حسابي'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem(
              value: 'logout',
              child: ListTile(
                leading: Icon(Icons.logout_rounded, color: AppTheme.errorColor),
                title: Text('تسجيل الخروج'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
    );
  }

  Future<void> _confirmLogout() async {
    final signedOut = await confirmAndSignOut(context, redirectTo: null);
    // Le menu « حسابي » redevient le bouton de connexion
    if (signedOut && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ModernAppBar(
        title: 'مسابقة أهل القرآن الواتسابية',
        centerTitle: true,
        actions: [const NotificationBell(), _buildAccountButton()],
      ),

      body:
          _isLoading
              ? const ModernLoadingIndicator(
                message: 'جاري تحميل البيانات...',
                size: 50,
              )
              : ModernPullToRefresh(
                onRefresh: _loadVersions,
                child: ListView(
                  // Permet de tirer pour actualiser même si le contenu est court
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  children: [
                    _buildWelcomeHeader(),
                    Padding(
                      padding: const EdgeInsets.all(AppTheme.spacingM),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_activeEidSession != null) ...[
                            _buildEidCard(),
                            const SizedBox(height: AppTheme.spacingM),
                          ],
                          _buildRegistrationSection(),
                          const SizedBox(height: AppTheme.spacingM),
                          AppListCard(
                            margin: EdgeInsets.zero,
                            onTap:
                                () => context.push('/participant_result_page'),
                            leading: const AppIconBadge(
                              icon: Icons.leaderboard_rounded,
                              color: AppTheme.secondaryColor,
                              size: 24,
                            ),
                            title: 'نتائج المسابقة',
                            subtitle: 'عرض النتائج المنشورة لكل نسخة',
                          ),
                          const SizedBox(height: AppTheme.spacingM),
                          _buildServicesSection(),
                          const SizedBox(height: AppTheme.spacingL),
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
        radius: 38,
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Image.asset('assets/images/logos/logo.png'),
        ),
      ),
      title: 'مسابقة أهل القرآن الواتسابية',
      subtitle: 'مرحباً بكم، تعلّم وتنافس في خدمة كتاب الله',
      badges: [
        if (_hasActiveCompetition && _activeVersion != null)
          AppHeaderBadge(
            icon: Icons.emoji_events_rounded,
            text: _activeVersion!.name,
            highlightColor: AppTheme.secondaryColor,
          ),
      ],
    );
  }

  /// Session « فسحة العيد » active
  Widget _buildEidCard() {
    final session = _activeEidSession!;

    return AppGradientHeader(
      shape: AppHeaderShape.card,
      compact: true,
      icon: Icons.celebration_rounded,
      title: session.name,
      subtitle: session.description,
      bottom: ElevatedButton.icon(
        onPressed:
            () => context.push('/participant/eid-session', extra: session),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AppTheme.primaryColor,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
          ),
        ),
        icon: Icon(
          session.isOpen
              ? Icons.person_add_alt_1_rounded
              : Icons.emoji_events_rounded,
        ),
        label: Text(session.isOpen ? 'التسجيل في الفسحة' : 'عرض الفائزين'),
      ),
    );
  }

  Widget _buildRegistrationSection() {
    final hasCompetition = _hasActiveCompetition && _activeVersion != null;

    return AppSection(
      icon: Icons.how_to_reg_rounded,
      title: 'التسجيل في المسابقة',
      subtitle: hasCompetition ? _activeVersion!.name : null,
      child:
          !hasCompetition
              ? const AppNotice(
                text:
                    'مرحباً بكم في تطبيق مسابقة أهل القرآن الواتسابية. التسجيل غير متاح حالياً.',
                color: AppTheme.warningColor,
                icon: Icons.info_rounded,
              )
              : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed:
                              _childrenRegistrationOpen && !_isCheckingPlaces
                                  ? () => _openRegistration('صغار')
                                  : null,
                          style: AppButtonStyles.filled(AppTheme.primaryColor),
                          icon: const Icon(Icons.child_care_rounded),
                          label: const FittedBox(child: Text('فرع الصغار')),
                        ),
                      ),
                      const SizedBox(width: AppTheme.spacingS),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed:
                              _adultsRegistrationOpen && !_isCheckingPlaces
                                  ? () => _openRegistration('كبار')
                                  : null,
                          style: AppButtonStyles.filled(AppTheme.primaryColor),
                          icon: const Icon(Icons.person_rounded),
                          label: const FittedBox(child: Text('فرع الكبار')),
                        ),
                      ),
                    ],
                  ),
                  if (!_childrenRegistrationOpen ||
                      !_adultsRegistrationOpen) ...[
                    const SizedBox(height: AppTheme.spacingS),
                    AppNotice(
                      text:
                          !_childrenRegistrationOpen && !_adultsRegistrationOpen
                              ? 'تم الوصول للحد الأقصى من المشاركين في كلا الفرعين'
                              : !_childrenRegistrationOpen
                              ? 'تم الوصول للحد الأقصى من المشاركين في فرع الصغار'
                              : 'تم الوصول للحد الأقصى من المشاركين في فرع الكبار',
                      color: AppTheme.warningColor,
                      icon: Icons.info_rounded,
                    ),
                  ],
                ],
              ),
    );
  }

  Widget _buildServicesSection() {
    return AppSection(
      icon: Icons.apps_rounded,
      title: 'الخدمات',
      subtitle: 'تعلّم وتابع المسابقة',
      child: QuickActionGrid(
        crossAxisCount: 3,
        childAspectRatio: 0.85,
        actions: [
          QuickAction(
            title: 'الفوائد القرآنية',
            icon: Icons.menu_book_rounded,
            color: AppTheme.primaryColor,
            onTap: () => context.push('/participant/benefits'),
          ),
          QuickAction(
            title: 'أحكام التجويد',
            icon: Icons.record_voice_over_rounded,
            color: AppTheme.secondaryColor,
            onTap: () => context.push('/participant/tajweed'),
          ),
          QuickAction(
            title: 'أسئلة وأجوبة',
            icon: Icons.quiz_rounded,
            color: AppTheme.infoColor,
            onTap: () => context.push('/participant/quiz'),
          ),
          QuickAction(
            title: 'أرشيف المسابقات',
            icon: Icons.photo_library_rounded,
            color: AppTheme.accentColor,
            onTap: () => context.push('/participant/archives'),
          ),
          QuickAction(
            title: 'قائمة المشاركين',
            icon: Icons.groups_rounded,
            color: AppTheme.warningColor,
            // Version active, sinon la dernière version
            onTap:
                () => context.push(
                  '/participant/list/${_activeVersion?.id ?? 'default'}',
                ),
          ),
          QuickAction(
            title: 'من نحن',
            icon: Icons.info_rounded,
            color: AppTheme.textSecondaryColor,
            onTap: () => context.push('/participant/about-us'),
          ),
        ],
      ),
    );
  }
}
