class Participant {
  final String id;
  final String fullName; // الاسم الثلاثي
  final String gender; // الجنس (مثلاً "ذكر" أو "أنثى")
  final DateTime birthDate; // تاريخ الميلاد
  final int? registrationNumber; // رقم التسجيل
  final String phone; // رقم الهاتف
  final String quranMemorized; // كم حفظ من القرآن الكريم (عدد الأجزاء مثلاً)
  final String readingMethods; // عدد الروايات التي يقرأ بها
  final String residence; // مكان الإقامة الحالية
  final bool hasIjaza; // هل حصل على إجازة
  final bool wonPreviousRanks; // هل حصل على مراتب 1 أو 2 في مسابقات سابقة
  final bool participatedBefore; // هل شارك في نسخة سابقة من المسابقة
  final String ageGroup; // المجموعة العمرية ('كبار' أو 'صغار')
  final DateTime createdAt;
  bool isEvaluated;

  Participant({
    required this.id,
    required this.fullName,
    required this.gender,
    required this.birthDate,
     this.registrationNumber,
    required this.phone,
    required this.quranMemorized,
    required this.readingMethods,
    required this.residence,
    required this.hasIjaza,
    required this.wonPreviousRanks,
    required this.participatedBefore,
    required this.ageGroup,
    required this.createdAt,
    this.isEvaluated = false,
  });

  factory Participant.fromMap(Map<String, dynamic> map) {
    return Participant(
      id: map['id'] as String,
      fullName: map['full_name'] as String,
      gender: map['gender'] as String,
      birthDate: DateTime.parse(map['birth_date'] as String),
      registrationNumber: map['registration_number'] as int,
      phone: map['phone'] as String,
      quranMemorized: map['quran_memorized'] as String,
      readingMethods: map['reading_methods'] as String,
      residence: map['residence'] as String,
      hasIjaza: map['has_ijaza'] as bool,
      wonPreviousRanks: map['won_previous_ranks'] as bool,
      participatedBefore: map['participated_before'] as bool,
      ageGroup: map['age_group'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      isEvaluated: false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'full_name': fullName,
      'gender': gender,
      'birth_date': birthDate.toIso8601String(),
      'registration_number': registrationNumber,
      'phone': phone,
      'quran_memorized': quranMemorized,
      'reading_methods': readingMethods,
      'residence': residence,
      'has_ijaza': hasIjaza,
      'won_previous_ranks': wonPreviousRanks,
      'participated_before': participatedBefore,
      'age_group': ageGroup,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
