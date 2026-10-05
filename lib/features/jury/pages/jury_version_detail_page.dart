import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quranic_competition/core/services/auth_service.dart';
import 'package:quranic_competition/core/services/evaluation_service.dart';
import 'package:quranic_competition/core/services/participant_service.dart';
import 'package:quranic_competition/core/services/round_service.dart';
import 'package:quranic_competition/core/services/round_jury_service.dart';
import 'package:quranic_competition/models/app_user.dart';
import 'package:quranic_competition/models/jury_evaluation_args.dart';
import 'package:quranic_competition/models/round.dart';
import '../../../models/competition_version.dart';
import '../../../models/participant.dart';
import '../../../core/widgets/modern_navigation.dart';
import '../../../core/widgets/ui_components.dart';
import '../../../core/widgets/loading_states.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_ui.dart';
import 'package:quranic_competition/core/utils/search_utils.dart';

class JuryVersionDetailPage extends StatefulWidget {
  final CompetitionVersion version;

  const JuryVersionDetailPage({super.key, required this.version});

  @override
  State<JuryVersionDetailPage> createState() => _JuryVersionDetailPageState();
}

class _JuryVersionDetailPageState extends State<JuryVersionDetailPage> {
  final ParticipantService _participantService = ParticipantService();
  final EvaluationService _evaluationService = EvaluationService();
  final RoundJuryService _roundJuryService = RoundJuryService();
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

  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadParticipantsWithEvaluationStatus();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadParticipantsWithEvaluationStatus() async {
    setState(() => _isLoading = true);

    AuthService authService = AuthService();
    AppUser? user = await authService.getUserProfile();
    if (user == null) {
      // Gérer erreur utilisateur non connecté
      setState(() => _isLoading = false);
      return;
    }
    setState(() {
      appUser = user;
    });
    final versionId = widget.version.id;
    final juryId = user.id;

    // Récupérer uniquement les rounds assignés à ce jury pour cette version
    try {
      _allRounds = await _roundJuryService.getRoundsByJuryAndVersion(
        juryId,
        versionId,
      );
      print(
        '🔍 Rounds assignés au jury pour la version ${widget.version.name}: ${_allRounds.length}',
      );

      // Si aucun round n'est assigné, afficher un message et retourner
      if (_allRounds.isEmpty) {
        print('⚠️ Aucun round assigné à ce jury pour cette version');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ليس لديك صلاحية للوصول إلى هذه النسخة'),
              backgroundColor: AppTheme.errorColor,
              duration: Duration(seconds: 3),
            ),
          );
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) {
              context.pop();
            }
          });
        }
        setState(() => _isLoading = false);
        return;
      }
    } catch (e) {
      print('❌ Erreur lors du chargement des rounds assignés: $e');
      _allRounds = [];
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('خطأ في تحميل الجولات المعيّنة'),
            backgroundColor: AppTheme.errorColor,
            duration: Duration(seconds: 3),
          ),
        );
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            context.pop();
          }
        });
      }
      setState(() => _isLoading = false);
      return;
    }

    // Initialiser le round sélectionné avec le premier round disponible assigné au jury
    Round? initialSelectedRound;
    if (_allRounds.isNotEmpty) {
      // Trier les rounds par numéro pour avoir Round 1 en premier
      _allRounds.sort((a, b) => a.number.compareTo(b.number));
      initialSelectedRound = _allRounds.first;
      print(
        '🔍 Round initial sélectionné: ${initialSelectedRound.name} (numéro: ${initialSelectedRound.number})',
      );
    }

    // Déterminer le round actif parmi les rounds assignés au jury
    Round? activeRound;
    if (_allRounds.isNotEmpty) {
      try {
        final allRoundsForVersion = await RoundService().getRoundsByVersion(
          versionId,
        );
        final activeRoundForVersion = allRoundsForVersion.firstWhere(
          (r) => r.isActive,
          orElse: () => allRoundsForVersion.first,
        );

        // Vérifier si le round actif est assigné au jury
        if (_allRounds.any((r) => r.id == activeRoundForVersion.id)) {
          activeRound = _allRounds.firstWhere(
            (r) => r.id == activeRoundForVersion.id,
          );
          print(
            '🔍 Round actif détecté parmi les rounds assignés: ${activeRound.name}',
          );
        }
      } catch (e) {
        print('⚠️ Pas de round actif détecté parmi les rounds assignés');
      }
    }

    setState(() {
      this.activeRound = activeRound;
      _selectedRound = initialSelectedRound;
    });
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
    if (_selectedRound == null || appUser == null) return;

    // Ne pas afficher le loading indicator pour un changement rapide de round
    // setState(() => _isLoading = true);

    try {
      final versionId = widget.version.id;
      final juryId = appUser!.id;

      // Vérifier que le round sélectionné est bien assigné au jury (vérification rapide)
      // On peut sauter cette vérification car on sait déjà que _allRounds contient seulement les rounds assignés
      // final isAssigned = await _roundJuryService.isJuryAssignedToRound(
      //   juryId,
      //   _selectedRound!.id,
      // );

      // if (!isAssigned) {
      //   print('⚠️ Le round sélectionné n\'est pas assigné à ce jury');
      //   setState(() => _isLoading = false);
      //   ScaffoldMessenger.of(context).showSnackBar(
      //     const SnackBar(
      //       content: Text('ليس لديك صلاحية للوصول إلى هذه الجولة'),
      //       backgroundColor: AppTheme.errorColor,
      //     ),
      //   );
      //   return;
      // }

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

      // Récupérer évaluations du jury pour cette version (seulement pour le round sélectionné)
      print(
        '🔍 JuryVersionDetailPage - Rechargement des évaluations pour jury: $juryId, version: $versionId, round: ${_selectedRound!.id}',
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
        // Ne pas mettre _isLoading = false car on ne l'a pas mis à true
      });

      print('🔍 Participants rechargés pour le round: ${_selectedRound?.name}');
    } catch (e) {
      // Ne pas mettre _isLoading = false car on ne l'a pas mis à true
      print('❌ Erreur lors du rechargement des participants: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في تحميل المشاركين: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  void _applyFilter() {
    final searchQuery = _searchQuery.trim();
    final hasSearch = searchQuery.isNotEmpty;

    // Toujours filtrer par groupe d'âge sélectionné
    List<Participant> filtered =
        _allParticipants.where((p) => p.ageGroup == _selectedAgeGroup).toList();

    // Filtrer par statut d'évaluation
    if (_selectedEvaluationStatus == 'evaluated') {
      filtered = filtered.where((p) => p.isEvaluated).toList();
    } else if (_selectedEvaluationStatus == 'notEvaluated') {
      filtered = filtered.where((p) => !p.isEvaluated).toList();
    }

    // Filtrer par recherche (رقم التسجيل فقط)
    if (hasSearch) {
      final digits = SearchUtils.normalizeDigits(
        searchQuery,
      ).replaceAll(RegExp(r'\D'), '');
      // Correspondance exacte : "4" ne doit pas afficher 14, 40, 404...
      filtered =
          filtered
              .where(
                (p) =>
                    digits.isNotEmpty &&
                    SearchUtils.numberMatches(p.registrationNumber, digits),
              )
              .toList();
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

  bool get _isReadOnly =>
      _selectedRound != null &&
      (!_selectedRound!.isActive || _selectedRound!.resultIsPublished);

  Future<void> _openParticipant(Participant participant) async {
    // Évaluation non autorisée par l'administration
    if (!widget.version.juryEvaluationEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'التقييم غير مسموح به حالياً - يرجى انتظار إذن المسؤول',
          ),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }
    if (appUser == null || _selectedRound == null) return;

    final result = await context.push(
      '/jury/participant',
      extra: JuryEvaluationArgs(
        participant: participant,
        appUser: appUser!,
        version: widget.version,
        // Lecture seule si le tour n'est pas actif ou s'il est publié
        isReadOnly: _isReadOnly,
        round: _selectedRound!,
      ),
    );

    if (mounted && result == true) await _loadParticipantsForSelectedRound();
  }

  int _countFor({String? status}) {
    return _allParticipants.where((p) {
      if (p.ageGroup != _selectedAgeGroup) return false;
      if (status == 'evaluated') return p.isEvaluated;
      if (status == 'notEvaluated') return !p.isEvaluated;
      return true;
    }).length;
  }

  // ---------------------------------------------------------------------------
  // Interface
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ModernAppBar(title: widget.version.name),
      body:
          _isLoading
              ? const ModernLoadingIndicator()
              : ModernPullToRefresh(
                onRefresh: _loadParticipantsWithEvaluationStatus,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.all(AppTheme.spacingM),
                  children: [
                    _buildRoundHeader(),
                    const SizedBox(height: AppTheme.spacingM),
                    ..._buildNotices(),
                    _buildFilters(),
                    const SizedBox(height: AppTheme.spacingM),
                    if (_filteredParticipants.isEmpty)
                      EmptyState(
                        icon:
                            _searchQuery.isNotEmpty
                                ? Icons.search_off_rounded
                                : Icons.people_outline_rounded,
                        title:
                            _allParticipants.isEmpty
                                ? 'لا يوجد مشاركون'
                                : 'لا يوجد مشاركون في هذا الاختيار',
                        subtitle:
                            _allParticipants.isEmpty
                                ? 'لا يوجد مشاركون مسجلون في هذه الجولة'
                                : 'جرب تغيير الفلاتر',
                      )
                    else
                      ..._filteredParticipants.map(_buildParticipantCard),
                  ],
                ),
              ),
    );
  }

  /// En-tête : tour sélectionné, son mode et la progression du فرع
  Widget _buildRoundHeader() {
    final round = _selectedRound;
    final total = _countFor();
    final evaluated = _countFor(status: 'evaluated');

    final String mode;
    if (round == null) {
      mode = 'لا توجد جولة محددة';
    } else if (round.resultIsPublished) {
      mode = 'النتائج منشورة - قراءة فقط';
    } else if (round.isActive) {
      mode = 'جولة نشطة - يمكن التقييم';
    } else {
      mode = 'جولة متوقفة - لا يمكن التعديل';
    }

    return AppGradientHeader(
      shape: AppHeaderShape.card,
      compact: true,
      icon: Icons.flag_rounded,
      title:
          round != null
              ? 'الجولة ${round.number} - ${round.name ?? ''}'
              : 'لا توجد جولات متاحة',
      subtitle: mode,
      bottom: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Sélecteur de tour (si plusieurs tours sont assignés)
          if (_allRounds.length > 1) ...[
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingS,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: round?.id ?? _allRounds.first.id,
                  isExpanded: true,
                  items: [
                    for (final r in _allRounds)
                      DropdownMenuItem(
                        value: r.id,
                        child: Text(
                          'الجولة ${r.number} - ${r.name ?? ''}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (id) {
                    final match = _allRounds.where((r) => r.id == id);
                    if (match.isEmpty || id == _selectedRound?.id) return;
                    setState(() => _selectedRound = match.first);
                    _loadParticipantsForSelectedRound();
                  },
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacingS),
          ],
          AppHeaderProgress(
            value: total > 0 ? evaluated / total : 0,
            label: 'تقدم التقييم',
            trailingText: '$evaluated / $total',
          ),
        ],
      ),
    );
  }

  List<Widget> _buildNotices() {
    final notices = <Widget>[];

    // Évaluation pas encore autorisée (et résultats non publiés)
    if (!widget.version.juryEvaluationEnabled &&
        (_selectedRound == null || !_selectedRound!.resultIsPublished)) {
      notices.add(
        const AppNotice(
          text: 'التقييم غير مسموح به حالياً، يرجى انتظار إذن المسؤول.',
          color: AppTheme.errorColor,
          icon: Icons.block_rounded,
        ),
      );
    } else if (widget.version.juryEvaluationEnabled &&
        _allParticipants.isNotEmpty &&
        !_areAllGroupParticipantsEvaluated()) {
      notices.add(
        AppNotice(
          text:
              'يجب تقييم جميع المشاركين في فرع ${_selectedAgeGroup == 'كبار' ? 'الكبار' : 'الصغار'} قبل إرسال التصحيح.',
          color: AppTheme.warningColor,
          icon: Icons.pending_actions_rounded,
        ),
      );
    }

    return [
      for (final notice in notices) ...[
        notice,
        const SizedBox(height: AppTheme.spacingM),
      ],
    ];
  }

  Widget _buildFilters() {
    Widget chip(String label, String value) {
      return Padding(
        padding: const EdgeInsetsDirectional.only(end: AppTheme.spacingXS),
        child: ChoiceChip(
          label: Text(label),
          selected: _selectedEvaluationStatus == value,
          visualDensity: VisualDensity.compact,
          onSelected:
              (_) => setState(() {
                _selectedEvaluationStatus = value;
                _applyFilter();
              }),
        ),
      );
    }

    return AppSection(
      icon: Icons.filter_list_rounded,
      title: 'المشاركون',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'كبار', label: Text('الكبار')),
              ButtonSegment(value: 'صغار', label: Text('الصغار')),
            ],
            selected: {_selectedAgeGroup},
            showSelectedIcon: false,
            onSelectionChanged:
                (value) => setState(() {
                  _selectedAgeGroup = value.first;
                  _applyFilter();
                }),
          ),
          const SizedBox(height: AppTheme.spacingS),
          Wrap(
            children: [
              chip('الكل (${_countFor()})', 'all'),
              chip('مقيم (${_countFor(status: 'evaluated')})', 'evaluated'),
              chip(
                'غير مقيم (${_countFor(status: 'notEvaluated')})',
                'notEvaluated',
              ),
            ],
          ),
          ModernSearchBar(
            controller: _searchController,
            hintText: 'ابحث برقم التسجيل...',
            margin: const EdgeInsets.only(top: AppTheme.spacingS),
            onChanged:
                (value) => setState(() {
                  _searchQuery = value;
                  _applyFilter();
                }),
            // L'effacement réapplique le filtre (la liste restait filtrée)
            onClear:
                () => setState(() {
                  _searchQuery = '';
                  _applyFilter();
                }),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantCard(Participant participant) {
    final allowed = widget.version.juryEvaluationEnabled;

    final String status;
    final Color color;
    final IconData icon;
    if (!allowed) {
      status = 'التقييم غير متاح';
      color = AppTheme.textSecondaryColor;
      icon = Icons.block_rounded;
    } else if (participant.isEvaluated) {
      status = 'تم التقييم';
      color = AppTheme.successColor;
      icon = Icons.check_circle_rounded;
    } else if (_isReadOnly) {
      status = 'قراءة فقط';
      color = AppTheme.infoColor;
      icon = Icons.visibility_rounded;
    } else {
      status = 'بانتظار التقييم';
      color = AppTheme.warningColor;
      icon = Icons.edit_rounded;
    }

    return AppListCard(
      onTap: () => _openParticipant(participant),
      highlightColor:
          allowed && !participant.isEvaluated && !_isReadOnly
              ? AppTheme.warningColor
              : null,
      leading: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
        ),
        child: Center(
          child: FittedBox(
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Text(
                participant.registrationNumber?.toString() ?? '?',
                style: AppTheme.headingSmall.copyWith(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
      title: 'المشارك رقم ${participant.registrationNumber ?? '?'}',
      tags: [
        AppTag(text: status, color: color, icon: icon),
        AppTag(
          text: participant.ageGroup == 'كبار' ? 'الكبار' : 'الصغار',
          color: AppTheme.secondaryColor,
          icon: Icons.people_rounded,
        ),
        if (_isReadOnly)
          const AppTag(
            text: 'مقفلة',
            color: AppTheme.textSecondaryColor,
            icon: Icons.lock_outline_rounded,
          ),
      ],
    );
  }
}
