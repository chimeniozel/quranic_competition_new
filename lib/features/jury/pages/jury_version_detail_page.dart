import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quranic_competition/core/services/auth_service.dart';
import 'package:quranic_competition/core/services/evaluation_service.dart';
import 'package:quranic_competition/core/services/participant_service.dart';
import 'package:quranic_competition/core/services/round_service.dart';
import 'package:quranic_competition/models/app_user.dart';
import 'package:quranic_competition/models/jury_evaluation_args.dart';
import 'package:quranic_competition/models/round.dart';
import '../../../models/competition_version.dart';
import '../../../models/participant.dart';
import '../../../core/widgets/modern_navigation.dart';
import '../../../core/widgets/ui_components.dart';
import '../../../core/widgets/loading_states.dart';
import '../../../core/theme/app_theme.dart';

class JuryVersionDetailPage extends StatefulWidget {
  final CompetitionVersion version;

  const JuryVersionDetailPage({super.key, required this.version});

  @override
  State<JuryVersionDetailPage> createState() => _JuryVersionDetailPageState();
}

class _JuryVersionDetailPageState extends State<JuryVersionDetailPage> {
  final ParticipantService _participantService = ParticipantService();
  final EvaluationService _evaluationService = EvaluationService();
  final TextEditingController _searchController = TextEditingController();

