import 'package:flutter/material.dart';
import 'package:quranic_competition/core/services/eid_session_service.dart';
import 'package:quranic_competition/core/theme/app_theme.dart';
import '../../../../core/widgets/modern_navigation.dart';
import '../../../../core/widgets/ui_components.dart';
import '../../../../models/eid_session.dart';

class EidSessionFormPage extends StatefulWidget {
  final EidSession? session; // null pour créer, non null pour modifier

  const EidSessionFormPage({super.key, this.session});

  @override
  State<EidSessionFormPage> createState() => _EidSessionFormPageState();
}

class _EidSessionFormPageState extends State<EidSessionFormPage> {
  final EidSessionService _service = EidSessionService();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isActive = true;
  bool _isOpen = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.session != null) {
      _nameController.text = widget.session!.name;
      _descriptionController.text = widget.session!.description ?? '';
      _startDate = widget.session!.startDate;
      _endDate = widget.session!.endDate;
      _isActive = widget.session!.isActive;
      _isOpen = widget.session!.isOpen;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final picked = await showDatePicker(
      context: context,
      initialDate:
          isStartDate
              ? (_startDate ?? DateTime.now())
              : (_endDate ?? DateTime.now()),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (widget.session == null) {
        // Créer une nouvelle session
        await _service.createSession(
          name: _nameController.text.trim(),
          description:
              _descriptionController.text.trim().isEmpty
                  ? null
                  : _descriptionController.text.trim(),
          startDate: _startDate,
          endDate: _endDate,
          isActive: _isActive,
          isOpen: _isOpen,
        );
      } else {
        // Mettre à jour la session existante
        await _service.updateSession(
          id: widget.session!.id,
          name: _nameController.text.trim(),
          description:
              _descriptionController.text.trim().isEmpty
                  ? null
                  : _descriptionController.text.trim(),
          startDate: _startDate,
          endDate: _endDate,
          isActive: _isActive,
          isOpen: _isOpen,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.session == null
                  ? 'تم إنشاء الفسحة أو الدورة بنجاح'
                  : 'تم تحديث الفسحة أو الدورة بنجاح',
            ),
            backgroundColor: AppTheme.successColor,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ModernAppBar(
        title: widget.session == null
            ? 'إنشاء فسحة'
            : 'تعديل الفسحة',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacingS),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ModernCard(
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.spacingS),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'معلومات الفسحة أو الدورة',
                        style: AppTheme.headingSmall,
                      ),
                      const SizedBox(height: AppTheme.spacingS),
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'اسم الفسحة أو الدورة *',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusM,
                            ),
                          ),
                          prefixIcon: const Icon(Icons.event),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'يرجى إدخال اسم الفسحة أو الدورة';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppTheme.spacingS),
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'الوصف (اختياري)',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusM,
                            ),
                          ),
                          prefixIcon: const Icon(Icons.description),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spacingS),
              ModernCard(
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.spacingS),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('التواريخ', style: AppTheme.headingSmall),
                      const SizedBox(height: AppTheme.spacingS),
                      Row(
                        children: [
                          Expanded(
                            child: SecondaryButton(
                              onPressed: () => _selectDate(context, true),
                              text: _startDate != null
                                  ? '${_startDate!.day}/${_startDate!.month}/${_startDate!.year}'
                                  : 'تاريخ البداية',
                              icon: Icons.calendar_today,
                            ),
                          ),
                          const SizedBox(width: AppTheme.spacingS),
                          Expanded(
                            child: SecondaryButton(
                              onPressed: () => _selectDate(context, false),
                              text: _endDate != null
                                  ? '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}'
                                  : 'تاريخ النهاية',
                              icon: Icons.event,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spacingS),
              ModernCard(
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.spacingS),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'إعدادات الفسحة أو الدورة',
                        style: AppTheme.headingSmall,
                      ),
                      const SizedBox(height: AppTheme.spacingS),
                      Row(
                        children: [
                          Expanded(
                            child: ListTile(
                              title: const Text('تفعيل الفسحة أو الدورة'),
                              subtitle: const Text(
                                'عرض الفسحة أو الدورة على الصفحة الرئيسية',
                              ),
                              leading: Icon(
                                Icons.visibility,
                                color:
                                    _isActive
                                        ? AppTheme.successColor
                                        : AppTheme.textDisabledColor,
                              ),
                              trailing: Switch(
                                value: _isActive,
                                onChanged: (value) {
                                  setState(() => _isActive = value);
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: ListTile(
                              title: const Text('فتح التسجيل'),
                              subtitle: const Text(
                                'السماح للمستخدمين بالتسجيل',
                              ),
                              leading: Icon(
                                Icons.lock_open,
                                color:
                                    _isOpen
                                        ? AppTheme.infoColor
                                        : AppTheme.textDisabledColor,
                              ),
                              trailing: Switch(
                                value: _isOpen,
                                onChanged: (value) {
                                  setState(() => _isOpen = value);
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spacingL),
              SizedBox(
                width: double.infinity,
                child: PrimaryButton(
                  onPressed: _isLoading ? null : _submit,
                  text:
                      widget.session == null
                          ? 'إنشاء الفسحة أو الدورة'
                          : 'حفظ التغييرات',
                  icon: Icons.save,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
