class QuizOption {
  final String id;
  final String questionId;
  final String text;
  final bool isCorrect;
  final int order;
  final DateTime createdAt;

  const QuizOption({
    required this.id,
    required this.questionId,
    required this.text,
    required this.isCorrect,
    required this.order,
    required this.createdAt,
  });

  factory QuizOption.fromMap(Map<String, dynamic> map) {
    return QuizOption(
      id: map['id'] as String,
      questionId: map['question_id'] as String,
      text: map['text'] as String,
      isCorrect: map['is_correct'] as bool,
      order: map['order'] as int,
      createdAt: DateTime.parse(
        map['created_at'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'question_id': questionId,
      'text': text,
      'is_correct': isCorrect,
      'order': order,
      'created_at': createdAt.toIso8601String(),
    };
  }

  QuizOption copyWith({
    String? id,
    String? questionId,
    String? text,
    bool? isCorrect,
    int? order,
    DateTime? createdAt,
  }) {
    return QuizOption(
      id: id ?? this.id,
      questionId: questionId ?? this.questionId,
      text: text ?? this.text,
      isCorrect: isCorrect ?? this.isCorrect,
      order: order ?? this.order,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'QuizOption(id: $id, questionId: $questionId, text: $text, isCorrect: $isCorrect, order: $order, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is QuizOption &&
        other.id == id &&
        other.questionId == questionId &&
        other.text == text &&
        other.isCorrect == isCorrect &&
        other.order == order &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode => id.hashCode;
}
