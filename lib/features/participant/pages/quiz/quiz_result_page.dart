import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quranic_competition/models/quiz_result.dart';
import 'package:quranic_competition/models/quiz_question.dart';
import 'package:quranic_competition/models/quiz_option.dart';
import 'package:quranic_competition/core/services/quiz_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_ui.dart';
import '../../../../core/widgets/modern_navigation.dart';
import '../../../../core/widgets/ui_components.dart';

class QuizResultPage extends StatefulWidget {
  final QuizResult result;

  const QuizResultPage({super.key, required this.result});

  @override
  State<QuizResultPage> createState() => _QuizResultPageState();
}

class _QuizResultPageState extends State<QuizResultPage> {
  final QuizService _quizService = QuizService();
  bool _isLoadingQuestions = true;
  List<QuizQuestion> _questions = [];
  Map<String, List<QuizOption>> _optionsMap = {};

  @override
  void initState() {
    super.initState();
    _loadQuestionsAndOptions();
  }

  Future<void> _loadQuestionsAndOptions() async {
    try {
      final questions = await _quizService.getQuestionsByLevel(
        widget.result.levelId,
      );
      final optionsMap = <String, List<QuizOption>>{};

      for (final question in questions) {
        final options = await _quizService.getOptionsByQuestion(question.id);
        optionsMap[question.id] = options;
      }

      setState(() {
        _questions = questions;
        _optionsMap = optionsMap;
        _isLoadingQuestions = false;
      });
    } catch (e) {
      print('Erreur lors du chargement des questions: $e');
      setState(() {
        _isLoadingQuestions = false;
      });
    }
  }

  Color _getGradeColor(String grade) {
    switch (grade) {
      case 'ممتاز':
        return AppTheme.successColor;
      case 'جيد جداً':
        return AppTheme.infoColor;
      case 'جيد':
        return AppTheme.warningColor;
      case 'مقبول':
        return AppTheme.secondaryColor;
      case 'ضعيف':
        return AppTheme.errorColor;
      default:
        return AppTheme.textSecondaryColor;
    }
  }

