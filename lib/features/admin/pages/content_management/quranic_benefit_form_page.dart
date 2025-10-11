import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quranic_competition/core/services/quranic_benefit_service.dart';
import 'package:quranic_competition/models/quranic_benefit.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class QuranicBenefitFormPage extends StatefulWidget {
  final String? benefitId; // null pour création, non-null pour édition

  const QuranicBenefitFormPage({super.key, this.benefitId});

  @override
  State<QuranicBenefitFormPage> createState() => _QuranicBenefitFormPageState();
}

class _QuranicBenefitFormPageState extends State<QuranicBenefitFormPage> {
  final QuranicBenefitService _benefitService = QuranicBenefitService();
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _imageUrlController = TextEditingController();

  bool _isLoading = false;
  bool _isEditing = false;
  QuranicBenefit? _existingBenefit;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.benefitId != null;
    if (_isEditing) {
      _loadBenefit();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadBenefit() async {
    if (widget.benefitId == null) return;

    setState(() => _isLoading = true);

    try {
      final benefit = await _benefitService.getBenefitById(widget.benefitId!);
      if (benefit != null) {
        setState(() {
          _existingBenefit = benefit;
          _titleController.text = benefit.title;
          _contentController.text = benefit.content;
          _imageUrlController.text = benefit.imageUrl ?? '';
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('لم يتم العثور على الفائدة القرآنية'),
              backgroundColor: Colors.red,
            ),
          );
          context.pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحميل الفائدة: $e'),
            backgroundColor: Colors.red,
          ),
        );
        context.pop();
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveBenefit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        throw Exception('المستخدم غير مسجل الدخول');
      }

      if (_isEditing && _existingBenefit != null) {
        // Mise à jour
        await _benefitService.updateBenefit(
          id: _existingBenefit!.id,
          title: _titleController.text.trim(),
          content: _contentController.text.trim(),
          imageUrl:
              _imageUrlController.text.trim().isEmpty
                  ? null
                  : _imageUrlController.text.trim(),
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم تحديث الفائدة القرآنية بنجاح'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Création
        await _benefitService.createBenefit(
          title: _titleController.text.trim(),
          content: _contentController.text.trim(),
          imageUrl:
              _imageUrlController.text.trim().isEmpty
                  ? null
                  : _imageUrlController.text.trim(),
          authorId: currentUser.id,
          authorName: currentUser.userMetadata?['full_name'] ?? 'مدير',
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم إنشاء الفائدة القرآنية بنجاح'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }

      if (mounted) {
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في حفظ الفائدة: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildFormField({
    required String label,
    required TextEditingController controller,
    required String? Function(String?) validator,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? hintText,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        validator: validator,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? 'تعديل الفائدة القرآنية' : 'إضافة فائدة قرآنية جديدة',
        ),
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
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildFormField(
                        label: 'عنوان الفائدة',
                        controller: _titleController,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'يرجى إدخال عنوان الفائدة';
                          }
                          if (value.trim().length < 3) {
                            return 'يجب أن يكون العنوان 3 أحرف على الأقل';
                          }
                          return null;
                        },
                        hintText: 'مثال: فضل قراءة القرآن',
                      ),
                      _buildFormField(
                        label: 'محتوى الفائدة',
                        controller: _contentController,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'يرجى إدخال محتوى الفائدة';
                          }
                          if (value.trim().length < 10) {
                            return 'يجب أن يكون المحتوى 10 أحرف على الأقل';
                          }
                          return null;
                        },
                        maxLines: 8,
                        hintText: 'اكتب هنا محتوى الفائدة القرآنية...',
                      ),
                      _buildFormField(
                        label: 'رابط الصورة (اختياري)',
                        controller: _imageUrlController,
                        validator: (value) {
                          if (value != null && value.trim().isNotEmpty) {
                            final uri = Uri.tryParse(value.trim());
                            if (uri == null ||
                                (!uri.hasScheme || !uri.hasAuthority)) {
                              return 'يرجى إدخال رابط صورة صحيح';
                            }
                          }
                          return null;
                        },
                        keyboardType: TextInputType.url,
                        hintText: 'https://example.com/image.jpg',
                      ),
                      const SizedBox(height: 24),
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
                              onPressed: _isLoading ? null : _saveBenefit,
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
                      const SizedBox(height: 16),
                      if (_isEditing && _existingBenefit != null) ...[
                        const Divider(),
                        const SizedBox(height: 8),
                        Text(
                          'معلومات إضافية',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.person, size: 16),
                                    const SizedBox(width: 8),
                                    Text(
                                      'الكاتب: ${_existingBenefit!.authorName}',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.calendar_today, size: 16),
                                    const SizedBox(width: 8),
                                    Text(
                                      'تاريخ الإنشاء: ${_formatDate(_existingBenefit!.createdAt)}',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.update, size: 16),
                                    const SizedBox(width: 8),
                                    Text(
                                      'آخر تحديث: ${_formatDate(_existingBenefit!.updatedAt)}',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      _existingBenefit!.isActive
                                          ? Icons.check_circle
                                          : Icons.cancel,
                                      size: 16,
                                      color:
                                          _existingBenefit!.isActive
                                              ? Colors.green
                                              : Colors.red,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'الحالة: ${_existingBenefit!.isActive ? "مفعل" : "غير مفعل"}',
                                      style: TextStyle(
                                        color:
                                            _existingBenefit!.isActive
                                                ? Colors.green
                                                : Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
