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
      // Mettre à jour le rôle dans profiles (source de vérité)
      await _supabase
          .from('profiles')
          .update({'role': newRole.code})
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

      // Rafraîchir les permissions de l'utilisateur actuel si c'est lui-même
      final currentUser = _supabase.auth.currentUser;
      if (currentUser != null && currentUser.id == userId) {
        // Forcer le rafraîchissement depuis la DB
        await PermissionService().refreshPermissions();
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
      final response = await _supabase
          .from('profiles')
          .select(
            'can_create_versions, can_publish_content, can_validate_accounts, '
            'can_delete, can_modify, can_modify_versions, can_assign_roles, '
            'can_view_content',
          )
          .eq('id', userId)
          .maybeSingle();

      if (response == null) return null;

      // Vérifier si les colonnes de permissions existent (au moins une valeur non null)
      final hasPermissions = response['can_create_versions'] != null ||
          response['can_publish_content'] != null ||
          response['can_validate_accounts'] != null;

      if (!hasPermissions) return null;

      return {
        'can_create_versions': (response['can_create_versions'] as bool?) ?? false,
        'can_publish_content': (response['can_publish_content'] as bool?) ?? false,
        'can_validate_accounts': (response['can_validate_accounts'] as bool?) ?? false,
        'can_delete': (response['can_delete'] as bool?) ?? false,
        'can_modify': (response['can_modify'] as bool?) ?? false,
        'can_modify_versions': (response['can_modify_versions'] as bool?) ?? false,
        'can_assign_roles': (response['can_assign_roles'] as bool?) ?? false,
        'can_view_content': (response['can_view_content'] as bool?) ?? false,
      };
    } catch (e) {
      print('⚠️ Erreur lors de la récupération des permissions: $e');
      return null;
    }
  }

  Future<void> updateUserPermissions(
    String userId,
    Map<String, bool> permissions,
  ) async {
    try {
      await _supabase.from('profiles').update({
        'can_create_versions': permissions['can_create_versions'],
        'can_publish_content': permissions['can_publish_content'],
        'can_validate_accounts': permissions['can_validate_accounts'],
        'can_delete': permissions['can_delete'],
        'can_modify': permissions['can_modify'],
        'can_modify_versions': permissions['can_modify_versions'],
        'can_assign_roles': permissions['can_assign_roles'],
        'can_view_content': permissions['can_view_content'],
      }).eq('id', userId);

      // Rafraîchir les permissions de l'utilisateur actuel si c'est lui-même
      final currentUser = _supabase.auth.currentUser;
      if (currentUser != null && currentUser.id == userId) {
        // Forcer le rafraîchissement depuis la DB
        await PermissionService().refreshPermissions();
      }
    } catch (e) {
      throw Exception('Erreur lors de la mise à jour des permissions: $e');
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
      print('🗑️ Tentative de suppression de l\'utilisateur: $userId');
      
      // Supprimer d'abord les assignations de jury si l'utilisateur est un jury
      try {
        await _supabase
            .from('round_jury_assignments')
            .delete()
            .eq('user_id', userId);
        print('✅ Assignations de jury supprimées');
      } catch (e) {
        print('⚠️ Erreur lors de la suppression des assignations: $e');
        // Continuer même si la suppression des assignations échoue
      }

      // Supprimer le profil de la table profiles
      try {
        await _supabase
            .from('profiles')
            .delete()
            .eq('id', userId);
        print('✅ Profil supprimé de la table profiles');
      } catch (e) {
        print('⚠️ Erreur lors de la suppression du profil: $e');
        // Continuer même si la suppression du profil échoue
      }

      // Supprimer l'utilisateur de Supabase Auth
      try {
        await _supabase.auth.admin.deleteUser(userId);
        print('✅ Utilisateur supprimé de Supabase Auth');
      } catch (e) {
        print('❌ Erreur lors de la suppression de Supabase Auth: $e');
        // Si la suppression de Auth échoue, vérifier si le profil a été supprimé
        final profileExists = await _supabase
            .from('profiles')
            .select('id')
            .eq('id', userId)
            .maybeSingle();
        
        if (profileExists == null) {
          // Le profil a été supprimé, considérer comme succès partiel
          print('✅ Profil supprimé mais Auth a échoué - considéré comme succès');
          return;
        }
        
        // Si le profil existe encore, lancer une exception
        throw Exception('فشل حذف المستخدم من نظام المصادقة. قد تحتاج إلى صلاحيات إدارية خاصة.');
      }
    } catch (e) {
      print('❌ Erreur complète lors de la suppression: $e');
      throw Exception('خطأ أثناء حذف المستخدم: ${e.toString()}');
    }
  }
}
