import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:quranic_competition/models/evaluation.dart';

class EvaluationService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> submitEvaluation(Evaluation evaluation, String ageGroup) async {
    try {
      final notesJson =
          ageGroup == 'كبار'
              ? evaluation.noteModel.toMapAdult()
              : evaluation.noteModel.toMapChild();

      final response =
          await _supabase.from('evaluations').insert({
            'participant_id': evaluation.participantId,
            'jury_id': evaluation.juryId,
            'version_id': evaluation.versionId,
            'round': evaluation.round,
            'total_score': evaluation.totalScore,
            'notes': evaluation.notes,
            'notes_json': notesJson, // colonne JSON dans la base
            'submitted_at': evaluation.submittedAt.toIso8601String(),
          }).select(); // facultatif si tu veux récupérer l’ID inséré

      print("✅ Évaluation enregistrée : $response");
    } catch (e) {
      print('❌ Erreur lors de l’enregistrement de l’évaluation : $e');
      throw Exception('Échec d’enregistrement de l’évaluation');
    }
  }

  Future<Evaluation?> getEvaluationByJuryAndParticipant({
    required String juryId,
    required String participantId,
    required String versionId,
    required int round,
    required String ageGroup, // ✅ ajouté
  }) async {
    final response =
        await _supabase
            .from('evaluations')
            .select()
            .eq('jury_id', juryId)
            .eq('participant_id', participantId)
            .eq('version_id', versionId)
            .eq('round', round)
            .maybeSingle();

    if (response == null) return null;

    return Evaluation.fromMap(response, ageGroup); // ✅ passé ici
  }

  Future<void> updateEvaluation(Evaluation evaluation, String ageGroup) async {
    try {
      final updateMap = {
        'total_score': evaluation.totalScore,
        'notes': evaluation.notes,
        'submitted_at': evaluation.submittedAt.toIso8601String(),
        'notes_json':
            ageGroup == "كبار"
                ? evaluation.noteModel.toMapAdult()
                : evaluation.noteModel.toMapChild(),
      };

      await _supabase
          .from('evaluations')
          .update(updateMap)
          .eq('id', evaluation.id);

      print('✅ Évaluation mise à jour avec succès');
    } catch (e) {
      print('❌ Erreur lors de la mise à jour de l\'évaluation : $e');
      throw Exception('Erreur lors de la mise à jour de l\'évaluation : $e');
    }
  }
}
