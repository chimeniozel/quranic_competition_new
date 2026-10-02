import 'package:quranic_competition/models/participant.dart';
import 'package:quranic_competition/models/round.dart';

class RoundResult {
  final String id;
  final String participantId;
  final String roundId;
  final String versionId;
  final double score;
  final bool passed;
  final String ageGroup;
  final DateTime createdAt;
  final Participant participant;
  final Round round;

  /// Rang réel du participant dans le classement complet du round.
  /// Renseigné par le service : il reste correct même quand le résultat
  /// provient d'une recherche et non de la liste paginée.
  final int? rank;

  RoundResult({
    required this.id,
    required this.participantId,
    required this.roundId,
    required this.versionId,
    required this.score,
    required this.passed,
    required this.ageGroup,
    required this.createdAt,
    required this.participant,
    required this.round,
    this.rank,
  });

  RoundResult copyWith({int? rank}) {
    return RoundResult(
      id: id,
      participantId: participantId,
      roundId: roundId,
      versionId: versionId,
      score: score,
      passed: passed,
      ageGroup: ageGroup,
      createdAt: createdAt,
      participant: participant,
      round: round,
      rank: rank ?? this.rank,
    );
  }

  factory RoundResult.fromMap(Map<String, dynamic> map) {
    return RoundResult(
      id: map['id'],
      participantId: map['participant_id'],
      roundId: map['round_id'],
      versionId: map['version_id'],
      score: (map['score'] as num).toDouble(),
      passed: map['passed'] as bool,
      ageGroup: map['age_group'],
      createdAt: DateTime.parse(map['created_at']),
      rank: (map['rank'] as num?)?.toInt(),
      participant: Participant.fromMap(map['participants']),
      round: Round.fromMap(map['rounds']),
    );
  }
}
