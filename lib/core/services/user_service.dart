import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:quranic_competition/models/app_user.dart';

class UserService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Récupère un utilisateur par son ID
  Future<AppUser?> getUserById(String id) async {
    final response =
        await _supabase.from('users').select().eq('id', id).maybeSingle();

    if (response == null) return null;

    return AppUser.fromMap(response);
  }

  /// Récupère tous les jurys liés à une version
  Future<List<AppUser>> getJurysByVersion(String versionId) async {
    final response = await _supabase
        .from('jury_assignments') // nom correct de ta table de lien
        .select(
          'users(*)',
        ) // récupère les données de l'utilisateur via la relation
        .eq('version_id', versionId);

    // Assure-toi que response est bien une List
    return response
        .map<AppUser>((item) => AppUser.fromMap(item['users']))
        .toList();
  }

  /// (Optionnel) Récupère l'utilisateur connecté
  Future<AppUser?> getCurrentUserProfile() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null;
    return getUserById(userId);
  }

  Future<List<AppUser>> getAllJurys() async {
    final response = await _supabase.from('users').select().eq('role', 'jury');
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
    // Supprimer les évaluations d'abord
    await _supabase
        .from('evaluations')
        .delete()
        .eq('jury_id', userId)
        .eq('version_id', versionId);

    // Supprimer l'entrée dans jury_assignments
    await _supabase
        .from('jury_assignments')
        .delete()
        .eq('user_id', userId)
        .eq('version_id', versionId);
  }

}
