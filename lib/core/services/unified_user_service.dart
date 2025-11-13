import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:quranic_competition/models/app_user.dart';
import 'package:quranic_competition/models/user_role.dart';
import 'package:quranic_competition/core/services/permission_service.dart';

/// Service unifié pour la gestion des utilisateurs
/// Utilise uniquement la table 'profiles' pour la cohérence
class UnifiedUserService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Récupère un utilisateur par son ID depuis la table profiles
  Future<AppUser?> getUserById(String id) async {
    try {
      final response =
          await _supabase.from('profiles').select().eq('id', id).maybeSingle();

      if (response == null) return null;

      return AppUser.fromMap(response);
    } catch (e) {
      print('Erreur lors de la récupération de l\'utilisateur: $e');
      return null;
    }
  }

  /// Récupère le profil de l'utilisateur connecté
  Future<AppUser?> getCurrentUserProfile() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null;
    return getUserById(userId);
  }

  /// Récupère tous les utilisateurs avec pagination et filtrage
  Future<Map<String, dynamic>> getUsersWithPagination({
    int page = 0,
    int limit = 20,
    String? searchQuery,
    String? roleFilter,
    bool? isValidatedFilter,
  }) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) {
        throw Exception('Utilisateur non connecté');
      }

      // Construire la requête de base
      var query = _supabase.from('profiles').select().neq('id', currentUserId);

      // Appliquer les filtres
      if (roleFilter != null && roleFilter != 'all') {
        query = query.eq('role', roleFilter);
      }

      if (isValidatedFilter != null) {
        query = query.eq('is_validated', isValidatedFilter);
      }

      // Récupérer tous les résultats pour le filtrage côté client
      final allUsers = await query.order('created_at', ascending: false);

      List<AppUser> users =
          allUsers.map<AppUser>((user) => AppUser.fromMap(user)).toList();

      // Appliquer la recherche côté client
      if (searchQuery != null && searchQuery.isNotEmpty) {
        users =
            users
                .where(
                  (user) =>
                      user.fullName.toLowerCase().contains(
                        searchQuery.toLowerCase(),
                      ) ||
                      user.phone.contains(searchQuery),
                )
                .toList();
      }

      // Pagination
      final totalCount = users.length;
      final startIndex = page * limit;
      final endIndex = (startIndex + limit).clamp(0, totalCount);

      final paginatedUsers = users.sublist(startIndex, endIndex);
      final hasMore = endIndex < totalCount;

      return {
        'users': paginatedUsers,
        'totalCount': totalCount,
        'hasMore': hasMore,
        'currentPage': page,
      };
    } catch (e) {
      print('Erreur lors de la récupération des utilisateurs: $e');
      throw Exception('Erreur lors de la récupération des utilisateurs: $e');
    }
  }

  /// Recherche des utilisateurs par nom ou téléphone
  Future<List<AppUser>> searchUsers(String query) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) {
        throw Exception('Utilisateur non connecté');
      }

      final response = await _supabase
          .from('profiles')
          .select()
          .neq('id', currentUserId)
          .or('full_name.ilike.%$query%,phone.ilike.%$query%')
          .order('created_at', ascending: false);

      return response.map<AppUser>((user) => AppUser.fromMap(user)).toList();
    } catch (e) {
      print('Erreur lors de la recherche des utilisateurs: $e');
      throw Exception('Erreur lors de la recherche des utilisateurs: $e');
    }
  }

  /// Récupère les utilisateurs par rôle
  Future<List<AppUser>> getUsersByRole(UserRole role) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) {
        throw Exception('Utilisateur non connecté');
      }

      final response = await _supabase
          .from('profiles')
          .select()
          .eq('role', role.code)
          .neq('id', currentUserId)
          .order('created_at', ascending: false);

      return response.map<AppUser>((user) => AppUser.fromMap(user)).toList();
    } catch (e) {
      print('Erreur lors de la récupération des utilisateurs par rôle: $e');
      throw Exception(
        'Erreur lors de la récupération des utilisateurs par rôle: $e',
      );
    }
  }

  /// Met à jour le rôle d'un utilisateur
  Future<void> updateUserRole(String userId, UserRole newRole) async {
    try {
      // Mettre à jour le rôle dans profiles (source de vérité)
      await _supabase
          .from('profiles')
          .update({
            'role': newRole.code,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);

      // Mettre à jour aussi userMetadata dans Supabase auth pour cohérence
      // Note: Cette opération nécessite les privilèges admin, donc on l'ignore si elle échoue
      try {
        final currentUser = _supabase.auth.currentUser;
        // Si c'est l'utilisateur actuel, on peut utiliser updateUser
        if (currentUser != null && currentUser.id == userId) {
          await _supabase.auth.updateUser(
            UserAttributes(data: {'role': newRole.code}),
          );
          // Forcer le rafraîchissement des permissions depuis la DB
          await PermissionService().refreshPermissions();
        } else {
          // Pour les autres utilisateurs, on essaie avec admin (peut échouer si pas admin)
          await _supabase.auth.admin.updateUserById(
            userId,
            attributes: AdminUserAttributes(userMetadata: {'role': newRole.code}),
          );
        }
      } catch (e) {
        // Si l'utilisateur n'est pas admin, on ne peut pas mettre à jour userMetadata
        // Ce n'est pas critique, le rôle dans profiles est la source de vérité
        print('⚠️ Impossible de mettre à jour userMetadata (normal si non-admin): $e');
      }
    } catch (e) {
      print('Erreur lors de la mise à jour du rôle: $e');
      throw Exception('Erreur lors de la mise à jour du rôle: $e');
    }
  }

  /// Valide ou désactive un utilisateur
  Future<void> updateUserValidationStatus(
    String userId,
    bool isValidated,
  ) async {
    try {
      await _supabase
          .from('profiles')
          .update({
            'is_validated': isValidated,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);
    } catch (e) {
      print('Erreur lors de la mise à jour du statut de validation: $e');
      throw Exception(
        'Erreur lors de la mise à jour du statut de validation: $e',
      );
    }
  }

  /// Met à jour les informations de profil d'un utilisateur
  Future<void> updateUserProfile(
    String userId, {
    String? fullName,
    String? phone,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (fullName != null) updateData['full_name'] = fullName;
      if (phone != null) updateData['phone'] = phone;

      await _supabase.from('profiles').update(updateData).eq('id', userId);
    } catch (e) {
      print('Erreur lors de la mise à jour du profil: $e');
      throw Exception('Erreur lors de la mise à jour du profil: $e');
    }
  }

  /// Supprime un utilisateur (soft delete)
  Future<void> deleteUser(String userId) async {
    try {
      await _supabase
          .from('profiles')
          .update({
            'is_validated': false,
            'role': 'deleted',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);
    } catch (e) {
      print('Erreur lors de la suppression de l\'utilisateur: $e');
      throw Exception('Erreur lors de la suppression de l\'utilisateur: $e');
    }
  }

  /// Obtient les statistiques des utilisateurs
  Future<Map<String, dynamic>> getUserStatistics() async {
    try {
      final superAdmins = await getUsersByRole(UserRole.superAdmin);
      final admins = await getUsersByRole(UserRole.admin);
      final juries = await getUsersByRole(UserRole.jury);
      final members = await getUsersByRole(UserRole.member);

      final totalUsers =
          superAdmins.length + admins.length + juries.length + members.length;

      // Récupérer le nombre d'utilisateurs validés
      final validatedResponse = await _supabase
          .from('profiles')
          .select('id')
          .eq('is_validated', true);

      final validatedUsers = validatedResponse.length;
      final unvalidatedUsers = totalUsers - validatedUsers;

      return {
        'total_users': totalUsers,
        'validated_users': validatedUsers,
        'unvalidated_users': unvalidatedUsers,
        'role_counts': {
          'super_admin': superAdmins.length,
          'admin': admins.length,
          'jury': juries.length,
          'member': members.length,
        },
        'validation_rate':
            totalUsers > 0 ? (validatedUsers / totalUsers * 100).round() : 0,
      };
    } catch (e) {
      print('Erreur lors du calcul des statistiques: $e');
      return {
        'total_users': 0,
        'validated_users': 0,
        'unvalidated_users': 0,
        'role_counts': {'super_admin': 0, 'admin': 0, 'jury': 0, 'member': 0},
        'validation_rate': 0,
      };
    }
  }

  /// Vérifie si un email est déjà utilisé
  Future<bool> isEmailAlreadyUsed(String email) async {
    try {
      final response =
          await _supabase
              .from('profiles')
              .select('id')
              .eq('email', email)
              .maybeSingle();

      return response != null;
    } catch (e) {
      print('Erreur lors de la vérification de l\'email: $e');
      return false;
    }
  }

  /// Vérifie si un téléphone est déjà utilisé
  Future<bool> isPhoneAlreadyUsed(String phone) async {
    try {
      final response =
          await _supabase
              .from('profiles')
              .select('id')
              .eq('phone', phone)
              .maybeSingle();

      return response != null;
    } catch (e) {
      print('Erreur lors de la vérification du téléphone: $e');
      return false;
    }
  }
}
