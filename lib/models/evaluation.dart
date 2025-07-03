import 'note_model.dart';

class Evaluation {
  final String id;
  final String participantId;
  final String juryId;
  final String versionId;
  final String roundId; // Référence à la table rounds
  final double totalScore;
  final String? notes; // Remarques générales
  final DateTime submittedAt;
  final NoteModel noteModel;

  Evaluation({
    required this.id,
    required this.participantId,
    required this.juryId,
    required this.versionId,
    required this.roundId,
    required this.totalScore,
    this.notes,
    required this.submittedAt,
    required this.noteModel,
  });

  factory Evaluation.fromMap(Map<String, dynamic> map, String ageGroup) {
    final notesJson = map['notes_json'] ?? {};

    return Evaluation(
      id: map['id'] as String,
      participantId: map['participant_id'] as String,
      juryId: map['jury_id'] as String,
      versionId: map['version_id'] as String,
      roundId: map['round_id'].toString(),
      totalScore: (map['total_score'] as num?)?.toDouble() ?? 0.0,
      notes: map['notes'] as String?,
      submittedAt: DateTime.parse(map['submitted_at'] as String),
      noteModel:
          ageGroup == "كبار"
              ? NoteModel.fromMapAdult(notesJson as Map<String, dynamic>)
              : NoteModel.fromMapChild(notesJson as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toMap(String ageGroup) {
    return {
      'id': id,
      'participant_id': participantId,
      'jury_id': juryId,
      'version_id': versionId,
      'round_id': roundId, // modification ici
      'total_score': totalScore,
      'notes': notes,
      'submitted_at': submittedAt.toIso8601String(),
      'notes_json':
          ageGroup == "كبار" ? noteModel.toMapAdult() : noteModel.toMapChild(),
    };
  }

  factory Evaluation.empty(String participantId) {
    return Evaluation(
      participantId: participantId,
      juryId: '',
      versionId: '',
      roundId: '',
      noteModel: NoteModel(
        noteTajwid: 0,
        noteHousnSawtt: 0,
        noteOu4oubetSawtt: 0,
        noteWaqfAndIbtidaa: 0,
        noteIltizamRiwaya: 0,
      ),
      id: '',
      totalScore: 0.0,
      submittedAt: DateTime.now(),
    );
  }
}
