import 'package:quranic_competition/models/participant.dart';
import 'package:quranic_competition/models/round.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ParticipantService {
  final _supabase = Supabase.instance.client;

  Future<int> registerParticipant({
    required Participant participant,
    required String versionId,
  }) async {
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
        throw Exception('التسجيل غير متاح لهذه المسابقة');
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

      // 1. Insérer le participant avec competition_id
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

      // 4. Récupérer le numéro d'inscription depuis la réponse du participant
      final registrationNumberData = response['registration_number'];
      print("Registration number from participant: $registrationNumberData");
      final registrationNumber =
          registrationNumberData is int
              ? registrationNumberData
              : 0; // Valeur par défaut si null ou non int

      return registrationNumber;
    } catch (e) {
      print('Erreur lors de l\'inscription: $e');
      throw Exception('Erreur lors de l\'inscription: $e');
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
      if (activeRound?.number == 1) {
        // Round 1 → tous les participants acceptés
        print('🔍 Round 1: Récupération de tous les participants acceptés');
        final response = await _supabase
            .from('participants')
            .select('*')
            .eq('is_accepted', true);

        final participants =
            response.map<Participant>((record) {
              return Participant.fromMap(record);
            }).toList();

        print(
          '🔍 Round 1: ${participants.length} participants acceptés trouvés',
        );
        return participants;
      } else if (activeRound?.number == 2) {
        // Round 2+ → participants acceptés ET qui ont passé le round 1
        print(
          '🔍 Round ${activeRound?.number}: Récupération des participants acceptés et qualifiés',
        );

        // Récupérer tous les participants acceptés
        final allParticipantsResponse = await _supabase
            .from('participants')
            .select('*')
            .eq('is_accepted', true);

        final allParticipants =
            allParticipantsResponse.map<Participant>((record) {
              return Participant.fromMap(record);
            }).toList();

        // Filtrer ceux qui ont passé le round 1
        final qualifiedParticipants = <Participant>[];
        for (final participant in allParticipants) {
          // Vérifier si le participant a passé le round 1
          final passedRound1Response =
              await _supabase
                  .from('participant_versions')
                  .select('passed_round1')
                  .eq('participant_id', participant.id)
                  .eq('version_id', versionId)
                  .single();

          if (passedRound1Response['passed_round1'] == true) {
            qualifiedParticipants.add(participant);
          }
        }

        print(
          '🔍 Round ${activeRound?.number}: ${qualifiedParticipants.length} participants qualifiés trouvés',
        );
        return qualifiedParticipants;
      } else {
        // Pas de round spécifique → tous les participants acceptés
        print(
          '🔍 Pas de round spécifique: Récupération de tous les participants acceptés',
        );
        final response = await _supabase
            .from('participants')
            .select('*')
            .eq('is_accepted', true);

        final participants =
            response.map<Participant>((record) {
              return Participant.fromMap(record);
            }).toList();

        print(
          '🔍 Pas de round spécifique: ${participants.length} participants acceptés trouvés',
        );
        return participants;
      }
    } catch (e) {
      print('❌ Erreur dans fetchParticipantsByVersionAndRounds: $e');
      return [];
    }
  }

  Future<List<Participant>> fetchParticipantsByVersion(
    String versionId, {
    Round? activeRound,
  }) async {
    print(
      '🔍 ParticipantService - fetchParticipantsByVersion pour version: $versionId, round: ${activeRound?.name}',
    );

    try {
      if (activeRound == null || activeRound.name == 'الجولة الأولى') {
        // Round 1 ou pas de round → tous les participants acceptés
        print(
          '🔍 Round 1 ou pas de round: Récupération de tous les participants acceptés',
        );
        final response = await _supabase
            .from('participants')
            .select('*')
            .eq('is_accepted', true);

        final participants =
            response.map<Participant>((record) {
              return Participant.fromMap(record);
            }).toList();

        print(
          '🔍 Round 1 ou pas de round: ${participants.length} participants acceptés trouvés',
        );
        return participants;
      } else {
        // Round 2+ → participants acceptés ET qui ont passé le round 1
        print(
          '🔍 Round ${activeRound.name}: Récupération des participants acceptés et qualifiés',
        );

        // Récupérer tous les participants acceptés
        final allParticipantsResponse = await _supabase
            .from('participants')
            .select('*')
            .eq('is_accepted', true);

        final allParticipants =
            allParticipantsResponse.map<Participant>((record) {
              return Participant.fromMap(record);
            }).toList();

        // Filtrer ceux qui ont passé le round 1
        final qualifiedParticipants = <Participant>[];
        for (final participant in allParticipants) {
          // Vérifier si le participant a passé le round 1
          final passedRound1Response =
              await _supabase
                  .from('participant_versions')
                  .select('passed_round1')
                  .eq('participant_id', participant.id)
                  .eq('version_id', versionId)
                  .single();

          if (passedRound1Response['passed_round1'] == true) {
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

      // Récupérer directement depuis la table participants
      final response = await _supabase
          .from('participants')
          .select('*')
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

      // Récupérer directement depuis la table participants
      final response = await _supabase
          .from('participants')
          .select('*')
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

  /// Récupère tous les participants de toutes les versions (pour versionId = 'default')
  Future<List<Participant>> getAllParticipantsFromAllVersions() async {
    try {
      print('🔍 ParticipantService - getAllParticipantsFromAllVersions');

      // Récupérer directement depuis la table participants
      final response = await _supabase
          .from('participants')
          .select('*')
          .order('created_at', ascending: false);

      final participants =
          response.map<Participant>((record) {
            return Participant.fromMap(record);
          }).toList();

      print(
        '🔍 ParticipantService - getAllParticipantsFromAllVersions: ${participants.length} participants récupérés',
      );
      return participants;
    } catch (e) {
      print('❌ Erreur dans getAllParticipantsFromAllVersions: $e');

      // Gestion spécifique des erreurs de connexion
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Failed host lookup')) {
        throw Exception(
          'مشكلة في الاتصال بالإنترنت. يرجى التحقق من اتصالك والمحاولة مرة أخرى.',
        );
      } else if (e.toString().contains('timeout')) {
        throw Exception('انتهت مهلة الاتصال. يرجى المحاولة مرة أخرى.');
      } else {
        throw Exception('حدث خطأ في تحميل البيانات. يرجى المحاولة مرة أخرى.');
      }
    }
  }
}
