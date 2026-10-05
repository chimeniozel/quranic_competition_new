import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:quranic_competition/core/services/quiz_service.dart';
import 'package:quranic_competition/models/quiz_level.dart';
import 'package:quranic_competition/models/quiz_question.dart';
import 'package:quranic_competition/models/quiz_option.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_ui.dart';
import '../../../../core/widgets/loading_states.dart';
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
  // Questions déjà prises en compte par le compteur : revenir en arrière puis
  // avancer de nouveau ne doit pas compter deux fois la même question.
  final Set<String> _countedQuestionIds = {};

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

      // Charger les options de toutes les questions en parallèle (et non
      // plus une requête après l'autre), puis randomiser leur ordre
      final allOptions = await Future.wait(
        shuffledQuestions.map((q) => _quizService.getOptionsByQuestion(q.id)),
      );
      final options =
          allOptions
              .map(
                (questionOptions) =>
                    List<QuizOption>.of(questionOptions)..shuffle(random),
              )
              .toList();

      if (!mounted) return;
      setState(() {
        _level = level;
        _questions = shuffledQuestions;
        _options = options;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Erreur lors du chargement du quiz: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر تحميل الأسئلة. تحقق من الاتصال وحاول مجدداً.'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      context.pop();
    }
  }

  void _selectAnswer(String questionId, String optionId) {
    // La correction est affichée dès le choix : la réponse est donc
    // verrouillée, on ne peut plus la changer après avoir vu la solution.
    if (_answers.containsKey(questionId)) return;

    setState(() {
      _answers[questionId] = optionId;
    });
  }

  /// Retourne la bonne option d'une question (null si aucune n'est marquée).
  QuizOption? _correctOption(List<QuizOption> options) {
    for (final option in options) {
      if (option.isCorrect) return option;
    }
    return null;
  }

  Future<void> _nextQuestion() async {
    final currentQuestion = _questions[_currentQuestionIndex];
    final selectedOptionId = _answers[currentQuestion.id];

    // Le compteur de bonnes réponses consécutives ne prend chaque question en
    // compte qu'une seule fois : revenir en arrière puis avancer de nouveau
    // ne doit pas recompter la même question.
    if (_countedQuestionIds.add(currentQuestion.id)) {
      final selectedOption =
          selectedOptionId == null
              ? null
              : _options[_currentQuestionIndex].firstWhere(
                (opt) => opt.id == selectedOptionId,
                orElse: () => _options[_currentQuestionIndex].first,
              );

      if (selectedOption != null && selectedOption.isCorrect) {
        _consecutiveCorrectAnswers++;

        // Message d'encouragement à chaque 10 bonnes réponses consécutives
        if (_consecutiveCorrectAnswers % 10 == 0) {
          await _showEncouragementMessage(_consecutiveCorrectAnswers);
        }
      } else {
        // Réponse fausse ou absente : la série est interrompue
        _consecutiveCorrectAnswers = 0;
      }
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

      // Remplace le quiz terminé : le retour ne ramène plus sur un quiz
      // bloqué en état « envoi en cours »
      if (mounted) {
        context.pushReplacement('/participant/quiz/result', extra: result);
      }
    } catch (e) {
      debugPrint('Erreur lors de l\'envoi du quiz: $e');
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر إرسال الإجابات. حاول مجدداً.'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
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
            AppGradientHeader(
              shape: AppHeaderShape.card,
              compact: true,
              leading: CircleAvatar(
                radius: 22,
                backgroundColor: Colors.white,
                child: Text(
                  '${_currentQuestionIndex + 1}',
                  style: AppTheme.bodyLarge.copyWith(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title:
                  'السؤال ${_currentQuestionIndex + 1} من ${_questions.length}',
              trailing: AppHeaderBadge(
                icon: Icons.stars_rounded,
                text: '${question.points} نقطة',
              ),
            ),
            const SizedBox(height: 16),

            // Énoncé
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingM),
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor,
                borderRadius: BorderRadius.circular(AppTheme.radiusL),
                boxShadow: AppTheme.shadowS,
              ),
              child: Text(
                question.question,
                style: AppTheme.bodyLarge.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  height: 1.7,
                ),
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
                          color: AppTheme.dividerColor,
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
                          color: AppTheme.dividerColor,
                          child: const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.image_not_supported_rounded,
                                  size: 50,
                                ),
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
              final hasAnswered = selectedOptionId != null;

              // Dès qu'une réponse est donnée : la bonne option passe en vert
              // (qu'elle ait été choisie ou non) et l'option choisie à tort
              // passe en rouge. Les autres restent neutres.
              final showAsCorrect = hasAnswered && option.isCorrect;
              final showAsWrong =
                  hasAnswered && isSelected && !option.isCorrect;
              final isHighlighted = showAsCorrect || showAsWrong;

              Color backgroundColor;
              Color borderColor;
              Color textColor;
              Color markerColor;
              IconData? markerIcon;

              if (showAsCorrect) {
                backgroundColor = AppTheme.successColor.withValues(alpha: 0.08);
                borderColor = AppTheme.successColor;
                textColor = AppTheme.successColor;
                markerColor = AppTheme.successColor;
                markerIcon = Icons.check_rounded;
              } else if (showAsWrong) {
                backgroundColor = AppTheme.errorColor.withValues(alpha: 0.08);
                borderColor = AppTheme.errorColor;
                textColor = AppTheme.errorColor;
                markerColor = AppTheme.errorColor;
                markerIcon = Icons.close_rounded;
              } else {
                backgroundColor = AppTheme.backgroundColor;
                borderColor = AppTheme.dividerColor;
                textColor = AppTheme.textPrimaryColor;
                markerColor = AppTheme.textDisabledColor;
                markerIcon = null;
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  // Plus de changement possible une fois la correction visible
                  onTap:
                      hasAnswered
                          ? null
                          : () => _selectAnswer(question.id, option.id),
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  child: Container(
                    padding: const EdgeInsets.all(AppTheme.spacingM),
                    decoration: BoxDecoration(
                      color: backgroundColor,
                      borderRadius: BorderRadius.circular(AppTheme.radiusM),
                      border: Border.all(
                        color: borderColor,
                        width: isHighlighted ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: markerColor,
                          ),
                          child:
                              markerIcon != null
                                  ? Icon(
                                    markerIcon,
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
                              color: textColor,
                              fontWeight:
                                  isHighlighted
                                      ? FontWeight.w500
                                      : FontWeight.normal,
                            ),
                          ),
                        ),
                        // Libellé explicite à côté de l'option concernée
                        if (showAsCorrect || showAsWrong) ...[
                          const SizedBox(width: 8),
                          Text(
                            showAsCorrect ? 'إجابة صحيحة' : 'إجابة خاطئة',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: markerColor,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),

            // Message de correction affiché dès qu'une réponse est choisie
            if (selectedOptionId != null)
              _buildAnswerFeedback(options, selectedOptionId),
          ],
        ),
      ),
    );
  }

  /// Bandeau indiquant si la réponse choisie est juste, et rappelant la bonne
  /// réponse lorsqu'elle est fausse.
  Widget _buildAnswerFeedback(List<QuizOption> options, String selectedId) {
    final correctOption = _correctOption(options);
    final isCorrect = correctOption != null && correctOption.id == selectedId;

    final color = isCorrect ? AppTheme.successColor : AppTheme.errorColor;

    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:
            (isCorrect
                ? AppTheme.successColor.withValues(alpha: 0.08)
                : AppTheme.errorColor.withValues(alpha: 0.08)),
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border: Border.all(color: color, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: color,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCorrect ? 'إجابة صحيحة' : 'إجابة خاطئة',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                if (!isCorrect && correctOption != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'الإجابة الصحيحة: ${correctOption.text}',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.successColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    final progress = (_currentQuestionIndex + 1) / _questions.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacingM,
        AppTheme.spacingS,
        AppTheme.spacingM,
        0,
      ),
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                color: AppTheme.primaryColor,
                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
              ),
            ),
          ),
          const SizedBox(width: AppTheme.spacingS),
          Text(
            '${_currentQuestionIndex + 1}/${_questions.length}',
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons() {
    final isLast = _currentQuestionIndex == _questions.length - 1;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingS),
      decoration: const BoxDecoration(
        color: AppTheme.backgroundColor,
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (_currentQuestionIndex > 0) ...[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _previousQuestion,
                  style: AppButtonStyles.outlined(AppTheme.primaryColor),
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text('السابق'),
                ),
              ),
              const SizedBox(width: AppTheme.spacingS),
            ],
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _nextQuestion,
                style: AppButtonStyles.filled(
                  isLast ? AppTheme.secondaryColor : AppTheme.primaryColor,
                ),
                icon:
                    _isSubmitting
                        ? const AppButtonLoader()
                        : Icon(
                          isLast
                              ? Icons.send_rounded
                              : Icons.arrow_back_rounded,
                        ),
                label: Text(isLast ? 'إرسال الإجابات' : 'التالي'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Quitter en plein quiz perdait les réponses sans prévenir
  Future<void> _confirmExit() async {
    final leave = await ModernDialog.showConfirm(
      context,
      title: 'مغادرة الاختبار',
      message: 'ستفقد إجاباتك الحالية. هل تريد المغادرة؟',
      cancelText: 'متابعة الاختبار',
      confirmText: 'مغادرة',
      confirmColor: AppTheme.errorColor,
    );
    if (leave == true && mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _answers.isEmpty || _isSubmitting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit();
      },
      child: _buildScaffold(),
    );
  }

  Widget _buildScaffold() {
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
              : _questions.isEmpty
              ? const Center(
                child: EmptyState(
                  icon: Icons.quiz_rounded,
                  title: 'لا توجد أسئلة في هذا المستوى',
                  subtitle: 'سيتم إضافة الأسئلة قريباً',
                ),
              )
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
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.warningColor.withOpacity(0.5),
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
                              Icons.stars_rounded,
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
