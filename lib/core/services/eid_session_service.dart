import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:quranic_competition/models/eid_session.dart';
import 'package:quranic_competition/models/eid_participant.dart';
import 'dart:math';

class EidSessionService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ========== SESSIONS ==========

  /// Récupère la session active (une seule à la fois)
  Future<EidSession?> getActiveSession() async {
    try {
      final response = await _supabase
          .from('eid_sessions')
          .select('*')
          .eq('is_active', true)
          .maybeSingle();

      if (response == null) return null;
      return EidSession.fromMap(response);
    } catch (e) {
      print('❌ Erreur lors de la récupération de la session active: $e');
      return null;
    }
  }

  /// Récupère toutes les sessions (pour admin)
  Future<List<EidSession>> getAllSessions() async {
    try {
      final response = await _supabase
          .from('eid_sessions')
          .select('*')
          .order('created_at', ascending: false);

      return response.map((row) => EidSession.fromMap(row)).toList();
    } catch (e) {
      print('❌ Erreur lors de la récupération des sessions: $e');
      return [];
    }
  }

  /// Crée une nouvelle session
  Future<EidSession> createSession({
    required String name,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    bool isActive = true,
    bool isOpen = true,
  }) async {
    try {
      // Si on essaie d'activer une session, désactiver les autres d'abord
      if (isActive) {
        await _supabase
            .from('eid_sessions')
            .update({'is_active': false})
            .eq('is_active', true);
      }

      final now = DateTime.now();
      final sessionData = {
        'name': name,
        'description': description,
        'start_date': startDate?.toIso8601String(),
        'end_date': endDate?.toIso8601String(),
        'is_active': isActive,
        'is_open': isOpen,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };

      final response = await _supabase
          .from('eid_sessions')
          .insert(sessionData)
          .select()
          .single();

      return EidSession.fromMap(response);
    } catch (e) {
      print('❌ Erreur lors de la création de la session: $e');
      throw Exception('Impossible de créer la session');
    }
  }

  /// Met à jour une session
  Future<EidSession> updateSession({
    required String id,
    String? name,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    bool? isActive,
    bool? isOpen,
  }) async {
    try {
      // Si on essaie d'activer cette session, désactiver les autres d'abord
      if (isActive == true) {
        await _supabase
            .from('eid_sessions')
            .update({'is_active': false})
            .eq('is_active', true)
            .neq('id', id);
      }

      final updateData = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (name != null) updateData['name'] = name;
      if (description != null) updateData['description'] = description;
      if (startDate != null) updateData['start_date'] = startDate.toIso8601String();
      if (endDate != null) updateData['end_date'] = endDate.toIso8601String();
      if (isActive != null) updateData['is_active'] = isActive;
      if (isOpen != null) updateData['is_open'] = isOpen;

      final response = await _supabase
          .from('eid_sessions')
          .update(updateData)
          .eq('id', id)
          .select()
          .single();

      return EidSession.fromMap(response);
    } catch (e) {
      print('❌ Erreur lors de la mise à jour de la session: $e');
      throw Exception('Impossible de mettre à jour la session');
    }
  }

  /// Supprime une session
  Future<void> deleteSession(String id) async {
    try {
      await _supabase.from('eid_sessions').delete().eq('id', id);
    } catch (e) {
      print('❌ Erreur lors de la suppression de la session: $e');
      throw Exception('Impossible de supprimer la session');
    }
  }

  // ========== PARTICIPANTS ==========

  /// Récupère tous les participants d'une session
  Future<List<EidParticipant>> getParticipantsBySession(String sessionId) async {
    try {
      final response = await _supabase
          .from('eid_participants')
          .select('*')
          .eq('session_id', sessionId)
          .order('created_at', ascending: false);

      return response.map((row) => EidParticipant.fromMap(row)).toList();
    } catch (e) {
      print('❌ Erreur lors de la récupération des participants: $e');
      return [];
    }
  }

  /// Inscrit un participant à une session
  Future<EidParticipant> registerParticipant({
    required String sessionId,
    required String fullName,
    required String phone,
    required String gender,
  }) async {
    try {
      // 1. Récupérer la session par ID et vérifier son statut
      final sessionData = await _supabase
          .from('eid_sessions')
          .select('*')
          .eq('id', sessionId)
          .maybeSingle();

      if (sessionData == null) {
        throw Exception('الفسحة أو الدورة غير موجودة');
      }

      final session = EidSession.fromMap(sessionData);

      // 2. Vérifier que la session est active (visible)
      if (!session.isActive) {
        throw Exception('الفسحة أو الدورة غير مفعلة حالياً');
      }

      // 3. Vérifier que l'inscription est ouverte
      if (!session.isOpen) {
        throw Exception('التسجيل مغلق لهذه الفسحة أو الدورة');
      }

      final now = DateTime.now();
      final participantData = {
        'session_id': sessionId,
        'full_name': fullName,
        'phone': phone,
        'gender': gender,
        'is_winner': false,
        'created_at': now.toIso8601String(),
      };

      final response = await _supabase
          .from('eid_participants')
          .insert(participantData)
          .select()
          .single();

      return EidParticipant.fromMap(response);
    } catch (e) {
      print('❌ Erreur lors de l\'inscription: $e');
      rethrow;
    }
  }

  /// Sélectionne des gagnants aléatoirement (loterie)
  /// Les nouveaux gagnants remplacent les anciens gagnants de la session
  /// Le tirage n'est possible que si la session est active et l'inscription est fermée
  Future<List<EidParticipant>> selectWinners({
    required String sessionId,
    required int numberOfWinners,
  }) async {
    try {
      // 1. Vérifier que la session est active et que l'inscription est fermée
      final session = await _supabase
          .from('eid_sessions')
          .select('*')
          .eq('id', sessionId)
          .maybeSingle();

      if (session == null) {
        throw Exception('الفسحة أو الدورة غير موجودة');
      }

      final sessionData = EidSession.fromMap(session);
      
      if (!sessionData.isActive) {
        throw Exception('لا يمكن إجراء القرعة لأن الفسحة أو الدورة غير مفعلة');
      }

      if (sessionData.isOpen) {
        throw Exception('لا يمكن إجراء القرعة لأن التسجيل لا يزال مفتوحاً. يجب إغلاق التسجيل أولاً');
      }

      // 2. Réinitialiser tous les anciens gagnants de cette session
      await _supabase
          .from('eid_participants')
          .update({'is_winner': false})
          .eq('session_id', sessionId)
          .eq('is_winner', true);

      // 3. Récupérer tous les participants de la session
      final allParticipants = await _supabase
          .from('eid_participants')
          .select('*')
          .eq('session_id', sessionId);

      if (allParticipants.isEmpty) {
        throw Exception('لا يوجد مشاركون في هذه الفسحة أو الدورة');
      }

      // Vérifier que le nombre de gagnants est entre 1 et 10
      if (numberOfWinners < 1 || numberOfWinners > 10) {
        throw Exception('عدد الفائزين يجب أن يكون بين 1 و 10');
      }

      if (allParticipants.length < numberOfWinners) {
        throw Exception('عدد المتسابقين (${allParticipants.length}) أقل من عدد الفائزين المطلوبة ($numberOfWinners)');
      }

      // 3. Randomiser tous les participants
      final shuffled = List<Map<String, dynamic>>.from(allParticipants);
      final random = Random(DateTime.now().millisecondsSinceEpoch);
      shuffled.shuffle(random);

      // 4. Sélectionner les nouveaux gagnants
      final winners = shuffled.take(numberOfWinners).toList();

      // 5. Marquer les nouveaux gagnants dans la base de données
      final winnerIds = winners.map((w) => w['id'] as String).toList();
      await _supabase
          .from('eid_participants')
          .update({'is_winner': true})
          .inFilter('id', winnerIds);

      // 6. Récupérer les gagnants mis à jour
      final updatedWinners = await _supabase
          .from('eid_participants')
          .select('*')
          .inFilter('id', winnerIds);

      return updatedWinners
          .map((row) => EidParticipant.fromMap(row))
          .toList();
    } catch (e) {
      print('❌ Erreur lors de la sélection des gagnants: $e');
      rethrow;
    }
  }

  /// Réinitialise les gagnants (pour refaire la loterie)
  Future<void> resetWinners(String sessionId) async {
    try {
      await _supabase
          .from('eid_participants')
          .update({'is_winner': false})
          .eq('session_id', sessionId);
    } catch (e) {
      print('❌ Erreur lors de la réinitialisation des gagnants: $e');
      rethrow;
    }
  }

  /// Récupère les gagnants d'une session
  Future<List<EidParticipant>> getWinners(String sessionId) async {
    try {
      final response = await _supabase
          .from('eid_participants')
          .select('*')
          .eq('session_id', sessionId)
          .eq('is_winner', true)
          .order('created_at', ascending: false);

      return response.map((row) => EidParticipant.fromMap(row)).toList();
    } catch (e) {
      print('❌ Erreur lors de la récupération des gagnants: $e');
      return [];
    }
  }

  /// Supprime un participant
  Future<void> deleteParticipant(String participantId) async {
    try {
      await _supabase.from('eid_participants').delete().eq('id', participantId);
    } catch (e) {
      print('❌ Erreur lors de la suppression du participant: $e');
      rethrow;
    }
  }

  /// Compte le nombre de participants par session
  Future<int> getParticipantCount(String sessionId) async {
    try {
      final response = await _supabase
          .from('eid_participants')
          .select('id')
          .eq('session_id', sessionId);

      return response.length;
    } catch (e) {
      print('❌ Erreur lors du comptage des participants: $e');
      return 0;
    }
  }
}

