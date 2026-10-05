import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:quranic_competition/models/round.dart';
import 'package:quranic_competition/models/participant.dart';
import 'package:quranic_competition/models/round_result.dart';
import 'package:quranic_competition/core/utils/search_utils.dart';

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
        '📈 Seuils de réussite: Adultes=${versionSuccessAverages['adults']}/100, '
        'Enfants=${versionSuccessAverages['children']}/20',
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

      // Noms des jurys, pour un message d'erreur exploitable
      final juryNames = await _getJuryNames(jurys);

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
              'المتسابق ${participant.registrationNumber ?? ''} '
              '${participant.fullName} — لم يقيّمه ${juryNames[jury] ?? jury}',
            );
          }
        }
      }

      if (missingEvaluations.isNotEmpty) {
        // Le détail était calculé puis jeté : l'administrateur ne savait pas
        // quelles évaluations manquaient.
        final preview = missingEvaluations.take(5).join('\n• ');
        final remaining = missingEvaluations.length - 5;

        throw Exception(
          'لم تكتمل جميع التقييمات بعد '
          '(${missingEvaluations.length} تقييمًا ناقصًا):\n• $preview'
          '${remaining > 0 ? '\n• ... و$remaining أخرى' : ''}',
        );
      }

      print('✅ Toutes les évaluations sont complètes');
    } catch (e) {
      print('❌ Erreur lors de la vérification des évaluations: $e');
      rethrow;
    }
  }

  /// Noms des jurys (pour les messages destinés à l'administrateur)
  Future<Map<String, String>> _getJuryNames(List<String> juryIds) async {
    if (juryIds.isEmpty) return {};

    try {
      final response = await _supabase
          .from('profiles')
          .select('id, full_name')
          .inFilter('id', juryIds);

      return {
        for (final row in response)
          row['id'] as String: (row['full_name'] as String?) ?? '',
      };
    } catch (e) {
      print('⚠️ Impossible de récupérer les noms des jurys: $e');
      return {};
    }
  }

  /// Moyenne d'un critère précis dans `notes_json`
  static double? _criterionValue(dynamic notesJson, String key) {
    if (notesJson is! Map) return null;
    final value = notesJson[key];
    return value is num ? value.toDouble() : null;
  }

  /// Arrondi à deux décimales : la valeur enregistrée est exactement celle
  /// qui est affichée, donc deux participants « à égalité » à l'écran le sont
  /// réellement dans le classement.
  static double _round2(double value) => (value * 100).round() / 100;

  /// Correcteurs ayant évalué l'intégralité des participants du round.
  ///
  /// Seuls ceux-là entrent dans la moyenne, qu'ils soient encore assignés au
  /// round ou non : c'est ce qui garantit un diviseur identique pour tous.
  Set<String> _findCompleteJurys(
    Map<String, Map<String, Map<String, dynamic>>> latestByParticipant,
    List<Participant> participants,
  ) {
    final allJurys =
        latestByParticipant.values.expand((byJury) => byJury.keys).toSet();

    return allJurys.where((juryId) {
      return participants.every(
        (participant) =>
            latestByParticipant[participant.id]?.containsKey(juryId) ?? false,
      );
    }).toSet();
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
      // Une seule requête pour tout le round (au lieu d'une par participant)
      final evaluations = await _supabase
          .from('evaluations')
          .select(
            'participant_id, jury_id, total_score, notes_json, submitted_at',
          )
          .eq('round_id', roundId)
          .order('submitted_at', ascending: true);

      // Une seule évaluation par (participant, jury) : la plus récente.
      // Protège des doublons créés par un double envoi.
      final latestByParticipant = <String, Map<String, Map<String, dynamic>>>{};

      for (final row in evaluations) {
        final participantId = row['participant_id'] as String?;
        final juryId = row['jury_id'] as String?;
        if (participantId == null || juryId == null) continue;

        // Les lignes arrivent triées par date : la dernière écrase la précédente
        latestByParticipant.putIfAbsent(participantId, () => {})[juryId] = row;
      }

      // Ne retenir que les correcteurs ayant évalué TOUS les participants.
      //
      // Se fier à la seule liste des correcteurs assignés serait faux : quand
      // un correcteur est retiré d'une جولة après avoir tout évalué,
      // l'application supprime son assignation mais conserve volontairement
      // ses notes (« سيتم الاحتفاظ بتقييماته لأنها مكتملة ») — elles doivent
      // donc continuer à compter.
      //
      // Le critère retenu est l'exhaustivité : la moyenne de chaque
      // participant porte ainsi sur exactement le même ensemble de
      // correcteurs. Un ensemble partiel resté en base (suppression
      // interrompue) avantagerait ou pénaliserait certains participants selon
      // qui les a notés.
      final completeJurys = _findCompleteJurys(
        latestByParticipant,
        participants,
      );

      if (completeJurys.isEmpty) {
        throw Exception('لا يوجد أي مصحّح أكمل تقييم جميع المتسابقين');
      }

      final ignoredJurys = latestByParticipant.values
          .expand((byJury) => byJury.keys)
          .toSet()
          .difference(completeJurys);

      if (ignoredJurys.isNotEmpty) {
        print(
          '⚠️ ${ignoredJurys.length} مصحّحًا لم يكمل التقييم — لن تُحتسب تقييماته',
        );
      }

      print('🧮 المعدّل يُحتسب على ${completeJurys.length} مصحّحًا');

      final results = <Map<String, dynamic>>[];

      for (final participant in participants) {
        final byJury = latestByParticipant[participant.id] ?? {};
        final juryEvaluations = [
          for (final juryId in completeJurys)
            if (byJury[juryId] != null) byJury[juryId]!,
        ];

        if (juryEvaluations.isEmpty) {
          throw Exception('لا يوجد أي تقييم للمتسابق ${participant.fullName}');
        }

        final isAdult = participant.ageGroup == 'كبار';

        double sumScore = 0;
        double sumTajwid = 0;
        double sumVoice = 0;
        var tajwidCount = 0;
        var voiceCount = 0;

        for (final evaluation in juryEvaluations) {
          sumScore += (evaluation['total_score'] as num).toDouble();

          final notes = evaluation['notes_json'];
          final tajwid = _criterionValue(notes, 'التجويد');
          if (tajwid != null) {
            sumTajwid += tajwid;
            tajwidCount++;
          }
          final voice = _criterionValue(notes, 'حسن الصوت');
          if (voice != null) {
            sumVoice += voice;
            voiceCount++;
          }
        }

        final count = juryEvaluations.length;
        final averageScore = _round2(sumScore / count);

        // Critères de départage, moyennés sur les mêmes jurys
        final averageTajwid =
            tajwidCount > 0 ? _round2(sumTajwid / tajwidCount) : 0.0;
        final averageVoice =
            voiceCount > 0 ? _round2(sumVoice / voiceCount) : 0.0;

        // Le seuil est comparé à la note arrondie : ce que voit le
        // participant correspond exactement à sa réussite ou à son échec.
        final successThreshold =
            isAdult ? successAverages['adults']! : successAverages['children']!;
        final passed = averageScore >= successThreshold;

        results.add({
          'participant_id': participant.id,
          'round_id': roundId,
          'version_id': versionId,
          'score': averageScore,
          'passed': passed,
          'age_group': participant.ageGroup,
          'tiebreak_tajwid': averageTajwid,
          'tiebreak_voice': averageVoice,
          'registration_number': participant.registrationNumber ?? 0,
          'jury_count': count,
        });

        print(
          '📊 ${participant.fullName} (${participant.ageGroup}): '
          '${averageScore.toStringAsFixed(2)}/${successThreshold.toStringAsFixed(1)} '
          'على $count مصحّحًا (${passed ? 'ناجح' : 'راسب'})',
        );
      }

      return _assignRanks(results);
    } catch (e) {
      print('❌ Erreur lors du calcul des résultats: $e');
      rethrow;
    }
  }

  /// Attribue le rang de chaque participant, séparément par groupe d'âge.
  ///
  /// Deux valeurs sont enregistrées, pour deux besoins différents :
  ///
  /// • `rank` — le classement affiché. **À moyenne égale, même rang**, et les
  ///   rangs se suivent sans trou : deux participants à 92.50 sont tous deux
  ///   « المركز 2 », et le suivant est 3e (1, 2, 2, 3). C'est le rang réel,
  ///   valable aussi pour un résultat isolé trouvé par la recherche.
  ///
  /// • `display_order` — l'ordre d'affichage dans la liste, toujours unique :
  ///   1. moyenne décroissante
  ///   2. note de التجويد décroissante (critère le plus lourd)
  ///   3. note de حسن الصوت décroissante
  ///   4. numéro d'inscription croissant
  ///   Il ne départage pas les ex aequo au classement, il fixe seulement un
  ///   ordre stable — sans lui, la pagination pourrait sauter ou répéter des
  ///   lignes entre deux requêtes.
  List<Map<String, dynamic>> _assignRanks(List<Map<String, dynamic>> results) {
    final byAgeGroup = <String, List<Map<String, dynamic>>>{};
    for (final result in results) {
      byAgeGroup
          .putIfAbsent(result['age_group'] as String, () => [])
          .add(result);
    }

    for (final group in byAgeGroup.values) {
      group.sort((a, b) {
        final byScore = (b['score'] as double).compareTo(a['score'] as double);
        if (byScore != 0) return byScore;

        final byTajwid = (b['tiebreak_tajwid'] as double).compareTo(
          a['tiebreak_tajwid'] as double,
        );
        if (byTajwid != 0) return byTajwid;

        final byVoice = (b['tiebreak_voice'] as double).compareTo(
          a['tiebreak_voice'] as double,
        );
        if (byVoice != 0) return byVoice;

        return (a['registration_number'] as int).compareTo(
          b['registration_number'] as int,
        );
      });

      // Le rang n'avance qu'au changement de moyenne : les rangs se
      // suivent sans trou (1, 2, 2, 3) même en cas d'ex aequo.
      var currentRank = 0;
      double? previousScore;

      for (var i = 0; i < group.length; i++) {
        group[i]['display_order'] = i + 1;

        final score = group[i]['score'] as double;
        if (previousScore == null || score != previousScore) {
          currentRank++;
          previousScore = score;
        }

        group[i]['rank'] = currentRank;
      }
    }

    return results;
  }

  /// Sauvegarde les résultats dans la base de données
  ///
  /// Un seul `upsert` pour tout le round : l'ancienne version faisait deux
  /// requêtes par participant (recherche puis insertion/mise à jour), soit un
  /// millier d'allers-retours pour 500 participants — long, et surtout non
  /// atomique : une coupure en plein calcul laissait un classement à moitié
  /// écrit.
  Future<void> _saveResultsToDatabase(
    List<Map<String, dynamic>> results,
  ) async {
    if (results.isEmpty) return;

    try {
      final now = DateTime.now().toIso8601String();

      final rows =
          results.map((result) {
            return {
              'participant_id': result['participant_id'],
              'round_id': result['round_id'],
              'version_id': result['version_id'],
              'score': result['score'],
              'passed': result['passed'],
              'age_group': result['age_group'],
              'rank': result['rank'],
              'display_order': result['display_order'],
              'tiebreak_tajwid': result['tiebreak_tajwid'],
              'tiebreak_voice': result['tiebreak_voice'],
              'jury_count': result['jury_count'],
              'updated_at': now,
            };
          }).toList();

      await _supabase
          .from('round_results')
          .upsert(rows, onConflict: 'participant_id,round_id');

      print('💾 ${rows.length} résultats enregistrés');

      await _removeObsoleteResults(
        roundId: results.first['round_id'] as String,
        keptParticipantIds:
            results.map((r) => r['participant_id'] as String).toSet(),
      );
    } catch (e) {
      print('❌ Erreur lors de la sauvegarde des résultats: $e');
      rethrow;
    }
  }

  /// Supprime les résultats d'un round qui ne correspondent plus à aucun
  /// participant éligible.
  ///
  /// Sans cela, un participant rejeté ou retiré après un premier calcul
  /// restait dans le classement à chaque recalcul, et décalait les rangs.
  Future<void> _removeObsoleteResults({
    required String roundId,
    required Set<String> keptParticipantIds,
  }) async {
    try {
      final existing = await _supabase
          .from('round_results')
          .select('participant_id')
          .eq('round_id', roundId);

      final obsolete =
          existing
              .map((row) => row['participant_id'] as String)
              .where((id) => !keptParticipantIds.contains(id))
              .toList();

      if (obsolete.isEmpty) return;

      await _supabase
          .from('round_results')
          .delete()
          .eq('round_id', roundId)
          .inFilter('participant_id', obsolete);

      print('🧹 ${obsolete.length} résultats obsolètes supprimés');
    } catch (e) {
      print('⚠️ Nettoyage des résultats obsolètes impossible: $e');
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
          .order('display_order', ascending: true)
          // Repli pour d'anciens résultats calculés avant l'ajout de l'ordre
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

      // Le rang est calculé une fois pour toutes au moment du calcul des
      // résultats, selon les critères retenus (moyenne, puis التجويد, puis
      // حسن الصوت, puis numéro d'inscription). Trier dessus rend la
      // pagination parfaitement stable et donne le vrai classement, même
      // pour un résultat isolé trouvé par la recherche.
      final response = await query
          // Ordre d'affichage unique : pagination stable
          .order('display_order', ascending: true)
          // Repli pour d'anciens résultats calculés avant son ajout
          .order('score', ascending: false)
          .order('id', ascending: true)
          .range(from, to)
          .count(CountOption.exact);

      final totalCount = response.count;
      List<RoundResult> results =
          response.data
              .map<RoundResult>((row) => RoundResult.fromMap(row))
              .toList();

      // Résultats calculés avant l'enregistrement du rang : il faut le
      // reconstituer. La position dans la liste ne convient pas — en
      // recherche elle vaudrait 1 pour le premier résultat trouvé, quel que
      // soit son vrai classement.
      if (results.any((result) => result.rank == null)) {
        results = await _fillMissingRanks(
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

  /// Reconstitue le rang des résultats qui n'en ont pas encore d'enregistré.
  ///
  /// Une seule requête ramène les notes du round (une colonne numérique,
  /// quelques centaines de valeurs au plus), et le rang se déduit de la
  /// position de la note parmi les notes distinctes triées — exactement la
  /// même règle qu'au calcul : note égale ⇒ rang égal, sans saut.
  Future<List<RoundResult>> _fillMissingRanks(
    List<RoundResult> results, {
    required String roundId,
    required String ageGroup,
  }) async {
    try {
      final rows = await _supabase
          .from('round_results')
          .select('score')
          .eq('round_id', roundId)
          .eq('age_group', ageGroup);

      final distinctScores =
          rows
              .map<double>((row) => (row['score'] as num).toDouble())
              .toSet()
              .toList()
            ..sort((a, b) => b.compareTo(a));

      return results.map((result) {
        if (result.rank != null) return result;

        final position = distinctScores.indexOf(result.score);
        return position < 0 ? result : result.copyWith(rank: position + 1);
      }).toList();
    } catch (e) {
      print('⚠️ Impossible de reconstituer les rangs: $e');
      return results;
    }
  }

  /// Construit le filtre PostgREST appliqué à la table `participants`.
  ///
  /// - numéro d'inscription : correspondance exacte (ex: "4" trouve
  ///   uniquement le n°4, pas 14, 40 ou 404)
  /// - nom complet : correspondance partielle (ilike), seulement si la
  ///   saisie n'est pas un nombre et que [includeName] est vrai (certains
  ///   écrans cherchent par numéro seul)
  String _buildParticipantSearchFilter(
    String search, {
    bool includeName = true,
  }) {
    // Les virgules et parenthèses sont des séparateurs de la syntaxe `or`.
    final sanitized =
        SearchUtils.normalizeDigits(
          search,
        ).replaceAll(RegExp(r'[,()."*]'), ' ').trim();
    if (sanitized.isEmpty) return '';

    final numeric = SearchUtils.numericQuery(sanitized);
    final digits = numeric ?? sanitized.replaceAll(RegExp(r'\D'), '');
    final filters = <String>[
      if (numeric == null && includeName) 'full_name.ilike.*$sanitized*',
      if ((numeric != null || !includeName) &&
          digits.isNotEmpty &&
          digits.length <= 9)
        'registration_number.eq.${int.parse(digits)}',
    ];

    return filters.join(',');
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
