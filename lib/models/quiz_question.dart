class QuizQuestion {
  final String id;
  final String levelId;
  final String question;
  final String? imageUrl;
  final int points;
  final int order;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const QuizQuestion({
    required this.id,
    required this.levelId,
    required this.question,
    this.imageUrl,
    required this.points,
    required this.order,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory QuizQuestion.fromMap(Map<String, dynamic> map) {
    return QuizQuestion(
      id: map['id'] as String,
      levelId: map['level_id'] as String,
      question: map['question'] as String,
      imageUrl: map['image_url'] as String?,
      points: map['points'] as int,
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
      'level_id': levelId,
      'question': question,
      'image_url': imageUrl,
      'points': points,
      'order': order,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  QuizQuestion copyWith({
    String? id,
    String? levelId,
    String? question,
    String? imageUrl,
    int? points,
    int? order,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return QuizQuestion(
      id: id ?? this.id,
      levelId: levelId ?? this.levelId,
      question: question ?? this.question,
      imageUrl: imageUrl ?? this.imageUrl,
      points: points ?? this.points,
      order: order ?? this.order,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'QuizQuestion(id: $id, levelId: $levelId, question: $question, imageUrl: $imageUrl, points: $points, order: $order, isActive: $isActive, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is QuizQuestion &&
        other.id == id &&
        other.levelId == levelId &&
        other.question == question &&
        other.imageUrl == imageUrl &&
        other.points == points &&
        other.order == order &&
        other.isActive == isActive &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode => id.hashCode;
}
