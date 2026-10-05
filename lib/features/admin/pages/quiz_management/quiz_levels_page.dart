import 'package:flutter/material.dart';
import 'package:quranic_competition/core/widgets/app_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:quranic_competition/core/services/quiz_service.dart';
import 'package:quranic_competition/core/services/permission_service.dart';
import 'package:quranic_competition/core/widgets/role_guard.dart';
import 'package:quranic_competition/models/quiz_level.dart';
import 'package:quranic_competition/core/widgets/modern_navigation.dart';
import 'package:quranic_competition/core/widgets/loading_states.dart';
import 'package:quranic_competition/core/theme/app_theme.dart';
import 'package:quranic_competition/core/widgets/modern_dashboard.dart';

class QuizLevelsPage extends StatefulWidget {
  const QuizLevelsPage({super.key});

  @override
  State<QuizLevelsPage> createState() => _QuizLevelsPageState();
}

class _QuizLevelsPageState extends State<QuizLevelsPage> {
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
      final levels = await _quizService.getLevels();
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
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _toggleLevelStatus(QuizLevel level) async {
    try {
      await _quizService.toggleLevelStatus(level.id);
      await _loadLevels();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              level.isActive ? 'تم إلغاء تفعيل المستوى' : 'تم تفعيل المستوى',
            ),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تغيير حالة المستوى: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _checkPermissionAndEdit(QuizLevel level) async {
    context.push('/admin/quiz/levels/edit/${level.id}');
  }

  Future<void> _deleteLevel(QuizLevel level) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('تأكيد الحذف'),
            content: Text(
              'هل أنت متأكد من حذف المستوى "${level.name}"؟\nسيتم حذف جميع الأسئلة المرتبطة به.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('إلغاء'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('حذف', style: TextStyle(color: AppTheme.errorColor)),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      try {
        await _quizService.deleteLevel(level.id);
        await _loadLevels();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم حذف المستوى بنجاح'),
              backgroundColor: AppTheme.successColor,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('خطأ في حذف المستوى: $e'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    }
  }

  Widget _buildLevelCard(QuizLevel level) {
    final color =
        level.isActive ? AppTheme.primaryColor : AppTheme.textSecondaryColor;

    return AppListCard(
      onTap: () => context.push('/admin/quiz/levels/${level.id}/questions'),
      leading: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
        ),
        child: Center(
          child: Text(
            '${level.order}',
            style: AppTheme.headingSmall.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      title: level.name,
      subtitle: level.description,
      tags: [
        AppTag(
          text: level.isActive ? 'منشور' : 'غير منشور',
          color:
              level.isActive
                  ? AppTheme.successColor
                  : AppTheme.textSecondaryColor,
          icon: level.isActive ? Icons.visibility_rounded : Icons.visibility_off_rounded,
        ),
        AppTag(
          text: 'الترتيب ${level.order}',
          color: AppTheme.textSecondaryColor,
          icon: Icons.sort_rounded,
        ),
      ],
      trailing: PopupMenuButton<String>(
        onSelected: (value) {
          switch (value) {
            case 'edit':
              _checkPermissionAndEdit(level);
              break;
            case 'questions':
              context.push('/admin/quiz/levels/${level.id}/questions');
              break;
            case 'toggle':
              _toggleLevelStatus(level);
              break;
            case 'delete':
              _deleteLevel(level);
              break;
          }
        },
        itemBuilder: (context) {
          final items = <PopupMenuEntry<String>>[];
          final permissionService = PermissionService();

          // إضافة عنصر التعديل فقط إذا كانت الصلاحية متوفرة
          if (permissionService.canModifySync()) {
            items.add(
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_rounded, size: 16, color: AppTheme.primaryColor),
                    SizedBox(width: 8),
                    Text('تعديل'),
                  ],
                ),
              ),
            );
          }

          // عنصر الأسئلة متاح للجميع (للقراءة فقط)
          items.add(
            PopupMenuItem(
              value: 'questions',
              child: Row(
                children: [
                  Icon(Icons.quiz_rounded, size: 16, color: AppTheme.successColor),
                  SizedBox(width: 8),
                  Text('إدارة الأسئلة'),
                ],
              ),
            ),
          );

          // إضافة عنصر التفعيل/إلغاء التفعيل فقط إذا كانت الصلاحية متوفرة
          if (permissionService.canModifySync()) {
            items.add(
              PopupMenuItem(
                value: 'toggle',
                child: Row(
                  children: [
                    Icon(
                      level.isActive ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                      size: 16,
                      color:
                          level.isActive
                              ? AppTheme.warningColor
                              : AppTheme.successColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      level.isActive ? 'إلغاء التفعيل' : 'تفعيل',
                      style: TextStyle(
                        color:
                            level.isActive
                                ? AppTheme.warningColor
                                : AppTheme.successColor,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          // إضافة عنصر الحذف فقط إذا كانت الصلاحية متوفرة
          if (permissionService.canDeleteSync()) {
            items.add(
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_rounded, size: 16, color: AppTheme.errorColor),
                    SizedBox(width: 8),
                    Text('حذف', style: TextStyle(color: AppTheme.errorColor)),
                  ],
                ),
              ),
            );
          }

          return items;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ModernAppBar(
        title: 'أسئلة و أجوبة في القرآن',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadLevels,
            tooltip: 'تحديث',
          ),
        ],
      ),
      floatingActionButton: CanModifyGuard(
        child: FloatingActionButton.extended(
          onPressed: () => context.push('/admin/quiz/levels/add'),
          icon: const Icon(Icons.add_rounded),
          label: const Text('مستوى جديد'),
        ),
      ),
      body:
          _isLoading
              ? const LoadingOverlay(child: SizedBox())
              : ModernPullToRefresh(
                onRefresh: _loadLevels,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.spacingM,
                    AppTheme.spacingS,
                    AppTheme.spacingM,
                    80,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Section
                      DashboardSection(
                        title: 'المستويات',
                        subtitle: 'إدارة المستويات',
                        child: Row(
                          children: [
                            Expanded(
                              child: StatCard(
                                title: 'إجمالي المستويات',
                                value: '${_levels.length}',
                                icon: Icons.quiz_rounded,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            const SizedBox(width: AppTheme.spacingS),
                            Expanded(
                              child: StatCard(
                                title: 'المستويات النشطة',
                                value:
                                    '${_levels.where((l) => l.isActive).length}',
                                icon: Icons.check_circle_rounded,
                                color: AppTheme.successColor,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: AppTheme.spacingL),

                      // Levels List Section
                      DashboardSection(
                        title: 'قائمة المستويات',
                        subtitle: '${_levels.length} مستوى',
                        child:
                            _levels.isEmpty
                                ? Container(
                                  height: 300,
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.quiz_rounded,
                                          size: 64,
                                          color: AppTheme.textSecondaryColor,
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'لا توجد مستويات متاحة حالياً',
                                          style: AppTheme.bodyLarge.copyWith(
                                            color: AppTheme.textSecondaryColor,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'ابدأ بإنشاء مستوى جديد',
                                          style: AppTheme.bodyMedium.copyWith(
                                            color: AppTheme.textSecondaryColor,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                : Column(
                                  children: [
                                    ..._levels.map(
                                      (level) => _buildLevelCard(level),
                                    ),
                                    const SizedBox(height: AppTheme.spacingS),
                                  ],
                                ),
                      ),

                      const SizedBox(height: AppTheme.spacingXL),
                    ],
                  ),
                ),
              ),
    );
  }
}
