class QuizResult {
  final String id;
  final String participantId;
  final String participantName;
  final String levelId;
  final String levelName;
  final int totalQuestions;
  final int correctAnswers;
  final int totalPoints;
  final int earnedPoints;
  final double percentage;
  final DateTime completedAt;
  final Map<String, String> answers; // questionId -> optionId

  const QuizResult({
    required this.id,
    required this.participantId,
    required this.participantName,
    required this.levelId,
    required this.levelName,
    required this.totalQuestions,
    required this.correctAnswers,
    required this.totalPoints,
    required this.earnedPoints,
    required this.percentage,
    required this.completedAt,
    required this.answers,
  });

  factory QuizResult.fromMap(Map<String, dynamic> map) {
    return QuizResult(
      id: map['id'] as String,
      participantId: map['participant_id'] as String,
      participantName: map['participant_name'] as String,
      levelId: map['level_id'] as String,
      levelName: map['level_name'] as String,
      totalQuestions: map['total_questions'] as int,
      correctAnswers: map['correct_answers'] as int,
      totalPoints: map['total_points'] as int,
      earnedPoints: map['earned_points'] as int,
      percentage: (map['percentage'] as num).toDouble(),
      completedAt: DateTime.parse(
        map['completed_at'] ?? DateTime.now().toIso8601String(),
      ),
      answers: Map<String, String>.from(
        map['answers'] as Map<String, dynamic>? ?? {},
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'participant_id': participantId,
      'participant_name': participantName,
      'level_id': levelId,
      'level_name': levelName,
      'total_questions': totalQuestions,
      'correct_answers': correctAnswers,
      'total_points': totalPoints,
      'earned_points': earnedPoints,
      'percentage': percentage,
      'completed_at': completedAt.toIso8601String(),
      'answers': answers,
    };
  }

  QuizResult copyWith({
    String? id,
    String? participantId,
    String? participantName,
    String? levelId,
    String? levelName,
    int? totalQuestions,
    int? correctAnswers,
    int? totalPoints,
    int? earnedPoints,
    double? percentage,
    DateTime? completedAt,
    Map<String, String>? answers,
  }) {
    return QuizResult(
      id: id ?? this.id,
      participantId: participantId ?? this.participantId,
      participantName: participantName ?? this.participantName,
      levelId: levelId ?? this.levelId,
      levelName: levelName ?? this.levelName,
      totalQuestions: totalQuestions ?? this.totalQuestions,
      correctAnswers: correctAnswers ?? this.correctAnswers,
      totalPoints: totalPoints ?? this.totalPoints,
      earnedPoints: earnedPoints ?? this.earnedPoints,
      percentage: percentage ?? this.percentage,
      completedAt: completedAt ?? this.completedAt,
      answers: answers ?? this.answers,
    );
  }

  String get grade {
    if (percentage >= 90) return 'ممتاز';
    if (percentage >= 80) return 'جيد جداً';
    if (percentage >= 70) return 'جيد';
    if (percentage >= 60) return 'مقبول';
    return 'ضعيف';
  }

  String get gradeColor {
    if (percentage >= 90) return 'green';
    if (percentage >= 80) return 'blue';
    if (percentage >= 70) return 'orange';
    if (percentage >= 60) return 'yellow';
    return 'red';
  }

  @override
  String toString() {
    return 'QuizResult(id: $id, participantId: $participantId, participantName: $participantName, levelId: $levelId, levelName: $levelName, totalQuestions: $totalQuestions, correctAnswers: $correctAnswers, totalPoints: $totalPoints, earnedPoints: $earnedPoints, percentage: $percentage, completedAt: $completedAt, answers: $answers)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is QuizResult &&
        other.id == id &&
        other.participantId == participantId &&
        other.participantName == participantName &&
        other.levelId == levelId &&
        other.levelName == levelName &&
        other.totalQuestions == totalQuestions &&
        other.correctAnswers == correctAnswers &&
        other.totalPoints == totalPoints &&
        other.earnedPoints == earnedPoints &&
        other.percentage == percentage &&
        other.completedAt == completedAt &&
        other.answers == answers;
  }

  @override
  int get hashCode => id.hashCode;
}
