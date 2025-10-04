class QuizLevel {
  final String id;
  final String name;
  final String description;
  final int order;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const QuizLevel({
    required this.id,
    required this.name,
    required this.description,
    required this.order,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory QuizLevel.fromMap(Map<String, dynamic> map) {
    return QuizLevel(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String,
      order: map['order'] as int,
      isActive: map['is_active'] as bool,
      createdAt: DateTime.parse(
        map['created_at'] ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        map['updated_at'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'order': order,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  QuizLevel copyWith({
    String? id,
    String? name,
    String? description,
    int? order,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return QuizLevel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      order: order ?? this.order,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'QuizLevel(id: $id, name: $name, description: $description, order: $order, isActive: $isActive, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is QuizLevel &&
        other.id == id &&
        other.name == name &&
        other.description == description &&
        other.order == order &&
        other.isActive == isActive &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode => id.hashCode;
}
