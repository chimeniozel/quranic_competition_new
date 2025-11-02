import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quranic_competition/core/services/quiz_service.dart';
import 'package:quranic_competition/models/quiz_level.dart';
import 'package:quranic_competition/core/theme/app_theme.dart';
import 'package:quranic_competition/core/widgets/ui_components.dart';
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
            backgroundColor: Colors.red,
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
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في حفظ المستوى: $e'),
            backgroundColor: Colors.red,
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
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
        ],
      ),
      body:
          _isLoading && _isEditing
              ? const LoadingOverlay(child: SizedBox())
              : Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppTheme.spacingS),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nom du niveau
                      ModernCard(
                        padding: const EdgeInsets.all(AppTheme.spacingS),
                        child: TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'اسم المستوى',
                            hintText: 'مثال: مبتدئ، متوسط، متقدم',
                            prefixIcon: Icon(Icons.quiz),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'يرجى إدخال اسم المستوى';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingS),

                      // Description
                      ModernCard(
                        padding: const EdgeInsets.all(AppTheme.spacingS),
                        child: TextFormField(
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
                      ),
                      const SizedBox(height: AppTheme.spacingS),

                      // Ordre
                      ModernCard(
                        padding: const EdgeInsets.all(AppTheme.spacingS),
                        child: TextFormField(
                          controller: _orderController,
                          decoration: const InputDecoration(
                            labelText: 'ترتيب المستوى',
                            hintText: '1، 2، 3...',
                            prefixIcon: Icon(Icons.sort),
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
                      ),
                      const SizedBox(height: AppTheme.spacingL),

                      // Informations
                      ModernCard(
                        backgroundColor: AppTheme.infoColor.withOpacity(0.1),
                        padding: const EdgeInsets.all(AppTheme.spacingS),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info,
                              color: AppTheme.infoColor,
                              size: 20,
                            ),
                            const SizedBox(width: AppTheme.spacingXS),
                            Expanded(
                              child: Text(
                                'سيتم ترتيب المستويات حسب الرقم المدخل. المستوى رقم 1 سيظهر أولاً.',
                                style: AppTheme.bodySmall.copyWith(
                                  color: AppTheme.infoColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingL),

                      // Boutons
                      Row(
                        children: [
                          Expanded(
                            child: SecondaryButton(
                              text: 'إلغاء',
                              onPressed: _isLoading ? null : () => context.pop(),
                              fullWidth: true,
                            ),
                          ),
                          const SizedBox(width: AppTheme.spacingS),
                          Expanded(
                            child: PrimaryButton(
                              text: _isEditing ? 'تحديث' : 'إنشاء',
                              onPressed: _isLoading ? null : _saveLevel,
                              isLoading: _isLoading,
                              fullWidth: true,
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
}
