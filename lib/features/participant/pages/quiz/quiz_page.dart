import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:quranic_competition/core/services/quiz_service.dart';
import 'package:quranic_competition/models/quiz_level.dart';
import 'package:quranic_competition/models/quiz_question.dart';
import 'package:quranic_competition/models/quiz_option.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/modern_navigation.dart';
import '../../../../core/widgets/ui_components.dart';

class QuizPage extends StatefulWidget {
  final String levelId;

  const QuizPage({super.key, required this.levelId});

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  final QuizService _quizService = QuizService();
  final PageController _pageController = PageController();

  QuizLevel? _level;
  List<QuizQuestion> _questions = [];
  List<List<QuizOption>> _options = [];
  Map<String, String> _answers = {}; // questionId -> optionId
  int _currentQuestionIndex = 0;
  bool _isLoading = false;
  bool _isSubmitting = false;
  int _consecutiveCorrectAnswers =
      0; // Compteur de bonnes réponses consécutives

  @override
  void initState() {
    super.initState();
    _loadQuizData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadQuizData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Charger le niveau
      final levels = await _quizService.getLevels();
      final level = levels.firstWhere((l) => l.id == widget.levelId);

      // Charger les questions
      final questions = await _quizService.getQuestionsByLevel(widget.levelId);

      // Randomiser l'ordre des questions avec une graine aléatoire
      // Utiliser une méthode de shuffle plus robuste
      final shuffledQuestions = <QuizQuestion>[];
      final remainingQuestions = List<QuizQuestion>.from(questions);
      final random = Random(DateTime.now().millisecondsSinceEpoch);

      while (remainingQuestions.isNotEmpty) {
        final randomIndex = random.nextInt(remainingQuestions.length);
        shuffledQuestions.add(remainingQuestions.removeAt(randomIndex));
      }

      // Charger les options pour chaque question et randomiser leur ordre
      final options = <List<QuizOption>>[];
      for (final question in shuffledQuestions) {
        final questionOptions = await _quizService.getOptionsByQuestion(
          question.id,
        );
        // Randomiser l'ordre des options pour chaque question avec une nouvelle graine
        final shuffledOptions = List<QuizOption>.from(questionOptions);
        final optionRandom = Random(
          DateTime.now().millisecondsSinceEpoch + question.id.hashCode,
        );
        shuffledOptions.shuffle(optionRandom);
        options.add(shuffledOptions);
      }

      setState(() {
        _level = level;
        _questions = shuffledQuestions;
        _options = options;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحميل النسخة: $e'),
            backgroundColor: Colors.red,
          ),
        );
        context.pop();
      }
    }
  }

  void _selectAnswer(String questionId, String optionId) {
    setState(() {
      _answers[questionId] = optionId;
    });
  }

  Future<void> _nextQuestion() async {
    // Vérifier si la réponse actuelle est correcte
    final currentQuestion = _questions[_currentQuestionIndex];
    final selectedOptionId = _answers[currentQuestion.id];

    if (selectedOptionId != null) {
      final currentOptions = _options[_currentQuestionIndex];
      final selectedOption = currentOptions.firstWhere(
        (opt) => opt.id == selectedOptionId,
        orElse: () => currentOptions.first,
      );

      if (selectedOption.isCorrect) {
        _consecutiveCorrectAnswers++;

        // Afficher un message d'encouragement après chaque 10 bonnes réponses consécutives
        if (_consecutiveCorrectAnswers % 10 == 0) {
          await _showEncouragementMessage(_consecutiveCorrectAnswers);
        }
      } else {
        // Réinitialiser le compteur si la réponse est incorrecte
        _consecutiveCorrectAnswers = 0;
      }
    } else {
      // Si aucune réponse n'est sélectionnée, réinitialiser le compteur
      _consecutiveCorrectAnswers = 0;
    }

    if (_currentQuestionIndex < _questions.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _submitQuiz();
    }
  }

  Future<void> _showEncouragementMessage(int consecutiveCount) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return _EncouragementDialog(consecutiveCount: consecutiveCount);
      },
    );
  }

  void _previousQuestion() {
    if (_currentQuestionIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _submitQuiz() async {
    if (_answers.length < _questions.length) {
      final unanswered = _questions.length - _answers.length;
      final confirmed = await ModernDialog.showConfirm(
        context,
        title: 'تأكيد الإرسال',
        message: 'لديك $unanswered سؤال لم تجب عليه. هل تريد المتابعة؟',
        cancelText: 'العودة',
        confirmText: 'إرسال',
      );

      if (confirmed != true) return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;

      // Permettre aux utilisateurs non connectés de faire le quiz
      final participantId =
          user?.id ?? 'anonymous_${DateTime.now().millisecondsSinceEpoch}';
      final participantName = user?.userMetadata?['name'] ?? 'مشارك';

      final result = await _quizService.calculateResult(
        participantId: participantId,
        participantName: participantName,
        levelId: _level!.id,
        levelName: _level!.name,
        answers: _answers,
      );

      if (mounted) {
        context.push('/participant/quiz/result', extra: result);
      }
    } catch (e) {
      setState(() {
        _isSubmitting = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في إرسال النسخة: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildQuestionCard(QuizQuestion question, List<QuizOption> options) {
    final selectedOptionId = _answers[question.id];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête de la question
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.blue[600],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Center(
                      child: Text(
                        '${_currentQuestionIndex + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'سؤال ${_currentQuestionIndex + 1} من ${_questions.length}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.blue[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.stars,
                              size: 16,
                              color: Colors.orange[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${question.points} نقطة',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Question
            Text(
              question.question,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),

            // Image si présente
            if (question.imageUrl != null && question.imageUrl!.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Builder(
                  builder: (context) {
                    // Si l'URL ne commence pas par http/https, c'est probablement un chemin de storage
                    String imageUrl = question.imageUrl!;
                    if (!imageUrl.startsWith('http://') &&
                        !imageUrl.startsWith('https://')) {
                      // C'est un chemin de storage Supabase, obtenir l'URL publique
                      try {
                        final supabase = Supabase.instance.client;
                        imageUrl = supabase.storage
                            .from('images')
                            .getPublicUrl(imageUrl);
                        print('URL publique de l\'image: $imageUrl');
                      } catch (e) {
                        print(
                          'Erreur lors de la récupération de l\'URL publique: $e',
                        );
                      }
                    }

                    return Image.network(
                      imageUrl,
                      width: double.infinity,
                      height: 200,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          height: 200,
                          color: Colors.grey[200],
                          child: Center(
                            child: CircularProgressIndicator(
                              value:
                                  loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        print('Erreur de chargement d\'image: $error');
                        print('URL de l\'image: $imageUrl');
                        print('URL originale: ${question.imageUrl}');
                        return Container(
                          height: 200,
                          color: Colors.grey[200],
                          child: const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.image_not_supported, size: 50),
                                SizedBox(height: 8),
                                Text('تعذر تحميل الصورة'),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Options de réponses
            ...options.map((option) {
              final isSelected = selectedOptionId == option.id;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () => _selectAnswer(question.id, option.id),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.blue[50] : Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color:
                            isSelected ? Colors.blue[300]! : Colors.grey[300]!,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color:
                                isSelected
                                    ? Colors.blue[600]
                                    : Colors.grey[400],
                          ),
                          child:
                              isSelected
                                  ? const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 16,
                                  )
                                  : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            option.text,
                            style: TextStyle(
                              fontSize: 16,
                              color:
                                  isSelected
                                      ? Colors.blue[700]
                                      : Colors.black87,
                              fontWeight:
                                  isSelected
                                      ? FontWeight.w500
                                      : FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingS,
        vertical: AppTheme.spacingS,
      ),
      child: ModernProgressIndicator(
        value: (_currentQuestionIndex + 1) / _questions.length,
        label: 'السؤال ${_currentQuestionIndex + 1} من ${_questions.length}',
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingS),
      child: Row(
        children: [
          if (_currentQuestionIndex > 0)
            Expanded(
              child: SecondaryButton(
                onPressed: _previousQuestion,
                text: 'السابق',
              ),
            ),
          if (_currentQuestionIndex > 0)
            const SizedBox(width: AppTheme.spacingS),
          Expanded(
            child: PrimaryButton(
              onPressed: _nextQuestion,
              text:
                  _currentQuestionIndex == _questions.length - 1
                      ? 'إرسال'
                      : 'التالي',
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ModernAppBar(
        title: _level?.name ?? 'النسخة',
        actions: [
          if (_isSubmitting)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  _buildProgressIndicator(),
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      onPageChanged: (index) {
                        setState(() {
                          _currentQuestionIndex = index;
                        });
                      },
                      itemCount: _questions.length,
                      itemBuilder: (context, index) {
                        return _buildQuestionCard(
                          _questions[index],
                          _options[index],
                        );
                      },
                    ),
                  ),
                  _buildNavigationButtons(),
                ],
              ),
    );
  }
}

// Widget pour le message d'encouragement avec effets visuels
class _EncouragementDialog extends StatefulWidget {
  final int consecutiveCount;

  const _EncouragementDialog({required this.consecutiveCount});

  @override
  State<_EncouragementDialog> createState() => _EncouragementDialogState();
}

class _EncouragementDialogState extends State<_EncouragementDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _controller.forward();

    // Fermer automatiquement après 3 secondes
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Transform.rotate(
              angle: _rotationAnimation.value * 0.1,
              child: Dialog(
                backgroundColor: Colors.transparent,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.amber.shade400,
                        Colors.orange.shade400,
                        Colors.deepOrange.shade400,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withOpacity(0.5),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Animation de confettis/étoiles
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 500),
                        builder: (context, value, child) {
                          return Transform.scale(
                            scale: value,
                            child: Icon(
                              Icons.stars,
                              size: 80,
                              color: Colors.white,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      Text(
                        '🎉 ممتاز! 🎉',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              offset: const Offset(2, 2),
                              blurRadius: 4,
                              color: Colors.black.withOpacity(0.3),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${widget.consecutiveCount} إجابات صحيحة متتالية!',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              offset: const Offset(1, 1),
                              blurRadius: 3,
                              color: Colors.black.withOpacity(0.3),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'استمر في التقدم! أنت تبلي بلاءً حسناً',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white.withOpacity(0.9),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
