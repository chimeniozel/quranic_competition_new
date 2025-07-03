class Round {
  final String id;
  final String versionId;
  final int number;
  final String? name;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isActive;

  Round({
    required this.id,
    required this.versionId,
    required this.number,
    this.name,
    this.startDate,
    this.endDate,
    this.isActive = true,
  });

  factory Round.fromMap(Map<String, dynamic> map) {
  return Round(
    id: map['id'].toString(),
    versionId: map['version_id'] is String ? map['version_id'] : map['version_id'].toString(),
    number: map['number'] is int ? map['number'] : int.parse(map['number'].toString()),
    name: map['name'],
    startDate: map['start_date'] != null ? DateTime.parse(map['start_date']) : null,
    endDate: map['end_date'] != null ? DateTime.parse(map['end_date']) : null,
    isActive: map['is_active'] ?? true,
  );
}


  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'version_id': versionId,
      'number': number,
      'name': name,
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'is_active': isActive,
    };
  }
}
