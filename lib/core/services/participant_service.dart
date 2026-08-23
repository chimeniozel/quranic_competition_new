import 'package:quranic_competition/models/participant.dart';
import 'package:quranic_competition/models/round.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ParticipantService {
  final _supabase = Supabase.instance.client;

  Future<int> registerParticipant({
    required Participant participant,
    required String versionId,
  }) async {
    const int maxRetries = 3;
    int retryCount = 0;

    while (retryCount < maxRetries) {
      try {
        // 0. Vérifier que l'inscription est toujours ouverte pour cette version
        final versionCheck =
            await _supabase
                .from('competition_versions')
                .select(
                  'is_active, is_registration_open, max_adults, max_children',
                )
                .eq('id', versionId)
                .single();

        final bool isActive = versionCheck['is_active'] as bool;
        final bool isRegistrationOpen =
            versionCheck['is_registration_open'] as bool;
        final int maxAdults = versionCheck['max_adults'] as int;
        final int maxChildren = versionCheck['max_children'] as int;

        if (!isActive || !isRegistrationOpen) {
          throw Exception('التسجيل غير متاح لهذه النسخة');
        }

        // 0.1. Vérifier les limites de participants pour cette version spécifique
        final currentAdultsCount = await _supabase
            .from('participants')
            .select('id')
            .eq('competition_id', versionId)
            .eq('age_group', 'كبار')
            .then((response) => response.length);

        final currentChildrenCount = await _supabase
            .from('participants')
            .select('id')
            .eq('competition_id', versionId)
            .eq('age_group', 'صغار')
            .then((response) => response.length);

        print(
          '📊 Vérification côté serveur: Adultes=$currentAdultsCount/$maxAdults, Enfants=$currentChildrenCount/$maxChildren',
        );

        // Vérifier si le groupe d'âge du participant a atteint sa limite
        if (participant.ageGroup == 'كبار' && currentAdultsCount >= maxAdults) {
          throw Exception(
            'تم الوصول للحد الأقصى من المشاركين في فرع الكبار ($maxAdults مشارك)',
          );
        }

        if (participant.ageGroup == 'صغار' &&
            currentChildrenCount >= maxChildren) {
          throw Exception(
            'تم الوصول للحد الأقصى من المشاركين في فرع الصغار ($maxChildren مشارك)',
          );
        }

        // 0.2. Vérifier qu'aucun participant n'existe déjà avec le même téléphone pour cette compétition
        final existingParticipants = await _supabase
            .from('participants')
            .select('id')
            .eq('competition_id', versionId)
            .eq('phone', participant.phone)
            .limit(1);

        if (existingParticipants.isNotEmpty) {
          throw Exception('يوجد مشارك بنفس رقم الهاتف في هذه النسخة.');
        }

        // 0.3. Générer le numéro d'enregistrement pour cette compétition
        final nextRegistrationNumber = await _getNextRegistrationNumber(
          versionId,
        );
        print(
          '📝 Prochain numéro d\'enregistrement pour la compétition $versionId: $nextRegistrationNumber',
        );

        // 1. Insérer le participant avec competition_id et numéro d'enregistrement
        final response =
            await _supabase
                .from('participants')
                .insert({
                  'full_name': participant.fullName,
                  'gender': participant.gender,
                  'birth_date': participant.birthDate.toIso8601String(),
                  'phone': participant.phone,
                  'quran_memorized': participant.quranMemorized,
                  'reading_methods': participant.readingMethods,
                  'residence': participant.residence,
                  'has_ijaza': participant.hasIjaza,
                  'won_previous_ranks': participant.wonPreviousRanks,
                  'participated_before': participant.participatedBefore,
                  'age_group': participant.ageGroup,
                  'competition_id': versionId, // Ajouter le competition_id
                  'registration_number':
                      nextRegistrationNumber, // Ajouter le numéro d'enregistrement
                  'created_at': participant.createdAt.toIso8601String(),
                  'is_accepted': participant.isAccepted,
                  'rejection_reason': participant.rejectionReason,
                })
                .select()
                .single();

        print("Inscription réussie : $response");

        // 2. Récupérer l'id du participant nouvellement créé
        final participantId = response['id'] as String;

        // 3. Note: La table participant_versions n'est plus utilisée
        // Les participants sont maintenant directement liés aux compétitions via la table participants
        print("Participant créé avec succès, ID: $participantId");

        // 4. Retourner le numéro d'enregistrement généré
        print(
          "✅ Participant inscrit avec le numéro d'enregistrement: $nextRegistrationNumber",
        );
        return nextRegistrationNumber;
      } catch (e) {
        retryCount++;
        print(
          '⚠️ Tentative d\'inscription $retryCount/$maxRetries échouée: $e',
        );

        if (e is PostgrestException) {
          final errorMessage =
              '${e.message} ${e.details ?? ''} ${e.hint ?? ''}';

          if (errorMessage.contains('competition_id, phone')) {
            throw Exception('يوجد مشارك بنفس رقم الهاتف في هذه النسخة.');
          }

          if (errorMessage.contains('registration_number')) {
            if (retryCount < maxRetries) {
              print('🔄 Conflit de numéro détecté, nouvelle tentative...');
              await Future.delayed(Duration(milliseconds: 100 * retryCount));
              continue;
            }
          }
        } else {
          final errorString = e.toString();

          if (errorString.contains('competition_id, phone')) {
            throw Exception('يوجد مشارك بنفس رقم الهاتف في هذه النسخة.');
          }

          if (errorString.contains('registration_number') ||
              errorString.contains('duplicate key') ||
              errorString.contains('unique constraint')) {
            if (retryCount < maxRetries) {
              print('🔄 Conflit de numéro détecté, nouvelle tentative...');
              await Future.delayed(Duration(milliseconds: 100 * retryCount));
              continue;
            }
          }
        }

        print('❌ Erreur lors de l\'inscription: $e');
        throw Exception('Erreur lors de l\'inscription: $e');
      }
    }

    // Ne devrait jamais arriver ici
    throw Exception('Échec de l\'inscription après $maxRetries tentatives');
  }

  /// Génère le prochain numéro d'enregistrement pour une compétition donnée
  /// Utilise un mécanisme atomique pour éviter les race conditions
  Future<int> _getNextRegistrationNumber(String versionId) async {
    const int maxRetries = 3;
    int retryCount = 0;

    while (retryCount < maxRetries) {
      try {
        // Utiliser une transaction atomique pour générer le numéro
        final response = await _supabase.rpc(
          'get_next_registration_number',
          params: {'competition_id': versionId},
        );

        if (response != null) {
          final registrationNumber = response as int;
          print(
            '✅ Numéro d\'enregistrement généré atomiquement: $registrationNumber pour la compétition $versionId',
          );
          return registrationNumber;
        } else {
          throw Exception('Erreur lors de la génération du numéro');
        }
      } catch (e) {
        retryCount++;
        print(
          '⚠️ Tentative $retryCount/$maxRetries échouée pour la compétition $versionId: $e',
        );

        if (retryCount >= maxRetries) {
          // En cas d'échec total, utiliser la méthode de fallback
          print('🔄 Utilisation de la méthode de fallback');
          return await _getNextRegistrationNumberFallback(versionId);
        }

        // Attendre un court délai avant de réessayer
        await Future.delayed(Duration(milliseconds: 100 * retryCount));
      }
    }

    // Ne devrait jamais arriver ici
    return 1;
  }

  /// Méthode de fallback en cas d'échec de la méthode atomique
  Future<int> _getNextRegistrationNumberFallback(String versionId) async {
    try {
      // Récupérer le plus grand numéro d'enregistrement pour cette compétition
      // Filtrer les valeurs NULL pour éviter les problèmes
      final response = await _supabase
          .from('participants')
          .select('registration_number')
          .eq('competition_id', versionId)
          .not('registration_number', 'is', null)
          .order('registration_number', ascending: false)
          .limit(1);

      if (response.isEmpty) {
        // Premier participant de cette compétition
        print(
          '🎯 Premier participant pour la compétition $versionId (fallback)',
        );
        return 1;
      }

      final maxRegistrationNumber =
          response.first['registration_number'] as int? ?? 0;
      final nextNumber = maxRegistrationNumber + 1;

      print(
        '📊 Compétition $versionId (fallback): Dernier numéro = $maxRegistrationNumber, Prochain = $nextNumber',
      );
      return nextNumber;
    } catch (e) {
      print(
        '❌ Erreur lors de la génération du numéro d\'enregistrement (fallback): $e',
      );
      // En cas d'erreur, retourner 1 pour éviter les blocages
      return 1;
    }
  }

  Future<List<Participant>> fetchParticipantsByVersionAndRounds(
    String versionId, {
    Round? activeRound,
  }) async {
    print(
      '🔍 ParticipantService - fetchParticipantsByVersionAndRounds pour version: $versionId, round: ${activeRound?.number}',
    );

    try {
      if (activeRound == null) {
        // Aucun round sélectionné → retourner tous les participants acceptés de la version
        final response = await _supabase
            .from('participants')
            .select('*')
            .eq('competition_id', versionId)
            .eq('is_accepted', true);

        final participants =
            response
                .map<Participant>((record) => Participant.fromMap(record))
                .toList();

        print(
          '🔍 Aucun round spécifique: ${participants.length} participants acceptés trouvés pour la version $versionId',
        );
        return participants;
      }

      if (activeRound.number == 1) {
        // Round 1 → tous les participants acceptés de la version
        print(
          '🔍 Round 1: Récupération de tous les participants acceptés pour la version $versionId',
        );
        final response = await _supabase
            .from('participants')
            .select('*')
            .eq('competition_id', versionId)
            .eq('is_accepted', true);

        final participants =
            response
                .map<Participant>((record) => Participant.fromMap(record))
                .toList();

        print(
          '🔍 Round 1: ${participants.length} participants acceptés trouvés pour la version $versionId',
        );
        return participants;
      }

      // Round >= 2 → participants qui ont réussi le round précédent
      print(
        '🔍 Round ${activeRound.number}: Récupération des participants qualifiés depuis le round précédent',
      );

      // Identifier le round précédent
      final previousRoundNumber = activeRound.number - 1;
      final previousRoundResponse =
          await _supabase
              .from('rounds')
              .select('id')
              .eq('version_id', versionId)
              .eq('number', previousRoundNumber)
              .maybeSingle();

      List<Participant> qualifiedParticipants = [];

      if (previousRoundResponse != null) {
        final previousRoundId = previousRoundResponse['id'] as String;
        final qualifiedResponse = await _supabase
            .from('round_results')
            .select('participants(*)')
            .eq('version_id', versionId)
            .eq('round_id', previousRoundId)
            .eq('passed', true);

        qualifiedParticipants =
            qualifiedResponse.map<Participant>((row) {
              final participantMap =
                  row['participants'] as Map<String, dynamic>? ?? {};
              final participant = Participant.fromMap(participantMap);
              // S'assurer que le participant est marqué comme qualifié
              participant.passedRound1 = true;
              return participant;
            }).toList();

        print(
          '🔍 Round ${activeRound.number}: ${qualifiedParticipants.length} participants qualifiés via round_results',
        );
      } else {
        print(
          '⚠️ Aucun round précédent trouvé pour la version $versionId (round ${activeRound.number})',
        );
      }

      // Fallback pour compatibilité si round_results ne contient pas encore de données
      if (qualifiedParticipants.isEmpty) {
        print(
          '⚠️ Aucun participant trouvé via round_results, fallback sur passed_round1',
        );
        final fallbackResponse = await _supabase
            .from('participants')
            .select('*')
            .eq('competition_id', versionId)
            .eq('is_accepted', true)
            .eq('passed_round1', true);

        qualifiedParticipants =
            fallbackResponse
                .map<Participant>((record) => Participant.fromMap(record))
                .toList();
      }

      print(
        '🔍 Round ${activeRound.number}: ${qualifiedParticipants.length} participants qualifiés retournés',
      );
      return qualifiedParticipants;
    } catch (e) {
      print('❌ Erreur dans fetchParticipantsByVersionAndRounds: $e');
      return [];
    }
  }

  Future<List<Participant>> fetchParticipantsByVersion(
    String versionId, {
    Round? activeRound,
    bool includeRejected = false,
  }) async {
    print(
      '🔍 ParticipantService - fetchParticipantsByVersion pour version: $versionId, round: ${activeRound?.name}, includeRejected: $includeRejected',
    );

    try {
      if (activeRound == null || activeRound.name == 'الجولة الأولى') {
        // Round 1 ou pas de round → participants acceptés ou tous selon includeRejected
        print(
          '🔍 Round 1 ou pas de round: Récupération ${includeRejected ? 'de tous les participants' : 'des participants acceptés'}',
        );
        // Chaque version a sa propre liste : on filtre impérativement sur
        // competition_id, sinon les participants des autres versions
        // apparaissent dans celle-ci.
        var query = _supabase
            .from('participants')
            .select('*')
            .eq('competition_id', versionId);

        if (!includeRejected) {
          query = query.eq('is_accepted', true);
        }

        final response = await query;

        final participants =
            response.map<Participant>((record) {
              return Participant.fromMap(record);
            }).toList();

        print(
          '🔍 Round 1 ou pas de round: ${participants.length} participants trouvés',
        );
        return participants;
      } else {
        // Round 2+ → participants acceptés ET qui ont passé le round 1
        print(
          '🔍 Round ${activeRound.name}: Récupération des participants acceptés et qualifiés',
        );

        // Récupérer tous les participants acceptés (pour les rounds, on ne prend que les acceptés)
        final allParticipantsResponse = await _supabase
            .from('participants')
            .select('*')
            .eq('competition_id', versionId)
            .eq('is_accepted', true);

        final allParticipants =
            allParticipantsResponse.map<Participant>((record) {
              return Participant.fromMap(record);
            }).toList();

        // Filtrer ceux qui ont passé le round 1
        final qualifiedParticipants = <Participant>[];
        for (final participant in allParticipants) {
          // Vérifier si le participant a passé le round 1
          if (participant.passedRound1 == true) {
            qualifiedParticipants.add(participant);
          }
        }

        print(
          '🔍 Round ${activeRound.name}: ${qualifiedParticipants.length} participants qualifiés trouvés',
        );
        return qualifiedParticipants;
      }
    } catch (e) {
      print('❌ Erreur dans fetchParticipantsByVersion: $e');
      return [];
    }
  }

  // Supprimer un participant
  Future<void> deleteParticipant(String participantId) async {
    try {
      await _supabase.from('participants').delete().eq('id', participantId);
    } catch (e) {
      throw Exception('Erreur lors de la suppression du participant: $e');
    }
  }

  // Mettre à jour le statut d'acceptation d'un participant
  Future<void> updateParticipantAcceptance(
    String participantId,
    bool isAccepted,
  ) async {
    try {
      await _supabase
          .from('participants')
          .update({'is_accepted': isAccepted})
          .eq('id', participantId);
    } catch (e) {
      throw Exception('Erreur lors de la mise à jour du statut: $e');
    }
  }

  /// Récupère les participants d'une version spécifique avec pagination
  Future<List<Participant>> getParticipantsByVersion(
    String versionId, {
    int page = 0,
    int pageSize = 20,
  }) async {
    try {
      print(
        '🔍 ParticipantService - getParticipantsByVersion pour version: $versionId, page: $page, pageSize: $pageSize',
      );

      // Uniquement les participants inscrits à CETTE version
      final response = await _supabase
          .from('participants')
          .select('*')
          .eq('competition_id', versionId)
          .order('created_at', ascending: false)
          .range(page * pageSize, (page + 1) * pageSize - 1);

      final participants =
          response.map<Participant>((record) {
            return Participant.fromMap(record);
          }).toList();

      print(
        '🔍 ParticipantService - getParticipantsByVersion: ${participants.length} participants récupérés',
      );
      return participants;
    } catch (e) {
      print('❌ Erreur dans getParticipantsByVersion: $e');
      rethrow;
    }
  }

  /// Récupère tous les participants d'une version (sans pagination)
  Future<List<Participant>> getAllParticipantsByVersion(
    String versionId,
  ) async {
    try {
      print(
        '🔍 ParticipantService - getAllParticipantsByVersion pour version: $versionId',
      );

      // Uniquement les participants inscrits à CETTE version
      final response = await _supabase
          .from('participants')
          .select('*')
          .eq('competition_id', versionId)
          .order('created_at', ascending: false);

      final participants =
          response.map<Participant>((record) {
            return Participant.fromMap(record);
          }).toList();

      print(
        '🔍 ParticipantService - getAllParticipantsByVersion: ${participants.length} participants récupérés',
      );
      return participants;
    } catch (e) {
      print('❌ Erreur dans getAllParticipantsByVersion: $e');
      rethrow;
    }
  }
}
