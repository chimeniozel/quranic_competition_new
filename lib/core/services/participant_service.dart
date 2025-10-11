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
              })
              .select()
              .single();

      print("Inscription réussie : $response");

      // 2. Récupérer l'id du participant nouvellement créé
      final participantId = response['id'] as String;

      // 3. Créer l’entrée dans la table de liaison participant_versions
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

      // 4. Récupérer le numéro d’inscription si généré depuis la base
      final registrationNumber = versionResponse['registration_number'] as int;

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
}
