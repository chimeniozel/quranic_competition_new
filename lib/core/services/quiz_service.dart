import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:quranic_competition/models/quiz_level.dart';
import 'package:quranic_competition/models/quiz_question.dart';
import 'package:quranic_competition/models/quiz_option.dart';
import 'package:quranic_competition/models/quiz_result.dart';

class QuizService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ========== QUIZ LEVELS ==========

  // Créer un niveau de quiz
  Future<QuizLevel> createLevel({
    required String name,
    required String description,
    required int order,
  }) async {
    try {
      final now = DateTime.now();
      final levelData = {
        'name': name,
        'description': description,
        'order': order,
        'is_active': true,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };

      final response =
          await _supabase
              .from('quiz_levels')
              .insert(levelData)
              .select()
              .single();

      return QuizLevel.fromMap(response);
    } catch (e) {
      print('Erreur lors de la création du niveau: $e');
      throw Exception('Impossible de créer le niveau');
    }
  }

  // Récupérer tous les niveaux
  Future<List<QuizLevel>> getLevels() async {
    try {
      final response = await _supabase
          .from('quiz_levels')
          .select('*')
          .order('order', ascending: true);

      return response.map<QuizLevel>((row) => QuizLevel.fromMap(row)).toList();
    } catch (e) {
      print('Erreur lors de la récupération des niveaux: $e');
      throw Exception('Impossible de récupérer les niveaux');
    }
  }

  // Récupérer les niveaux actifs (pour les participants)
  Future<List<QuizLevel>> getActiveLevels() async {
    try {
      final response = await _supabase
          .from('quiz_levels')
          .select('*')
          .eq('is_active', true)
          .order('order', ascending: true);

      return response.map<QuizLevel>((row) => QuizLevel.fromMap(row)).toList();
    } catch (e) {
      print('Erreur lors de la récupération des niveaux actifs: $e');
      throw Exception('Impossible de récupérer les niveaux actifs');
    }
  }

  // Mettre à jour un niveau
  Future<QuizLevel> updateLevel({
    required String id,
    required String name,
    required String description,
    required int order,
  }) async {
    try {
      final now = DateTime.now();
      final updateData = {
        'name': name,
        'description': description,
        'order': order,
        'updated_at': now.toIso8601String(),
      };

      final response =
          await _supabase
              .from('quiz_levels')
              .update(updateData)
              .eq('id', id)
              .select()
              .single();

      return QuizLevel.fromMap(response);
    } catch (e) {
      print('Erreur lors de la mise à jour du niveau: $e');
      throw Exception('Impossible de mettre à jour le niveau');
    }
  }

  // Basculer le statut d'un niveau
  Future<void> toggleLevelStatus(String id) async {
    try {
      final currentLevel =
          await _supabase
              .from('quiz_levels')
              .select('is_active')
              .eq('id', id)
              .single();

      await _supabase
          .from('quiz_levels')
          .update({'is_active': !currentLevel['is_active']})
          .eq('id', id);
    } catch (e) {
      print('Erreur lors du basculement du statut: $e');
      throw Exception('Impossible de basculer le statut du niveau');
    }
  }

  // Supprimer un niveau
  Future<void> deleteLevel(String id) async {
    try {
      await _supabase.from('quiz_levels').delete().eq('id', id);
    } catch (e) {
      print('Erreur lors de la suppression du niveau: $e');
      throw Exception('Impossible de supprimer le niveau');
    }
  }

  // ========== QUIZ QUESTIONS ==========

  // Créer une question
  Future<QuizQuestion> createQuestion({
    required String levelId,
    required String question,
    String? imageUrl,
    required int points,
    required int order,
  }) async {
    try {
      final now = DateTime.now();
      final questionData = {
        'level_id': levelId,
        'question': question,
        'image_url': imageUrl,
        'points': points,
        'order': order,
        'is_active': true,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };

      final response =
          await _supabase
              .from('quiz_questions')
              .insert(questionData)
              .select()
              .single();

      return QuizQuestion.fromMap(response);
    } catch (e) {
      print('Erreur lors de la création de la question: $e');
      throw Exception('Impossible de créer la question');
    }
  }

  // Récupérer les questions d'un niveau
  Future<List<QuizQuestion>> getQuestionsByLevel(String levelId) async {
    try {
      final response = await _supabase
          .from('quiz_questions')
          .select('*')
          .eq('level_id', levelId)
          .eq('is_active', true)
          .order('order', ascending: true);

      return response
          .map<QuizQuestion>((row) => QuizQuestion.fromMap(row))
          .toList();
    } catch (e) {
      print('Erreur lors de la récupération des questions: $e');
      throw Exception('Impossible de récupérer les questions');
    }
  }

  // Mettre à jour une question
  Future<QuizQuestion> updateQuestion({
    required String id,
    required String question,
    String? imageUrl,
    required int points,
    required int order,
  }) async {
    try {
      final now = DateTime.now();
      final updateData = {
        'question': question,
        'image_url': imageUrl,
        'points': points,
        'order': order,
        'updated_at': now.toIso8601String(),
      };

      final response =
          await _supabase
              .from('quiz_questions')
              .update(updateData)
              .eq('id', id)
              .select()
              .single();

      return QuizQuestion.fromMap(response);
    } catch (e) {
      print('Erreur lors de la mise à jour de la question: $e');
      throw Exception('Impossible de mettre à jour la question');
    }
  }

  // Supprimer une question
  Future<void> deleteQuestion(String id) async {
    try {
      await _supabase.from('quiz_questions').delete().eq('id', id);
    } catch (e) {
      print('Erreur lors de la suppression de la question: $e');
      throw Exception('Impossible de supprimer la question');
    }
  }

  // ========== QUIZ OPTIONS ==========

  // Créer des options pour une question
  Future<List<QuizOption>> createOptions({
    required String questionId,
    required List<String> options,
    required int correctIndex,
  }) async {
    try {
      final now = DateTime.now();
      final optionsData =
          options.asMap().entries.map((entry) {
            return {
              'question_id': questionId,
              'text': entry.value,
              'is_correct': entry.key == correctIndex,
              'order': entry.key + 1,
              'created_at': now.toIso8601String(),
            };
          }).toList();

      final response =
          await _supabase.from('quiz_options').insert(optionsData).select();

      return response
          .map<QuizOption>((row) => QuizOption.fromMap(row))
          .toList();
    } catch (e) {
      print('Erreur lors de la création des options: $e');
      throw Exception('Impossible de créer les options');
    }
  }

  // Récupérer les options d'une question
  Future<List<QuizOption>> getOptionsByQuestion(String questionId) async {
    try {
      final response = await _supabase
          .from('quiz_options')
          .select('*')
          .eq('question_id', questionId)
          .order('order', ascending: true);

      return response
          .map<QuizOption>((row) => QuizOption.fromMap(row))
          .toList();
    } catch (e) {
      print('Erreur lors de la récupération des options: $e');
      throw Exception('Impossible de récupérer les options');
    }
  }

  // Mettre à jour les options d'une question
  Future<List<QuizOption>> updateOptions({
    required String questionId,
    required List<String> options,
    required int correctIndex,
  }) async {
    try {
      // Supprimer les anciennes options
      await _supabase
          .from('quiz_options')
          .delete()
          .eq('question_id', questionId);

      // Créer les nouvelles options
      return await createOptions(
        questionId: questionId,
        options: options,
        correctIndex: correctIndex,
      );
    } catch (e) {
      print('Erreur lors de la mise à jour des options: $e');
      throw Exception('Impossible de mettre à jour les options');
    }
  }

  // ========== QUIZ RESULTS ==========

  // Calculer un résultat de quiz (sans sauvegarde)
  Future<QuizResult> calculateResult({
    required String participantId,
    required String participantName,
    required String levelId,
    required String levelName,
    required Map<String, String> answers, // questionId -> optionId
  }) async {
    try {
      // Récupérer toutes les questions du niveau
      final questions = await getQuestionsByLevel(levelId);

      int totalQuestions = questions.length;
      int correctAnswers = 0;
      int totalPoints = 0;
      int earnedPoints = 0;

      // Calculer les résultats
      for (final question in questions) {
        totalPoints += question.points;

        final selectedOptionId = answers[question.id];
        if (selectedOptionId != null) {
          // Vérifier si l'option sélectionnée est correcte
          final options = await getOptionsByQuestion(question.id);
          final selectedOption = options.firstWhere(
            (option) => option.id == selectedOptionId,
            orElse:
                () => QuizOption(
                  id: '',
                  questionId: question.id,
                  text: '',
                  isCorrect: false,
                  order: 0,
                  createdAt: DateTime.now(),
                ),
          );

          if (selectedOption.isCorrect) {
            correctAnswers++;
            earnedPoints += question.points;
          }
        }
      }

      final percentage =
          totalQuestions > 0 ? (correctAnswers / totalQuestions) * 100 : 0.0;

      // Créer le résultat (sans sauvegarde)
      final result = QuizResult(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        participantId: participantId,
        participantName: participantName,
        levelId: levelId,
        levelName: levelName,
        totalQuestions: totalQuestions,
        correctAnswers: correctAnswers,
        totalPoints: totalPoints,
        earnedPoints: earnedPoints,
        percentage: percentage,
        completedAt: DateTime.now(),
        answers: answers,
      );

      return result;
    } catch (e) {
      print('Erreur lors du calcul du résultat: $e');
      throw Exception('Impossible de calculer le résultat');
    }
  }
}
