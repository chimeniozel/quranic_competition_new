import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:quranic_competition/models/participant.dart';
import 'package:quranic_competition/models/evaluation.dart';
import 'package:quranic_competition/models/round.dart';
import 'package:quranic_competition/core/services/round_service.dart';

/// Statistiques d'évaluation pour un groupe d'âge
class EvaluationStats {
  final String ageGroup; // "كبار" ou "صغار"
  final int totalParticipants; // Nombre total de participants
  final int evaluatedParticipants; // Nombre de participants évalués
  final double progressPercentage; // Pourcentage d'évaluation (0.0 à 1.0)
  final String
  progressText; // Texte descriptif (ex: "123 من 164 مشارك تم تقييمه")

  EvaluationStats({
    required this.ageGroup,
    required this.totalParticipants,
    required this.evaluatedParticipants,
    required this.progressPercentage,
    required this.progressText,
  });
}

/// Service pour récupérer les statistiques d'évaluation
class EvaluationStatsService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final RoundService _roundService = RoundService();

  /// Récupère les statistiques d'évaluation pour tous les groupes d'âge d'une version active
  Future<List<EvaluationStats>> getEvaluationStatsForActiveRounds(
    String versionId,
  ) async {
    try {
      // 1. Récupérer le round actif
      Round? selectedRound = await _roundService.getActiveRound(versionId);

      if (selectedRound == null) {
        // Si aucun round actif, récupérer le dernier round (publié ou non)
        final allRounds = await _roundService.getRoundsByVersion(versionId);
        if (allRounds.isNotEmpty) {
          // Trier par numéro de round décroissant et prendre le premier
          allRounds.sort((a, b) => b.number.compareTo(a.number));
          selectedRound = allRounds.first;
          print(
            '⚠️ Aucun round actif, utilisation du dernier round: ${selectedRound.name} (Round ${selectedRound.number})',
          );
        } else {
          print('❌ Aucun round trouvé pour la version $versionId');
          return [];
        }
      } else {
        print(
          '✅ Round actif trouvé: ${selectedRound.name} (ID: ${selectedRound.id})',
        );
      }

      // 2. Récupérer tous les participants de cette version selon le round sélectionné
      final participants = await _getParticipantsForActiveRound(
        versionId,
        selectedRound,
      );
      print('📊 Participants récupérés: ${participants.length}');

      // 3. Récupérer toutes les évaluations pour ce round
      final evaluations = await _getEvaluationsForRound(selectedRound.id);
      print('📊 Évaluations récupérées: ${evaluations.length}');

      // 4. Calculer les statistiques par groupe d'âge
      final stats = <EvaluationStats>[];

      // Grouper les participants par âge
      final participantsByAge = <String, List<Participant>>{};
      for (final participant in participants) {
        participantsByAge
            .putIfAbsent(participant.ageGroup, () => [])
            .add(participant);
      }

      // Calculer les statistiques pour chaque groupe d'âge
      for (final entry in participantsByAge.entries) {
        final ageGroup = entry.key;
        final ageGroupParticipants = entry.value;

        // Trouver les participants évalués pour ce groupe d'âge
        final evaluatedParticipantIds =
            evaluations
                .where(
                  (e) =>
                      ageGroupParticipants.any((p) => p.id == e.participantId),
                )
                .map((e) => e.participantId)
                .toSet();

        final totalCount = ageGroupParticipants.length;
        final evaluatedCount = evaluatedParticipantIds.length;
        final progressPercentage =
            totalCount > 0 ? evaluatedCount / totalCount : 0.0;

        final statsItem = EvaluationStats(
          ageGroup: ageGroup,
          totalParticipants: totalCount,
          evaluatedParticipants: evaluatedCount,
          progressPercentage: progressPercentage,
          progressText: '$evaluatedCount من $totalCount مشارك تم تقييمه',
        );

        stats.add(statsItem);
        print(
          '📊 $ageGroup: $evaluatedCount/$totalCount évalués (${(progressPercentage * 100).toInt()}%)',
        );
      }

      return stats;
    } catch (e) {
      print('❌ Erreur lors de la récupération des statistiques: $e');
      return [];
    }
  }

  /// Récupère les participants selon le round actif
  Future<List<Participant>> _getParticipantsForActiveRound(
    String versionId,
    Round activeRound,
  ) async {
    try {
      if (activeRound.number == 1) {
        // Round 1: tous les participants de la version
        final response = await _supabase
            .from('participant_versions')
            .select('participant_id, participants(*)')
            .eq('version_id', versionId);

        return response.map<Participant>((record) {
          final participantData =
              record['participants'] as Map<String, dynamic>;
          return Participant.fromMap(participantData);
        }).toList();
      } else if (activeRound.number == 2) {
        // Round 2: seulement ceux qui ont passé le round 1
        final response = await _supabase
            .from('participant_versions')
            .select('participant_id, participants(*)')
            .eq('version_id', versionId)
            .eq('passed_round1', true);

        return response.map<Participant>((record) {
          final participantData =
              record['participants'] as Map<String, dynamic>;
          return Participant.fromMap(participantData);
        }).toList();
      } else {
        // Autres rounds: logique similaire
        final response = await _supabase
            .from('participant_versions')
            .select('participant_id, participants(*)')
            .eq('version_id', versionId)
            .eq('passed_round1', true);

        return response.map<Participant>((record) {
          final participantData =
              record['participants'] as Map<String, dynamic>;
          return Participant.fromMap(participantData);
        }).toList();
      }
    } catch (e) {
      print('❌ Erreur lors de la récupération des participants: $e');
      return [];
    }
  }

  /// Récupère toutes les évaluations pour un round spécifique
  Future<List<Evaluation>> _getEvaluationsForRound(String roundId) async {
    try {
      final response = await _supabase
          .from('evaluations')
          .select('*, participants(age_group)')
          .eq('round_id', roundId);

      return response.map<Evaluation>((e) {
        final ageGroup = e['participants']['age_group'];
        return Evaluation.fromMap(e, ageGroup);
      }).toList();
    } catch (e) {
      print('❌ Erreur lors de la récupération des évaluations: $e');
      return [];
    }
  }

  /// Récupère les statistiques pour une version spécifique (toutes les versions actives)
  Future<List<EvaluationStats>> getEvaluationStatsForAllActiveVersions() async {
    try {
      // Récupérer toutes les versions actives
      final versionsResponse = await _supabase
          .from('competition_versions')
          .select('id')
          .eq('is_active', true);

      final allStats = <EvaluationStats>[];

      if (versionsResponse.isEmpty) {
        // Si aucune version active, récupérer la dernière version (active ou inactive)
        final lastVersionResponse = await _supabase
            .from('competition_versions')
            .select('id, is_active')
            .order('created_at', ascending: false)
            .limit(1);

        if (lastVersionResponse.isNotEmpty) {
          final versionId = lastVersionResponse.first['id'] as String;
          final isActive = lastVersionResponse.first['is_active'] as bool;
          print(
            '⚠️ Aucune version active, utilisation de la dernière version: $versionId (Active: $isActive)',
          );
          final stats = await getEvaluationStatsForActiveRounds(versionId);
          allStats.addAll(stats);
        } else {
          print('❌ Aucune version trouvée dans la base de données');
        }
      } else {
        for (final versionData in versionsResponse) {
          final versionId = versionData['id'] as String;
          final stats = await getEvaluationStatsForActiveRounds(versionId);
          allStats.addAll(stats);
        }
      }

      // Grouper par âge et additionner les statistiques
      final groupedStats = <String, EvaluationStats>{};

      for (final stat in allStats) {
        if (groupedStats.containsKey(stat.ageGroup)) {
          final existing = groupedStats[stat.ageGroup]!;
          groupedStats[stat.ageGroup] = EvaluationStats(
            ageGroup: stat.ageGroup,
            totalParticipants:
                existing.totalParticipants + stat.totalParticipants,
            evaluatedParticipants:
                existing.evaluatedParticipants + stat.evaluatedParticipants,
            progressPercentage:
                existing.totalParticipants + stat.totalParticipants > 0
                    ? (existing.evaluatedParticipants +
                            stat.evaluatedParticipants) /
                        (existing.totalParticipants + stat.totalParticipants)
                    : 0.0,
            progressText:
                '${existing.evaluatedParticipants + stat.evaluatedParticipants} من ${existing.totalParticipants + stat.totalParticipants} مشارك تم تقييمه',
          );
        } else {
          groupedStats[stat.ageGroup] = stat;
        }
      }

      return groupedStats.values.toList();
    } catch (e) {
      print('❌ Erreur lors de la récupération des statistiques globales: $e');
      return [];
    }
  }
}
