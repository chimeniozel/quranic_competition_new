
import 'package:quranic_competition/models/round_result.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RoundResultsService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Récupère tous les résultats d'une version de compétition
  Future<List<RoundResult>> getResultsByVersion(String versionId) async {
    try {
      final response = await _supabase
          .from('round_results')
          .select('*, participants(*), rounds(*)')
          .eq('version_id', versionId)
          .order('created_at', ascending: false);

      return response
          .map<RoundResult>((row) => RoundResult.fromMap(row))
          .toList();
    } catch (e) {
      print('Erreur lors de la récupération des résultats: $e');
      throw Exception('Impossible de récupérer les résultats');
    }
  }

  /// Récupère les résultats d'un round spécifique
  Future<List<RoundResult>> getResultsByRound(String roundId) async {
    try {
      final response = await _supabase
          .from('round_results')
          .select('*, participants(*), rounds(*)')
          .eq('round_id', roundId)
          .order('score', ascending: false);

      return response
          .map<RoundResult>((row) => RoundResult.fromMap(row))
          .toList();
    } catch (e) {
      print('Erreur lors de la récupération des résultats du round: $e');
      throw Exception('Impossible de récupérer les résultats du round');
    }
  }

  /// Récupère les résultats d'un participant spécifique
  Future<List<RoundResult>> getResultsByParticipant(
    String participantId,
  ) async {
    try {
      final response = await _supabase
          .from('round_results')
          .select('*, participants(*), rounds(*)')
          .eq('participant_id', participantId)
          .order('created_at', ascending: false);

      return response
          .map<RoundResult>((row) => RoundResult.fromMap(row))
          .toList();
    } catch (e) {
      print('Erreur lors de la récupération des résultats du participant: $e');
      throw Exception('Impossible de récupérer les résultats du participant');
    }
  }

  /// Récupère les résultats filtrés par groupe d'âge
  Future<List<RoundResult>> getResultsByAgeGroup(
    String versionId,
    String ageGroup,
  ) async {
    try {
      final response = await _supabase
          .from('round_results')
          .select('*, participants(*), rounds(*)')
          .eq('version_id', versionId)
          .eq('age_group', ageGroup)
          .order('score', ascending: false);

      return response
          .map<RoundResult>((row) => RoundResult.fromMap(row))
          .toList();
    } catch (e) {
      print(
        'Erreur lors de la récupération des résultats par groupe d\'âge: $e',
      );
      throw Exception(
        'Impossible de récupérer les résultats par groupe d\'âge',
      );
    }
  }

  /// Récupère les résultats d'un round et d'un groupe d'âge spécifiques
  Future<List<RoundResult>> getResultsByRoundAndAgeGroup(
    String roundId,
    String ageGroup,
  ) async {
    try {
      final response = await _supabase
          .from('round_results')
          .select('*, participants(*), rounds(*)')
          .eq('round_id', roundId)
          .eq('age_group', ageGroup)
          .order('score', ascending: false);

      return response
          .map<RoundResult>((row) => RoundResult.fromMap(row))
          .toList();
    } catch (e) {
      print(
        'Erreur lors de la récupération des résultats par round et groupe d\'âge: $e',
      );
      throw Exception(
        'Impossible de récupérer les résultats par round et groupe d\'âge',
      );
    }
  }

  /// Récupère les versions de compétition disponibles avec des résultats
  Future<List<String>> getVersionsWithResults() async {
    try {
      final response = await _supabase
          .from('round_results')
          .select('version_id')
          .order('created_at', ascending: false);

      final versionIds =
          response
              .map<String>((row) => row['version_id'] as String)
              .toSet()
              .toList();
      return versionIds;
    } catch (e) {
      print('Erreur lors de la récupération des versions avec résultats: $e');
      throw Exception('Impossible de récupérer les versions avec résultats');
    }
  }

  /// Récupère les résultats avec pagination
  Future<Map<String, dynamic>> getResultsWithPagination({
    required String roundId,
    required String ageGroup,
    int page = 0,
    int limit = 20,
  }) async {
    try {
      // Récupérer tous les résultats d'abord
      final allResults = await _supabase
          .from('round_results')
          .select('*, participants(*), rounds(*)')
          .eq('round_id', roundId)
          .eq('age_group', ageGroup)
          .order('score', ascending: false);

      List<RoundResult> results = allResults.map<RoundResult>((row) => RoundResult.fromMap(row)).toList();

      final totalCount = results.length;
      final startIndex = page * limit;
      final endIndex = (startIndex + limit).clamp(0, totalCount);
      
      // Pagination côté client
      final paginatedResults = results.sublist(startIndex, endIndex);
      final hasMore = endIndex < totalCount;

      return {
        'results': paginatedResults,
        'totalCount': totalCount,
        'hasMore': hasMore,
        'currentPage': page,
      };
    } catch (e) {
      print('Erreur lors de la récupération des résultats avec pagination: $e');
      throw Exception('Impossible de récupérer les résultats avec pagination');
    }
  }
}
