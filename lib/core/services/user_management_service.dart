import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:quranic_competition/models/user_role.dart';
import 'package:quranic_competition/core/services/permission_service.dart';

class UserManagementService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Helper method pour obtenir le nom d'affichage du rôle
  String _getRoleDisplayName(String role) {
    switch (role) {
      case 'super_admin':
        return 'مدير عام';
      case 'admin':
        return 'مدير';
      case 'jury':
        return 'عضو لجنة التحكيم';
      case 'membre':
        return 'عضو عادي';
      default:
        return 'عضو عادي';
    }
  }

  // Récupérer tous les utilisateurs avec leurs rôles
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      // Utiliser une fonction SQL pour récupérer les utilisateurs avec leurs emails
      final response = await _supabase.rpc('get_users_with_profiles');

      // Transformer les données
      return (response as List).map((user) {
        return {
          'id': user['id'],
          'email': user['email'] ?? '',
          'role': user['role'] ?? 'membre',
          'full_name': user['full_name'],
          'phone': user['phone'],
          'is_validated': user['is_validated'] ?? false,
          'created_at': user['created_at'],
          'updated_at': user['updated_at'],
          'role_display_name': _getRoleDisplayName(user['role'] ?? 'membre'),
        };
      }).toList();
    } catch (e) {
      print('Erreur lors de la récupération des utilisateurs: $e');
      throw Exception('Erreur lors de la récupération des utilisateurs: $e');
    }
  }

  // Récupérer un utilisateur par son ID
  Future<Map<String, dynamic>?> getUserById(String userId) async {
    try {
      final response = await _supabase.rpc(
        'get_user_by_id',
        params: {'user_id': userId},
      );

      if (response != null && response is List && response.isNotEmpty) {
        final user = response.first;
        return {
          'id': user['id'],
          'email': user['email'] ?? '',
          'role': user['role'] ?? 'membre',
          'full_name': user['full_name'],
          'phone': user['phone'],
          'is_validated': user['is_validated'] ?? false,
          'created_at': user['created_at'],
          'updated_at': user['updated_at'],
          'role_display_name': _getRoleDisplayName(user['role'] ?? 'membre'),
        };
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Mettre à jour le rôle d'un utilisateur
  Future<void> updateUserRole(String userId, UserRole newRole) async {
    try {
      await _supabase
          .from('profiles')
          .update({'role': newRole.code})
          .eq('id', userId);

      // Rafraîchir les permissions de l'utilisateur actuel si c'est lui-même
      final currentUser = _supabase.auth.currentUser;
      if (currentUser != null && currentUser.id == userId) {
        final permissionService = PermissionService();
        permissionService.setUserRole(newRole);
      }
    } catch (e) {
      throw Exception('Erreur lors de la mise à jour du rôle: $e');
    }
  }

  // Vérifier si un utilisateur a une permission spécifique
  Future<bool> userHasPermission(String userId, String permission) async {
    try {
      final response = await _supabase.rpc(
        'user_has_permission',
        params: {'user_id': userId, 'permission': permission},
      );

      return response as bool;
    } catch (e) {
      return false;
    }
  }

  // Obtenir les permissions d'un utilisateur
  Future<Map<String, bool>?> getUserPermissions(String userId) async {
    try {
      final response = await _supabase.rpc(
        'get_user_permissions',
        params: {'user_id': userId},
      );

      if (response != null && response is List && response.isNotEmpty) {
        final permissions = response.first as Map<String, dynamic>;
        return {
          'can_create_versions': permissions['can_create_versions'] as bool,
          'can_publish_content': permissions['can_publish_content'] as bool,
          'can_validate_accounts': permissions['can_validate_accounts'] as bool,
          'can_delete': permissions['can_delete'] as bool,
          'can_modify': permissions['can_modify'] as bool,
          'can_modify_versions': permissions['can_modify_versions'] as bool,
          'can_assign_roles': permissions['can_assign_roles'] as bool,
          'can_view_content': permissions['can_view_content'] as bool,
        };
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Rechercher des utilisateurs par email ou nom
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    try {
      final response = await _supabase.rpc(
        'search_users',
        params: {'search_query': query},
      );

      return (response as List).map((user) {
        return {
          'id': user['id'],
          'email': user['email'] ?? '',
          'role': user['role'] ?? 'membre',
          'full_name': user['full_name'],
          'phone': user['phone'],
          'is_validated': user['is_validated'] ?? false,
          'created_at': user['created_at'],
          'updated_at': user['updated_at'],
          'role_display_name': _getRoleDisplayName(user['role'] ?? 'membre'),
        };
      }).toList();
    } catch (e) {
      throw Exception('Erreur lors de la recherche des utilisateurs: $e');
    }
  }

  // Filtrer les utilisateurs par rôle
  Future<List<Map<String, dynamic>>> getUsersByRole(UserRole role) async {
    try {
      final response = await _supabase.rpc(
        'get_users_by_role',
        params: {'user_role': role.code},
      );

      return (response as List).map((user) {
        return {
          'id': user['id'],
          'email': user['email'] ?? '',
          'role': user['role'] ?? 'membre',
          'full_name': user['full_name'],
          'phone': user['phone'],
          'is_validated': user['is_validated'] ?? false,
          'created_at': user['created_at'],
          'updated_at': user['updated_at'],
          'role_display_name': _getRoleDisplayName(user['role'] ?? 'membre'),
        };
      }).toList();
    } catch (e) {
      throw Exception(
        'Erreur lors de la récupération des utilisateurs par rôle: $e',
      );
    }
  }

  // Compter les utilisateurs par rôle
  Future<Map<String, int>> getUserRoleCounts() async {
    try {
      final superAdmins = await getUsersByRole(UserRole.superAdmin);
      final admins = await getUsersByRole(UserRole.admin);
      final juries = await getUsersByRole(UserRole.jury);
      final members = await getUsersByRole(UserRole.member);

      return {
        'super_admin': superAdmins.length,
        'admin': admins.length,
        'jury': juries.length,
        'member': members.length,
        'total':
            superAdmins.length + admins.length + juries.length + members.length,
      };
    } catch (e) {
      return {'super_admin': 0, 'admin': 0, 'jury': 0, 'member': 0, 'total': 0};
    }
  }

  // Valider un compte utilisateur (changer le statut de validation)
  Future<void> validateUserAccount(String userId, bool isValidated) async {
    try {
      await _supabase
          .from('profiles')
          .update({'is_validated': isValidated})
          .eq('id', userId);
    } catch (e) {
      throw Exception('Erreur lors de la validation du compte: $e');
    }
  }

  // Mettre à jour le statut de vérification d'un utilisateur (alias pour validateUserAccount)
  Future<void> updateUserVerificationStatus(
    String userId,
    bool isVerified,
  ) async {
    return await validateUserAccount(userId, isVerified);
  }

  // Obtenir les statistiques des utilisateurs
  Future<Map<String, dynamic>> getUserStatistics() async {
    try {
      final roleCounts = await getUserRoleCounts();
      final allUsers = await getAllUsers();

      final totalUsers = allUsers.length;
      final validatedUsers =
          allUsers.where((user) => user['is_validated'] == true).length;
      final unvalidatedUsers = totalUsers - validatedUsers;

      return {
        'total_users': totalUsers,
        'validated_users': validatedUsers,
        'unvalidated_users': unvalidatedUsers,
        'role_counts': roleCounts,
        'validation_rate':
            totalUsers > 0 ? (validatedUsers / totalUsers * 100).round() : 0,
      };
    } catch (e) {
      return {
        'total_users': 0,
        'validated_users': 0,
        'unvalidated_users': 0,
        'role_counts': {
          'super_admin': 0,
          'admin': 0,
          'jury': 0,
          'member': 0,
          'total': 0,
        },
        'validation_rate': 0,
      };
    }
  }

  // Créer un nouvel utilisateur avec un rôle spécifique
  Future<void> createUserWithRole({
    required String email,
    required String password,
    required UserRole role,
    String? fullName,
  }) async {
    try {
      // Créer l'utilisateur via l'API d'authentification
      final response = await _supabase.auth.admin.createUser(
        AdminUserAttributes(
          email: email,
          password: password,
          userMetadata: {'full_name': fullName, 'role': role.code},
        ),
      );

      if (response.user != null) {
        // Mettre à jour le rôle dans la table profiles
        await _supabase
            .from('profiles')
            .update({'role': role.code})
            .eq('id', response.user!.id);
      }
    } catch (e) {
      throw Exception('Erreur lors de la création de l\'utilisateur: $e');
    }
  }

  // Supprimer un utilisateur (Super Admin seulement)
  Future<void> deleteUser(String userId) async {
    try {
      await _supabase.auth.admin.deleteUser(userId);
    } catch (e) {
      throw Exception('Erreur lors de la suppression de l\'utilisateur: $e');
    }
  }
}
