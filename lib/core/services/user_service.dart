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

  /// Récupère tous les jurys liés à une version (utilise la nouvelle structure round_jury_assignments)
  Future<List<AppUser>> getJurysByVersion(String versionId) async {
    try {
      print(
        '🔍 Récupération des jurys pour la version: $versionId (nouvelle structure)',
      );

      // 1. Récupérer tous les rounds de cette version
      final roundsResponse = await _supabase
          .from('rounds')
          .select('id')
          .eq('version_id', versionId);

      if (roundsResponse.isEmpty) {
        print('⚠️ Aucun round trouvé pour cette version');
        return [];
      }

      final roundIds =
          roundsResponse.map((round) => round['id'] as String).toList();
      print('📋 ${roundIds.length} rounds trouvés pour la version');

      // 2. Récupérer tous les jurys assignés à ces rounds
      final assignmentsResponse = await _supabase
          .from('round_jury_assignments')
          .select('user_id')
          .inFilter('round_id', roundIds);

      if (assignmentsResponse.isEmpty) {
        print('⚠️ Aucun jury assigné à cette version');
        return [];
      }

      // 3. Extraire les IDs des jurys uniques
      final juryIds =
          assignmentsResponse
              .map<String>((assignment) => assignment['user_id'] as String)
              .toSet()
              .toList();

      print('👥 ${juryIds.length} jurys uniques trouvés pour la version');

      // 4. Récupérer les profils des jurys
      final profilesResponse = await _supabase
          .from('profiles')
          .select()
          .inFilter('id', juryIds)
          .eq('role', 'jury');

      final jurysList =
          profilesResponse
              .map<AppUser>((profile) => AppUser.fromMap(profile))
              .toList();

      print('✅ ${jurysList.length} profils de jurys récupérés');

      return jurysList;
    } catch (e) {
      print('❌ Erreur dans getJurysByVersion: $e');
      return [];
    }
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
    // Récupérer tous les rounds de cette version
    final roundsResponse = await _supabase
        .from('rounds')
        .select('id')
        .eq('version_id', versionId);

    if (roundsResponse.isEmpty) {
      throw Exception('Aucun round trouvé pour cette version');
    }

    // Assigner le jury à tous les rounds de la version
    for (final round in roundsResponse) {
      await _supabase.from('round_jury_assignments').insert({
        'user_id': userId,
        'round_id': round['id'],
      });
    }
  }

  Future<void> removeJuryFromVersion({
    required String userId,
    required String versionId,
  }) async {
    // Récupérer tous les rounds de cette version
    final roundsResponse = await _supabase
        .from('rounds')
        .select('id')
        .eq('version_id', versionId);

    if (roundsResponse.isEmpty) {
      return; // Aucun round à traiter
    }

    final roundIds =
        roundsResponse.map((round) => round['id'] as String).toList();

    // Supprimer toutes les assignations du jury pour ces rounds
    await _supabase
        .from('round_jury_assignments')
        .delete()
        .eq('user_id', userId)
        .inFilter('round_id', roundIds);
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
