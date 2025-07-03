import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quranic_competition/core/services/evaluation_service.dart';
import 'package:quranic_competition/models/app_user.dart';
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

  bool _isLoading = true;
  Round? _selectedRound;
  String _selectedGroup = 'كبار';

  List<Round> _rounds = [];
  List<Participant> _participants = [];
  Map<String, double> _participantScores = {};

  @override
  void initState() {
    super.initState();
    _loadRounds();
  }

  Future<void> _loadRounds() async {
    setState(() => _isLoading = true);
    try {
      final data = await _supabase
          .from('rounds')
          .select()
          .eq('version_id', widget.version.id)
          .order('number');

      final rounds = data.map<Round>((r) => Round.fromMap(r)).toList();
      setState(() {
        _rounds = rounds;
        _selectedRound = rounds.isNotEmpty ? rounds.first : null;
      });

      if (_selectedRound != null) {
        await _loadResults();
      }
    } catch (e) {
      print('Erreur lors du chargement des rounds: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors du chargement des tours : $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadResults() async {
    if (_selectedRound == null) return;

    setState(() => _isLoading = true);
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
                  "لم يقم كل المحكمين بتقييم كل المشاركين بعد.",
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
      grouped.forEach((participantId, evalList) {
        final average =
            evalList.map((e) => e.totalScore).reduce((a, b) => a + b) /
            evalList.length;
        scores[participantId] = average;
      });

      // 6. Mise à jour de l’état
      setState(() {
        _participants = participants;
        _participantScores = scores;
      });
    } catch (e) {
      print("Erreur lors du chargement: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطأ أثناء تحميل النتائج: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildParticipantList() {
    // Crée une map pour stocker participants uniques (par id)
    final Map<String, Participant> uniqueParticipants = {};

    // Ajoute uniquement les participants qui ont un score et correspondent au filtre
    for (final p in _participants) {
      if (_participantScores.containsKey(p.id) &&
          (_selectedGroup == 'كبار' || p.ageGroup == _selectedGroup)) {
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
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
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
      appBar: AppBar(title: Text('نتائج النسخة: ${widget.version.name}')),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                onRefresh: _loadResults,
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
                            if (round != null) {
                              setState(() => _selectedRound = round);
                              _loadResults();
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
                            if (group != null) {
                              setState(() => _selectedGroup = group);
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
    );
  }
}
