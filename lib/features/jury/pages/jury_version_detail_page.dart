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
  Round? _selectedRound;
  bool _allParticipantsEvaluated = false;
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

    // Récupérer tous les rounds pour cette version
    try {
      _allRounds = await RoundService().getRoundsByVersion(widget.version.id);
      print('🔍 Rounds trouvés: ${_allRounds.length}');
    } catch (e) {
      print('❌ Erreur lors du chargement des rounds: $e');
      _allRounds = [];
    }

    // Déterminer le round actif pour l'évaluation
    var activeRound = await RoundService().getActiveRound(widget.version.id);

    // Initialiser le round sélectionné avec le round actif, ou le premier round disponible
    Round? initialSelectedRound = activeRound;
    if (initialSelectedRound == null && _allRounds.isNotEmpty) {
      initialSelectedRound = _allRounds.first;
    }

    // S'assurer que le round sélectionné existe dans la liste
    if (initialSelectedRound != null) {
      final foundRound = _allRounds.firstWhere(
        (r) => r.id == initialSelectedRound!.id,
        orElse:
            () =>
                _allRounds.isNotEmpty
                    ? _allRounds.first
                    : initialSelectedRound!,
      );
      initialSelectedRound = foundRound;
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
    } else {
      // Si pas de round sélectionné, récupérer tous les participants de la version
      try {
        participants = await _participantService
            .fetchParticipantsByVersionAndRounds(versionId);
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
    final evaluationsResponse = await _evaluationService
        .getEvaluationsByJuryInVersion(juryId: juryId, versionId: versionId);

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
          print('Participant ${p.fullName} isEvaluated: ${p.isEvaluated}');
          return p;
        }).toList();

    // Vérifier si tous les participants sont évalués
    final allEvaluated = participantsWithStatus.every((p) => p.isEvaluated);

    print('📊 Participants chargés: ${participantsWithStatus.length}');
    print(
      '📊 Participants évalués: ${participantsWithStatus.where((p) => p.isEvaluated).length}',
    );
    print('📊 Tous évalués: $allEvaluated');

    setState(() {
      appUser = user;
      _allParticipants = participantsWithStatus;
      _allParticipantsEvaluated = allEvaluated;
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
      final participants = await _participantService
          .fetchParticipantsByVersionAndRounds(
            versionId,
            activeRound: _selectedRound,
          );

      // Récupérer évaluations du jury pour cette version
      final evaluationsResponse = await _evaluationService
          .getEvaluationsByJuryInVersion(juryId: juryId, versionId: versionId);

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

      // Vérifier si tous les participants sont évalués
      final allEvaluated = participantsWithStatus.every((p) => p.isEvaluated);

      setState(() {
        _allParticipants = participantsWithStatus;
        _allParticipantsEvaluated = allEvaluated;
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
          filtered
              .where((p) => p.registrationNumber.toString().contains(query))
              .toList();
    }

    print(
      '🔍 Filtrage: ${filtered.length} participants après filtrage (groupe: $_selectedAgeGroup, statut: $_selectedEvaluationStatus)',
    );

    setState(() {
      _filteredParticipants = filtered;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(widget.version.name),
            activeRound != null ? Text(" : ${activeRound?.name}") : Text(""),
            if (_allParticipantsEvaluated) ...[
              const SizedBox(width: 8),
              Chip(
                label: const Text(
                  'مكتمل',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
                backgroundColor: Colors.green,
              ),
            ],
          ],
        ),
      ),
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
                        roundName: _selectedRound?.name ?? 'Round',
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
                : SingleChildScrollView(
                  child: Column(
                    children: [
                      // Message de completion si tous sont évalués
                      if (_allParticipantsEvaluated)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.all(16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: Colors.green.shade600,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'تم تقييم جميع المشاركين',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade700,
                                      ),
                                    ),
                                    Text(
                                      'يمكن تصفح النتائج باستخدام الفلاتر أدناه',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.green.shade600,
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
                      Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'البحث عن المشاركين...',
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                        ),
                      ),

                      // Dropdown pour groupe d'âge
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
                      Container(
                        height: MediaQuery.of(context).size.height * 0.6,
                        child:
                            _filteredParticipants.isEmpty
                                ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.people_outline,
                                        size: 64,
                                        color: Colors.grey[400],
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        _allParticipants.isEmpty
                                            ? 'لا يوجد مشاركون في هذه النسخة'
                                            : 'لا يوجد مشاركون في هذه الفئة',
                                        style: TextStyle(
                                          fontSize: 18,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      if (_allParticipants.isEmpty) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                          'تأكد من وجود مشاركين مسجلين في هذه النسخة',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[500],
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ],
                                  ),
                                )
                                : ListView.builder(
                                  itemCount: _filteredParticipants.length,
                                  itemBuilder: (context, index) {
                                    final participant =
                                        _filteredParticipants[index];
                                    return ListTile(
                                      onTap: () {
                                        if (appUser != null &&
                                            _selectedRound != null) {
                                          // Déterminer si on est en mode lecture seule
                                          // Lecture seule si le round n'est pas actif OU s'il est publié
                                          final isReadOnly =
                                              !_selectedRound!.isActive ||
                                              _selectedRound!.resultIsPublished;

                                          context.push(
                                            '/jury/participant',
                                            extra: JuryEvaluationArgs(
                                              participant: participant,
                                              appUser: appUser!,
                                              version: widget.version,
                                              isReadOnly: isReadOnly,
                                              round: _selectedRound!,
                                            ),
                                          );
                                        }
                                      },
                                      title: Text(participant.fullName),
                                      subtitle: Text(
                                        'الفئة: ${participant.ageGroup}',
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            participant.isEvaluated
                                                ? Icons.check_circle
                                                : (_selectedRound != null &&
                                                    (!_selectedRound!
                                                            .isActive ||
                                                        _selectedRound!
                                                            .resultIsPublished))
                                                ? Icons.visibility
                                                : Icons.edit,
                                            color:
                                                participant.isEvaluated
                                                    ? Colors.green
                                                    : (_selectedRound != null &&
                                                        (!_selectedRound!
                                                                .isActive ||
                                                            _selectedRound!
                                                                .resultIsPublished))
                                                    ? Colors.blue
                                                    : Colors.orange,
                                          ),
                                          if (_selectedRound != null &&
                                              (!_selectedRound!.isActive ||
                                                  _selectedRound!
                                                      .resultIsPublished)) ...[
                                            const SizedBox(width: 8),
                                            Icon(
                                              Icons.lock_outline,
                                              color: Colors.grey.shade400,
                                              size: 16,
                                            ),
                                          ],
                                        ],
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
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.info, color: Colors.grey, size: 24),
            const SizedBox(width: 12),
            Text(
              'لا توجد جولات متاحة',
              style: TextStyle(color: Colors.grey, fontSize: 14),
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

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.event, color: Colors.blue, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButton<Round>(
              value: validSelectedRound,
              isExpanded: true,
              hint: const Text('اختر الجولة'),
              items:
                  _allRounds.map((round) {
                    final isActive = round.isActive;
                    final isPublished = round.resultIsPublished;
                    Color statusColor = Colors.black;

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
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              round.name.toString(),
                              style: TextStyle(color: statusColor),
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
        ],
      ),
    );
  }

  Widget _buildDisplayModeIndicator() {
    String title = '';
    String subtitle = '';
    Color color = Colors.blue;
    IconData icon = Icons.info;

    // Déterminer le mode basé sur le round sélectionné
    final isActive = _selectedRound != null && _selectedRound!.isActive;
    final isPublished =
        _selectedRound != null && _selectedRound!.resultIsPublished;

    if (_selectedRound != null) {
      title = '${_selectedRound!.name}';
      if (isActive && !isPublished) {
        title += ' ( لم تتم نشر النتائج )';
        subtitle = 'يمكن تقييم المشاركين في هذه الجولة';
        color = Colors.orange;
        icon = Icons.edit;
      } else if (isPublished) {
        title += ' ( تم نشر النتائج )';
        subtitle = 'عرض النتائج - وضع القراءة فقط';
        color = Colors.blue;
        icon = Icons.visibility;
      } else {
        title += '';
        subtitle = 'عرض النتائج - لا يمكن التعديل';
        // color = Colors.grey;
        icon = Icons.pause_circle;
      }
    } else {
      title = 'لا توجد جولة محددة';
      subtitle = 'اختر جولة لعرض المشاركين';
      // color = Colors.grey;
      icon = Icons.info;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 14,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(color: color.withOpacity(0.8), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
