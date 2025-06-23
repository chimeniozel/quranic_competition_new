import 'note_model.dart';

class Evaluation {
  final String id;
  final String participantId;
  final String juryId;
  final String versionId;
  final int round; // 1 ou 2
  final double totalScore;
  final String? notes; // Remarques générales
  final DateTime submittedAt;
  final NoteModel noteModel;

  Evaluation({
    required this.id,
    required this.participantId,
    required this.juryId,
    required this.versionId,
    required this.round,
    required this.totalScore,
    this.notes,
    required this.submittedAt,
    required this.noteModel,
  });

  factory Evaluation.fromMap(Map<String, dynamic> map, String ageGroup) {
    return Evaluation(
      id: map['id'],
      participantId: map['participant_id'],
      juryId: map['jury_id'],
      versionId: map['version_id'],
      round: map['round'],
      totalScore: (map['total_score'] ?? 0.0).toDouble(),
      notes: map['notes'],
      submittedAt: DateTime.parse(map['submitted_at']),
      noteModel: ageGroup == "كبار"
          ? NoteModel.fromMapAdult(map['notes_json'] ?? {})
          : NoteModel.fromMapChild(map['notes_json'] ?? {}),
    );
  }

  Map<String, dynamic> toMap(String ageGroup) {
    return {
      'id': id,
      'participant_id': participantId,
      'jury_id': juryId,
      'version_id': versionId,
      'round': round,
      'total_score': totalScore,
      'notes': notes,
      'submitted_at': submittedAt.toIso8601String(),
      'notes_json': ageGroup == "كبار"
          ? noteModel.toMapAdult()
          : noteModel.toMapChild(),
    };
  }
}
