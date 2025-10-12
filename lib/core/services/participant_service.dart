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
              .select('is_active, is_registration_open')
              .eq('id', versionId)
              .single();

      final bool isActive = versionCheck['is_active'] as bool;
      final bool isRegistrationOpen =
          versionCheck['is_registration_open'] as bool;

      if (!isActive || !isRegistrationOpen) {
        throw Exception('التسجيل غير متاح لهذه المسابقة');
      }

      // 1. Insérer le participant (sans version_id ni registration_number)
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
                'created_at': participant.createdAt.toIso8601String(),
                'is_accepted': participant.isAccepted,
                'rejection_reason': participant.rejectionReason,
              })
              .select()
              .single();

      print("Inscription réussie : $response");

      // 2. Récupérer l'id du participant nouvellement créé
      final participantId = response['id'] as String;

      // 3. Créer l'entrée dans la table de liaison participant_versions
      final versionResponse =
          await _supabase
              .from('participant_versions')
              .insert({
                'participant_id': participantId,
                'version_id': versionId,
                'created_at': DateTime.now().toIso8601String(),
              })
              .select()
              .single();

      print("Version response: $versionResponse");

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
    dynamic response;

    if (activeRound?.number == 1) {
      // Round 1 ou pas encore défini → tous les participants
      response = await _supabase
          .from('participant_versions')
          .select('participant_id, participants(*)')
          .eq('version_id', versionId);
      return response.map<Participant>((record) {
        final participantData = record['participants'] as Map<String, dynamic>;
        return Participant.fromMap(participantData);
      }).toList();
    } else if (activeRound?.number == 2) {
      // Round 2 et plus → uniquement ceux qui ont passé le round 1
      response = await _supabase
          .from('participant_versions')
          .select('participant_id, participants(*)')
          .eq('version_id', versionId)
          .eq('passed_round1', true);
      return response.map<Participant>((record) {
        final participantData = record['participants'] as Map<String, dynamic>;
        return Participant.fromMap(participantData);
      }).toList();
    } else {
      return [];
    }
  }

  Future<List<Participant>> fetchParticipantsByVersion(
    String versionId, {
    Round? activeRound,
  }) async {
    final response;
    if (activeRound == null) {
      response = await _supabase
          .from('participant_versions')
          .select('participant_id, participants(*)')
          .eq('version_id', versionId);
    } else if (activeRound.name == 'الجولة الأولى') {
      response = await _supabase
          .from('participant_versions')
          .select('participant_id, participants(*)')
          .eq('version_id', versionId);
    } else {
      response = await _supabase
          .from('participant_versions')
          .select('participant_id, participants(*)')
          .eq('version_id', versionId)
          .eq('passed_round1', true);
    }

    return response.map<Participant>((record) {
      final participantData = record['participants'] as Map<String, dynamic>;
      return Participant.fromMap(participantData);
    }).toList();
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
      // Récupérer les participants via la table participant_versions
      final response = await _supabase
          .from('participant_versions')
          .select('''
            participants (
              id,
              full_name,
              gender,
              birth_date,
              phone,
              quran_memorized,
              reading_methods,
              residence,
              has_ijaza,
              won_previous_ranks,
              participated_before,
              age_group,
              created_at,
              is_accepted,
              registration_number,
              rejection_reason
            )
          ''')
          .eq('version_id', versionId)
          .order('created_at', ascending: false)
          .range(page * pageSize, (page + 1) * pageSize - 1);

      return response
          .map((item) => Participant.fromMap(item['participants']))
          .toList();
    } catch (e) {
      print('Erreur lors de la récupération des participants: $e');
      rethrow;
    }
  }

  /// Récupère tous les participants d'une version (sans pagination)
  Future<List<Participant>> getAllParticipantsByVersion(
    String versionId,
  ) async {
    try {
      final response = await _supabase
          .from('participant_versions')
          .select('''
            participants (
              id,
              full_name,
              gender,
              birth_date,
              phone,
              quran_memorized,
              reading_methods,
              residence,
              has_ijaza,
              won_previous_ranks,
              participated_before,
              age_group,
              created_at,
              is_accepted,
              registration_number,
              rejection_reason
            )
          ''')
          .eq('version_id', versionId)
          .order('created_at', ascending: false);

      return response
          .map((item) => Participant.fromMap(item['participants']))
          .toList();
    } catch (e) {
      print('Erreur lors de la récupération de tous les participants: $e');
      rethrow;
    }
  }

  /// Récupère tous les participants de toutes les versions (pour versionId = 'default')
  Future<List<Participant>> getAllParticipantsFromAllVersions() async {
    try {
      final response = await _supabase
          .from('participant_versions')
          .select('''
            participants (
              id,
              full_name,
              gender,
              birth_date,
              phone,
              quran_memorized,
              reading_methods,
              residence,
              has_ijaza,
              won_previous_ranks,
              participated_before,
              age_group,
              created_at,
              is_accepted,
              registration_number,
              rejection_reason
            )
          ''')
          .order('created_at', ascending: false);

      return response
          .map((item) => Participant.fromMap(item['participants']))
          .toList();
    } catch (e) {
      print('Erreur lors de la récupération de tous les participants: $e');

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
