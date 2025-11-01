class EidParticipant {
  final String id;
  final String sessionId;
  final String fullName;
  final String phone;
  final String gender; // 'ذكر' ou 'أنثى'
  final bool isWinner; // Si le participant a été sélectionné par la loterie
  final DateTime createdAt;

  EidParticipant({
    required this.id,
    required this.sessionId,
    required this.fullName,
    required this.phone,
    required this.gender,
    this.isWinner = false,
    required this.createdAt,
  });

  factory EidParticipant.fromMap(Map<String, dynamic> map) {
    return EidParticipant(
      id: map['id'] as String,
      sessionId: map['session_id'] as String,
      fullName: map['full_name'] as String,
      phone: map['phone'] as String,
      gender: map['gender'] as String,
      isWinner: map['is_winner'] as bool? ?? false,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'session_id': sessionId,
      'full_name': fullName,
      'phone': phone,
      'gender': gender,
      'is_winner': isWinner,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

