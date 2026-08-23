import 'dart:math' as math;

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:quranic_competition/models/round.dart';
import 'package:quranic_competition/models/participant.dart';
import 'package:quranic_competition/models/round_result.dart';

class RoundResultsService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Calcule et sauvegarde les résultats d'un round
  Future<void> calculateRoundResults(String roundId) async {
    try {
      print('🔍 Début du calcul des résultats pour le round: $roundId');

      // 1. Récupérer les informations du round
      final round = await _getRoundById(roundId);
      if (round == null) {
        throw Exception('Round non trouvé avec l\'ID: $roundId');
      }

      print('📋 Round trouvé: ${round.name} (Round ${round.number})');

      // 2. Récupérer les participants éligibles pour ce round
      final eligibleParticipants = await _getEligibleParticipants(round);
      print('👥 ${eligibleParticipants.length} participants éligibles trouvés');

      if (eligibleParticipants.isEmpty) {
        throw Exception('Aucun participant éligible trouvé pour ce round');
      }

      // 3. Récupérer les jurys assignés à ce round
      final assignedJurys = await _getAssignedJurys(roundId);
      print('👨‍⚖️ ${assignedJurys.length} jurys assignés trouvés');

      if (assignedJurys.isEmpty) {
        throw Exception('Aucun jury assigné à ce round');
      }

      // 4. Vérifier que toutes les évaluations sont terminées
      await _verifyAllEvaluationsComplete(
        roundId,
        eligibleParticipants,
        assignedJurys,
      );
      print('✅ Toutes les évaluations sont terminées');

      // 5. Récupérer les moyennes de succès de la version
      final versionSuccessAverages = await _getVersionSuccessAverages(
        round.versionId,
      );
      print(
        '📈 Moyennes de succès récupérées: Adultes=${versionSuccessAverages['adults']}%, Enfants=${versionSuccessAverages['children']}%',
      );

      // 6. Calculer les résultats pour chaque participant
      final results = await _calculateResultsForParticipants(
        roundId,
        round.versionId,
        eligibleParticipants,
        assignedJurys,
        versionSuccessAverages,
      );

      print('📊 ${results.length} résultats calculés');

      // 6. Sauvegarder les résultats dans la base de données
      await _saveResultsToDatabase(results);
      print('💾 Résultats sauvegardés avec succès');

      // 7. Marquer le round comme ayant des résultats publiés
      // await _markRoundResultsAsPublished(roundId);
      print('🏁 Round marqué comme terminé');
    } catch (e) {
      print('❌ Erreur lors du calcul des résultats: $e');
      rethrow;
    }
  }

  /// Récupère un round par son ID
  Future<Round?> _getRoundById(String roundId) async {
    try {
      final response =
          await _supabase
              .from('rounds')
              .select()
              .eq('id', roundId)
              .maybeSingle();

      if (response == null) return null;

      return Round.fromMap(response);
    } catch (e) {
      print('❌ Erreur lors de la récupération du round: $e');
      return null;
    }
  }

  /// Récupère les participants éligibles selon les règles du round
  Future<List<Participant>> _getEligibleParticipants(Round round) async {
    try {
      List<Map<String, dynamic>> response;

      if (round.number == 1) {
        // Round 1: participants acceptés uniquement pour cette version
        response = await _supabase
            .from('participants')
            .select()
            .eq('competition_id', round.versionId)
            .eq('is_accepted', true);

        return response.map((record) => Participant.fromMap(record)).toList();
      }

      // Rounds >= 2: participants qui ont passé le round précédent
      final previousRoundNumber = round.number - 1;
      final previousRoundResponse =
          await _supabase
              .from('rounds')
              .select('id')
              .eq('version_id', round.versionId)
              .eq('number', previousRoundNumber)
              .maybeSingle();

      if (previousRoundResponse == null) {
        throw Exception(
          'Impossible de trouver le round précédent (${round.number - 1}) pour la version ${round.versionId}',
        );
      }

      final previousRoundId = previousRoundResponse['id'] as String;
      final qualifiedResponse = await _supabase
          .from('round_results')
          .select('participants(*)')
          .eq('version_id', round.versionId)
          .eq('round_id', previousRoundId)
          .eq('passed', true);

      if (qualifiedResponse.isEmpty) {
        // Fallback de compatibilité : utiliser le flag passed_round1 si présent
        response = await _supabase
            .from('participants')
            .select()
            .eq('competition_id', round.versionId)
            .eq('is_accepted', true)
            .eq('passed_round1', true);

        return response.map((record) => Participant.fromMap(record)).toList();
      }

      return qualifiedResponse.map((row) {
        final participantMap =
            row['participants'] as Map<String, dynamic>? ?? {};
        return Participant.fromMap(participantMap);
      }).toList();
    } catch (e) {
      print('❌ Erreur lors de la récupération des participants éligibles: $e');
      return [];
    }
  }

  /// Récupère les jurys assignés à un round
  Future<List<String>> _getAssignedJurys(String roundId) async {
    try {
      final response = await _supabase
          .from('round_jury_assignments')
          .select('user_id')
          .eq('round_id', roundId);

      return response
          .map<String>((assignment) => assignment['user_id'] as String)
          .toList();
    } catch (e) {
      print('❌ Erreur lors de la récupération des jurys assignés: $e');
      return [];
    }
  }

  /// Vérifie que toutes les évaluations sont terminées
  Future<void> _verifyAllEvaluationsComplete(
    String roundId,
    List<Participant> participants,
    List<String> jurys,
  ) async {
    try {
      final totalExpectedEvaluations = participants.length * jurys.length;
      print(
        '🔍 Vérification des évaluations: $totalExpectedEvaluations attendues',
      );

      // Récupérer toutes les évaluations existantes pour ce round
      final existingEvaluations = await _supabase
          .from('evaluations')
          .select('participant_id, jury_id')
          .eq('round_id', roundId);

      print('📋 ${existingEvaluations.length} évaluations trouvées');

      // Vérifier que chaque participant a été évalué par chaque jury
      final missingEvaluations = <String>[];

      for (final participant in participants) {
        for (final jury in jurys) {
          final hasEvaluation = existingEvaluations.any(
            (eval) =>
                eval['participant_id'] == participant.id &&
                eval['jury_id'] == jury,
          );

          if (!hasEvaluation) {
            missingEvaluations.add(
              'Participant ${participant.fullName} non évalué par le jury $jury',
            );
          }
        }
      }

      if (missingEvaluations.isNotEmpty) {
        final errorMessage =
            'Toutes les évaluations ne sont pas encore terminées.';
        throw Exception(errorMessage);
      }

      print('✅ Toutes les évaluations sont complètes');
    } catch (e) {
      print('❌ Erreur lors de la vérification des évaluations: $e');
      rethrow;
    }
  }

  /// Calcule les résultats pour tous les participants
  Future<List<Map<String, dynamic>>> _calculateResultsForParticipants(
    String roundId,
    String versionId,
    List<Participant> participants,
    List<String> jurys,
    Map<String, double> successAverages,
  ) async {
    try {
      final results = <Map<String, dynamic>>[];

      for (final participant in participants) {
        // Récupérer toutes les évaluations pour ce participant dans ce round
        final evaluations = await _supabase
            .from('evaluations')
            .select('total_score')
            .eq('round_id', roundId)
            .eq('participant_id', participant.id);

        if (evaluations.isEmpty) {
          throw Exception(
            'Aucune évaluation trouvée pour le participant ${participant.fullName}',
          );
        }

        // Calculer la moyenne des scores
        final totalScore = evaluations.fold<double>(
          0.0,
          (sum, eval) => sum + (eval['total_score'] as num).toDouble(),
        );
        final averageScore = totalScore / evaluations.length;

        // Déterminer si le participant a passé selon la moyenne de succès de son groupe d'âge
        final successThreshold =
            participant.ageGroup == 'كبار'
                ? successAverages['adults']!
                : successAverages['children']!;
        final passed = averageScore >= successThreshold;

        results.add({
          'participant_id': participant.id,
          'round_id': roundId,
          'version_id': versionId,
          'score': averageScore,
          'passed': passed,
          'age_group': participant.ageGroup,
        });

        print(
          '📊 ${participant.fullName} (${participant.ageGroup}): Score ${averageScore.toStringAsFixed(2)}/${successThreshold.toStringAsFixed(1)} (${passed ? 'Réussi' : 'Échoué'})',
        );
      }

      return results;
    } catch (e) {
      print('❌ Erreur lors du calcul des résultats: $e');
      rethrow;
    }
  }

  /// Sauvegarde les résultats dans la base de données
  Future<void> _saveResultsToDatabase(
    List<Map<String, dynamic>> results,
  ) async {
    try {
      for (final result in results) {
        // Vérifier si le résultat existe déjà
        final existingResult =
            await _supabase
                .from('round_results')
                .select('id')
                .eq('participant_id', result['participant_id'])
                .eq('round_id', result['round_id'])
                .maybeSingle();

        if (existingResult != null) {
          // Mettre à jour le résultat existant
          await _supabase
              .from('round_results')
              .update({
                'score': result['score'],
                'passed': result['passed'],
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('id', existingResult['id']);

          print(
            '🔄 Résultat mis à jour pour le participant ${result['participant_id']}',
          );
        } else {
          // Insérer un nouveau résultat
          await _supabase.from('round_results').insert({
            'participant_id': result['participant_id'],
            'round_id': result['round_id'],
            'version_id': result['version_id'],
            'score': result['score'],
            'passed': result['passed'],
            'age_group': result['age_group'],
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });

          print(
            '➕ Nouveau résultat créé pour le participant ${result['participant_id']}',
          );
        }
      }
    } catch (e) {
      print('❌ Erreur lors de la sauvegarde des résultats: $e');
      rethrow;
    }
  }

  /// Marque le round comme ayant des résultats publiés
  // ignore: unused_element
  Future<void> _markRoundResultsAsPublished(String roundId) async {
    try {
      await _supabase
          .from('rounds')
          .update({
            'result_is_published': true,
            'published_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', roundId);

      print('🏁 Round marqué comme publié');
    } catch (e) {
      print('❌ Erreur lors du marquage du round: $e');
      rethrow;
    }
  }

  /// Récupère les résultats d'un round
  Future<List<RoundResult>> getRoundResults(String roundId) async {
    try {
      final response = await _supabase
          .from('round_results')
          .select('''
            *,
            participants(*),
            rounds(*)
          ''')
          .eq('round_id', roundId)
          .order('score', ascending: false);

      return response.map((record) => RoundResult.fromMap(record)).toList();
    } catch (e) {
      print('❌ Erreur lors de la récupération des résultats: $e');
      return [];
    }
  }

  /// Vérifie si un round a des résultats calculés
  Future<bool> hasRoundResults(String roundId) async {
    try {
      final response = await _supabase
          .from('round_results')
          .select('id')
          .eq('round_id', roundId)
          .limit(1);

      return response.isNotEmpty;
    } catch (e) {
      print('❌ Erreur lors de la vérification des résultats: $e');
      return false;
    }
  }

  /// Récupère les résultats avec pagination
  Future<Map<String, dynamic>> getResultsWithPagination({
    required String roundId,
    required String ageGroup,
    int page = 0,
    int limit = 20,
    String searchQuery = '',
    bool includeNameInSearch = true,
  }) async {
    try {
      final search = searchQuery.trim();
      final searchFilter =
          search.isEmpty
              ? ''
              : _buildParticipantSearchFilter(
                search,
                includeName: includeNameInSearch,
              );

      // Recherche saisie mais aucun critère exploitable (ex: seulement des
      // caractères ignorés) : aucun résultat, inutile d'interroger la base.
      if (search.isNotEmpty && searchFilter.isEmpty) {
        return {
          'results': <RoundResult>[],
          'totalCount': 0,
          'hasMore': false,
          'currentPage': page,
        };
      }

      final from = page * limit;
      final to = from + limit - 1;

      var query = _supabase
          .from('round_results')
          .select('*, participants!inner(*), rounds(*)')
          .eq('round_id', roundId)
          .eq('age_group', ageGroup);

      // La recherche est faite directement en base : elle porte donc sur
      // l'ensemble des participants du round, pas seulement sur la page
      // déjà chargée dans l'interface.
      if (searchFilter.isNotEmpty) {
        query = query.or(searchFilter, referencedTable: 'participants');
      }

      final response = await query
          .order('score', ascending: false)
          // Départage stable des ex-aequo : indispensable pour que la
          // pagination ne saute ni ne duplique de lignes.
          .order('id', ascending: true)
          .range(from, to)
          .count(CountOption.exact);

      final totalCount = response.count;
      List<RoundResult> results =
          response.data
              .map<RoundResult>((row) => RoundResult.fromMap(row))
              .toList();

      if (searchFilter.isEmpty) {
        // Liste complète : le rang correspond à la position dans la page.
        results = [
          for (var i = 0; i < results.length; i++)
            results[i].copyWith(rank: from + i + 1),
        ];
      } else {
        // Résultats de recherche : le rang réel doit être calculé en base.
        results = await _attachRealRanks(
          results,
          roundId: roundId,
          ageGroup: ageGroup,
        );
      }

      return {
        'results': results,
        'totalCount': totalCount,
        'hasMore': from + results.length < totalCount,
        'currentPage': page,
      };
    } catch (e) {
      print('Erreur lors de la récupération des résultats avec pagination: $e');
      throw Exception('Impossible de récupérer les résultats avec pagination');
    }
  }

  /// Construit le filtre PostgREST appliqué à la table `participants`.
  ///
  /// - nom complet : correspondance partielle (ilike), seulement si
  ///   [includeName] est vrai (certains écrans cherchent par numéro seul)
  /// - numéro d'inscription : la colonne étant numérique, on cherche les
  ///   numéros qui commencent par les chiffres saisis (ex: "40" trouve 40,
  ///   404, 4012...) à l'aide d'intervalles.
  String _buildParticipantSearchFilter(
    String search, {
    bool includeName = true,
  }) {
    // Les virgules et parenthèses sont des séparateurs de la syntaxe `or`.
    final sanitized = search.replaceAll(RegExp(r'[,()."*]'), ' ').trim();
    if (sanitized.isEmpty) return '';

    final filters = <String>[if (includeName) 'full_name.ilike.*$sanitized*'];

    final digits = sanitized.replaceAll(RegExp(r'\D'), '');
    if (digits.isNotEmpty && digits.length <= 9) {
      final prefix = int.parse(digits);
      for (var extraDigits = 0; extraDigits <= 3; extraDigits++) {
        final factor = math.pow(10, extraDigits).toInt();
        final start = prefix * factor;
        filters.add(
          'and(registration_number.gte.$start,'
          'registration_number.lt.${start + factor})',
        );
      }
    }

    return filters.join(',');
  }

  /// Calcule en base le rang réel de chaque résultat trouvé par la recherche
  /// (nombre de participants mieux classés + 1), selon le même ordre que le
  /// classement affiché (score décroissant, puis id croissant).
  Future<List<RoundResult>> _attachRealRanks(
    List<RoundResult> results, {
    required String roundId,
    required String ageGroup,
  }) async {
    return Future.wait(
      results.map((result) async {
        try {
          final betterCount = await _supabase
              .from('round_results')
              .count(CountOption.exact)
              .eq('round_id', roundId)
              .eq('age_group', ageGroup)
              .or(
                'score.gt.${result.score},'
                'and(score.eq.${result.score},id.lt.${result.id})',
              );
          return result.copyWith(rank: betterCount + 1);
        } catch (e) {
          print('⚠️ Impossible de calculer le rang de ${result.id}: $e');
          return result;
        }
      }),
    );
  }

  /// Récupère les moyennes de succès d'une version de compétition
  Future<Map<String, double>> _getVersionSuccessAverages(
    String versionId,
  ) async {
    try {
      final response =
          await _supabase
              .from('competition_versions')
              .select('success_average_adults, success_average_children')
              .eq('id', versionId)
              .single();

      return {
        'adults': (response['success_average_adults'] ?? 85.0).toDouble(),
        'children': (response['success_average_children'] ?? 14.0).toDouble(),
      };
    } catch (e) {
      print('❌ Erreur lors de la récupération des moyennes de succès: $e');
      // Valeurs par défaut en cas d'erreur
      return {'adults': 85.0, 'children': 14.0};
    }
  }
}
