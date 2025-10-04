import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:quranic_competition/core/services/evaluation_service.dart';
import 'package:quranic_competition/models/competition_version.dart';
import 'package:quranic_competition/models/evaluation.dart';
import 'package:quranic_competition/models/participant.dart';
import 'package:quranic_competition/models/round.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  int _currentPage = 0;
  int _totalCount = 0;
  Round? _selectedRound;
  String _selectedGroup = 'كبار';

  List<Round> _rounds = [];
  List<Participant> _participants = [];
  Map<String, double> _participantScores = {};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    loadVersionResults();
  }

  @override
  void dispose() {
    _scrollController.dispose();
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
          _selectedRound = rounds.isNotEmpty ? rounds.first : null;
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

  Future<void> _loadMoreResults() async {
    if (!_hasMore || _isLoadingMore) return;

    setState(() => _currentPage++);
    await loadVersionResults(reset: false);
  }

  Future<void> _saveRoundResults(
    Map<String, double> scores,
    List<Participant> participants,
  ) async {
    try {
      // Supprimer les anciens résultats pour ce round s'ils existent
      // await _supabase
      //     .from('round_results')
      //     .delete()
      //     .eq('round_id', _selectedRound!.id)
      //     .eq('version_id', widget.version.id);

      // Insérer les nouveaux résultats
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
        await _supabase.from('round_results').insert(resultsToInsert);

        print(
          '✅ Résultats sauvegardés pour ${resultsToInsert.length} participants',
        );
      }
    } catch (e) {
      print('❌ Erreur lors de la sauvegarde des résultats: $e');
      // Ne pas faire échouer toute la méthode si la sauvegarde échoue
    }
  }

  Future<void> _loadResultsFromTable({bool reset = true}) async {
    if (_selectedRound == null) return;

    try {
      // Charger les résultats depuis la table round_results avec pagination
      final resultsData = await _supabase
          .from('round_results')
          .select('*, participants(*)')
          .eq('round_id', _selectedRound!.id)
          .eq('version_id', widget.version.id)
          .eq('age_group', _selectedGroup)
          .order('score', ascending: false);

      if (resultsData.isNotEmpty) {
        final List<Participant> participants = [];
        final Map<String, double> scores = {};

        for (final row in resultsData) {
          final participantData = row['participants'];
          final participant = Participant.fromMap(participantData);
          participants.add(participant);
          scores[participant.id] = (row['score'] as num).toDouble();
        }

        // Appliquer la pagination côté client
        final totalCount = participants.length;
        final startIndex = _currentPage * 20;
        final endIndex = (startIndex + 20).clamp(0, totalCount);
        
        final paginatedParticipants = participants.sublist(startIndex, endIndex);
        final paginatedScores = <String, double>{};
        
        for (final participant in paginatedParticipants) {
          paginatedScores[participant.id] = scores[participant.id]!;
        }

        setState(() {
          if (reset) {
            _participants = paginatedParticipants;
            _participantScores = paginatedScores;
            _currentPage = 0;
          } else {
            _participants.addAll(paginatedParticipants);
            _participantScores.addAll(paginatedScores);
          }
          _totalCount = totalCount;
          _hasMore = endIndex < totalCount;
        });

        print(
          '✅ Résultats chargés depuis round_results: ${paginatedParticipants.length} participants (page ${_currentPage + 1})',
        );
        return;
      }
    } catch (e) {
      print('❌ Erreur lors du chargement depuis round_results: $e');
    }

    // Si aucun résultat trouvé dans round_results, calculer les résultats
    print('⚠️ Aucun résultat trouvé dans round_results, calcul en cours...');
    await _calculateAndSaveResults();
  }

  Future<void> _calculateAndSaveResults() async {
    if (_selectedRound == null) return;

    try {
      // 1. Récupérer toutes les évaluations de ce round
      final result = await _evaluationService.getEvaluationsByRoundId(
        _selectedRound!.id,
      );

      // 2. Récupérer les participants
      final participants = result.participants;
      final participantIds = participants.map((p) => p.id).toSet();

      // 3. Récupérer les jurys assignés à cette version
      final juryAssignments = await _supabase
          .from('jury_assignments')
          .select('user_id')
          .eq('version_id', widget.version.id);

      final juryIds =
          juryAssignments.map<String>((e) => e['user_id'] as String).toSet();

      // 4. Vérifier que chaque jury a évalué chaque participant
      bool allEvaluated = true;

      for (final juryId in juryIds) {
        for (final participantId in participantIds) {
          final exists = result.evaluations.any(
            (e) => e.juryId == juryId && e.participantId == participantId,
          );
          if (!exists) {
            allEvaluated = false;
            break;
          }
        }
        if (!allEvaluated) break;
      }

      if (!allEvaluated) {
        setState(() => _isLoading = false);

        // أظهر الرسالة ثم عد إلى الخلف بعد إغلاقها
        showDialog(
          context: context,
          builder:
              (_) => AlertDialog(
                title: const Text("النتائج غير مكتملة"),
                content: const Text(
                  "لم يقم كل المصححين بتقييم كل المشاركين بعد.",
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      context.pop(); // إغلاق الرسالة
                      context.pop(); // الرجوع إلى الصفحة السابقة
                    },
                    child: const Text("حسناً"),
                  ),
                ],
              ),
        );
        return;
      }

      // 5. Calcul de la moyenne des évaluations pour chaque participant
      final Map<String, List<Evaluation>> grouped = {};
      for (final eval in result.evaluations) {
        grouped.putIfAbsent(eval.participantId, () => []).add(eval);
      }

      final Map<String, double> scores = {};
      for (final entry in grouped.entries) {
        final participantId = entry.key;
        final evalList = entry.value;

        final average =
            evalList.map((e) => e.totalScore).reduce((a, b) => a + b) /
            evalList.length;

        scores[participantId] = average;

        // ✅ Vérification des conditions de passage
        final participant = participants.firstWhere(
          (p) => p.id == participantId,
        );

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

      // 6. Sauvegarder les résultats dans la table des résultats
      await _saveRoundResults(scores, participants);

      // 7. Mise à jour de l'état
      setState(() {
        _participants = participants;
        _participantScores = scores;
      });
    } catch (e) {
      print("Erreur lors du calcul des résultats: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطأ أثناء تحميل النتائج: $e')));
    }
  }

  Widget _buildParticipantList() {
    // Crée une map pour stocker participants uniques (par id)
    final Map<String, Participant> uniqueParticipants = {};

    // Ajoute uniquement les participants qui ont un score et correspondent au filtre
    for (final p in _participants) {
      if (_participantScores.containsKey(p.id) &&
          (p.ageGroup == _selectedGroup)) {
        uniqueParticipants[p.id] = p;
      }
    }

    // Transforme la map en liste
    final filtered = uniqueParticipants.values.toList();

    // Trie par score décroissant
    filtered.sort(
      (a, b) => (_participantScores[b.id] ?? 0).compareTo(
        _participantScores[a.id] ?? 0,
      ),
    );

    if (filtered.isEmpty) {
      return const Center(child: Text("لا توجد نتائج لهذه الفئة أو الجولة"));
    }

    return ListView.builder(
      controller: _scrollController,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filtered.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == filtered.length) {
          // Indicateur de chargement en bas
          return _isLoadingMore
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                )
              : _hasMore
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: ElevatedButton(
                          onPressed: _loadMoreResults,
                          child: const Text('تحميل المزيد'),
                        ),
                      ),
                    )
                  : const SizedBox.shrink();
        }
        final p = filtered[index];
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

        return ListTile(
          leading: medalIcon,
          title: Text(p.fullName),
          subtitle: Text('النتيجة: ${score.toStringAsFixed(2)}'),
          trailing: Text('الترتيب: ${index + 1}'),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('نتائج النسخة: ${widget.version.name}'),
            if (_totalCount > 0)
              Text(
                'إجمالي: $_totalCount مشارك',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
              ),
          ],
        ),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                onRefresh: () => _loadResultsFromTable(reset: true),
                child: ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        const Text('اختر الجولة:'),
                        DropdownButton<Round>(
                          value: _selectedRound,
                          items:
                              _rounds.map((r) {
                                return DropdownMenuItem(
                                  value: r,
                                  child: Text('الجولة ${r.number}'),
                                );
                              }).toList(),
                          onChanged: (round) {
                            if (round != null && round.id != _selectedRound?.id) {
                              setState(() {
                                _selectedRound = round;
                                _currentPage = 0;
                                _hasMore = true;
                              });
                              _loadResultsFromTable(reset: true);
                            }
                          },
                        ),
                        const SizedBox(width: 20),
                        const Text('الفئة:'),
                        DropdownButton<String>(
                          value: _selectedGroup,
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
                            if (group != null && group != _selectedGroup) {
                              setState(() {
                                _selectedGroup = group;
                                _currentPage = 0;
                                _hasMore = true;
                              });
                              _loadResultsFromTable(reset: true);
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildParticipantList(),
                  ],
                ),
              ),
      bottomNavigationBar:
          _selectedRound == null
              ? null
              : _selectedRound!.resultIsPublished
              ? null
              : _participants.isEmpty
              ? null
              : GestureDetector(
                onTap: () {
                  _shareResults(_selectedRound!, widget.version.id);
                },
                child: Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.5),
                        spreadRadius: 5,
                        blurRadius: 7,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("مشاركة النتائج"),
                      const SizedBox(width: 12),
                      const Icon(HugeIcons.strokeRoundedShare01),
                    ],
                  ),
                ),
              ),
    );
  }

  Future<void> _shareResults(Round round, String versionId) async {
    try {
      if (round.name == 'الجولة الأولى') {
        final response = await Supabase.instance.client
            .from('rounds')
            .update({'result_is_published': true, 'is_active': false})
            .eq('id', round.id)
            .whenComplete(() async {
              await Supabase.instance.client
                  .from('rounds')
                  .update({'is_active': true})
                  .eq('number', 2)
                  .eq('version_id', versionId);
            });
        if (response.error != null) {
          throw response.error!;
        }
      } else {
        final response = await Supabase.instance.client
            .from('rounds')
            .update({'result_is_published': true, 'is_active': false})
            .eq('id', round.id)
            .eq('version_id', versionId);

        if (response.error != null) {
          throw response.error!;
        }
      }

      // Optionnel : message de succès
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ النتائج تم نشرها بنجاح")),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("⚠️ خطأ أثناء نشر النتائج: $e")));
      }
    }
  }
}