  IconData _getGradeIcon(String grade) {
    switch (grade) {
      case 'ممتاز':
        return Icons.star_rounded;
      case 'جيد جداً':
        return Icons.thumb_up_rounded;
      case 'جيد':
        return Icons.check_circle_rounded;
      case 'مقبول':
        return Icons.info_rounded;
      case 'ضعيف':
        return Icons.warning_rounded;
      default:
        return Icons.help_rounded;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ModernAppBar(
        title: 'نتيجة المسابقة',
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.home_rounded),
            onPressed: () => context.go('/participant_home_page'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingS),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête avec le niveau et le score
              AppGradientHeader(
                shape: AppHeaderShape.card,
                icon: _getGradeIcon(widget.result.grade),
                title: widget.result.levelName,
                subtitle: 'تم إكمال الاختبار',
                badges: [
                  AppHeaderBadge(
                    icon: Icons.workspace_premium_rounded,
                    text: widget.result.grade,
                    highlightColor: AppTheme.secondaryColor,
                  ),
                ],
                bottom: AppHeaderProgress(
                  value: widget.result.percentage / 100,
                  label: 'النسبة المئوية',
                  trailingText:
                      '${widget.result.percentage.toStringAsFixed(1)}%',
                ),
              ),
              const SizedBox(height: AppTheme.spacingS),

              // Résultats principaux
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'النقاط المكتسبة',
                      '${widget.result.earnedPoints}/${widget.result.totalPoints}',
                      Icons.stars_rounded,
                      AppTheme.warningColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      'الإجابات الصحيحة',
                      '${widget.result.correctAnswers}/${widget.result.totalQuestions}',
                      Icons.check_circle_rounded,
                      AppTheme.successColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'النسبة المئوية',
                      '${widget.result.percentage.toStringAsFixed(1)}%',
                      Icons.percent_rounded,
                      AppTheme.infoColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      'التقدير',
                      widget.result.grade,
                      _getGradeIcon(widget.result.grade),
                      _getGradeColor(widget.result.grade),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Barre de progression
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.pageBackgroundColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.dividerColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'التقدم في المسابقة',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: widget.result.percentage / 100,
                      backgroundColor: AppTheme.dividerColor,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _getGradeColor(widget.result.grade),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${widget.result.percentage.toStringAsFixed(1)}% مكتمل',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Détails des réponses
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.infoColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.infoColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.analytics_rounded,
                          color: AppTheme.infoColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'تفاصيل النتائج',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.infoColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildDetailRow('المستوى', widget.result.levelName),
                    _buildDetailRow(
                      'إجمالي الأسئلة',
                      '${widget.result.totalQuestions}',
                    ),
                    _buildDetailRow(
                      'الإجابات الصحيحة',
                      '${widget.result.correctAnswers}',
                    ),
                    _buildDetailRow(
                      'الإجابات الخاطئة',
                      '${widget.result.totalQuestions - widget.result.correctAnswers}',
                    ),
                    _buildDetailRow(
                      'إجمالي النقاط',
                      '${widget.result.totalPoints}',
                    ),
                    _buildDetailRow(
                      'النقاط المكتسبة',
                      '${widget.result.earnedPoints}',
                    ),
                    _buildDetailRow(
                      'تاريخ الإكمال',
                      _formatDate(widget.result.completedAt),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Message de félicitations ou d'encouragement
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _getGradeColor(
                    widget.result.grade,
                  ).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _getGradeColor(
                      widget.result.grade,
                    ).withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      _getGradeIcon(widget.result.grade),
                      size: 50,
                      color: _getGradeColor(widget.result.grade),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _getCongratulationMessage(widget.result.grade),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _getGradeColor(widget.result.grade),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _getEncouragementMessage(widget.result.percentage),
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondaryColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Section des questions avec réponses colorées
              if (!_isLoadingQuestions && _questions.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.pageBackgroundColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.dividerColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.quiz_rounded, color: AppTheme.infoColor),
                          const SizedBox(width: 8),
                          Text(
                            'مراجعة الإجابات',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.infoColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ..._questions.asMap().entries.map((entry) {
                        final index = entry.key;
                        final question = entry.value;
                        return _buildQuestionReview(
                          question: question,
                          questionIndex: index,
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Boutons d'action
              Row(
                children: [
                  Expanded(
                    child: SecondaryButton(
                      onPressed: () => context.go('/participant/quiz'),
                      text: 'مسابقات أخرى',
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingS),
                  Expanded(
                    child: PrimaryButton(
                      onPressed: () => context.go('/participant_home_page'),
                      text: 'الرئيسية',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return AppStatTile(label: title, value: value, icon: icon, color: color);
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 14, color: AppTheme.textSecondaryColor),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  String _getCongratulationMessage(String grade) {
    switch (grade) {
      case 'ممتاز':
        return 'ممتاز! أداء رائع جداً';
      case 'جيد جداً':
        return 'جيد جداً! أداء ممتاز';
      case 'جيد':
        return 'جيد! أداء جيد';
      case 'مقبول':
        return 'مقبول! يمكنك التحسن أكثر';
      case 'ضعيف':
        return 'حاول مرة أخرى';
      default:
        return 'تم إكمال المسابقة';
    }
  }

  String _getEncouragementMessage(double percentage) {
    if (percentage >= 90) {
      return 'أنت على الطريق الصحيح! استمر في التعلم والممارسة.';
    } else if (percentage >= 70) {
      return 'أداء جيد! يمكنك التحسن أكثر بالمراجعة والممارسة.';
    } else if (percentage >= 50) {
      return 'لا بأس، المهم أن تتعلم من أخطائك وتستمر في المحاولة.';
    } else {
      return 'لا تستسلم! المراجعة والممارسة ستساعدك على التحسن.';
    }
  }

  Widget _buildQuestionReview({
    required QuizQuestion question,
    required int questionIndex,
  }) {
    final options = _optionsMap[question.id] ?? [];
    final selectedOptionId = widget.result.answers[question.id];
    final selectedOption = options.firstWhere(
      (opt) => opt.id == selectedOptionId,
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
    final isCorrect = selectedOption.isCorrect;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              isCorrect
                  ? AppTheme.successColor.withValues(alpha: 0.3)
                  : AppTheme.errorColor.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête de la question
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color:
                      isCorrect ? AppTheme.successColor : AppTheme.errorColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Icon(
                    isCorrect ? Icons.check_rounded : Icons.close_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'سؤال ${questionIndex + 1}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color:
                        isCorrect ? AppTheme.successColor : AppTheme.errorColor,
                  ),
                ),
              ),
              Text(
                '${question.points} نقطة',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.warningColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Texte de la question
          Text(
            question.question,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
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
                  String imageUrl = question.imageUrl!;
                  if (!imageUrl.startsWith('http://') &&
                      !imageUrl.startsWith('https://')) {
                    try {
                      final supabase = Supabase.instance.client;
                      imageUrl = supabase.storage
                          .from('images')
                          .getPublicUrl(imageUrl);
                    } catch (e) {
                      print('Erreur lors de la récupération de l\'URL: $e');
                    }
                  }

                  return Image.network(
                    imageUrl,
                    width: double.infinity,
                    height: 150,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 150,
                        color: AppTheme.dividerColor,
                        child: const Center(
                          child: Icon(Icons.image_not_supported_rounded),
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
            final isSelected = option.id == selectedOptionId;
            final isCorrectAnswer = option.isCorrect;

            // Déterminer la couleur
            Color? backgroundColor;
            Color? borderColor;
            Color? textColor;
            IconData? icon;

            if (isCorrectAnswer) {
              // La bonne réponse est toujours en vert
              backgroundColor = AppTheme.successColor.withValues(alpha: 0.08);
              borderColor = AppTheme.successColor;
              textColor = AppTheme.successColor;
              icon = Icons.check_circle_rounded;
            } else if (isSelected && !isCorrect) {
              // La réponse de l'utilisateur est incorrecte → rouge
              backgroundColor = AppTheme.errorColor.withValues(alpha: 0.08);
              borderColor = AppTheme.errorColor;
              textColor = AppTheme.errorColor;
              icon = Icons.cancel_rounded;
            } else {
              // Réponse non sélectionnée et incorrecte
              backgroundColor = AppTheme.pageBackgroundColor;
              borderColor = AppTheme.dividerColor;
              textColor = AppTheme.textSecondaryColor;
              icon = null;
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: borderColor,
                    width: isSelected || isCorrectAnswer ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    if (icon != null) Icon(icon, color: textColor, size: 24),
                    if (icon != null) const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        option.text,
                        style: TextStyle(
                          fontSize: 16,
                          color: textColor,
                          fontWeight:
                              isSelected || isCorrectAnswer
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
