import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:quranic_competition/models/app_user.dart';
import 'package:quranic_competition/models/round.dart';

class RoundJuryService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Récupère tous les jurys assignés à un round spécifique
  Future<List<AppUser>> getJurysByRound(String roundId) async {
    try {
      print('🔍 Récupération des jurys pour le round: $roundId');

      // Essayer d'abord avec la jointure profiles(*)
      try {
        final response = await _supabase
            .from('round_jury_assignments')
            .select('profiles(*)')
            .eq('round_id', roundId);

        print('✅ Jointure réussie: ${response.length} jurys trouvés');

        return response
            .map<AppUser>((item) => AppUser.fromMap(item['profiles']))
            .toList();
      } catch (joinError) {
        print('⚠️ Jointure échouée: $joinError');
        print('🔄 Utilisation de la méthode alternative...');
      }

      // Méthode alternative: récupérer les IDs puis les profils
      final assignmentsResponse = await _supabase
          .from('round_jury_assignments')
          .select('user_id')
          .eq('round_id', roundId);

      print('📋 ${assignmentsResponse.length} assignments trouvés');

      if (assignmentsResponse.isEmpty) {
        print('⚠️ Aucun jury assigné à ce round');
        return [];
      }

      final userIds =
          assignmentsResponse
              .map<String>((assignment) => assignment['user_id'] as String)
              .toList();

      print('👥 IDs des jurys: $userIds');

      // Récupérer les profils des utilisateurs
      final profilesResponse = await _supabase
          .from('profiles')
          .select()
          .inFilter('id', userIds)
          .eq('role', 'jury');

      print('✅ ${profilesResponse.length} profils de jurys récupérés');

      return profilesResponse
          .map<AppUser>((profile) => AppUser.fromMap(profile))
          .toList();
    } catch (e) {
      print('❌ Erreur lors de la récupération des jurys: $e');
      return [];
    }
  }

  /// Récupère tous les jurys assignés à une version (tous les rounds)
  Future<List<AppUser>> getJurysByVersion(String versionId) async {
    try {
      print('🔍 Récupération des jurys pour la version: $versionId');

      // Utiliser la vue pour récupérer tous les jurys de la version
      final response = await _supabase
          .from('jury_round_assignments_view')
          .select('*')
          .eq('version_id', versionId);

      print('📋 ${response.length} assignments trouvés pour la version');

      // Extraire les jurys uniques
      final Map<String, AppUser> uniqueJurys = {};

      for (final assignment in response) {
        final juryId = assignment['jury_id'] as String;
        if (!uniqueJurys.containsKey(juryId)) {
          uniqueJurys[juryId] = AppUser(
            id: juryId,
            fullName: assignment['jury_name'] as String,
            phone: assignment['jury_phone'] as String? ?? '',
            email: assignment['jury_email'] as String? ?? '',
            role: assignment['role'] as String,
            isVerified:
                true, // Les jurys assignés sont considérés comme vérifiés
            createdAt: DateTime.parse(assignment['assigned_at'] as String),
          );
        }
      }

      final jurysList = uniqueJurys.values.toList();
      print('✅ ${jurysList.length} jurys uniques trouvés pour la version');

      return jurysList;
    } catch (e) {
      print('❌ Erreur lors de la récupération des jurys par version: $e');
      return [];
    }
  }

  /// Récupère tous les rounds d'un jury pour une version donnée
  Future<List<Round>> getRoundsByJuryAndVersion(
    String juryId,
    String versionId,
  ) async {
    try {
      print(
        '🔍 Récupération des rounds pour le jury $juryId dans la version $versionId',
      );

      // 1. Récupérer tous les rounds de cette version
      final roundsForVersion = await _supabase
          .from('rounds')
          .select('id')
          .eq('version_id', versionId);

      if (roundsForVersion.isEmpty) {
        print('⚠️ Aucun round trouvé pour cette version');
        return [];
      }

      final roundIds = roundsForVersion
          .map<String>((round) => round['id'] as String)
          .toList();

      print('📋 ${roundIds.length} rounds trouvés pour la version');

      // 2. Récupérer les IDs des rounds assignés au jury depuis round_jury_assignments
      final assignmentsResponse = await _supabase
          .from('round_jury_assignments')
          .select('round_id')
          .eq('user_id', juryId)
          .inFilter('round_id', roundIds);

      if (assignmentsResponse.isEmpty) {
        print('⚠️ Aucun round assigné à ce jury pour cette version');
        return [];
      }

      final assignedRoundIds = assignmentsResponse
          .map<String>((item) => item['round_id'] as String)
          .toSet()
          .toList();

      print('📋 ${assignedRoundIds.length} rounds assignés trouvés pour ce jury');

      // 3. Récupérer les détails complets des rounds assignés depuis la table rounds
      final roundsResponse = await _supabase
          .from('rounds')
          .select()
          .inFilter('id', assignedRoundIds)
          .eq('version_id', versionId)
          .order('number');

      print('✅ ${roundsResponse.length} rounds récupérés avec détails complets');

      return roundsResponse
          .map<Round>((item) => Round.fromMap(item))
          .toList();
    } catch (e) {
      print('❌ Erreur lors de la récupération des rounds du jury: $e');
      print('❌ Stack trace: ${StackTrace.current}');
      return [];
    }
  }

  /// Assigne un jury à un round
  Future<bool> assignJuryToRound(String juryId, String roundId) async {
    try {
      print('➕ Assignation du jury $juryId au round $roundId');

      final response =
          await _supabase.from('round_jury_assignments').insert({
            'user_id': juryId,
            'round_id': roundId,
          }).select();

      if (response.isNotEmpty) {
        print('✅ Jury assigné avec succès au round');
        return true;
      } else {
        print('❌ Échec de l\'assignation du jury');
        return false;
      }
    } catch (e) {
      print('❌ Erreur lors de l\'assignation du jury: $e');
      return false;
    }
  }

  /// Supprime l'assignation d'un jury d'un round
  Future<bool> removeJuryFromRound(String juryId, String roundId) async {
    try {
      print(
        '➖ Suppression de l\'assignation du jury $juryId du round $roundId',
      );

      final response =
          await _supabase
              .from('round_jury_assignments')
              .delete()
              .eq('user_id', juryId)
              .eq('round_id', roundId)
              .select();

      if (response.isNotEmpty) {
        print('✅ Assignation du jury supprimée avec succès');
        return true;
      } else {
        print('❌ Aucune assignation trouvée à supprimer');
        return false;
      }
    } catch (e) {
      print('❌ Erreur lors de la suppression de l\'assignation: $e');
      return false;
    }
  }

  /// Supprime toutes les assignations d'un jury d'une version (tous les rounds)
  Future<bool> removeJuryFromVersion(String juryId, String versionId) async {
    try {
      print(
        '➖ Suppression de toutes les assignations du jury $juryId de la version $versionId',
      );

      // Récupérer tous les rounds de la version
      final roundsResponse = await _supabase
          .from('rounds')
          .select('id')
          .eq('version_id', versionId);

      if (roundsResponse.isEmpty) {
        print('⚠️ Aucun round trouvé pour cette version');
        return true;
      }

      final roundIds =
          roundsResponse.map<String>((round) => round['id'] as String).toList();

      // Supprimer toutes les assignations du jury pour ces rounds
      final response =
          await _supabase
              .from('round_jury_assignments')
              .delete()
              .eq('user_id', juryId)
              .inFilter('round_id', roundIds)
              .select();

      print('✅ ${response.length} assignations supprimées');
      return true;
    } catch (e) {
      print('❌ Erreur lors de la suppression des assignations: $e');
      return false;
    }
  }

  /// Vérifie si un jury est assigné à un round spécifique
  Future<bool> isJuryAssignedToRound(String juryId, String roundId) async {
    try {
      final response =
          await _supabase
              .from('round_jury_assignments')
              .select('id')
              .eq('user_id', juryId)
              .eq('round_id', roundId)
              .maybeSingle();

      return response != null;
    } catch (e) {
      print('❌ Erreur lors de la vérification de l\'assignation: $e');
      return false;
    }
  }

  /// Récupère les statistiques des assignations pour une version
  Future<Map<String, dynamic>> getAssignmentStats(String versionId) async {
    try {
      final response = await _supabase
          .from('jury_round_assignments_view')
          .select('*')
          .eq('version_id', versionId);

      final totalAssignments = response.length;
      final uniqueJurys =
          response.map((item) => item['jury_id']).toSet().length;
      final uniqueRounds =
          response.map((item) => item['round_id']).toSet().length;

      return {
        'total_assignments': totalAssignments,
        'unique_jurys': uniqueJurys,
        'unique_rounds': uniqueRounds,
        'assignments': response,
      };
    } catch (e) {
      print('❌ Erreur lors de la récupération des statistiques: $e');
      return {
        'total_assignments': 0,
        'unique_jurys': 0,
        'unique_rounds': 0,
        'assignments': [],
      };
    }
  }
}
