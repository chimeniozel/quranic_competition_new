class JuryAssignments {
  final String id;
  final String userId;
  final String versionId;
  final DateTime assignedAt;

  JuryAssignments({
    required this.id,
    required this.userId,
    required this.versionId,
    required this.assignedAt,
  });

  factory JuryAssignments.fromMap(Map<String, dynamic> map) {
    return JuryAssignments(
      id: map['id'],
      userId: map['user_id'],
      versionId: map['version_id'],
      assignedAt: DateTime.parse(map['assigned_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'version_id': versionId,
      'assigned_at': assignedAt.toIso8601String(),
    };
  }
}
