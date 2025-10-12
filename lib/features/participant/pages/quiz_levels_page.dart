import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quranic_competition/core/services/quiz_service.dart';
import 'package:quranic_competition/models/quiz_level.dart';
import '../../../core/widgets/modern_navigation.dart';
import '../../../core/widgets/ui_components.dart';
import '../../../core/widgets/loading_states.dart';
import '../../../core/theme/app_theme.dart';

class ParticipantQuizLevelsPage extends StatefulWidget {
  const ParticipantQuizLevelsPage({super.key});

  @override
  State<ParticipantQuizLevelsPage> createState() =>
      _ParticipantQuizLevelsPageState();
}

class _ParticipantQuizLevelsPageState extends State<ParticipantQuizLevelsPage> {
  final QuizService _quizService = QuizService();
  List<QuizLevel> _levels = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadLevels();
  }

  Future<void> _loadLevels() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final levels = await _quizService.getActiveLevels();
      setState(() {
        _levels = levels;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحميل المستويات: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildLevelCard(QuizLevel level) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingS,
        vertical: 4,
      ),
      child: ModernCard(
        child: InkWell(
          onTap: () {
            context.push('/participant/quiz/level/${level.id}');
          },
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primaryColor.withValues(alpha: 0.8),
                            AppTheme.primaryColor,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Center(
                        child: Text(
                          '${level.order}',
                          style: AppTheme.labelLarge.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingM),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            level.name,
                            style: AppTheme.labelLarge.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          const SizedBox(height: AppTheme.spacingS),
                          Text(
                            level.description,
                            style: AppTheme.labelMedium.copyWith(
                              color: AppTheme.textSecondaryColor,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      color: AppTheme.textSecondaryColor,
                      size: 20,
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingM),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingM,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.successColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppTheme.successColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.quiz, size: 16, color: AppTheme.successColor),
                      const SizedBox(width: 4),
                      Text(
                        'ابدأ المسابقة',
                        style: AppTheme.labelSmall.copyWith(
                          color: AppTheme.successColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return EmptyState(
      icon: Icons.quiz,
      title: 'لا توجد مسابقات متاحة حالياً',
      subtitle: 'سيتم إضافة مسابقات جديدة قريباً',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ModernAppBar(
        title: 'مسابقات التجويد',
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadLevels),
        ],
      ),
      body:
          _isLoading
              ? const LoadingOverlay(child: SizedBox())
              : _levels.isEmpty
              ? _buildEmptyState()
              : ModernPullToRefresh(
                onRefresh: _loadLevels,
                child: ListView.builder(
                  itemCount: _levels.length,
                  itemBuilder:
                      (context, index) => _buildLevelCard(_levels[index]),
                ),
              ),
    );
  }
}
