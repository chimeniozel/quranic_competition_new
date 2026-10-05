import 'dart:io';
import 'package:flutter/material.dart';
import 'package:quranic_competition/core/widgets/app_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:quranic_competition/core/services/quiz_service.dart';
import 'package:quranic_competition/core/services/file_permission_service.dart';
import 'package:quranic_competition/core/services/permission_service.dart';
import 'package:quranic_competition/models/quiz_level.dart';
import 'package:quranic_competition/models/quiz_question.dart';
import 'package:quranic_competition/core/theme/app_theme.dart';
import 'package:quranic_competition/core/widgets/modern_navigation.dart';
import 'package:quranic_competition/core/widgets/loading_states.dart';

class QuizQuestionFormPage extends StatefulWidget {
  final String? questionId;
  final String? levelId;

  const QuizQuestionFormPage({super.key, this.questionId, this.levelId});

  @override
  State<QuizQuestionFormPage> createState() => _QuizQuestionFormPageState();
}

class _QuizQuestionFormPageState extends State<QuizQuestionFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _questionController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _pointsController = TextEditingController();
  final _quizService = QuizService();
  final _imagePicker = ImagePicker();
  final FilePermissionService _permissionService = FilePermissionService();
  final PermissionService _permissionCheckService = PermissionService();

  List<QuizLevel> _levels = [];
  QuizLevel? _selectedLevel;
  List<TextEditingController> _optionControllers = [];
  int _correctOptionIndex = 0;
  bool _isLoading = false;
  bool _isEditing = false;
  QuizQuestion? _existingQuestion;
  File? _selectedImage;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.questionId != null;
    _initializeData();
  }

  Future<void> _initializeData() async {
    // Charger les niveaux d'abord
    await _loadLevels();

    if (_isEditing) {
      await _loadQuestion();
    } else {
      await _initializeForNewQuestion();
    }
  }

  @override
  void dispose() {
    _questionController.dispose();
    _imageUrlController.dispose();
    _pointsController.dispose();
    for (final controller in _optionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadLevels() async {
    try {
      final levels = await _quizService.getLevels();
      setState(() {
        _levels = levels;
        if (widget.levelId != null) {
          _selectedLevel = levels.firstWhere((l) => l.id == widget.levelId);
        }
      });
    } catch (e) {
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

  Future<void> _loadQuestion() async {
    if (widget.questionId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Charger les questions de tous les niveaux pour trouver celle-ci
      final allQuestions = <QuizQuestion>[];
      for (final level in _levels) {
        final questions = await _quizService.getQuestionsByLevel(level.id);
        allQuestions.addAll(questions);
      }

      final question = allQuestions.firstWhere(
        (q) => q.id == widget.questionId,
      );
      final level = _levels.firstWhere((l) => l.id == question.levelId);

      // Charger les options
      final options = await _quizService.getOptionsByQuestion(question.id);

      setState(() {
        _existingQuestion = question;
        _selectedLevel = level;
        _questionController.text = question.question;
        _imageUrlController.text = question.imageUrl ?? '';
        _pointsController.text = question.points.toString();

        // Initialiser les options
        _optionControllers.clear();
        for (int i = 0; i < options.length; i++) {
          _optionControllers.add(TextEditingController(text: options[i].text));
          if (options[i].isCorrect) {
            _correctOptionIndex = i;
          }
        }

        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحميل السؤال: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _initializeForNewQuestion() async {
    // Sélectionner le niveau
    if (widget.levelId != null) {
      try {
        _selectedLevel = _levels.firstWhere((l) => l.id == widget.levelId);
      } catch (e) {
        // Si le niveau n'est pas trouvé, prendre le premier niveau disponible
        if (_levels.isNotEmpty) {
          _selectedLevel = _levels.first;
        }
      }
    } else if (_levels.isNotEmpty) {
      // Si aucun levelId spécifié, prendre le premier niveau
      _selectedLevel = _levels.first;
    }

    // Initialiser avec 2 options vides
    _optionControllers = List.generate(2, (index) => TextEditingController());
    _pointsController.text = '1';
  }

  Future<void> _pickImage() async {
    // Demander la permission avant de charger l'image
    final hasPermission = await _permissionService.requestStoragePermission(
      context,
    );
    if (!hasPermission) {
      return; // L'utilisateur n'a pas accordé la permission
    }

    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
          _imageUrlController.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في اختيار الصورة: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _removeSelectedImage() {
    setState(() {
      _selectedImage = null;
      _imageUrlController.clear();
    });
  }

  Future<String> _uploadImageToStorage(File imageFile) async {
    try {
      final supabase = Supabase.instance.client;

      // Générer un nom de fichier unique
      final fileName =
          'quiz_question_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = 'quiz-questions/$fileName';

      // Upload vers Supabase Storage
      await supabase.storage
          .from('images')
          .uploadBinary(
            filePath,
            await imageFile.readAsBytes(),
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: false,
            ),
          );

      // Obtenir l'URL publique
      final imageUrl = supabase.storage.from('images').getPublicUrl(filePath);

      return imageUrl;
    } catch (e) {
      throw Exception('خطأ في رفع الصورة: $e');
    }
  }

  void _addOption() {
    setState(() {
      _optionControllers.add(TextEditingController());
    });
  }

  void _removeOption(int index) {
    if (_optionControllers.length > 2) {
      setState(() {
        _optionControllers.removeAt(index);
        if (_correctOptionIndex >= _optionControllers.length) {
          _correctOptionIndex = _optionControllers.length - 1;
        }
      });
    }
  }

  static const _optionLetters = ['أ', 'ب', 'ج', 'د', 'هـ', 'و'];

  List<Widget> _buildOptionFields() {
    return _optionControllers.asMap().entries.map((entry) {
      final index = entry.key;
      final isCorrect = _correctOptionIndex == index;
      final color =
          isCorrect ? AppTheme.successColor : AppTheme.textSecondaryColor;

      return Container(
        margin: const EdgeInsets.only(bottom: AppTheme.spacingS),
        padding: const EdgeInsets.all(AppTheme.spacingS),
        decoration: BoxDecoration(
          color:
              isCorrect
                  ? AppTheme.successColor.withValues(alpha: 0.06)
                  : AppTheme.backgroundColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
          border: Border.all(
            color: isCorrect ? AppTheme.successColor : AppTheme.dividerColor,
            width: isCorrect ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: color.withValues(alpha: 0.15),
                  child: Text(
                    index < _optionLetters.length
                        ? _optionLetters[index]
                        : '${index + 1}',
                    style: AppTheme.bodyMedium.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.spacingS),
                Expanded(
                  child: TextFormField(
                    controller: _optionControllers[index],
                    decoration: InputDecoration(
                      hintText: 'نص الخيار ${index + 1}',
                      isDense: true,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'يرجى ملء هذا الخيار';
                      }
                      return null;
                    },
                  ),
                ),
                if (_optionControllers.length > 2)
                  IconButton(
                    tooltip: 'حذف الخيار',
                    icon: const Icon(Icons.delete_outline_rounded),
                    color: AppTheme.errorColor,
                    onPressed: () => _removeOption(index),
                  ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingXS),
            // Marquer comme bonne réponse
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () => setState(() => _correctOptionIndex = index),
                style: TextButton.styleFrom(
                  foregroundColor: color,
                  visualDensity: VisualDensity.compact,
                ),
                icon: Icon(
                  isCorrect
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 20,
                ),
                label: Text(
                  isCorrect ? 'الإجابة الصحيحة' : 'تحديد كإجابة صحيحة',
                  style: AppTheme.bodySmall.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Future<void> _saveQuestion() async {
    if (!_formKey.currentState!.validate()) return;

    // Vérifier الصلاحيات
    final canModify = await _permissionCheckService.canModify();
    if (!canModify) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('ليس لديك صلاحية تعديل الأسئلة'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    if (_selectedLevel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار مستوى'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    // Vérifier qu'il y a au moins 2 options
    if (_optionControllers.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إضافة على الأقل خيارين'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    // Vérifier que toutes les options sont remplies
    for (int i = 0; i < _optionControllers.length; i++) {
      if (_optionControllers[i].text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('يرجى ملء الخيار ${i + 1}'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final question = _questionController.text.trim();
      String? imageUrl;

      // Gérer l'upload de l'image si une image est sélectionnée
      if (_selectedImage != null) {
        imageUrl = await _uploadImageToStorage(_selectedImage!);
      } else if (_imageUrlController.text.trim().isNotEmpty) {
        imageUrl = _imageUrlController.text.trim();
      }

      final points = int.parse(_pointsController.text.trim());

      // Calculer l'ordre automatiquement
      int order;
      if (_isEditing && _existingQuestion != null) {
        // Conserver l'ordre existant lors de la modification
        order = _existingQuestion!.order;
      } else {
        // Calculer le prochain ordre pour une nouvelle question
        try {
          final questions = await _quizService.getQuestionsByLevel(
            _selectedLevel!.id,
          );
          order =
              questions.isEmpty
                  ? 1
                  : questions
                          .map((q) => q.order)
                          .reduce((a, b) => a > b ? a : b) +
                      1;
        } catch (e) {
          order = 1;
        }
      }

      if (_isEditing && _existingQuestion != null) {
        // Mise à jour
        await _quizService.updateQuestion(
          id: _existingQuestion!.id,
          question: question,
          imageUrl: imageUrl,
          points: points,
          order: order,
        );

        // Mettre à jour les options
        final options = _optionControllers.map((c) => c.text.trim()).toList();
        await _quizService.updateOptions(
          questionId: _existingQuestion!.id,
          options: options,
          correctIndex: _correctOptionIndex,
        );
      } else {
        // Création
        final newQuestion = await _quizService.createQuestion(
          levelId: _selectedLevel!.id,
          question: question,
          imageUrl: imageUrl,
          points: points,
          order: order,
        );

        // Créer les options
        final options = _optionControllers.map((c) => c.text.trim()).toList();
        await _quizService.createOptions(
          questionId: newQuestion.id,
          options: options,
          correctIndex: _correctOptionIndex,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing ? 'تم تحديث السؤال بنجاح' : 'تم إنشاء السؤال بنجاح',
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
            content: Text('خطأ في حفظ السؤال: $e'),
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

  bool get _hasImage =>
      _selectedImage != null || _imageUrlController.text.trim().isNotEmpty;

  Widget _buildImagePicker() {
    if (!_hasImage) {
      return Material(
        color: AppTheme.secondaryColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        child: InkWell(
          onTap: _pickImage,
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingM),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
              border: Border.all(
                color: AppTheme.secondaryColor.withValues(alpha: 0.4),
              ),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.add_photo_alternate_rounded,
                  size: 36,
                  color: AppTheme.secondaryColor,
                ),
                const SizedBox(height: 4),
                Text(
                  'إضافة صورة للسؤال (اختياري)',
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.secondaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
          child:
              _selectedImage != null
                  ? Image.file(_selectedImage!, height: 200, fit: BoxFit.cover)
                  : Image.network(
                    _imageUrlController.text.trim(),
                    height: 200,
                    fit: BoxFit.cover,
                    errorBuilder:
                        (context, error, stackTrace) => Container(
                          height: 200,
                          color: AppTheme.dividerColor,
                          child: const Icon(
                            Icons.image_not_supported_rounded,
                            size: 48,
                            color: AppTheme.textSecondaryColor,
                          ),
                        ),
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const SizedBox(
                        height: 200,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    },
                  ),
        ),
        const SizedBox(height: AppTheme.spacingS),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickImage,
                style: AppButtonStyles.outlined(AppTheme.primaryColor),
                icon: const Icon(Icons.swap_horiz_rounded),
                label: const Text('تغيير'),
              ),
            ),
            const SizedBox(width: AppTheme.spacingS),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _removeSelectedImage,
                style: AppButtonStyles.outlined(AppTheme.errorColor),
                icon: const Icon(Icons.delete_rounded),
                label: const Text('حذف'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ModernAppBar(
        title: _isEditing ? 'تعديل السؤال' : 'إضافة سؤال جديد',
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
                      icon: Icons.tune_rounded,
                      title: 'الإعدادات',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          DropdownButtonFormField<QuizLevel>(
                            value: _selectedLevel,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'المستوى',
                              prefixIcon: Icon(Icons.layers_rounded),
                            ),
                            items:
                                _levels
                                    .map(
                                      (level) => DropdownMenuItem(
                                        value: level,
                                        child: Text(level.name),
                                      ),
                                    )
                                    .toList(),
                            onChanged:
                                (value) =>
                                    setState(() => _selectedLevel = value),
                            validator:
                                (value) =>
                                    value == null ? 'يرجى اختيار مستوى' : null,
                          ),
                          const SizedBox(height: AppTheme.spacingS),
                          TextFormField(
                            controller: _pointsController,
                            decoration: const InputDecoration(
                              labelText: 'النقاط',
                              prefixIcon: Icon(Icons.stars_rounded),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'يرجى إدخال النقاط';
                              }
                              final points = int.tryParse(value.trim());
                              if (points == null || points < 1) {
                                return 'يرجى إدخال رقم صحيح أكبر من 0';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingM),
                    AppSection(
                      icon: Icons.help_rounded,
                      color: AppTheme.infoColor,
                      title: 'السؤال',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: _questionController,
                            decoration: const InputDecoration(
                              labelText: 'نص السؤال',
                              hintText: 'اكتب السؤال هنا...',
                              alignLabelWithHint: true,
                            ),
                            maxLines: 3,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'يرجى إدخال السؤال';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: AppTheme.spacingS),
                          _buildImagePicker(),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingM),
                    AppSection(
                      icon: Icons.checklist_rounded,
                      color: AppTheme.successColor,
                      title: 'خيارات الإجابة',
                      subtitle:
                          'حدّد الإجابة الصحيحة (${_optionControllers.length} من 6)',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ..._buildOptionFields(),
                          if (_optionControllers.length < 6)
                            OutlinedButton.icon(
                              onPressed: _addOption,
                              style: AppButtonStyles.outlined(
                                AppTheme.primaryColor,
                              ),
                              icon: const Icon(
                                Icons.add_circle_outline_rounded,
                              ),
                              label: const Text('إضافة خيار'),
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
                            onPressed: _isLoading ? null : _saveQuestion,
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
                              _isEditing ? 'حفظ التعديلات' : 'إضافة السؤال',
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
