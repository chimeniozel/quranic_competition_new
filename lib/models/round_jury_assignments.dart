import 'package:uuid/uuid.dart';

class RoundJuryAssignment {
  final String id;
  final String userId;
  final String roundId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  RoundJuryAssignment({
    String? id,
    required this.userId,
    required this.roundId,
    this.createdAt,
    this.updatedAt,
  }) : id = id ?? const Uuid().v4();

  /// Conversion depuis JSON (par exemple, depuis Supabase)
  factory RoundJuryAssignment.fromJson(Map<String, dynamic> json) {
    return RoundJuryAssignment(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      roundId: json['round_id'] as String,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }

  /// Conversion en JSON (pour insertion/mise à jour Supabase)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'round_id': roundId,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// Copie avec modifications
  RoundJuryAssignment copyWith({
    String? id,
    String? userId,
    String? roundId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RoundJuryAssignment(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      roundId: roundId ?? this.roundId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() =>
      'RoundJuryAssignment(id: $id, userId: $userId, roundId: $roundId, createdAt: $createdAt, updatedAt: $updatedAt)';
}
