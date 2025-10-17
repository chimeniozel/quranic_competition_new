import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quranic_competition/core/services/evaluation_service.dart';
import 'package:quranic_competition/models/competition_version.dart';
import 'package:quranic_competition/models/evaluation.dart';
import 'package:quranic_competition/models/participant.dart';
import 'package:quranic_competition/models/round.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/widgets/modern_navigation.dart';
import '../../../../core/widgets/ui_components.dart';
import '../../../../core/widgets/loading_states.dart';
import '../../../../core/theme/app_theme.dart';

class VersionResultsPage extends StatefulWidget {
  final CompetitionVersion version;

  const VersionResultsPage({super.key, required this.version});

  @override
  State<VersionResultsPage> createState() => _VersionResultsPageState();
}

class _VersionResultsPageState extends State<VersionResultsPage> {
  final EvaluationService _evaluationService = EvaluationService();
  final SupabaseClient _supabase = Supabase.instance.client;
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _totalCount = 0;
  Round? _selectedRound;
  String _selectedGroup = 'كبار';
  String _searchQuery = '';

  List<Round> _rounds = [];
  List<Participant> _participants = [];
  List<Participant> _allParticipants =
      []; // Pour stocker tous les participants non filtrés
  Map<String, double> _participantScores = {};
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    loadVersionResults();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> loadVersionResults({bool reset = true}) async {
    if (reset) {
      setState(() => _isLoading = true);
    } else {
      setState(() => _isLoadingMore = true);
    }

    try {
      // 1. Charger les rounds (seulement au premier chargement)
      if (reset) {
        final data = await _supabase
            .from('rounds')
            .select()
            .eq('version_id', widget.version.id)
            .order('is_active');

        final rounds = data.map<Round>((r) => Round.fromMap(r)).toList();
        setState(() {
          _rounds = rounds;
          // Sélectionner la première round (Round 1) par défaut
          _selectedRound =
              rounds.isNotEmpty
                  ? rounds.firstWhere(
                    (r) => r.number == 1,
                    orElse: () => rounds.first,
                  )
                  : null;
        });
      }

      // 2. Si un round est sélectionné, charger les résultats
      if (_selectedRound != null) {
        await _loadResultsFromTable(reset: reset);
      }
    } catch (e) {
      print("Erreur lors du chargement: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطأ أثناء تحميل النتائج: $e')));
    } finally {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (_hasMore && !_isLoadingMore) {
        _loadMoreResults();
      }
    }
  }

  Future<void> _saveRoundResults(
    Map<String, double> scores,
    List<Participant> participants,
  ) async {
    try {
      // Supprimer les anciens résultats pour ce round s'ils existent
      print(
        '🗑️ Suppression des anciens résultats pour le round ${_selectedRound!.id} et groupe $_selectedGroup...',
      );
      await _supabase
          .from('round_results')
          .delete()
          .eq('round_id', _selectedRound!.id)
          .eq('version_id', widget.version.id)
          .eq('age_group', _selectedGroup);

      print('✅ Anciens résultats supprimés');

      // Insérer les nouveaux résultats
      print(
        '📝 Préparation de ${scores.length} résultats à sauvegarder pour le groupe $_selectedGroup...',
      );
      final List<Map<String, dynamic>> resultsToInsert = [];

      for (final entry in scores.entries) {
        final participantId = entry.key;
        final score = entry.value;
        final participant = participants.firstWhere(
          (p) => p.id == participantId,
        );

        // Déterminer si le participant a réussi
        bool passed = false;
        if (participant.ageGroup == "صغار" && score >= 14) {
          passed = true;
        } else if (participant.ageGroup == "كبار" && score >= 85) {
          passed = true;
        }

        resultsToInsert.add({
          'participant_id': participantId,
          'round_id': _selectedRound!.id,
          'version_id': widget.version.id,
          'score': score,
          'passed': passed,
          'age_group': participant.ageGroup,
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      // Insérer tous les résultats en une seule opération
      if (resultsToInsert.isNotEmpty) {
        print(
          '💾 Insertion de ${resultsToInsert.length} résultats dans round_results...',
        );
        await _supabase.from('round_results').insert(resultsToInsert);

        print(
          '✅ Résultats sauvegardés avec succès pour ${resultsToInsert.length} participants du groupe $_selectedGroup',
        );
      } else {
        print('⚠️ Aucun résultat à sauvegarder pour le groupe $_selectedGroup');
      }
    } catch (e) {
      print('❌ Erreur lors de la sauvegarde des résultats: $e');
      // Ne pas faire échouer toute la méthode si la sauvegarde échoue
    }
  }

  Future<void> _loadResultsFromTable({bool reset = true}) async {
    if (_selectedRound == null) return;

    try {
      // Charger les résultats depuis la table round_results
      final resultsData = await _supabase
          .from('round_results')
          .select('*, participants(*)')
          .eq('round_id', _selectedRound!.id)
          .eq('version_id', widget.version.id)
          .eq('age_group', _selectedGroup)
          .eq('participants.is_accepted', true)
          .order('score', ascending: false);

      if (resultsData.isNotEmpty) {
        print(
          '📊 Résultats trouvés dans round_results, recalcul pour mise à jour...',
        );
        // Toujours recalculer pour s'assurer que la table est à jour
        await _calculateAndSaveResults();
        return;
      }
    } catch (e) {
      print('❌ Erreur lors du chargement depuis round_results: $e');
    }

    // Si aucun résultat trouvé dans round_results, calculer les résultats
    print('⚠️ Aucun résultat trouvé dans round_results, calcul en cours...');
    await _calculateAndSaveResults();
  }

  Future<bool> _checkAllEvaluationsComplete() async {
    try {
      // 1. Récupérer les participants acceptés du groupe sélectionné
      final result = await _evaluationService.getEvaluationsByRoundId(
        _selectedRound!.id,
      );

      final participants =
          result.participants
              .where((p) => p.isAccepted && p.ageGroup == _selectedGroup)
              .toList();
      final participantIds = participants.map((p) => p.id).toSet();

      // 2. Récupérer les jurys assignés à cette version
      final juryAssignments = await _supabase
          .from('jury_assignments')
          .select('user_id')
          .eq('version_id', widget.version.id);

      final juryIds =
          juryAssignments.map<String>((e) => e['user_id'] as String).toSet();

      // 3. Vérifier seulement le round sélectionné
      final selectedRoundId = _selectedRound!.id;
      final selectedRoundNumber = _selectedRound!.number;

      print('🎯 Vérification du round sélectionné: $selectedRoundNumber');

      // 4. Calculer le nombre d'évaluations attendues pour ce round seulement
      final expectedEvaluationsForSelectedRound =
          juryIds.length * participantIds.length;

      print(
        '📊 Évaluations attendues pour le round $selectedRoundNumber: $expectedEvaluationsForSelectedRound',
      );

      // 5. Vérifier seulement le round sélectionné
      final roundToCheck = {
        'id': selectedRoundId,
        'number': selectedRoundNumber,
      };

      for (final round in [roundToCheck]) {
        final roundId = round['id'] as String;
        final roundNumber = round['number'] as int;

        // Récupérer les évaluations pour ce round
        final roundEvaluationsResponse = await _supabase
            .from('evaluations')
            .select('jury_id, participant_id')
            .eq('version_id', widget.version.id)
            .eq('round_id', roundId);

        final roundEvaluations =
            roundEvaluationsResponse
                .map(
                  (e) => {
                    'jury_id': e['jury_id'] as String,
                    'participant_id': e['participant_id'] as String,
                  },
                )
                .toList();

        // Vérifier que chaque jury a évalué chaque participant pour ce round
        for (final juryId in juryIds) {
          // Vérifier d'abord si ce jury a au moins une évaluation pour ce round
          final juryHasEvaluations = roundEvaluations.any(
            (e) => e['jury_id'] == juryId,
          );

          if (!juryHasEvaluations) {
            print(
              '❌ Jury $juryId n\'a aucune évaluation pour le round $roundNumber',
            );
            return false;
          }

          // Vérifier que ce jury a évalué tous les participants
          for (final participantId in participantIds) {
            final exists = roundEvaluations.any(
              (e) =>
                  e['jury_id'] == juryId &&
                  e['participant_id'] == participantId,
            );
            if (!exists) {
              print(
                '❌ Jury $juryId n\'a pas évalué le participant $participantId pour le round $roundNumber',
              );
              return false;
            }
          }
        }
      }

      // 6. Vérification supplémentaire : compter les évaluations pour le round sélectionné seulement
      final roundEvaluationsResponse = await _supabase
          .from('evaluations')
          .select('id, participant_id')
          .eq('version_id', widget.version.id)
          .eq('round_id', selectedRoundId);

      // Compter seulement les évaluations des participants du groupe sélectionné
      final actualEvaluationsForRound =
          roundEvaluationsResponse.where((e) {
            final participantId = e['participant_id'] as String;
            return participantIds.contains(participantId);
          }).length;

      print(
        '📊 Évaluations réelles pour le round $selectedRoundNumber: $actualEvaluationsForRound',
      );

      if (actualEvaluationsForRound < expectedEvaluationsForSelectedRound) {
        print(
          '❌ Nombre d\'évaluations insuffisant pour le round $selectedRoundNumber: $actualEvaluationsForRound/$expectedEvaluationsForSelectedRound',
        );
        return false;
      }

      print('✅ Toutes les évaluations sont complètes');
      return true;
    } catch (e) {
      print('❌ Erreur lors de la vérification des évaluations: $e');
      return false;
    }
  }

  Future<void> _calculateAndSaveResults() async {
    if (_selectedRound == null) return;

    try {
      // 1. Vérifier que tous les jurys ont évalué tous les participants du round sélectionné
      print('🔍 Vérification des évaluations pour le round sélectionné...');
      final evaluationsComplete = await _checkAllEvaluationsComplete();

      if (!evaluationsComplete) {
        setState(() => _isLoading = false);

        showDialog(
          context: context,
          builder:
              (_) => AlertDialog(
                title: const Text("النتائج غير مكتملة"),
                content: const Text(
                  "لم يقم كل المصححين بتقييم كل المشاركين في الجولة المحددة بعد.\n\n"
                  "يجب أن يقوم كل مصحح بتقييم كل مشارك في هذه الجولة.",
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      context.pop();
                      context.pop();
                    },
                    child: const Text("حسناً"),
                  ),
                ],
              ),
        );
        return;
      }

      // 2. Récupérer toutes les évaluations de ce round
      final result = await _evaluationService.getEvaluationsByRoundId(
        _selectedRound!.id,
      );

      // 3. Récupérer les participants (seulement ceux acceptés et du groupe sélectionné)
      final participants =
          result.participants
              .where((p) => p.isAccepted && p.ageGroup == _selectedGroup)
              .toList();

      print(
        '👥 Participants acceptés du groupe $_selectedGroup: ${participants.length}',
      );

      // 4. Calcul de la moyenne des évaluations pour chaque participant (seulement pour le round sélectionné)
      final roundEvaluations =
          result.evaluations
              .where((e) => e.roundId == _selectedRound!.id)
              .toList();
      print(
        '🧮 Calcul des moyennes pour ${roundEvaluations.length} évaluations du round ${_selectedRound!.number}...',
      );
      final Map<String, List<Evaluation>> grouped = {};
      for (final eval in roundEvaluations) {
        grouped.putIfAbsent(eval.participantId, () => []).add(eval);
      }

      print(
        '📊 Groupement par participant: ${grouped.length} participants uniques',
      );
      final Map<String, double> scores = {};
      for (final entry in grouped.entries) {
        final participantId = entry.key;
        final evalList = entry.value;

        // Vérifier que le participant est dans notre liste filtrée
        final participant =
            participants.where((p) => p.id == participantId).firstOrNull;
        if (participant == null) {
          print(
            '⚠️ Participant $participantId non trouvé dans la liste filtrée, ignoré',
          );
          continue;
        }

        final average =
            evalList.map((e) => e.totalScore).reduce((a, b) => a + b) /
            evalList.length;

        scores[participantId] = average;
        print(
          '📈 Participant $participantId: ${evalList.length} évaluations, moyenne: ${average.toStringAsFixed(2)}',
        );

        // ✅ Vérification des conditions de passage

        bool passed = false;
        if (participant.ageGroup == "صغار" && average >= 14) {
          passed = true;
        } else if (participant.ageGroup == "كبار" && average >= 85) {
          passed = true;
        }

        if (passed) {
          // ✅ Mise à jour Supabase
          await _supabase
              .from('participant_versions')
              .update({'passed_round1': true})
              .match({
                'participant_id': participantId,
                'version_id': widget.version.id,
              });
        }
      }

      // 5. Sauvegarder les résultats dans la table des résultats
      print('💾 Début de la sauvegarde des résultats calculés...');
      print(
        '📊 ${scores.length} scores calculés pour ${participants.length} participants du groupe $_selectedGroup',
      );
      await _saveRoundResults(scores, participants);
      print('✅ Sauvegarde terminée avec succès');

      // 6. Mise à jour de l'état
      print(
        '💾 Mise à jour de l\'état - participants.length: ${participants.length}',
      );
      print(
        '💾 IDs des participants: ${participants.map((p) => p.id).toList()}',
      );

      // Déduplication des participants par ID
      final uniqueParticipants = <String, Participant>{};
      for (final participant in participants) {
        uniqueParticipants[participant.id] = participant;
      }
      final deduplicatedParticipants = uniqueParticipants.values.toList();

      print(
        '🔧 Déduplication - Avant: ${participants.length}, Après: ${deduplicatedParticipants.length}',
      );

      setState(() {
        _allParticipants = deduplicatedParticipants;
        _participantScores = scores;
        _totalCount = deduplicatedParticipants.length;
        _hasMore = true;
      });

      // Appliquer le filtrage et la pagination
      _applyFiltersAndPagination();
    } catch (e) {
      print("Erreur lors du calcul des résultats: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطأ أثناء تحميل النتائج: $e')));
    }
  }

  void _applyFiltersAndPagination({bool reset = true}) {
    print('🔍 _applyFiltersAndPagination - reset: $reset');
    print('📊 _allParticipants.length: ${_allParticipants.length}');
    print('📊 _participants.length (avant): ${_participants.length}');

    // 1. Filtrer les participants selon la recherche
    List<Participant> filteredParticipants =
        _allParticipants.where((participant) {
          if (_searchQuery.isEmpty) return true;

          final query = _searchQuery.toLowerCase();
          return participant.fullName.toLowerCase().contains(query) ||
              (participant.registrationNumber?.toString().contains(query) ??
                  false) ||
              participant.phone.toLowerCase().contains(query);
        }).toList();

    print('🔍 filteredParticipants.length: ${filteredParticipants.length}');

    // 2. Trier par score décroissant
    filteredParticipants.sort(
      (a, b) => (_participantScores[b.id] ?? 0).compareTo(
        _participantScores[a.id] ?? 0,
      ),
    );

    // 3. Appliquer la pagination
    final itemsPerPage = 20;

    if (reset) {
      // Reset : afficher les premiers participants
      final endIndex = itemsPerPage.clamp(0, filteredParticipants.length);
      final paginatedParticipants = filteredParticipants.sublist(0, endIndex);

      print(
        '🔄 Reset - endIndex: $endIndex, paginatedParticipants.length: ${paginatedParticipants.length}',
      );

      setState(() {
        _participants = paginatedParticipants;
        _hasMore = endIndex < filteredParticipants.length;
      });
    } else {
      // Load more : ajouter les participants suivants
      final startIndex =
          _participants
              .length; // Commencer après les participants déjà affichés
      final endIndex = (startIndex + itemsPerPage).clamp(
        0,
        filteredParticipants.length,
      );

      print('📈 Load more - startIndex: $startIndex, endIndex: $endIndex');

      if (startIndex < filteredParticipants.length) {
        final paginatedParticipants = filteredParticipants.sublist(
          startIndex,
          endIndex,
        );

        print('📈 Ajout de ${paginatedParticipants.length} participants');
        print(
          '📈 IDs des participants à ajouter: ${paginatedParticipants.map((p) => p.id).toList()}',
        );

        setState(() {
          _participants.addAll(paginatedParticipants);
          _hasMore = endIndex < filteredParticipants.length;
        });

        print('📊 _participants.length (après): ${_participants.length}');
      }
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
    _applyFiltersAndPagination(reset: true);
  }

  Future<void> _loadMoreResults() async {
    if (!_hasMore || _isLoadingMore) return;

    setState(() => _isLoadingMore = true);

    // Simuler un petit délai pour une meilleure UX
    await Future.delayed(const Duration(milliseconds: 300));

    // Charger plus de participants
    _applyFiltersAndPagination(reset: false);

    setState(() => _isLoadingMore = false);
  }

  Widget _buildParticipantList() {
    if (_participants.isEmpty) {
      return EmptyState(
        icon: Icons.emoji_events_outlined,
        title: 'لا توجد نتائج',
        subtitle:
            _searchQuery.isNotEmpty
                ? 'لا توجد نتائج مطابقة للبحث'
                : 'لا توجد نتائج لهذه الفئة أو الجولة',
      );
    }

    return ListView.builder(
      controller: _scrollController,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _participants.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _participants.length) {
          // Indicateur de chargement automatique en bas
          return _isLoadingMore
              ? Container(
                padding: const EdgeInsets.all(AppTheme.spacingM),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppTheme.primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingS),
                    Text(
                      'جاري تحميل المزيد...',
                      style: AppTheme.labelMedium.copyWith(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              )
              : _hasMore
              ? Container(
                padding: const EdgeInsets.all(AppTheme.spacingM),
                child: Text(
                  'اسحب لأسفل لتحميل المزيد',
                  style: AppTheme.labelMedium.copyWith(
                    color: AppTheme.textSecondaryColor,
                  ),
                  textAlign: TextAlign.center,
                ),
              )
              : Container(
                padding: const EdgeInsets.all(AppTheme.spacingM),
                child: Text(
                  'تم تحميل جميع النتائج',
                  style: AppTheme.labelMedium.copyWith(
                    color: AppTheme.successColor,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              );
        }
        final p = _participants[index];
        final score = _participantScores[p.id] ?? 0;

        Widget? medalIcon;
        if (index == 0) {
          medalIcon = const Icon(
            Icons.emoji_events,
            color: Colors.amber,
            size: 28,
          );
        } else if (index == 1) {
          medalIcon = const Icon(
            Icons.emoji_events,
            color: Colors.grey,
            size: 26,
          );
        } else if (index == 2) {
          medalIcon = const Icon(
            Icons.emoji_events,
            color: Colors.brown,
            size: 24,
          );
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          child: ModernCard(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingS),
              child: Row(
                children: [
                  // Position et médaille
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color:
                          index < 3
                              ? AppTheme.primaryColor.withValues(alpha: 0.1)
                              : AppTheme.backgroundColor,
                      borderRadius: BorderRadius.circular(AppTheme.radiusM),
                      border: Border.all(
                        color:
                            index < 3
                                ? AppTheme.primaryColor
                                : AppTheme.dividerColor,
                      ),
                    ),
                    child: Center(
                      child:
                          medalIcon ??
                          Text(
                            '${index + 1}',
                            style: AppTheme.labelLarge.copyWith(
                              color:
                                  index < 3
                                      ? AppTheme.primaryColor
                                      : AppTheme.textPrimaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingS),

                  // Informations du participant
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.fullName,
                          style: AppTheme.labelLarge.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'النتيجة: ${score.toStringAsFixed(2)}',
                          style: AppTheme.labelMedium.copyWith(
                            color: AppTheme.textSecondaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Score et rang
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spacingS,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color:
                              index < 3
                                  ? AppTheme.successColor.withValues(alpha: 0.1)
                                  : AppTheme.primaryColor.withValues(
                                    alpha: 0.1,
                                  ),
                          borderRadius: BorderRadius.circular(AppTheme.radiusS),
                        ),
                        child: Text(
                          '${score.toStringAsFixed(1)}',
                          style: AppTheme.labelMedium.copyWith(
                            color:
                                index < 3
                                    ? AppTheme.successColor
                                    : AppTheme.primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'المركز ${index + 1}',
                        style: AppTheme.labelSmall.copyWith(
                          color: AppTheme.textSecondaryColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ModernAppBar(title: 'نتائج النسخة: ${widget.version.name}'),
      body:
          _isLoading
              ? const LoadingOverlay(child: SizedBox())
              : ModernPullToRefresh(
                onRefresh: () => _loadResultsFromTable(reset: true),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppTheme.spacingS),
                  child: Column(
                    children: [
                      // Section de filtrage moderne
                      ModernCard(
                        child: Padding(
                          padding: const EdgeInsets.all(AppTheme.spacingS),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.filter_list,
                                    color: AppTheme.primaryColor,
                                  ),
                                  const SizedBox(width: AppTheme.spacingS),
                                  Text(
                                    'تصفية النتائج',
                                    style: AppTheme.labelLarge.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppTheme.spacingS),

                              // Sélection de la ronde
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'اختر الجولة',
                                          style: AppTheme.labelMedium.copyWith(
                                            color: AppTheme.textSecondaryColor,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Container(
                                          decoration: BoxDecoration(
                                            color: AppTheme.backgroundColor,
                                            borderRadius: BorderRadius.circular(
                                              AppTheme.radiusM,
                                            ),
                                            border: Border.all(
                                              color: AppTheme.dividerColor,
                                            ),
                                          ),
                                          child: DropdownButton<Round>(
                                            value: _selectedRound,
                                            isExpanded: true,
                                            underline: const SizedBox(),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: AppTheme.spacingS,
                                              vertical: 8,
                                            ),
                                            items:
                                                _rounds.map((r) {
                                                  return DropdownMenuItem(
                                                    value: r,
                                                    child: Text(
                                                      'الجولة ${r.number}',
                                                      style:
                                                          AppTheme.labelMedium,
                                                    ),
                                                  );
                                                }).toList(),
                                            onChanged: (round) {
                                              if (round != null &&
                                                  round.id !=
                                                      _selectedRound?.id) {
                                                setState(() {
                                                  _selectedRound = round;
                                                  _hasMore = true;
                                                  _searchQuery = '';
                                                });
                                                _searchController.clear();
                                                _loadResultsFromTable(
                                                  reset: true,
                                                );
                                              }
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: AppTheme.spacingM),

                                  // Sélection de la catégorie
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'الفئة',
                                          style: AppTheme.labelMedium.copyWith(
                                            color: AppTheme.textSecondaryColor,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Container(
                                          decoration: BoxDecoration(
                                            color: AppTheme.backgroundColor,
                                            borderRadius: BorderRadius.circular(
                                              AppTheme.radiusM,
                                            ),
                                            border: Border.all(
                                              color: AppTheme.dividerColor,
                                            ),
                                          ),
                                          child: DropdownButton<String>(
                                            value: _selectedGroup,
                                            isExpanded: true,
                                            underline: const SizedBox(),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: AppTheme.spacingS,
                                              vertical: 8,
                                            ),
                                            items: const [
                                              DropdownMenuItem(
                                                value: 'كبار',
                                                child: Text('كبار'),
                                              ),
                                              DropdownMenuItem(
                                                value: 'صغار',
                                                child: Text('صغار'),
                                              ),
                                            ],
                                            onChanged: (group) {
                                              if (group != null &&
                                                  group != _selectedGroup) {
                                                setState(() {
                                                  _selectedGroup = group;
                                                  _hasMore = true;
                                                  _searchQuery = '';
                                                });
                                                _searchController.clear();
                                                _loadResultsFromTable(
                                                  reset: true,
                                                );
                                              }
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingS),

                      // Section de recherche moderne
                      ModernCard(
                        child: Padding(
                          padding: const EdgeInsets.all(AppTheme.spacingS),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.search,
                                    color: AppTheme.primaryColor,
                                  ),
                                  const SizedBox(width: AppTheme.spacingS),
                                  Text(
                                    'البحث في النتائج',
                                    style: AppTheme.labelLarge.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppTheme.spacingS),
                              Container(
                                decoration: BoxDecoration(
                                  color: AppTheme.backgroundColor,
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusM,
                                  ),
                                  border: Border.all(
                                    color: AppTheme.dividerColor,
                                  ),
                                ),
                                child: TextField(
                                  controller: _searchController,
                                  onChanged: _onSearchChanged,
                                  decoration: InputDecoration(
                                    hintText:
                                        'البحث بالاسم، رقم التسجيل أو الهاتف...',
                                    hintStyle: AppTheme.labelMedium.copyWith(
                                      color: AppTheme.textDisabledColor,
                                    ),
                                    prefixIcon: Container(
                                      margin: const EdgeInsets.all(
                                        AppTheme.spacingXS,
                                      ),
                                      padding: const EdgeInsets.all(
                                        AppTheme.spacingXS,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: AppTheme.primaryGradient,
                                        borderRadius: BorderRadius.circular(
                                          AppTheme.radiusS,
                                        ),
                                        boxShadow: AppTheme.shadowS,
                                      ),
                                      child: const Icon(
                                        Icons.search,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ),
                                    suffixIcon:
                                        _searchQuery.isNotEmpty
                                            ? IconButton(
                                              icon: const Icon(Icons.clear),
                                              onPressed: () {
                                                _searchController.clear();
                                                _onSearchChanged('');
                                              },
                                            )
                                            : null,
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: AppTheme.spacingM,
                                      vertical: AppTheme.spacingM,
                                    ),
                                  ),
                                  style: AppTheme.labelMedium,
                                ),
                              ),
                              if (_searchQuery.isNotEmpty) ...[
                                const SizedBox(height: AppTheme.spacingS),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppTheme.spacingS,
                                    vertical: AppTheme.spacingXS,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor.withOpacity(
                                      0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.radiusS,
                                    ),
                                  ),
                                  child: Text(
                                    'نتائج البحث عن: "$_searchQuery"',
                                    style: AppTheme.labelSmall.copyWith(
                                      color: AppTheme.primaryColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingS),

                      // Section d'informations sur les résultats
                      if (_totalCount > 0)
                        ModernCard(
                          child: Padding(
                            padding: const EdgeInsets.all(AppTheme.spacingS),
                            child: Row(
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
                                    Icons.emoji_events,
                                    color: AppTheme.primaryColor,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: AppTheme.spacingS),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'النتائج',
                                        style: AppTheme.labelLarge.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'إجمالي $_totalCount مشارك مقبول في فئة ${_selectedGroup}',
                                        style: AppTheme.labelMedium.copyWith(
                                          color: AppTheme.textSecondaryColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: AppTheme.spacingS,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryColor.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          AppTheme.radiusM,
                                        ),
                                      ),
                                      child: Text(
                                        '$_totalCount',
                                        style: AppTheme.labelLarge.copyWith(
                                          color: AppTheme.primaryColor,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: AppTheme.spacingXS,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.successColor
                                            .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(
                                          AppTheme.radiusS,
                                        ),
                                      ),
                                      child: Text(
                                        'مقبولون',
                                        style: AppTheme.labelSmall.copyWith(
                                          color: AppTheme.successColor,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                      const SizedBox(height: AppTheme.spacingS),
                      _buildParticipantList(),
                    ],
                  ),
                ),
              ),
      bottomNavigationBar: _buildBottomActionBar(),
    );
  }

  Widget? _buildBottomActionBar() {
    if (_selectedRound == null) return null;

    // Si les résultats sont déjà publiés
    if (_selectedRound!.resultIsPublished) {
      return Container(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          boxShadow: [
            BoxShadow(
              color: AppTheme.textPrimaryColor.withValues(alpha: 0.1),
              spreadRadius: 1,
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Container(
            padding: const EdgeInsets.all(AppTheme.spacingS),
            decoration: BoxDecoration(
              color: AppTheme.successColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
              border: Border.all(color: AppTheme.successColor.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: AppTheme.successColor,
                  size: 24,
                ),
                const SizedBox(width: AppTheme.spacingS),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'النتائج منشورة',
                        style: AppTheme.labelMedium.copyWith(
                          color: AppTheme.successColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'النتائج متاحة للجميع',
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.successColor.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingS,
                    vertical: AppTheme.spacingXS,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.successColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(AppTheme.radiusS),
                  ),
                  child: Text(
                    'منشور',
                    style: AppTheme.labelSmall.copyWith(
                      color: AppTheme.successColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Si pas de participants
    if (_participants.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          boxShadow: [
            BoxShadow(
              color: AppTheme.textPrimaryColor.withValues(alpha: 0.1),
              spreadRadius: 1,
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Container(
            padding: const EdgeInsets.all(AppTheme.spacingS),
            decoration: BoxDecoration(
              color: AppTheme.warningColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
              border: Border.all(color: AppTheme.warningColor.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.warning_outlined,
                  color: AppTheme.warningColor,
                  size: 24,
                ),
                const SizedBox(width: AppTheme.spacingS),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'لا يمكن النشر',
                        style: AppTheme.labelMedium.copyWith(
                          color: AppTheme.warningColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'لا توجد نتائج للنشر',
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.warningColor.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Bouton de publication normal
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        boxShadow: [
          BoxShadow(
            color: AppTheme.textPrimaryColor.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Informations sur la publication
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppTheme.spacingS),
              margin: const EdgeInsets.only(bottom: AppTheme.spacingS),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusS),
                border: Border.all(
                  color: AppTheme.primaryColor.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.emoji_events,
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: AppTheme.spacingS),
                  Expanded(
                    child: Text(
                      'جاهز للنشر: ${_participants.length} مشارك',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingXS,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(AppTheme.radiusS),
                    ),
                    child: Text(
                      '${_participants.length}',
                      style: AppTheme.labelSmall.copyWith(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Bouton de publication
            SizedBox(
              width: double.infinity,
              child: PrimaryButton(
                onPressed: () {
                  _shareResults(_selectedRound!, widget.version.id);
                },
                text: 'نشر النتائج',
                icon: Icons.publish,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareResults(Round round, String versionId) async {
    print('🚀 Début de la publication des résultats');
    print('📊 Ronde: ${round.name} (ID: ${round.id})');
    print('🏆 Version: $versionId');
    print('👥 Participants: ${_participants.length}');

    try {
      // 1. Vérifications préliminaires
      print('🔍 Étape 1: Validation des données...');
      if (!_validateResultsBeforePublishing(round)) {
        print('❌ Validation échouée - Arrêt de la publication');
        return;
      }

      // 2. Confirmation de publication
      print('🔍 Étape 2: Demande de confirmation...');
      final confirmed = await _showPublishConfirmationDialog(round);
      if (!confirmed) {
        print('❌ Publication annulée par l\'utilisateur');
        return;
      }

      // 3. Affichage du loading
      print('🔍 Étape 3: Affichage du loading...');
      _showPublishingDialog();

      // 4. Publication des résultats
      print('🔍 Étape 4: Publication des résultats...');
      await _publishResults(round, versionId);

      // 5. Mise à jour de l'état local
      print('🔍 Étape 5: Mise à jour de l\'état local...');
      _updateLocalStateAfterPublishing(round);

      // 6. Fermeture du dialog et message de succès
      print('🔍 Étape 6: Affichage du message de succès...');
      if (context.mounted) {
        Navigator.of(context).pop(); // Fermer le dialog de loading
        _showSuccessDialog(round);
      }

      print('✅ Publication terminée avec succès');
    } catch (e) {
      print('❌ Erreur lors de la publication: $e');
      print('🔍 Stack trace: ${StackTrace.current}');

      // 7. Gestion des erreurs
      if (context.mounted) {
        Navigator.of(context).pop(); // Fermer le dialog de loading
        _showErrorDialog(e.toString());
      }
    }
  }

  bool _validateResultsBeforePublishing(Round round) {
    print('🔍 Validation des résultats avant publication...');

    // Vérifier qu'il y a des participants
    if (_participants.isEmpty) {
      print('❌ Aucun participant trouvé');
      _showValidationErrorDialog('لا يمكن نشر النتائج بدون مشاركين');
      return false;
    }

    print('✅ ${_participants.length} participants trouvés');

    // Vérifier que tous les participants ont des scores
    final participantsWithoutScores =
        _participants
            .where(
              (p) =>
                  !_participantScores.containsKey(p.id) ||
                  _participantScores[p.id] == 0,
            )
            .toList();

    if (participantsWithoutScores.isNotEmpty) {
      print('❌ ${participantsWithoutScores.length} participants sans scores');
      for (final p in participantsWithoutScores) {
        print('  - ${p.fullName} (ID: ${p.id})');
      }

      _showValidationErrorDialog(
        'يوجد ${participantsWithoutScores.length} مشارك بدون نقاط. يرجى التأكد من إكمال جميع التقييمات.',
      );
      return false;
    }

    print('✅ Tous les participants ont des scores');

    // Vérifier que les résultats ne sont pas déjà publiés
    if (round.resultIsPublished) {
      print('❌ Les résultats sont déjà publiés');
      _showValidationErrorDialog('النتائج منشورة بالفعل');
      return false;
    }

    print('✅ Validation réussie - Prêt pour la publication');
    return true;
  }

  Future<bool> _showPublishConfirmationDialog(Round round) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.publish, color: AppTheme.warningColor, size: 28),
                  const SizedBox(width: AppTheme.spacingS),
                  const Text('تأكيد نشر النتائج'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'هل أنت متأكد من نشر نتائج ${round.name}؟',
                    style: AppTheme.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingM),
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spacingS),
                    decoration: BoxDecoration(
                      color: AppTheme.warningColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusS),
                      border: Border.all(
                        color: AppTheme.warningColor.withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: AppTheme.warningColor,
                              size: 20,
                            ),
                            const SizedBox(width: AppTheme.spacingS),
                            Text(
                              'تنبيه مهم',
                              style: AppTheme.labelMedium.copyWith(
                                color: AppTheme.warningColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppTheme.spacingS),
                        Text(
                          'بعد النشر، سيتم إغلاق هذه الجولة وستصبح النتائج مرئية للجميع. لا يمكن التراجع عن هذا الإجراء.',
                          style: AppTheme.bodySmall.copyWith(
                            color: AppTheme.textSecondaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingM),
                  Row(
                    children: [
                      Icon(
                        Icons.emoji_events,
                        color: AppTheme.primaryColor,
                        size: 20,
                      ),
                      const SizedBox(width: AppTheme.spacingS),
                      Text(
                        'عدد المشاركين: ${_participants.length}',
                        style: AppTheme.bodyMedium,
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(
                    'إلغاء',
                    style: AppTheme.labelMedium.copyWith(
                      color: AppTheme.textSecondaryColor,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.warningColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusS),
                    ),
                  ),
                  child: Text(
                    'نشر النتائج',
                    style: AppTheme.labelMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  void _showPublishingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppTheme.primaryColor),
              const SizedBox(height: AppTheme.spacingM),
              Text(
                'جاري نشر النتائج...',
                style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: AppTheme.spacingS),
              Text(
                'يرجى الانتظار',
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.textSecondaryColor,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _publishResults(Round round, String versionId) async {
    try {
      final client = Supabase.instance.client;

      if (round.number == 1) {
        // Pour la première ronde : publier + activer la ronde suivante
        print('🔄 Publication de la première ronde: ${round.name}');

        // Méthode alternative : mise à jour manuelle si la fonction RPC n'existe pas
        await _publishRound1Manually(round, versionId);
      } else {
        // Pour les autres rondes : publier seulement
        print('🔄 Publication de la ronde ${round.number}: ${round.name}');

        final response = await client
            .from('rounds')
            .update({
              'result_is_published': true,
              'is_active': false,
              'published_at': DateTime.now().toIso8601String(),
            })
            .eq('id', round.id)
            .eq('version_id', versionId);

        print('✅ Mise à jour de la ronde réussie: ${response}');
      }

      // Log de l'activité (optionnel)
      await _logPublishingActivity(round, versionId);
    } catch (e) {
      print('❌ Erreur lors de la publication: $e');
      throw Exception('فشل في نشر النتائج: $e');
    }
  }

  Future<void> _publishRound1Manually(Round round, String versionId) async {
    try {
      final client = Supabase.instance.client;

      // 1. Publier la ronde 1
      print('📝 Mise à jour de la ronde 1...');
      await client
          .from('rounds')
          .update({
            'result_is_published': true,
            'is_active': false,
            'published_at': DateTime.now().toIso8601String(),
          })
          .eq('id', round.id)
          .eq('version_id', versionId);

      // 2. Activer la ronde suivante (ronde 2)
      print('📝 Activation de la ronde 2...');
      await client
          .from('rounds')
          .update({'is_active': true})
          .eq('version_id', versionId)
          .eq('number', 2);

      // 3. Mettre à jour le statut passed_round1 pour les participants qui ont réussi
      print('📝 Mise à jour du statut des participants...');
      for (final participant in _participants) {
        final score = _participantScores[participant.id] ?? 0;
        bool passed = false;

        if (participant.ageGroup == "صغار" && score >= 14) {
          passed = true;
        } else if (participant.ageGroup == "كبار" && score >= 85) {
          passed = true;
        }

        if (passed) {
          await client
              .from('participant_versions')
              .update({'passed_round1': true})
              .match({
                'participant_id': participant.id,
                'version_id': versionId,
              });
        }
      }

      print('✅ Publication de la ronde 1 terminée avec succès');
    } catch (e) {
      print('❌ Erreur lors de la publication manuelle de la ronde 1: $e');
      throw Exception('فشل في نشر نتائج الجولة الأولى: $e');
    }
  }

  Future<void> _logPublishingActivity(Round round, String versionId) async {
    try {
      // Vérifier si la table admin_activities existe avant d'essayer d'insérer
      print('📝 Enregistrement de l\'activité de publication...');

      await Supabase.instance.client.from('admin_activities').insert({
        'action': 'publish_results',
        'details': {
          'round_name': round.name,
          'round_number': round.number,
          'version_id': versionId,
          'participants_count': _participants.length,
          'published_at': DateTime.now().toIso8601String(),
        },
        'created_at': DateTime.now().toIso8601String(),
      });

      print('✅ Activité de publication enregistrée avec succès');
    } catch (e) {
      print('⚠️ Erreur lors de l\'enregistrement de l\'activité: $e');
      print('ℹ️ La publication continue sans enregistrement d\'activité');
      // Ne pas faire échouer la publication pour cette erreur
    }
  }

  void _updateLocalStateAfterPublishing(Round round) {
    setState(() {
      // Mettre à jour l'état local du round
      final roundIndex = _rounds.indexWhere((r) => r.id == round.id);
      if (roundIndex != -1) {
        _rounds[roundIndex] = Round(
          id: round.id,
          name: round.name,
          number: round.number,
          versionId: round.versionId,
          startDate: round.startDate,
          endDate: round.endDate,
          isActive: false,
          resultIsPublished: true,
        );
        _selectedRound = _rounds[roundIndex];
      }
    });
  }

  void _showSuccessDialog(Round round) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.check_circle, color: AppTheme.successColor, size: 28),
              const SizedBox(width: AppTheme.spacingS),
              const Text('تم النشر بنجاح'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingM),
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  border: Border.all(
                    color: AppTheme.successColor.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.emoji_events,
                      color: AppTheme.successColor,
                      size: 48,
                    ),
                    const SizedBox(height: AppTheme.spacingS),
                    Text(
                      'تم نشر نتائج ${round.name} بنجاح',
                      style: AppTheme.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.successColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppTheme.spacingS),
                    Text(
                      'النتائج الآن متاحة للجميع',
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.textSecondaryColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              if (round.number == 1) ...[
                const SizedBox(height: AppTheme.spacingM),
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingS),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusS),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.arrow_forward,
                        color: AppTheme.primaryColor,
                        size: 20,
                      ),
                      const SizedBox(width: AppTheme.spacingS),
                      Expanded(
                        child: Text(
                          'تم تفعيل الجولة الثانية تلقائياً',
                          style: AppTheme.bodySmall.copyWith(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Rafraîchir la page pour voir les changements
                loadVersionResults(reset: true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.successColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusS),
                ),
              ),
              child: Text(
                'موافق',
                style: AppTheme.labelMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showValidationErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.error_outline, color: AppTheme.errorColor, size: 28),
              const SizedBox(width: AppTheme.spacingS),
              const Text('خطأ في التحقق'),
            ],
          ),
          content: Text(message, style: AppTheme.bodyMedium),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'موافق',
                style: AppTheme.labelMedium.copyWith(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.error, color: AppTheme.errorColor, size: 28),
              const SizedBox(width: AppTheme.spacingS),
              const Text('خطأ في النشر'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'حدث خطأ أثناء نشر النتائج:',
                style: AppTheme.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppTheme.spacingS),
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingS),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusS),
                  border: Border.all(
                    color: AppTheme.errorColor.withOpacity(0.3),
                  ),
                ),
                child: Text(
                  error,
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.errorColor,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spacingS),
              Text(
                'يرجى المحاولة مرة أخرى أو التواصل مع الدعم الفني.',
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.textSecondaryColor,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'موافق',
                style: AppTheme.labelMedium.copyWith(
                  color: AppTheme.errorColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
