import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:quranic_competition/core/services/quiz_service.dart';
import 'package:quranic_competition/core/services/file_permission_service.dart';
import 'package:quranic_competition/models/quiz_level.dart';
import 'package:quranic_competition/models/quiz_question.dart';
import 'package:quranic_competition/core/theme/app_theme.dart';
import 'package:quranic_competition/core/widgets/ui_components.dart';
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
            backgroundColor: Colors.red,
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
            backgroundColor: Colors.red,
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
            backgroundColor: Colors.red,
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

  List<Widget> _buildOptionFields() {
    return _optionControllers.asMap().entries.map((entry) {
      final index = entry.key;
      return Padding(
        padding: const EdgeInsets.only(bottom: AppTheme.spacingS),
        child: ModernCard(
          padding: const EdgeInsets.all(AppTheme.spacingS),
          child: Row(
            children: [
              Radio<int>(
                value: index,
                groupValue: _correctOptionIndex,
                onChanged: (value) {
                  setState(() {
                    _correctOptionIndex = value!;
                  });
                },
                activeColor: AppTheme.primaryColor,
              ),
              Expanded(
                child: TextFormField(
                  controller: _optionControllers[index],
                  decoration: InputDecoration(
                    labelText: 'الخيار ${index + 1}',
                    suffixIcon:
                        _optionControllers.length > 2
                            ? IconButton(
                              icon: const Icon(
                                Icons.delete,
                                color: AppTheme.errorColor,
                              ),
                              onPressed: () => _removeOption(index),
                            )
                            : null,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'يرجى ملء هذا الخيار';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  Future<void> _saveQuestion() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedLevel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار مستوى'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Vérifier qu'il y a au moins 2 options
    if (_optionControllers.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إضافة على الأقل خيارين'),
          backgroundColor: Colors.red,
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
            backgroundColor: Colors.red,
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
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في حفظ السؤال: $e'),
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
        title: _isEditing ? 'تعديل السؤال' : 'إضافة سؤال جديد',
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
                      // Sélection du niveau
                      ModernCard(
                        padding: const EdgeInsets.all(AppTheme.spacingS),
                        child: DropdownButtonFormField<QuizLevel>(
                          value: _selectedLevel,
                          decoration: InputDecoration(
                            labelText: 'المستوى',
                            prefixIcon: const Icon(Icons.quiz),
                            filled: true,
                            fillColor: AppTheme.surfaceColor,
                          ),
                          items:
                              _levels.map((level) {
                                return DropdownMenuItem(
                                  value: level,
                                  child: Text(level.name),
                                );
                              }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedLevel = value;
                            });
                          },
                          validator: (value) {
                            if (value == null) {
                              return 'يرجى اختيار مستوى';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingS),

                      // Question
                      ModernCard(
                        padding: const EdgeInsets.all(AppTheme.spacingS),
                        child: TextFormField(
                          controller: _questionController,
                          decoration: const InputDecoration(
                            labelText: 'السؤال',
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
                      ),
                      const SizedBox(height: AppTheme.spacingS),

                      // Section Image
                      ModernCard(
                        padding: const EdgeInsets.all(AppTheme.spacingS),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'صورة السؤال (اختياري)',
                              style: AppTheme.headingSmall.copyWith(
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: AppTheme.spacingS),

                            // Aperçu de l'image (nouvelle ou existante)
                            if (_selectedImage != null ||
                                (_imageUrlController.text.trim().isNotEmpty &&
                                    _selectedImage == null)) ...[
                              Container(
                                width: double.infinity,
                                height: 200,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusM,
                                  ),
                                  border: Border.all(
                                    color: AppTheme.dividerColor,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusM,
                                  ),
                                  child:
                                      _selectedImage != null
                                          ? Image.file(
                                            _selectedImage!,
                                            fit: BoxFit.cover,
                                          )
                                          : Image.network(
                                            _imageUrlController.text.trim(),
                                            fit: BoxFit.cover,
                                            errorBuilder: (
                                              context,
                                              error,
                                              stackTrace,
                                            ) {
                                              return Container(
                                                color: AppTheme.surfaceColor,
                                                child: Icon(
                                                  Icons.image_not_supported,
                                                  size: 50,
                                                  color:
                                                      AppTheme
                                                          .textSecondaryColor,
                                                ),
                                              );
                                            },
                                            loadingBuilder: (
                                              context,
                                              child,
                                              loadingProgress,
                                            ) {
                                              if (loadingProgress == null) {
                                                return child;
                                              }
                                              return Center(
                                                child: CircularProgressIndicator(
                                                  value:
                                                      loadingProgress
                                                                  .expectedTotalBytes !=
                                                              null
                                                          ? loadingProgress
                                                                  .cumulativeBytesLoaded /
                                                              loadingProgress
                                                                  .expectedTotalBytes!
                                                          : null,
                                                ),
                                              );
                                            },
                                          ),
                                ),
                              ),
                              const SizedBox(height: AppTheme.spacingXS),
                              Row(
                                children: [
                                  Expanded(
                                    child: SecondaryButton(
                                      text: 'تغيير الصورة',
                                      icon: Icons.edit,
                                      onPressed: _pickImage,
                                      fullWidth: true,
                                    ),
                                  ),
                                  const SizedBox(width: AppTheme.spacingXS),
                                  Expanded(
                                    child: SecondaryButton(
                                      text: 'حذف',
                                      icon: Icons.delete,
                                      onPressed: _removeSelectedImage,
                                      fullWidth: true,
                                      textColor: AppTheme.errorColor,
                                      borderColor: AppTheme.errorColor,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppTheme.spacingS),
                              const Divider(),
                              const SizedBox(height: AppTheme.spacingXS),
                            ],

                            // Bouton pour choisir une image
                            if (_selectedImage == null &&
                                _imageUrlController.text.trim().isEmpty)
                              PrimaryButton(
                                text: 'اختيار صورة من المعرض',
                                icon: Icons.photo_library,
                                onPressed: _pickImage,
                                fullWidth: true,
                                backgroundColor: AppTheme.infoColor,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingS),

                      // Points
                      ModernCard(
                        padding: const EdgeInsets.all(AppTheme.spacingS),
                        child: TextFormField(
                          controller: _pointsController,
                          decoration: const InputDecoration(
                            labelText: 'النقاط',
                            prefixIcon: Icon(Icons.stars),
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
                      ),
                      const SizedBox(height: AppTheme.spacingL),

                      // Options de réponses
                      Text('خيارات الإجابة', style: AppTheme.headingSmall),
                      const SizedBox(height: AppTheme.spacingS),

                      // Options de réponses
                      Column(
                        children: [
                          ..._buildOptionFields(),
                          // Bouton pour ajouter une option
                          if (_optionControllers.length < 6)
                            SecondaryButton(
                              text: 'إضافة خيار',
                              icon: Icons.add,
                              onPressed: _addOption,
                              fullWidth: true,
                            ),
                        ],
                      ),
                      const SizedBox(height: AppTheme.spacingL),

                      // Boutons
                      Row(
                        children: [
                          Expanded(
                            child: SecondaryButton(
                              text: 'إلغاء',
                              onPressed:
                                  _isLoading ? null : () => context.pop(),
                              fullWidth: true,
                            ),
                          ),
                          const SizedBox(width: AppTheme.spacingS),
                          Expanded(
                            child: PrimaryButton(
                              text: _isEditing ? 'تحديث' : 'إنشاء',
                              onPressed: _isLoading ? null : _saveQuestion,
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
