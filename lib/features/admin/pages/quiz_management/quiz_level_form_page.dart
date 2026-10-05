import 'package:flutter/material.dart';
import 'package:quranic_competition/core/widgets/app_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:quranic_competition/core/services/quiz_service.dart';
import 'package:quranic_competition/core/services/permission_service.dart';
import 'package:quranic_competition/models/quiz_level.dart';
import 'package:quranic_competition/core/theme/app_theme.dart';
import 'package:quranic_competition/core/widgets/modern_navigation.dart';
import 'package:quranic_competition/core/widgets/loading_states.dart';

class QuizLevelFormPage extends StatefulWidget {
  final String? levelId;

  const QuizLevelFormPage({super.key, this.levelId});

  @override
  State<QuizLevelFormPage> createState() => _QuizLevelFormPageState();
}

class _QuizLevelFormPageState extends State<QuizLevelFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _orderController = TextEditingController();
  final _quizService = QuizService();
  final PermissionService _permissionService = PermissionService();

  bool _isLoading = false;
  bool _isEditing = false;
  QuizLevel? _existingLevel;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.levelId != null;
    if (_isEditing) {
      _loadLevel();
    } else {
      _loadNextOrder();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _orderController.dispose();
    super.dispose();
  }

  Future<void> _loadLevel() async {
    if (widget.levelId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final levels = await _quizService.getLevels();
      final level = levels.firstWhere((l) => l.id == widget.levelId);
      setState(() {
        _existingLevel = level;
        _nameController.text = level.name;
        _descriptionController.text = level.description;
        _orderController.text = level.order.toString();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحميل المستوى: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _loadNextOrder() async {
    try {
      final levels = await _quizService.getLevels();
      final nextOrder =
          levels.isEmpty
              ? 1
              : levels.map((l) => l.order).reduce((a, b) => a > b ? a : b) + 1;
      _orderController.text = nextOrder.toString();
    } catch (e) {
      _orderController.text = '1';
    }
  }

  Future<void> _saveLevel() async {
    if (!_formKey.currentState!.validate()) return;

    // Vérifier الصلاحيات
    final canModify = await _permissionService.canModify();
    if (!canModify) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('ليس لديك صلاحية تعديل المستويات'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final name = _nameController.text.trim();
      final description = _descriptionController.text.trim();
      final order = int.parse(_orderController.text.trim());

      if (_isEditing && _existingLevel != null) {
        // Mise à jour
        await _quizService.updateLevel(
          id: _existingLevel!.id,
          name: name,
          description: description,
          order: order,
        );
      } else {
        // Création
        await _quizService.createLevel(
          name: name,
          description: description,
          order: order,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing ? 'تم تحديث المستوى بنجاح' : 'تم إنشاء المستوى بنجاح',
            ),
            backgroundColor: AppTheme.successColor,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في حفظ المستوى: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ModernAppBar(
        title: _isEditing ? 'تعديل المستوى' : 'إضافة مستوى جديد',
      ),
      body:
          _isLoading && _isEditing
              ? const ModernLoadingIndicator()
              : Form(
                key: _formKey,
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.all(AppTheme.spacingM),
                  children: [
                    AppSection(
                      icon: Icons.layers_rounded,
                      title: 'معلومات المستوى',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'اسم المستوى',
                              hintText: 'مثال: مبتدئ، متوسط، متقدم',
                              prefixIcon: Icon(Icons.label_rounded),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'يرجى إدخال اسم المستوى';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: AppTheme.spacingS),
                          TextFormField(
                            controller: _descriptionController,
                            decoration: const InputDecoration(
                              labelText: 'وصف المستوى',
                              hintText: 'اشرح محتوى هذا المستوى...',
                              alignLabelWithHint: true,
                            ),
                            maxLines: 3,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'يرجى إدخال وصف المستوى';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingM),
                    AppSection(
                      icon: Icons.format_list_numbered_rounded,
                      color: AppTheme.secondaryColor,
                      title: 'الترتيب',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: _orderController,
                            decoration: const InputDecoration(
                              labelText: 'ترتيب المستوى',
                              hintText: '1، 2، 3...',
                              prefixIcon: Icon(Icons.sort_rounded),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'يرجى إدخال ترتيب المستوى';
                              }
                              final order = int.tryParse(value.trim());
                              if (order == null || order < 1) {
                                return 'يرجى إدخال رقم صحيح أكبر من 0';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: AppTheme.spacingS),
                          const AppNotice(
                            text:
                                'تُرتَّب المستويات حسب هذا الرقم: المستوى رقم 1 يظهر أولاً.',
                            icon: Icons.info_rounded,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingL),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isLoading ? null : () => context.pop(),
                            style: AppButtonStyles.outlined(
                              AppTheme.textSecondaryColor,
                            ),
                            icon: const Icon(Icons.close_rounded),
                            label: const Text('إلغاء'),
                          ),
                        ),
                        const SizedBox(width: AppTheme.spacingS),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _saveLevel,
                            style: AppButtonStyles.filled(
                              AppTheme.primaryColor,
                            ),
                            icon:
                                _isLoading
                                    ? const AppButtonLoader()
                                    : Icon(
                                      _isEditing
                                          ? Icons.save_rounded
                                          : Icons.add_circle_rounded,
                                    ),
                            label: Text(
                              _isEditing ? 'حفظ التعديلات' : 'إضافة المستوى',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacingL),
                  ],
                ),
              ),
    );
  }
}
