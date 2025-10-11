class AppUser {
  final String id;
  final String fullName;
  final String phone;
  final String email;
  final String role; // participant, jury, admin, super_admin, membre_ordinaire
  final bool isVerified;
  final DateTime createdAt;

  AppUser({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.email,
    required this.role,
    required this.isVerified,
    required this.createdAt,
  });

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['id'],
      fullName: map['full_name'] ?? '',
      phone: map['phone'] ?? '',
      email:
          map['email'] ??
          '', // Peut être null si récupéré depuis profiles uniquement
      role: map['role'] ?? 'membre',
      isVerified:
          map['is_validated'] ??
          map['is_verified'] ??
          false, // Support des deux formats
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'full_name': fullName,
      'phone': phone,
      'email': email,
      'role': role,
      'is_validated': isVerified, // Utilise is_validated pour la table profiles
      'created_at': createdAt.toIso8601String(),
    };
  }
}
