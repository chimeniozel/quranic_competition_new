import 'dart:io';
import 'package:flutter/material.dart';
import 'package:quranic_competition/core/widgets/app_ui.dart';
import 'package:quranic_competition/core/theme/app_theme.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:quranic_competition/core/services/tajweed_rule_service.dart';
import 'package:quranic_competition/core/services/file_permission_service.dart';
import 'package:quranic_competition/core/services/permission_service.dart';
import 'package:quranic_competition/models/tajweed_rule.dart';
import 'package:quranic_competition/core/services/push_notification_service.dart';
import 'dart:convert';

class TajweedRuleFormPage extends StatefulWidget {
  final String? ruleId;

  const TajweedRuleFormPage({super.key, this.ruleId});

  @override
  State<TajweedRuleFormPage> createState() => _TajweedRuleFormPageState();
}

class _TajweedRuleFormPageState extends State<TajweedRuleFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _videoUrlController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _ruleService = TajweedRuleService();
  final _imagePicker = ImagePicker();
  final FilePermissionService _permissionService = FilePermissionService();
  final PermissionService _permissionCheckService = PermissionService();

  TajweedType _selectedType = TajweedType.post;
  bool _isLoading = false;
  bool _isEditing = false;
  TajweedRule? _existingRule;
  File? _selectedImage;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.ruleId != null;
    if (_isEditing) {
      _loadRule();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _videoUrlController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  bool _isValidYouTubeUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;

    // Vérifier les domaines YouTube valides
    final validHosts = [
      'www.youtube.com',
      'youtube.com',
      'm.youtube.com',
      'youtu.be',
    ];

    if (!validHosts.contains(uri.host)) return false;

    // Vérifier les patterns YouTube valides
    if (uri.host == 'youtu.be') {
      // Format: https://youtu.be/VIDEO_ID
      return uri.pathSegments.isNotEmpty && uri.pathSegments.first.isNotEmpty;
    } else {
      // Format: https://youtube.com/watch?v=VIDEO_ID
      return uri.queryParameters.containsKey('v') &&
          uri.queryParameters['v']!.isNotEmpty;
    }
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
          _imageUrlController
              .clear(); // Effacer l'URL si une image est sélectionnée
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
    });
  }

  Future<String> _uploadImageToStorage(File imageFile) async {
    try {
      final supabase = Supabase.instance.client;

      // Générer un nom de fichier unique
      final fileName =
          'tajweed_rule_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = 'tajweed-rules/$fileName';

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

  Future<void> _loadRule() async {
    if (widget.ruleId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final rule = await _ruleService.getRuleById(widget.ruleId!);
      if (rule != null) {
        setState(() {
          _existingRule = rule;
          _titleController.text = rule.title;
          _contentController.text = rule.content;
          _selectedType = rule.type;
          _videoUrlController.text = rule.videoUrl ?? '';
          _imageUrlController.text = rule.imageUrl ?? '';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في التحميل : $e'),
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

  Future<void> _saveRule() async {
    if (!_formKey.currentState!.validate()) return;

    // Vérifier الصلاحيات
    final canModify = await _permissionCheckService.canModify();
    if (!canModify) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('ليس لديك صلاحية تعديل المحتوى'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        throw Exception('المستخدم غير مسجل الدخول');
      }

      // Gérer l'upload de l'image si une image est sélectionnée
      String? imageUrl;
      if (_selectedImage != null) {
        imageUrl = await _uploadImageToStorage(_selectedImage!);
      } else if (_imageUrlController.text.trim().isNotEmpty) {
        imageUrl = _imageUrlController.text.trim();
      }

      if (_isEditing && _existingRule != null) {
        // Mise à jour
        await _ruleService.updateRule(
          id: _existingRule!.id,
          title: _titleController.text.trim(),
          content: _contentController.text.trim(),
          type: _selectedType,
          videoUrl:
              _videoUrlController.text.trim().isNotEmpty
                  ? _videoUrlController.text.trim()
                  : null,
          imageUrl: imageUrl,
        );
      } else {
        // Création
        await _ruleService.createRule(
          title: _titleController.text.trim(),
          content: _contentController.text.trim(),
          type: _selectedType,
          videoUrl:
              _videoUrlController.text.trim().isNotEmpty
                  ? _videoUrlController.text.trim()
                  : null,
          imageUrl: imageUrl,
          authorId: user.id,
          authorName: user.userMetadata?['full_name'] ?? 'الإدارة',
        );

        // Notification publique à la création
        try {
          final push = PushNotificationService();
          await push.sendNotification(
            title: '📚 حكم تجويد جديدة',
            body: _titleController.text.trim(),
            type: 'info',
            payload: jsonEncode({
              'type': 'tajweed_rule_created',
              'title': _titleController.text.trim(),
              'content_type': _selectedType.name,
              'created_by': user.id,
            }),
            userId: null,
          );
        } catch (_) {}
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? 'تم التحديث بنجاح' : 'تم الإنشاء بنجاح'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في الحفظ : $e'),
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

  Widget _buildTypeSelector() {
    Widget option(TajweedType type, IconData icon, String title, String hint) {
      final selected = _selectedType == type;
      return Expanded(
        child: Material(
          color:
              selected
                  ? AppTheme.primaryColor.withValues(alpha: 0.08)
                  : AppTheme.backgroundColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
            onTap: () => setState(() => _selectedType = type),
            child: Container(
              padding: const EdgeInsets.all(AppTheme.spacingS),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
                border: Border.all(
                  color:
                      selected ? AppTheme.primaryColor : AppTheme.dividerColor,
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    icon,
                    size: 30,
                    color:
                        selected
                            ? AppTheme.primaryColor
                            : AppTheme.textSecondaryColor,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: AppTheme.bodyMedium.copyWith(
                      color:
                          selected
                              ? AppTheme.primaryColor
                              : AppTheme.textPrimaryColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(hint, style: AppTheme.bodySmall),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return AppSection(
      icon: Icons.category_rounded,
      title: 'نوع المحتوى',
      child: Row(
        children: [
          option(TajweedType.post, Icons.article_rounded, 'منشور', 'نص وصور'),
          const SizedBox(width: AppTheme.spacingS),
          option(
            TajweedType.video,
            Icons.smart_display_rounded,
            'فيديو',
            'رابط يوتيوب',
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'تعديل حكم تجويد' : 'إضافة حكم تجويد'),
      ),
      body:
          _isLoading && _isEditing
              ? const Center(child: CircularProgressIndicator())
              : Form(
                key: _formKey,
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.all(AppTheme.spacingM),
                  children: [
                    _buildTypeSelector(),
                    const SizedBox(height: AppTheme.spacingM),

                    AppSection(
                      icon: Icons.edit_note_rounded,
                      title: 'المحتوى',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: _titleController,
                            decoration: const InputDecoration(
                              labelText: 'العنوان',
                              hintText: 'مثال: النون الساكنة والتنوين',
                              prefixIcon: Icon(Icons.title_rounded),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'يرجى إدخال العنوان ';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: AppTheme.spacingS),
                          TextFormField(
                            controller: _contentController,
                            decoration: const InputDecoration(
                              labelText: 'الشرح',
                              hintText: 'اشرح بالتفصيل...',
                              alignLabelWithHint: true,
                            ),
                            maxLines: 6,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'يرجى إدخال المحتوى';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingM),

                    // Vidéo (seulement si type = vidéo)
                    if (_selectedType == TajweedType.video) ...[
                      AppSection(
                        icon: Icons.smart_display_rounded,
                        color: AppTheme.accentColor,
                        title: 'الفيديو',
                        child: TextFormField(
                          controller: _videoUrlController,
                          decoration: const InputDecoration(
                            labelText: 'رابط الفيديو',
                            hintText: 'https://youtube.com/watch?v=...',
                            prefixIcon: Icon(Icons.link_rounded),
                          ),
                          keyboardType: TextInputType.url,
                          textDirection: TextDirection.ltr,
                          validator: (value) {
                            if (_selectedType == TajweedType.video) {
                              if (value == null || value.trim().isEmpty) {
                                return 'يرجى إدخال رابط الفيديو';
                              }
                              final uri = Uri.tryParse(value);
                              if (uri == null || !uri.hasAbsolutePath) {
                                return 'يرجى إدخال رابط صحيح';
                              }
                              // Valider que c'est un lien YouTube
                              if (!_isValidYouTubeUrl(value)) {
                                return 'يرجى إدخال رابط يوتيوب صحيح';
                              }
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingM),
                    ],

                    AppSection(
                      icon: Icons.image_rounded,
                      color: AppTheme.secondaryColor,
                      title: 'الصورة',
                      subtitle: 'اختيارية',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_selectedImage != null) ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusM,
                              ),
                              child: Image.file(
                                _selectedImage!,
                                height: 200,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(height: AppTheme.spacingS),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _pickImage,
                                    style: AppButtonStyles.outlined(
                                      AppTheme.primaryColor,
                                    ),
                                    icon: const Icon(Icons.swap_horiz_rounded),
                                    label: const Text('تغيير'),
                                  ),
                                ),
                                const SizedBox(width: AppTheme.spacingS),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _removeSelectedImage,
                                    style: AppButtonStyles.outlined(
                                      AppTheme.errorColor,
                                    ),
                                    icon: const Icon(Icons.delete_rounded),
                                    label: const Text('حذف'),
                                  ),
                                ),
                              ],
                            ),
                          ] else
                            // Zone de sélection d'image
                            Material(
                              color: AppTheme.secondaryColor.withValues(
                                alpha: 0.06,
                              ),
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusM,
                              ),
                              child: InkWell(
                                onTap: _pickImage,
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusM,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: AppTheme.spacingL,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.radiusM,
                                    ),
                                    border: Border.all(
                                      color: AppTheme.secondaryColor.withValues(
                                        alpha: 0.4,
                                      ),
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      const Icon(
                                        Icons.add_photo_alternate_rounded,
                                        size: 40,
                                        color: AppTheme.secondaryColor,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'اختيار صورة من المعرض',
                                        style: AppTheme.bodyMedium.copyWith(
                                          color: AppTheme.secondaryColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(height: AppTheme.spacingS),
                          TextFormField(
                            controller: _imageUrlController,
                            textDirection: TextDirection.ltr,
                            decoration: InputDecoration(
                              labelText: 'أو رابط الصورة',
                              hintText: 'https://example.com/image.jpg',
                              prefixIcon: const Icon(Icons.link_rounded),
                              suffixIcon:
                                  _imageUrlController.text.isNotEmpty
                                      ? IconButton(
                                        icon: const Icon(Icons.close_rounded),
                                        onPressed: () {
                                          _imageUrlController.clear();
                                          setState(() {});
                                        },
                                      )
                                      : null,
                            ),
                            keyboardType: TextInputType.url,
                            onChanged: (value) {
                              // Une URL saisie remplace l'image choisie
                              if (value.isNotEmpty) {
                                setState(() => _selectedImage = null);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingM),

                    if (!_isEditing) ...[
                      const AppNotice(
                        text:
                            'سيكون المحتوى غير منشور افتراضياً، يمكنك نشره لاحقاً من القائمة.',
                        color: AppTheme.warningColor,
                        icon: Icons.visibility_off_rounded,
                      ),
                      const SizedBox(height: AppTheme.spacingM),
                    ],

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
                            onPressed: _isLoading ? null : _saveRule,
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
                            label: Text(_isEditing ? 'حفظ التعديلات' : 'إضافة'),
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
