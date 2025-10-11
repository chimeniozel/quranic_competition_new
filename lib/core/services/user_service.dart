import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:quranic_competition/models/app_user.dart';

class UserService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Récupère un utilisateur par son ID depuis la table profiles
  Future<AppUser?> getUserById(String id) async {
    final response =
        await _supabase.from('profiles').select().eq('id', id).maybeSingle();

    if (response == null) return null;

    return AppUser.fromMap(response);
  }

  /// Récupère tous les jurys liés à une version
  Future<List<AppUser>> getJurysByVersion(String versionId) async {
    final response = await _supabase
        .from('jury_assignments')
        .select(
          'profiles(*)',
        ) // récupère les données de l'utilisateur via la relation avec profiles
        .eq('version_id', versionId);

    // Assure-toi que response est bien une List
    return response
        .map<AppUser>((item) => AppUser.fromMap(item['profiles']))
        .toList();
  }

  /// (Optionnel) Récupère l'utilisateur connecté
  Future<AppUser?> getCurrentUserProfile() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null;
    return getUserById(userId);
  }

  Future<List<AppUser>> getAllJurys() async {
    final response = await _supabase
        .from('profiles')
        .select()
        .eq('role', 'jury');
    return (response as List).map((e) => AppUser.fromMap(e)).toList();
  }

  Future<void> assignJuryToVersion({
    required String userId,
    required String versionId,
  }) async {
    await _supabase.from('jury_assignments').insert({
      'user_id': userId,
      'version_id': versionId,
    });
  }

  Future<void> removeJuryFromVersion({
    required String userId,
    required String versionId,
  }) async {
    await _supabase
        .from('jury_assignments')
        .delete()
        .eq('user_id', userId)
        .eq('version_id', versionId);
  }

  /// Récupère tous les utilisateurs sauf l'utilisateur connecté
  Future<List<AppUser>> getAllUsersExceptCurrent() async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) {
      throw Exception('Utilisateur non connecté');
    }

    final response = await _supabase
        .from('profiles')
        .select()
        .neq('id', currentUserId)
        .order('created_at', ascending: false);

    return response.map<AppUser>((user) => AppUser.fromMap(user)).toList();
  }

  /// Récupère les utilisateurs avec pagination
  Future<Map<String, dynamic>> getUsersWithPagination({
    int page = 0,
    int limit = 20,
    String? searchQuery,
    String? filter,
  }) async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) {
      throw Exception('Utilisateur non connecté');
    }

    // Récupérer tous les utilisateurs d'abord (pour simplifier)
    final allUsers = await _supabase
        .from('profiles')
        .select()
        .neq('id', currentUserId)
        .order('created_at', ascending: false);

    List<AppUser> users =
        allUsers.map<AppUser>((user) => AppUser.fromMap(user)).toList();

    // Appliquer les filtres côté client
    if (filter != null && filter != 'all') {
      switch (filter) {
        case 'verified':
          users = users.where((user) => user.isVerified).toList();
          break;
        case 'unverified':
          users = users.where((user) => !user.isVerified).toList();
          break;
        case 'jury':
          users = users.where((user) => user.role == 'jury').toList();
          break;
        case 'admin':
          users =
              users
                  .where(
                    (user) =>
                        user.role == 'admin' || user.role == 'super_admin',
                  )
                  .toList();
          break;
      }
    }

    // Appliquer la recherche côté client
    if (searchQuery != null && searchQuery.isNotEmpty) {
      users =
          users
              .where(
                (user) =>
                    user.fullName.toLowerCase().contains(
                      searchQuery.toLowerCase(),
                    ) ||
                    user.email.toLowerCase().contains(
                      searchQuery.toLowerCase(),
                    ) ||
                    user.phone.contains(searchQuery),
              )
              .toList();
    }

    final totalCount = users.length;
    final startIndex = page * limit;
    final endIndex = (startIndex + limit).clamp(0, totalCount);

    // Pagination côté client
    final paginatedUsers = users.sublist(startIndex, endIndex);
    final hasMore = endIndex < totalCount;

    return {
      'users': paginatedUsers,
      'totalCount': totalCount,
      'hasMore': hasMore,
      'currentPage': page,
    };
  }

  /// Valide ou désactive un utilisateur
  Future<void> updateUserVerificationStatus({
    required String userId,
    required bool isVerified,
  }) async {
    await _supabase
        .from('profiles')
        .update({'is_validated': isVerified})
        .eq('id', userId);
  }

  /// Met à jour le rôle d'un utilisateur
  Future<void> updateUserRole({
    required String userId,
    required String newRole,
  }) async {
    await _supabase.from('profiles').update({'role': newRole}).eq('id', userId);
  }

  /// Récupère les utilisateurs par rôle
  Future<List<AppUser>> getUsersByRole(String role) async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) {
      throw Exception('Utilisateur non connecté');
    }

    final response = await _supabase
        .from('profiles')
        .select()
        .eq('role', role)
        .neq('id', currentUserId)
        .order('created_at', ascending: false);

    return response.map<AppUser>((user) => AppUser.fromMap(user)).toList();
  }

  /// Récupère les utilisateurs validés
  Future<List<AppUser>> getVerifiedUsers() async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) {
      throw Exception('Utilisateur non connecté');
    }

    final response = await _supabase
        .from('profiles')
        .select()
        .eq('is_validated', true)
        .neq('id', currentUserId)
        .order('created_at', ascending: false);

    return response.map<AppUser>((user) => AppUser.fromMap(user)).toList();
  }

  /// Récupère les utilisateurs non validés
  Future<List<AppUser>> getUnverifiedUsers() async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) {
      throw Exception('Utilisateur non connecté');
    }

    final response = await _supabase
        .from('profiles')
        .select()
        .eq('is_validated', false)
        .neq('id', currentUserId)
        .order('created_at', ascending: false);

    return response.map<AppUser>((user) => AppUser.fromMap(user)).toList();
  }

  /// Supprime un utilisateur (soft delete ou hard delete selon les besoins)
  Future<void> deleteUser(String userId) async {
    // Option 1: Soft delete - marquer comme supprimé
    await _supabase
        .from('profiles')
        .update({'is_validated': false, 'role': 'deleted'})
        .eq('id', userId);

    // Option 2: Hard delete (décommentez si nécessaire)
    // await _supabase.from('profiles').delete().eq('id', userId);
  }
}
