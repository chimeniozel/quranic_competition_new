class EidSession {
  final String id;
  final String name;
  final String? description;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isActive; // Si la session est active et visible
  final bool isOpen; // Si l'inscription est ouverte
  final DateTime createdAt;
  final DateTime updatedAt;

  EidSession({
    required this.id,
    required this.name,
    this.description,
    this.startDate,
    this.endDate,
    required this.isActive,
    required this.isOpen,
    required this.createdAt,
    required this.updatedAt,
  });

  factory EidSession.fromMap(Map<String, dynamic> map) {
    return EidSession(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      startDate: map['start_date'] != null
          ? DateTime.parse(map['start_date'] as String)
          : null,
      endDate: map['end_date'] != null
          ? DateTime.parse(map['end_date'] as String)
          : null,
      isActive: map['is_active'] as bool? ?? false,
      isOpen: map['is_open'] as bool? ?? false,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'is_active': isActive,
      'is_open': isOpen,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

