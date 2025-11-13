import 'dart:io';
import 'package:flutter/material.dart';
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
    final hasPermission =
        await _permissionService.requestStoragePermission(context);
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
            backgroundColor: Colors.red,
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

  Future<void> _saveRule() async {
    if (!_formKey.currentState!.validate()) return;

    // Vérifier الصلاحيات
    final canModify = await _permissionCheckService.canModify();
    if (!canModify) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('ليس لديك صلاحية تعديل المحتوى'),
          backgroundColor: Colors.red,
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
            title: '📚 قاعدة تجويد جديدة',
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
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في الحفظ : $e'),
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

  Widget _buildTypeSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'نوع المحتوى',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            RadioListTile<TajweedType>(
              title: const Text('منشور'),
              subtitle: const Text('نص وصور'),
              value: TajweedType.post,
              groupValue: _selectedType,
              onChanged: (value) {
                setState(() {
                  _selectedType = value!;
                });
              },
            ),
            RadioListTile<TajweedType>(
              title: const Text('فيديو'),
              subtitle: const Text('رابط فيديو'),
              value: TajweedType.video,
              groupValue: _selectedType,
              onChanged: (value) {
                setState(() {
                  _selectedType = value!;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'تعديل' : 'إضافة'),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body:
          _isLoading && _isEditing
              ? const Center(child: CircularProgressIndicator())
              : Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTypeSelector(),
                      const SizedBox(height: 16),

                      // Titre
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'العنوان',
                          hintText: 'مثال: النون الساكنة والتنوين',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'يرجى إدخال العنوان ';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Contenu
                      TextFormField(
                        controller: _contentController,
                        decoration: const InputDecoration(
                          labelText: 'المحتوى',
                          hintText: 'اشرح بالتفصيل...',
                          border: OutlineInputBorder(),
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
                      const SizedBox(height: 16),

                      // Section Image
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'الصورة',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Aperçu de l'image sélectionnée
                              if (_selectedImage != null) ...[
                                Container(
                                  width: double.infinity,
                                  height: 200,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.grey[300]!,
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.file(
                                      _selectedImage!,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: _pickImage,
                                        icon: const Icon(Icons.edit),
                                        label: const Text('تغيير الصورة'),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: _removeSelectedImage,
                                        icon: const Icon(
                                          Icons.delete,
                                          color: Colors.red,
                                        ),
                                        label: const Text(
                                          'حذف',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                const Divider(),
                                const SizedBox(height: 8),
                              ],

                              // Bouton pour choisir une image
                              if (_selectedImage == null)
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: _pickImage,
                                    icon: const Icon(Icons.photo_library),
                                    label: const Text('اختيار صورة من المعرض'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue[50],
                                      foregroundColor: Colors.blue[700],
                                    ),
                                  ),
                                ),

                              const SizedBox(height: 12),

                              // URL de l'image (alternative)
                              TextFormField(
                                controller: _imageUrlController,
                                decoration: InputDecoration(
                                  labelText: 'أو رابط الصورة (اختياري)',
                                  hintText: 'https://example.com/image.jpg',
                                  border: const OutlineInputBorder(),
                                  prefixIcon: const Icon(Icons.link),
                                  suffixIcon:
                                      _imageUrlController.text.isNotEmpty
                                          ? IconButton(
                                            icon: const Icon(Icons.clear),
                                            onPressed: () {
                                              _imageUrlController.clear();
                                              setState(() {});
                                            },
                                          )
                                          : null,
                                ),
                                keyboardType: TextInputType.url,
                                onChanged: (value) {
                                  if (value.isNotEmpty) {
                                    setState(() {
                                      _selectedImage =
                                          null; // Effacer l'image si une URL est saisie
                                    });
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // URL de la vidéo (seulement si type = video)
                      if (_selectedType == TajweedType.video) ...[
                        TextFormField(
                          controller: _videoUrlController,
                          decoration: const InputDecoration(
                            labelText: 'رابط الفيديو',
                            hintText: 'https://youtube.com/watch?v=...',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.video_library),
                          ),
                          keyboardType: TextInputType.url,
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
                        const SizedBox(height: 16),
                      ],

                      // Informations sur l'état par défaut
                      Card(
                        color: Colors.orange[50],
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Icon(Icons.info, color: Colors.orange[700]),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'سيكون المنشور غير نشط افتراضياً. يمكنك تفعيله لاحقاً.',
                                  style: TextStyle(
                                    color: Colors.orange[700],
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Boutons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed:
                                  _isLoading ? null : () => context.pop(),
                              child: const Text('إلغاء'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _saveRule,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                              child:
                                  _isLoading
                                      ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                        ),
                                      )
                                      : Text(_isEditing ? 'تحديث' : 'إنشاء'),
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
