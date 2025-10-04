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
  });

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
      participant: Participant.fromMap(map['participants']),
      round: Round.fromMap(map['rounds']),
    );
  }
}