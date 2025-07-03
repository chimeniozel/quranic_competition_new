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
    final roundId = await _getActiveRoundIdForVersion(versionId);

    print('RoundId attendu (normalisé): "${roundId?.trim().toLowerCase()}"');

    // 1. Récupérer participants liés à la version
    final participants = await _participantService.fetchParticipantsByVersion(
      versionId,
    );

    // 2. Récupérer évaluations du jury pour cette version
    final evaluationsResponse = await _evaluationService
        .getEvaluationsByJuryInVersion(juryId: juryId, versionId: versionId);

    // Affichage debug des roundId des évaluations récupérées
    for (final eval in evaluationsResponse) {
      print(
        'Evaluation roundId (normalisé): "${eval.roundId?.trim().toLowerCase()}"',
      );
    }

    final normalizedRoundId = roundId?.trim().toLowerCase();

    // 3. Construire set des participantIds évalués pour le round actif (comparaison normalisée)
    final Set<String> evaluatedParticipantIds =
        evaluationsResponse
            .where(
              (eval) =>
                  (eval.roundId?.trim().toLowerCase() ?? '') ==
                  (normalizedRoundId ?? ''),
            )
            .map((e) => e.participantId)
            .toSet();

    // 4. Marquer participants évalués
    final participantsWithStatus =
        participants.map((p) {
          p.isEvaluated = evaluatedParticipantIds.contains(p.id);
          print('Participant ${p.fullName} isEvaluated: ${p.isEvaluated}');
          return p;
        }).toList();

    setState(() {
      appUser = user;
      _allParticipants = participantsWithStatus;
      _applyFilter();
      _isLoading = false;
    });
  }

  Future<String?> _getActiveRoundIdForVersion(String versionId) async {
    RoundService _roundService = RoundService();
    // Exemple d'appel au service round pour récupérer le round actif
    final round = await _roundService.getActiveRound(versionId);
    setState(() {
      activeRound = round;
    });
    if (round == null) {
      print('Aucun round actif trouvé pour version $versionId');
      return null;
    }
    print('Round actif pour version $versionId : ${round.id}');
    return round.id;
  }

  void _applyFilter() {
    List<Participant> filtered =
        _allParticipants.where((p) => p.ageGroup == _selectedAgeGroup).toList();

    if (_selectedEvaluationStatus == 'evaluated') {
      filtered = filtered.where((p) => p.isEvaluated).toList();
    } else if (_selectedEvaluationStatus == 'notEvaluated') {
      filtered = filtered.where((p) => !p.isEvaluated).toList();
    }

    setState(() {
      _filteredParticipants = filtered;
    });
  }

  void _selectGroup(String group) {
    setState(() {
      _selectedAgeGroup = group;
      _applyFilter();
    });
  }

  void _selectEvaluationFilter(String filter) {
    setState(() {
      _selectedEvaluationStatus = filter;
      _applyFilter();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('تفاصيل النسخة: ${widget.version.name}')),
      floatingActionButton:
          _filteredParticipants.isEmpty
              ? Container()
              : Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                margin: const EdgeInsets.only(right: 30.0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () async {
                      if (appUser == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("❌ لم يتم العثور على حساب المستخدم"),
                          ),
                        );
                        return;
                      }

                      final EvaluationService _evaluationService =
                          EvaluationService();

                      final juryId = appUser?.id ?? '';

                      // 1. Récupérer toutes les évaluations faites par ce jury dans cette version
                      final evaluations = await _evaluationService
                          .getEvaluationsByJuryInVersion(
                            juryId: juryId,
                            versionId: widget.version.id,
                          );

                      await EvaluationService.exportEvaluatedParticipantsLocally(
                        context: context,
                        evaluations: evaluations,
                        participants: _filteredParticipants,
                        version: widget.version,
                        roundName:
                            activeRound!
                                .name!, // Tu peux aussi le récupérer dynamiquement
                        juryName: appUser!.fullName,
                        ageGroup: _selectedAgeGroup,
                      );
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("إرسال التصحيح"),
                        const SizedBox(width: 8),
                        const Icon(Icons.send, size: 25, color: Colors.white),
                      ],
                    ),
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
      body: Container(
        width: MediaQuery.of(context).size.width,
        padding: const EdgeInsets.symmetric(horizontal: 10.0),
        child:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                  children: [
                    // Dropdown pour groupe d’âge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.all(8.0),
                            child: DropdownButton<String>(
                              value: _selectedAgeGroup,
                              items:
                                  ['كبار', 'صغار'].map((group) {
                                    return DropdownMenuItem(
                                      value: group,
                                      child: Text(group),
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

                        // Dropdown pour statut évaluation
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.all(8.0),
                            child: DropdownButton<String>(
                              value: _selectedEvaluationStatus,
                              items: [
                                DropdownMenuItem(
                                  value: 'all',
                                  child: Text('الكل'),
                                ),
                                DropdownMenuItem(
                                  value: 'evaluated',
                                  child: Text('مقيم'),
                                ),
                                DropdownMenuItem(
                                  value: 'notEvaluated',
                                  child: Text('غير مقيم'),
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
                    // Liste des participants filtrés
                    Expanded(
                      child:
                          _filteredParticipants.isEmpty
                              ? Center(
                                child: Text('لا يوجد مشاركون في هذه الفئة'),
                              )
                              : ListView.builder(
                                itemCount: _filteredParticipants.length,
                                itemBuilder: (context, index) {
                                  final participant =
                                      _filteredParticipants[index];
                                  return ListTile(
                                    onTap: () {
                                      if (appUser != null) {
                                        context.push(
                                          '/jury/participant',
                                          extra: JuryEvaluationArgs(
                                            participant: participant,
                                            appUser: appUser!,
                                            version: widget.version,
                                          ),
                                        );
                                      }
                                    },
                                    title: Text(participant.fullName),
                                    subtitle: Text(
                                      'الفئة: ${participant.ageGroup}',
                                    ),
                                    trailing: Icon(
                                      participant.isEvaluated
                                          ? Icons.check_circle
                                          : Icons.error,
                                      color:
                                          participant.isEvaluated
                                              ? Colors.green
                                              : Colors.orange,
                                    ),
                                  );
                                },
                              ),
                    ),
                  ],
                ),
      ),
    );
  }
}
