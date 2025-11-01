import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quranic_competition/models/quiz_result.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/modern_navigation.dart';
import '../../../../core/widgets/ui_components.dart';

class QuizResultPage extends StatelessWidget {
  final QuizResult result;

  const QuizResultPage({super.key, required this.result});

  Color _getGradeColor(String grade) {
    switch (grade) {
      case 'ممتاز':
        return Colors.green;
      case 'جيد جداً':
        return Colors.blue;
      case 'جيد':
        return Colors.orange;
      case 'مقبول':
        return Colors.yellow[700]!;
      case 'ضعيف':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getGradeIcon(String grade) {
    switch (grade) {
      case 'ممتاز':
        return Icons.star;
      case 'جيد جداً':
        return Icons.thumb_up;
      case 'جيد':
        return Icons.check_circle;
      case 'مقبول':
        return Icons.info;
      case 'ضعيف':
        return Icons.warning;
      default:
        return Icons.help;
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
            icon: const Icon(Icons.home),
            onPressed: () => context.go('/participant'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingS),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête avec le niveau
              ModernCard(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppTheme.spacingS),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primaryColor.withValues(alpha: 0.8),
                        AppTheme.primaryColor,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.quiz, size: 60, color: Colors.white),
                      const SizedBox(height: AppTheme.spacingS),
                      Text(
                        result.levelName,
                        style: AppTheme.labelLarge.copyWith(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingS),
                      Text(
                        'تم إكمال المسابقة بنجاح',
                        style: AppTheme.labelMedium.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spacingS),

              // Résultats principaux
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'النقاط المكتسبة',
                      '${result.earnedPoints}/${result.totalPoints}',
                      Icons.stars,
                      Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      'الإجابات الصحيحة',
                      '${result.correctAnswers}/${result.totalQuestions}',
                      Icons.check_circle,
                      Colors.green,
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
                      '${result.percentage.toStringAsFixed(1)}%',
                      Icons.percent,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      'التقدير',
                      result.grade,
                      _getGradeIcon(result.grade),
                      _getGradeColor(result.grade),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Barre de progression
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'التقدم في المسابقة',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: result.percentage / 100,
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _getGradeColor(result.grade),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${result.percentage.toStringAsFixed(1)}% مكتمل',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Détails des réponses
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.analytics, color: Colors.blue[600]),
                        const SizedBox(width: 8),
                        Text(
                          'تفاصيل النتائج',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildDetailRow('المستوى', result.levelName),
                    _buildDetailRow(
                      'إجمالي الأسئلة',
                      '${result.totalQuestions}',
                    ),
                    _buildDetailRow(
                      'الإجابات الصحيحة',
                      '${result.correctAnswers}',
                    ),
                    _buildDetailRow(
                      'الإجابات الخاطئة',
                      '${result.totalQuestions - result.correctAnswers}',
                    ),
                    _buildDetailRow('إجمالي النقاط', '${result.totalPoints}'),
                    _buildDetailRow(
                      'النقاط المكتسبة',
                      '${result.earnedPoints}',
                    ),
                    _buildDetailRow(
                      'تاريخ الإكمال',
                      _formatDate(result.completedAt),
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
                  color: _getGradeColor(result.grade).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _getGradeColor(result.grade).withOpacity(0.3),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      _getGradeIcon(result.grade),
                      size: 50,
                      color: _getGradeColor(result.grade),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _getCongratulationMessage(result.grade),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _getGradeColor(result.grade),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _getEncouragementMessage(result.percentage),
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

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
                      onPressed: () => context.go('/participant'),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(fontSize: 12, color: color.withOpacity(0.8)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
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
}