  List<Participant> _allParticipants = [];
  List<Participant> _filteredParticipants = [];
  String _selectedAgeGroup = 'كبار';
  String _selectedEvaluationStatus = 'all'; // all, evaluated, notEvaluated
  bool _isLoading = false;
  AppUser? appUser;
  Round? activeRound;
  Round? _selectedRound;
  List<Round> _allRounds = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_applyFilter);
    _loadParticipantsWithEvaluationStatus();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadParticipantsWithEvaluationStatus() async {
    setState(() => _isLoading = true);

    // Récupérer tous les rounds pour cette version de compétition
    try {
      _allRounds = await RoundService().getRoundsByVersion(widget.version.id);
      print(
        '🔍 Rounds trouvés pour la version ${widget.version.name}: ${_allRounds.length}',
      );
    } catch (e) {
      print('❌ Erreur lors du chargement des rounds: $e');
      _allRounds = [];
    }

    // Initialiser le round sélectionné avec le premier round disponible de cette version
    Round? initialSelectedRound;
    if (_allRounds.isNotEmpty) {
      // Trier les rounds par numéro pour avoir Round 1 en premier
      _allRounds.sort((a, b) => a.number.compareTo(b.number));
      initialSelectedRound = _allRounds.first;
      print(
        '🔍 Round initial sélectionné: ${initialSelectedRound.name} (numéro: ${initialSelectedRound.number})',
      );
    }

    // Déterminer le round actif pour affichage (optionnel)
    Round? activeRound;
    try {
      activeRound = await RoundService().getActiveRound(widget.version.id);
      print('🔍 Round actif détecté: ${activeRound?.name}');
    } catch (e) {
      print('⚠️ Pas de round actif détecté');
    }

    setState(() {
      this.activeRound = activeRound;
      _selectedRound = initialSelectedRound;
    });

    AuthService authService = AuthService();
    AppUser? user = await authService.getUserProfile();
    if (user == null) {
      // Gérer erreur utilisateur non connecté
      return;
    }
    setState(() {
      appUser = user;
    });
    final versionId = widget.version.id;
    final juryId = user.id;
    print(
      'RoundId sélectionné (normalisé): "${_selectedRound?.id.trim().toLowerCase()}"',
    );

    // 1. Récupérer participants liés au round sélectionné
    List<Participant> participants = [];

    if (_selectedRound != null) {
      participants = await _participantService
          .fetchParticipantsByVersionAndRounds(
            versionId,
            activeRound: _selectedRound,
          );

      // Filtrer selon le numéro du round
      if (_selectedRound!.number == 1) {
        // Round 1 : Afficher seulement les participants acceptés
        participants = participants.where((p) => p.isAccepted == true).toList();
        print('🔍 Round 1 - Participants acceptés: ${participants.length}');
      } else if (_selectedRound!.number >= 2) {
        // Round 2+ : Afficher les participants acceptés ET qui ont passé le round précédent
        // Le service fetchParticipantsByVersionAndRounds s'occupe déjà de récupérer
        // les participants qui ont passé le round précédent
        participants = participants.where((p) => p.isAccepted == true).toList();
        print(
          '🔍 Round ${_selectedRound!.number} - Participants acceptés et qualifiés: ${participants.length}',
        );
      }
    } else {
      // Si pas de round sélectionné, récupérer tous les participants de la version
      try {
        participants = await _participantService
            .fetchParticipantsByVersionAndRounds(versionId);
        // Filtrer seulement les participants acceptés
        participants = participants.where((p) => p.isAccepted == true).toList();
      } catch (e) {
        print('❌ Erreur lors du chargement des participants: $e');
        participants = [];
      }
    }

    print('🔍 Participants récupérés du service: ${participants.length}');
    print(
      '🔍 Round sélectionné: ${_selectedRound?.id} - ${_selectedRound?.name}',
    );

    // 2. Récupérer évaluations du jury pour cette version
    print(
      '🔍 JuryVersionDetailPage - Récupération des évaluations pour jury: $juryId, version: $versionId',
    );
    final evaluationsResponse = await _evaluationService
        .getEvaluationsByJuryInVersion(juryId: juryId, versionId: versionId);
    print(
      '🔍 JuryVersionDetailPage - Évaluations récupérées: ${evaluationsResponse.length}',
    );

    // Affichage debug des roundId des évaluations récupérées
    for (final eval in evaluationsResponse) {
      print(
        'Evaluation roundId (normalisé): "${eval.roundId.trim().toLowerCase()}"',
      );
    }

    final normalizedRoundId = _selectedRound?.id.trim().toLowerCase();

    // 3. Construire set des participantIds évalués pour le round sélectionné (comparaison normalisée)
    final Set<String> evaluatedParticipantIds =
        evaluationsResponse
            .where(
              (eval) =>
                  (eval.roundId.trim().toLowerCase()) ==
                  (normalizedRoundId ?? ''),
            )
            .map((e) => e.participantId)
            .toSet();

    // 4. Marquer participants évalués
    final participantsWithStatus =
        participants.map((p) {
          p.isEvaluated = evaluatedParticipantIds.contains(p.id);
          print(
            'Participant #${p.registrationNumber} isEvaluated: ${p.isEvaluated}',
          );
          return p;
        }).toList();

    print('📊 Participants chargés: ${participantsWithStatus.length}');
    print(
      '📊 Participants évalués: ${participantsWithStatus.where((p) => p.isEvaluated).length}',
    );

    setState(() {
      appUser = user;
      _allParticipants = participantsWithStatus;
      _applyFilter();
      _isLoading = false;
    });
  }

  Future<void> _loadParticipantsForSelectedRound() async {
    if (_selectedRound == null) return;

    setState(() => _isLoading = true);

    try {
      final versionId = widget.version.id;
      final juryId = appUser?.id ?? '';

      // Récupérer participants pour le round sélectionné
      var participants = await _participantService
          .fetchParticipantsByVersionAndRounds(
            versionId,
            activeRound: _selectedRound,
          );

      // Filtrer selon le numéro du round
      if (_selectedRound!.number == 1) {
        // Round 1 : Afficher seulement les participants acceptés
        participants = participants.where((p) => p.isAccepted == true).toList();
        print(
          '🔍 Round 1 - Participants acceptés rechargés: ${participants.length}',
        );
      } else if (_selectedRound!.number >= 2) {
        // Round 2+ : Afficher les participants acceptés ET qui ont passé le round précédent
        participants = participants.where((p) => p.isAccepted == true).toList();
        print(
          '🔍 Round ${_selectedRound!.number} - Participants acceptés et qualifiés rechargés: ${participants.length}',
        );
      }

      // Récupérer évaluations du jury pour cette version
      print(
        '🔍 JuryVersionDetailPage - Rechargement des évaluations pour jury: $juryId, version: $versionId',
      );
      final evaluationsResponse = await _evaluationService
          .getEvaluationsByJuryInVersion(juryId: juryId, versionId: versionId);
      print(
        '🔍 JuryVersionDetailPage - Évaluations rechargées: ${evaluationsResponse.length}',
      );

      final normalizedRoundId = _selectedRound?.id.trim().toLowerCase();

      // Construire set des participantIds évalués pour le round sélectionné
      final Set<String> evaluatedParticipantIds =
          evaluationsResponse
              .where(
                (eval) =>
                    (eval.roundId.trim().toLowerCase()) ==
                    (normalizedRoundId ?? ''),
              )
              .map((e) => e.participantId)
              .toSet();

      // Marquer participants évalués
      final participantsWithStatus =
          participants.map((p) {
            p.isEvaluated = evaluatedParticipantIds.contains(p.id);
            return p;
          }).toList();

      setState(() {
        _allParticipants = participantsWithStatus;
        _applyFilter();
        _isLoading = false;
      });

      print('🔍 Participants rechargés pour le round: ${_selectedRound?.name}');
    } catch (e) {
      setState(() => _isLoading = false);
      print('❌ Erreur lors du rechargement des participants: $e');
    }
  }

  void _applyFilter() {
    List<Participant> filtered = _allParticipants;

    // Filtrer par groupe d'âge
    filtered = filtered.where((p) => p.ageGroup == _selectedAgeGroup).toList();

    // Filtrer par statut d'évaluation
    if (_selectedEvaluationStatus == 'evaluated') {
      filtered = filtered.where((p) => p.isEvaluated).toList();
    } else if (_selectedEvaluationStatus == 'notEvaluated') {
      filtered = filtered.where((p) => !p.isEvaluated).toList();
    }
    // Si 'all', on garde tous les participants du groupe d'âge

    // Filtrer par recherche si nécessaire
    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      filtered =
          filtered.where((p) {
            // Recherche par nom
            final nameMatch = p.fullName.toLowerCase().contains(query);
            // Recherche par numéro d'enregistrement
            final numberMatch =
                p.registrationNumber?.toString().contains(query) ?? false;
            // Recherche par téléphone
            final phoneMatch = p.phone.toLowerCase().contains(query);

            return nameMatch || numberMatch || phoneMatch;
          }).toList();
    }

    print(
      '🔍 Filtrage: ${filtered.length} participants après filtrage (groupe: $_selectedAgeGroup, statut: $_selectedEvaluationStatus)',
    );

    setState(() {
      _filteredParticipants = filtered;
    });
  }

  /// Vérifier si tous les participants du groupe d'âge sélectionné ont été évalués
  bool _areAllGroupParticipantsEvaluated() {
    // Récupérer tous les participants du groupe d'âge sélectionné (sans filtre de recherche)
    final groupParticipants =
        _allParticipants.where((p) => p.ageGroup == _selectedAgeGroup).toList();

    if (groupParticipants.isEmpty) return false;

    // Vérifier si tous sont évalués
    final allEvaluated = groupParticipants.every((p) => p.isEvaluated);

    print(
      '🔍 Vérification évaluation groupe $_selectedAgeGroup: ${groupParticipants.where((p) => p.isEvaluated).length}/${groupParticipants.length} évalués',
    );

    return allEvaluated;
  }

  Widget _buildParticipantStatusIcon(Participant participant) {
    // Si l'évaluation n'est pas autorisée
    if (!widget.version.juryEvaluationEnabled) {
      return Icon(Icons.block, color: AppTheme.errorColor, size: 28);
    }

    // Déterminer l'icône et la couleur selon le statut
    final isReadOnly =
        _selectedRound != null &&
        (!_selectedRound!.isActive || _selectedRound!.resultIsPublished);

    IconData icon;
    Color color;

    if (participant.isEvaluated) {
      icon = Icons.check_circle;
      color = AppTheme.successColor;
    } else if (isReadOnly) {
      icon = Icons.visibility;
      color = AppTheme.infoColor;
    } else {
      icon = Icons.edit;
      color = AppTheme.warningColor;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 28),
        if (isReadOnly) ...[
          const SizedBox(width: AppTheme.spacingS),
          Icon(
            Icons.lock_outline,
            color: AppTheme.textSecondaryColor,
            size: 16,
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ModernAppBar(
        title:
            activeRound != null
                ? '${widget.version.name} - ${activeRound!.name}'
                : widget.version.name,
      ),
      floatingActionButton:
          // Afficher le bouton seulement si :
          // 1. L'évaluation est autorisée (jury_evaluation_enabled == true)
          // 2. Il y a des participants
          // 3. Tous les participants du groupe sont évalués
          _filteredParticipants.isEmpty ||
                  !widget.version.juryEvaluationEnabled ||
                  !_areAllGroupParticipantsEvaluated()
              ? null
              : Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingS,
                  vertical: AppTheme.spacingS,
                ),
                margin: const EdgeInsets.only(right: AppTheme.spacingL),
                child: SizedBox(
                  width: double.infinity,
                  child: PrimaryButton(
                    text: 'حفظ التصحيح',
                    icon: Icons.send,
                    backgroundColor: AppTheme.successColor,
                    onPressed: () async {
                      if (appUser == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text(
                              "لم يتم العثور على حساب المستخدم",
                            ),
                            backgroundColor: AppTheme.errorColor,
                          ),
                        );
                        return;
                      }

                      final EvaluationService evaluationService =
                          EvaluationService();

                      final juryId = appUser?.id ?? '';

                      // Récupérer toutes les évaluations faites par ce jury dans cette version
                      print(
                        '🔍 JuryVersionDetailPage - Export des évaluations pour jury: $juryId, version: ${widget.version.id}',
                      );
                      final evaluations = await evaluationService
                          .getEvaluationsByJuryInVersion(
                            juryId: juryId,
                            versionId: widget.version.id,
                          );
                      print(
                        '🔍 JuryVersionDetailPage - Évaluations pour export: ${evaluations.length}',
                      );

                      await EvaluationService.exportEvaluatedParticipantsLocally(
                        context: context,
                        evaluations: evaluations,
                        participants: _filteredParticipants,
                        version: widget.version,
                        roundName: _selectedRound?.name ?? 'Round',
                        juryName: appUser!.fullName,
                        ageGroup: _selectedAgeGroup,
                      );
                    },
                  ),
                ),
              ),

      /*FloatingActionButton(
        child: 
        
        Container(
          padding: const EdgeInsets.all(8),
          child: const Text("النتائج"),
        ),
        onPressed: () async {
          await EvaluationService.exportEvaluatedParticipantsLocally(
            participants: _allParticipants,
            version: widget.version,
            roundName: activeRound!.name!,
            juryName: appUser!.fullName,
            ageGroup: _selectedAgeGroup,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('✅ تم تصدير الملف إلى Supabase')),
          );
        },
      ),*/
      body:
          _isLoading
              ? const ModernLoadingIndicator()
              : ModernPullToRefresh(
                onRefresh: _loadParticipantsWithEvaluationStatus,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppTheme.spacingS),
                  child: Column(
                    children: [
                      // Message d'autorisation d'évaluation
                      if (!widget.version.juryEvaluationEnabled)
                        ModernCard(
                          backgroundColor: AppTheme.errorColor.withOpacity(0.1),
                          child: Row(
                            children: [
                              Icon(
                                Icons.block,
                                color: AppTheme.errorColor,
                                size: 28,
                              ),
                              const SizedBox(width: AppTheme.spacingS),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'التقييم غير مسموح به',
                                      style: AppTheme.headingSmall.copyWith(
                                        color: AppTheme.errorColor,
                                      ),
                                    ),
                                    const SizedBox(height: AppTheme.spacingXS),
                                    Text(
                                      'يرجى انتظار إذن المسؤول لبدء التقييم',
                                      style: AppTheme.bodyMedium.copyWith(
                                        color: AppTheme.errorColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Message d'avertissement si le groupe n'est pas complètement évalué
                      if (!_areAllGroupParticipantsEvaluated() &&
                          widget.version.juryEvaluationEnabled &&
                          _allParticipants.isNotEmpty)
                        ModernCard(
                          backgroundColor: AppTheme.warningColor.withOpacity(
                            0.1,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.pending_actions,
                                color: AppTheme.warningColor,
                                size: 24,
                              ),
                              const SizedBox(width: AppTheme.spacingS),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'التقييم غير مكتمل',
                                      style: AppTheme.labelLarge.copyWith(
                                        color: AppTheme.warningColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: AppTheme.spacingXS),
                                    Text(
                                      'يجب تقييم جميع المشاركين في فئة $_selectedAgeGroup قبل إرسال التصحيح',
                                      style: AppTheme.bodySmall.copyWith(
                                        color: AppTheme.warningColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Indicateur de mode d'affichage
                      _buildDisplayModeIndicator(),

                      // Dropdown pour sélectionner le round
                      _buildRoundSelector(),

                      // Champ de recherche
                      ModernCard(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'البحث برقم التسجيل أو الهاتف...',
                            hintStyle: AppTheme.bodyMedium.copyWith(
                              color: AppTheme.textDisabledColor,
                            ),
                            prefixIcon: Icon(
                              Icons.search,
                              color: AppTheme.primaryColor,
                            ),
                            border: InputBorder.none,
                            filled: false,
                          ),
                          style: AppTheme.bodyMedium,
                        ),
                      ),

                      // Filtres : Groupe d'âge et Statut d'évaluation
                      Row(
                        children: [
                          Expanded(
                            child: ModernCard(
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.people,
                                    color: AppTheme.primaryColor,
                                    size: 20,
                                  ),
                                  const SizedBox(width: AppTheme.spacingS),
                                  Expanded(
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: _selectedAgeGroup,
                                        isExpanded: true,
                                        items:
                                            ['كبار', 'صغار'].map((group) {
                                              return DropdownMenuItem(
                                                value: group,
                                                child: Text(
                                                  group,
                                                  style: AppTheme.bodyMedium,
                                                ),
                                              );
                                            }).toList(),
                                        onChanged: (value) {
                                          if (value != null) {
                                            setState(() {
                                              _selectedAgeGroup = value;
                                              _applyFilter();
                                            });
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: AppTheme.spacingS),
                          Expanded(
                            child: ModernCard(
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.filter_list,
                                    color: AppTheme.primaryColor,
                                    size: 20,
                                  ),
                                  const SizedBox(width: AppTheme.spacingS),
                                  Expanded(
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: _selectedEvaluationStatus,
                                        isExpanded: true,
                                        items: [
                                          DropdownMenuItem(
                                            value: 'all',
                                            child: Text(
                                              'الكل',
                                              style: AppTheme.bodyMedium,
                                            ),
                                          ),
                                          DropdownMenuItem(
                                            value: 'evaluated',
                                            child: Text(
                                              'مقيم',
                                              style: AppTheme.bodyMedium,
                                            ),
                                          ),
                                          DropdownMenuItem(
                                            value: 'notEvaluated',
                                            child: Text(
                                              'غير مقيم',
                                              style: AppTheme.bodyMedium,
                                            ),
                                          ),
                                        ],
                                        onChanged: (value) {
                                          if (value != null) {
                                            setState(() {
                                              _selectedEvaluationStatus = value;
                                              _applyFilter();
                                            });
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      // Liste des participants filtrés
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.5,
                        child:
                            _filteredParticipants.isEmpty
                                ? EmptyState(
                                  icon: Icons.people_outline,
                                  title:
                                      _allParticipants.isEmpty
                                          ? 'لا يوجد مشاركون'
                                          : 'لا يوجد مشاركون في هذه الفئة',
                                  subtitle:
                                      _allParticipants.isEmpty
                                          ? 'لا توجد مشاركون مسجلون في هذه النسخة'
                                          : 'جرب تغيير الفلاتر',
                                )
                                : ListView.builder(
                                  itemCount: _filteredParticipants.length,
                                  itemBuilder: (context, index) {
                                    final participant =
                                        _filteredParticipants[index];
                                    return Container(
                                      margin: const EdgeInsets.only(
                                        bottom: AppTheme.spacingS,
                                      ),
                                      child: ModernCard(
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(
                                            AppTheme.radiusM,
                                          ),
                                          onTap: () async {
                                            // Vérifier si l'évaluation est autorisée
                                            if (!widget
                                                .version
                                                .juryEvaluationEnabled) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Row(
                                                    children: [
                                                      Icon(
                                                        Icons.block,
                                                        color: Colors.white,
                                                      ),
                                                      SizedBox(width: 8),
                                                      Expanded(
                                                        child: Text(
                                                          'التقييم غير مسموح به حالياً - يرجى انتظار إذن المسؤول',
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  backgroundColor:
                                                      Colors.red.shade600,
                                                  duration: Duration(
                                                    seconds: 3,
                                                  ),
                                                ),
                                              );
                                              return;
                                            }

                                            if (appUser != null &&
                                                _selectedRound != null) {
                                              // Déterminer si on est en mode lecture seule
                                              // Lecture seule si le round n'est pas actif OU s'il est publié
                                              final isReadOnly =
                                                  !_selectedRound!.isActive ||
                                                  _selectedRound!
                                                      .resultIsPublished;

                                              final result = await context.push(
                                                '/jury/participant',
                                                extra: JuryEvaluationArgs(
                                                  participant: participant,
                                                  appUser: appUser!,
                                                  version: widget.version,
                                                  isReadOnly: isReadOnly,
                                                  round: _selectedRound!,
                                                ),
                                              );

                                              if (!mounted) return;

                                              if (result == true) {
                                                if (_selectedRound != null) {
                                                  await _loadParticipantsForSelectedRound();
                                                } else {
                                                  await _loadParticipantsWithEvaluationStatus();
                                                }
                                              }
                                            }
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.all(
                                              AppTheme.spacingS,
                                            ),
                                            child: Row(
                                              children: [
                                                // Avatar
                                                CircleAvatar(
                                                  radius: 24,
                                                  backgroundColor: AppTheme
                                                      .primaryColor
                                                      .withOpacity(0.1),
                                                  child: Text(
                                                    participant
                                                            .registrationNumber
                                                            ?.toString() ??
                                                        '?',
                                                    style: AppTheme.labelLarge
                                                        .copyWith(
                                                          color:
                                                              AppTheme
                                                                  .primaryColor,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                  ),
                                                ),
                                                const SizedBox(
                                                  width: AppTheme.spacingS,
                                                ),
                                                // Informations
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        'المشارك رقم ${participant.registrationNumber}',
                                                        style: AppTheme
                                                            .labelLarge
                                                            .copyWith(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                      ),
                                                      const SizedBox(
                                                        height:
                                                            AppTheme.spacingXS,
                                                      ),
                                                      Text(
                                                        'الفئة: ${participant.ageGroup}',
                                                        style:
                                                            AppTheme.bodyMedium,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                // Icône de statut
                                                _buildParticipantStatusIcon(
                                                  participant,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                      ),
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _buildRoundSelector() {
    if (_allRounds.isEmpty) {
      return ModernCard(
        backgroundColor: AppTheme.textSecondaryColor.withOpacity(0.1),
        child: Row(
          children: [
            Icon(Icons.info, color: AppTheme.textSecondaryColor, size: 24),
            const SizedBox(width: AppTheme.spacingS),
            Expanded(
              child: Text(
                'لا توجد جولات متاحة',
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.textSecondaryColor,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Vérifier que la valeur sélectionnée existe dans la liste
    Round? validSelectedRound = _selectedRound;
    if (_selectedRound != null) {
      final exists = _allRounds.any((round) => round.id == _selectedRound!.id);
      if (!exists) {
        validSelectedRound = _allRounds.first;
        setState(() {
          _selectedRound = validSelectedRound;
        });
      }
    } else {
      validSelectedRound = _allRounds.first;
      setState(() {
        _selectedRound = validSelectedRound;
      });
    }

    return ModernCard(
      child: Row(
        children: [
          Icon(Icons.event, color: AppTheme.primaryColor, size: 24),
          const SizedBox(width: AppTheme.spacingS),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<Round>(
                value: validSelectedRound,
                isExpanded: true,
                hint: Text('اختر الجولة', style: AppTheme.bodyMedium),
                items:
                    _allRounds.map((round) {
                      final isActive = round.isActive;
                      final isPublished = round.resultIsPublished;
                      Color statusColor =
                          isActive
                              ? AppTheme.warningColor
                              : isPublished
                              ? AppTheme.infoColor
                              : AppTheme.textSecondaryColor;

                      return DropdownMenuItem<Round>(
                        value: round,
                        child: Row(
                          children: [
                            Icon(
                              isActive
                                  ? Icons.play_circle
                                  : isPublished
                                  ? Icons.visibility
                                  : Icons.pause_circle,
                              color: statusColor,
                              size: 16,
                            ),
                            const SizedBox(width: AppTheme.spacingS),
                            Expanded(
                              child: Text(
                                round.name.toString(),
                                style: AppTheme.bodyMedium.copyWith(
                                  color: statusColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                onChanged: (Round? newRound) {
                  if (newRound != null && newRound.id != _selectedRound?.id) {
                    setState(() {
                      _selectedRound = newRound;
                    });
                    _loadParticipantsForSelectedRound();
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisplayModeIndicator() {
    String title = '';
    String subtitle = '';
    Color color = AppTheme.infoColor;
    IconData icon = Icons.info;

    // Déterminer le mode basé sur le round sélectionné
    final isActive = _selectedRound != null && _selectedRound!.isActive;
    final isPublished =
        _selectedRound != null && _selectedRound!.resultIsPublished;

    if (_selectedRound != null) {
      title = '${_selectedRound!.name}';
      if (isActive && !isPublished) {
        title += ' (نشطة)';
        subtitle = 'يمكن تقييم المشاركين في هذه الجولة';
        color = AppTheme.warningColor;
        icon = Icons.edit;
      } else if (isPublished) {
        title += ' (تم نشر النتائج)';
        subtitle = 'عرض النتائج - وضع القراءة فقط';
        color = AppTheme.infoColor;
        icon = Icons.visibility;
      } else {
        subtitle = 'عرض النتائج - لا يمكن التعديل';
        color = AppTheme.textSecondaryColor;
        icon = Icons.pause_circle;
      }
    } else {
      title = 'لا توجد جولة محددة';
      subtitle = 'اختر جولة لعرض المشاركين';
      color = AppTheme.textSecondaryColor;
      icon = Icons.info;
    }

    return ModernCard(
      backgroundColor: color.withOpacity(0.1),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: AppTheme.spacingS),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTheme.labelLarge.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingXS),
                Text(
                  subtitle,
                  style: AppTheme.bodySmall.copyWith(color: color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
