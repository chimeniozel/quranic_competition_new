import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quranic_competition/core/services/quiz_service.dart';
import 'package:quranic_competition/models/quiz_level.dart';
import 'package:quranic_competition/models/quiz_question.dart';
import 'package:quranic_competition/core/theme/app_theme.dart';
import 'package:quranic_competition/core/widgets/ui_components.dart';
import 'package:quranic_competition/core/widgets/modern_navigation.dart';
import 'package:quranic_competition/core/widgets/loading_states.dart';

class QuizQuestionsPage extends StatefulWidget {
  final String levelId;

  const QuizQuestionsPage({super.key, required this.levelId});

  @override
  State<QuizQuestionsPage> createState() => _QuizQuestionsPageState();
}

class _QuizQuestionsPageState extends State<QuizQuestionsPage> {
  final QuizService _quizService = QuizService();
  final ScrollController _scrollController = ScrollController();
  List<QuizQuestion> _allQuestions = [];
  List<QuizQuestion> _displayedQuestions = [];
  QuizLevel? _level;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  // Pagination
  int _currentPage = 1;
  static const int _itemsPerPage = 10;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadData();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      // Charger plus de questions quand on arrive à 200px du bas
      _loadMoreQuestions();
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Charger le niveau
      final levels = await _quizService.getLevels();
      final level = levels.firstWhere((l) => l.id == widget.levelId);

      // Charger les questions
      final questions = await _quizService.getQuestionsByLevel(widget.levelId);

      setState(() {
        _level = level;
        _allQuestions = questions;
        _currentPage = 1;
        _hasMore = questions.length > _itemsPerPage;
        _displayedQuestions =
            questions.length > _itemsPerPage
                ? questions.sublist(0, _itemsPerPage)
                : questions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحميل البيانات: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteQuestion(QuizQuestion question) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('تأكيد الحذف'),
            content: Text(
              'هل أنت متأكد من حذف السؤال "${question.question.length > 50 ? '${question.question.substring(0, 50)}...' : question.question}"؟',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('إلغاء'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('حذف', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      try {
        await _quizService.deleteQuestion(question.id);
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم حذف السؤال بنجاح'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('خطأ في حذف السؤال: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _loadMoreQuestions() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    // Simuler un délai pour l'animation
    await Future.delayed(const Duration(milliseconds: 300));

    final nextPage = _currentPage + 1;
    final startIndex = _currentPage * _itemsPerPage;
    final endIndex = startIndex + _itemsPerPage;

    if (startIndex < _allQuestions.length) {
      final nextQuestions = _allQuestions.sublist(
        startIndex,
        endIndex > _allQuestions.length ? _allQuestions.length : endIndex,
      );

      setState(() {
        _displayedQuestions.addAll(nextQuestions);
        _currentPage = nextPage;
        _hasMore = endIndex < _allQuestions.length;
        _isLoadingMore = false;
      });
    } else {
      setState(() {
        _hasMore = false;
        _isLoadingMore = false;
      });
    }
  }

  Widget _buildQuestionCard(QuizQuestion question) {
    return ModernCard(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingS,
        vertical: AppTheme.spacingXS,
      ),
      padding: const EdgeInsets.all(AppTheme.spacingS),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                ),
                child: Center(
                  child: Text(
                    '${question.order}',
                    style: AppTheme.bodyLarge.copyWith(
                      color: AppTheme.successColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spacingS),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      question.question,
                      style: AppTheme.bodyLarge.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppTheme.spacingXS),
                    Row(
                      children: [
                        Icon(
                          Icons.stars,
                          size: 16,
                          color: AppTheme.warningColor,
                        ),
                        const SizedBox(width: AppTheme.spacingXS),
                        Text(
                          '${question.points} نقطة',
                          style: AppTheme.bodySmall.copyWith(
                            color: AppTheme.warningColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      context.push('/admin/quiz/questions/edit/${question.id}');
                      break;
                    case 'delete':
                      _deleteQuestion(question);
                      break;
                  }
                },
                itemBuilder:
                    (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 16),
                            SizedBox(width: 8),
                            Text('تعديل'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 16, color: Colors.red),
                            SizedBox(width: 8),
                            Text('حذف', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
              ),
            ],
          ),
          if (question.imageUrl != null && question.imageUrl!.isNotEmpty) ...[
            const SizedBox(height: AppTheme.spacingS),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
              child: Image.network(
                question.imageUrl!,
                width: double.infinity,
                height: 150,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 150,
                    color: AppTheme.surfaceColor,
                    child: Icon(
                      Icons.image_not_supported,
                      size: 50,
                      color: AppTheme.textSecondaryColor,
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: AppTheme.spacingS),
          Row(
            children: [
              Icon(
                Icons.calendar_today,
                size: 16,
                color: AppTheme.textSecondaryColor,
              ),
              const SizedBox(width: AppTheme.spacingXS),
              Text(
                'تم الإنشاء: ${_formatDate(question.createdAt)}',
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.textSecondaryColor,
                ),
              ),
              const Spacer(),
              Icon(Icons.update, size: 16, color: AppTheme.textSecondaryColor),
              const SizedBox(width: AppTheme.spacingXS),
              Text(
                'آخر تحديث: ${_formatDate(question.updatedAt)}',
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.textSecondaryColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingXL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.quiz_outlined,
              size: 80,
              color: AppTheme.textSecondaryColor,
            ),
            const SizedBox(height: AppTheme.spacingS),
            Text(
              'لا توجد أسئلة في هذا المستوى',
              style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacingXS),
            Text(
              'ابدأ بإضافة سؤال جديد',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondaryColor,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      alignment: Alignment.center,
      child: const CircularProgressIndicator(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ModernAppBar(
        title: _level?.name ?? 'الأسئلة',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'تحديث',
          ),
        ],
      ),
      body:
          _isLoading
              ? const LoadingOverlay(child: SizedBox())
              : _allQuestions.isEmpty
              ? _buildEmptyState()
              : ModernPullToRefresh(
                onRefresh: _loadData,
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    vertical: AppTheme.spacingXS,
                  ),
                  itemCount:
                      _displayedQuestions.length +
                      (_hasMore && _isLoadingMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index < _displayedQuestions.length) {
                      return _buildQuestionCard(_displayedQuestions[index]);
                    } else {
                      // Indicateur de chargement en bas (seulement si _hasMore && _isLoadingMore)
                      return _buildLoadingIndicator();
                    }
                  },
                ),
              ),
      floatingActionButton: ModernFAB(
        onPressed:
            () => context.push(
              '/admin/quiz/questions/add?levelId=${widget.levelId}',
            ),
        icon: Icons.add,
      ),
    );
  }
}
