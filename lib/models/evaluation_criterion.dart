class EvaluationCriterion {
  final String id;
  final String evaluationId;
  final String criterion;
  final double score;

  EvaluationCriterion({
    required this.id,
    required this.evaluationId,
    required this.criterion,
    required this.score,
  });

  factory EvaluationCriterion.fromMap(Map<String, dynamic> map) {
    return EvaluationCriterion(
      id: map['id'],
      evaluationId: map['evaluation_id'],
      criterion: map['criterion'],
      score: map['score']?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'evaluation_id': evaluationId,
      'criterion': criterion,
      'score': score,
    };
  }
}
