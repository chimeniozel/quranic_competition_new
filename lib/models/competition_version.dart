class CompetitionVersion {
  final String id;
  final String name;
  final int year;
  final bool isActive;
  final int maxAdults;
  final int maxChildren;
  final bool isRegistrationOpen;
  final bool juryEvaluationEnabled; // Autorisation pour les jurys d'évaluer

  CompetitionVersion({
    required this.id,
    required this.name,
    required this.year,
    required this.isActive,
    required this.maxAdults,
    required this.maxChildren,
    required this.isRegistrationOpen,
    this.juryEvaluationEnabled = false, // Par défaut : désactivé
  });

  factory CompetitionVersion.fromMap(Map<String, dynamic> map) {
    return CompetitionVersion(
      id: map['id'],
      name: map['name'],
      year: map['year'],
      isActive: map['is_active'],
      maxAdults: map['max_adults'] ?? 0,
      maxChildren: map['max_children'] ?? 0,
      isRegistrationOpen: map['is_registration_open'] ?? true,
      juryEvaluationEnabled: map['jury_evaluation_enabled'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'year': year,
      'is_active': isActive,
      'max_adults': maxAdults,
      'max_children': maxChildren,
      'is_registration_open': isRegistrationOpen,
      'jury_evaluation_enabled': juryEvaluationEnabled,
    };
  }
}
