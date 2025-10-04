class ParticipantVersion {
  final String id;
  final String participantId;
  final String versionId;
  final DateTime createdAt;
  bool passedRound1;

  ParticipantVersion({
    required this.id,
    required this.participantId,
    required this.versionId,
    required this.createdAt,
    required this.passedRound1,
  });

  factory ParticipantVersion.fromMap(Map<String, dynamic> map) {
    return ParticipantVersion(
      id: map['id'],
      participantId: map['participant_id'],
      versionId: map['version_id'],
      createdAt: DateTime.parse(map['created_at']),
      passedRound1: map['passed_round1'] as bool,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'participant_id': participantId,
      'version_id': versionId,
      'created_at': createdAt.toIso8601String(),
      'passed_round1': passedRound1,
    };
  }
}
