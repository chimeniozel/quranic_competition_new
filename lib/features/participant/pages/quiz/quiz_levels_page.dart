import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quranic_competition/core/services/quiz_service.dart';
import 'package:quranic_competition/models/quiz_level.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_ui.dart';
import '../../../../core/widgets/loading_states.dart';
import '../../../../core/widgets/modern_navigation.dart';

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
      if (!mounted) return;
      setState(() {
        _levels = levels;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Erreur lors du chargement des niveaux: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر تحميل المستويات. تحقق من الاتصال وحاول مجدداً.'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  Widget _buildLevelCard(QuizLevel level) {
    return AppListCard(
      onTap: () => context.push('/participant/quiz/level/${level.id}'),
      leading: Container(
        width: 48,
        height: 48,
        decoration: const BoxDecoration(
          gradient: AppTheme.primaryGradient,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            '${level.order}',
            style: AppTheme.headingSmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      title: level.name,
      subtitle: level.description,
      tags: const [
        AppTag(
          text: 'ابدأ الاختبار',
          color: AppTheme.secondaryColor,
          icon: Icons.play_arrow_rounded,
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return const EmptyState(
      icon: Icons.quiz_rounded,
      title: 'لا توجد اختبارات متاحة حالياً',
      subtitle: 'سيتم إضافة اختبارات جديدة قريباً',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ModernAppBar(
        title: 'أسئلة وأجوبة في القرآن',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تحديث',
            onPressed: _loadLevels,
          ),
        ],
      ),
      body:
          _isLoading
              ? const ModernLoadingIndicator()
              : ModernPullToRefresh(
                onRefresh: _loadLevels,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  children: [
                    const AppGradientHeader(
                      icon: Icons.quiz_rounded,
                      title: 'أسئلة وأجوبة في القرآن',
                      subtitle: 'اختبر معلوماتك واختر المستوى المناسب لك',
                    ),
                    Padding(
                      padding: const EdgeInsets.all(AppTheme.spacingM),
                      child:
                          _levels.isEmpty
                              ? _buildEmptyState()
                              : Column(
                                children: _levels.map(_buildLevelCard).toList(),
                              ),
                    ),
                  ],
                ),
              ),
    );
  }
}
