import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quranic_competition/core/services/eid_session_service.dart';
import 'package:quranic_competition/core/services/push_notification_service.dart';
import 'package:quranic_competition/core/theme/app_theme.dart';
import 'package:quranic_competition/core/widgets/app_ui.dart';
import 'package:quranic_competition/core/widgets/modern_navigation.dart';
import 'package:quranic_competition/models/eid_session.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  String? _dateError;

  bool get _isEditing => widget.session != null;

  @override
  void initState() {
    super.initState();
    final session = widget.session;
    if (session != null) {
      _nameController.text = session.name;
      _descriptionController.text = session.description ?? '';
      _startDate = session.startDate;
      _endDate = session.endDate;
      _isActive = session.isActive;
      _isOpen = session.isOpen;
    }
    // L'en-tête affiche le nom en direct
    _nameController.addListener(_onNameChanged);
  }

  void _onNameChanged() => setState(() {});

  @override
  void dispose() {
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(bool isStartDate) async {
    FocusScope.of(context).unfocus();
    final current = isStartDate ? _startDate : _endDate;
    final picked = await showDatePicker(
      context: context,
      initialDate:
          current ?? (isStartDate ? null : _startDate) ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: isStartDate ? 'تاريخ البداية' : 'تاريخ النهاية',
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isStartDate) {
        _startDate = picked;
      } else {
        _endDate = picked;
      }
      _dateError = null;
    });
  }

  bool _validateDates() {
    final start = _startDate;
    final end = _endDate;
    final invalid = start != null && end != null && end.isBefore(start);
    setState(
      () =>
          _dateError =
              invalid ? 'تاريخ النهاية يجب أن يكون بعد تاريخ البداية' : null,
    );
    return !invalid;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final formValid = _formKey.currentState!.validate();
    final datesValid = _validateDates();
    if (!formValid || !datesValid) return;

    setState(() => _isLoading = true);

    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();

    try {
      if (!_isEditing) {
        await _service.createSession(
          name: name,
          description: description.isEmpty ? null : description,
          startDate: _startDate,
          endDate: _endDate,
          isActive: _isActive,
          isOpen: _isOpen,
        );

        // Notification publique, seulement si la فسحة est visible
        if (_isActive) {
          try {
            await PushNotificationService().sendNotification(
              title: '🎉 تم إنشاء فعالية جديدة',
              body: name,
              type: 'info',
              payload: jsonEncode({
                'type': 'eid_session_created',
                'name': name,
                'created_by': Supabase.instance.client.auth.currentUser?.id,
              }),
              userId: null,
            );
          } catch (_) {}
        }
      } else {
        await _service.updateSession(
          id: widget.session!.id,
          name: name,
          description: description.isEmpty ? null : description,
          startDate: _startDate,
          endDate: _endDate,
          isActive: _isActive,
          isOpen: _isOpen,
          replaceOptionalFields: true,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing ? 'تم حفظ التعديلات بنجاح' : 'تم إنشاء الفسحة بنجاح',
          ),
          backgroundColor: AppTheme.successColor,
        ),
      );
      context.pop(true);
    } catch (e) {
      debugPrint('Erreur enregistrement فسحة: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing ? 'تعذر حفظ التعديلات' : 'تعذر إنشاء الفسحة',
          ),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Widgets
  // ---------------------------------------------------------------------------

  Widget _buildSwitch({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      value: value,
      onChanged: _isLoading ? null : onChanged,
      secondary: AppIconBadge(
        icon: icon,
        color: value ? color : AppTheme.textDisabledColor,
      ),
      title: Text(
        title,
        style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(subtitle, style: AppTheme.bodySmall),
    );
  }

  static String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';

  /// Durée en jours (bornes incluses), si les deux dates sont choisies
  int? get _durationDays {
    final start = _startDate;
    final end = _endDate;
    if (start == null || end == null || end.isBefore(start)) return null;
    return end.difference(start).inDays + 1;
  }

  /// Aperçu en direct de la فسحة telle qu'elle sera enregistrée
  Widget _buildHeader() {
    final name = _nameController.text.trim();
    final start = _startDate;
    final end = _endDate;

    return AppGradientHeader(
      shape: AppHeaderShape.card,
      compact: true,
      icon:
          _isEditing ? Icons.edit_calendar_rounded : Icons.celebration_rounded,
      title:
          name.isNotEmpty ? name : (_isEditing ? 'تعديل الفسحة' : 'فسحة جديدة'),
      subtitle:
          _isEditing
              ? 'عدّل المعلومات ثم احفظ التغييرات'
              : 'املأ المعلومات لإنشاء فسحة أو دورة',
      badges: [
        AppHeaderBadge(
          icon:
              _isActive
                  ? Icons.visibility_rounded
                  : Icons.visibility_off_rounded,
          text: _isActive ? 'ظاهرة' : 'مخفية',
        ),
        AppHeaderBadge(
          icon: _isOpen ? Icons.lock_open_rounded : Icons.lock_rounded,
          text: _isOpen ? 'التسجيل مفتوح' : 'التسجيل مغلق',
          highlightColor: _isOpen ? null : AppTheme.secondaryColor,
        ),
        if (start != null || end != null)
          AppHeaderBadge(
            icon: Icons.date_range_rounded,
            text: [
              if (start != null) _formatDate(start),
              if (end != null) _formatDate(end),
            ].join(' - '),
          ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacingM,
        AppTheme.spacingS,
        AppTheme.spacingM,
        AppTheme.spacingS,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.backgroundColor,
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : () => context.pop(),
                style: AppButtonStyles.outlined(AppTheme.textSecondaryColor),
                icon: const Icon(Icons.close_rounded),
                label: const Text('إلغاء'),
              ),
            ),
            const SizedBox(width: AppTheme.spacingS),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _submit,
                style: AppButtonStyles.filled(AppTheme.primaryColor),
                icon:
                    _isLoading
                        ? const AppButtonLoader()
                        : Icon(
                          _isEditing
                              ? Icons.save_rounded
                              : Icons.add_circle_rounded,
                        ),
                label: Text(_isEditing ? 'حفظ التعديلات' : 'إنشاء الفسحة'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wasActive = widget.session?.isActive ?? false;

    return Scaffold(
      appBar: ModernAppBar(title: _isEditing ? 'تعديل الفسحة' : 'فسحة جديدة'),
      body: Form(
        key: _formKey,
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(AppTheme.spacingM),
          children: [
            _buildHeader(),
            const SizedBox(height: AppTheme.spacingM),
            AppSection(
              icon: Icons.info_rounded,
              title: 'معلومات الفسحة',
              subtitle: 'الاسم والوصف كما يظهران للمشاركين',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _nameController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'اسم الفسحة أو الدورة *',
                      hintText: 'مثال: فسحة عيد الفطر',
                      prefixIcon: Icon(Icons.label_rounded),
                    ),
                    validator:
                        (value) =>
                            value == null || value.trim().isEmpty
                                ? 'يرجى إدخال اسم الفسحة أو الدورة'
                                : null,
                  ),
                  const SizedBox(height: AppTheme.spacingS),
                  TextFormField(
                    controller: _descriptionController,
                    minLines: 3,
                    maxLines: 5,
                    maxLength: 500,
                    decoration: const InputDecoration(
                      labelText: 'الوصف (اختياري)',
                      hintText: 'تفاصيل تظهر للمشاركين...',
                      prefixIcon: Icon(Icons.notes_rounded),
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            AppSection(
              icon: Icons.date_range_rounded,
              color: AppTheme.secondaryColor,
              title: 'التواريخ',
              subtitle: 'اختيارية: فترة إقامة الفسحة',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _DateField(
                    label: 'تاريخ البداية',
                    icon: Icons.event_rounded,
                    value: _startDate,
                    enabled: !_isLoading,
                    onTap: () => _selectDate(true),
                    onClear: () => setState(() => _startDate = null),
                  ),
                  const SizedBox(height: AppTheme.spacingS),
                  _DateField(
                    label: 'تاريخ النهاية',
                    icon: Icons.event_available_rounded,
                    value: _endDate,
                    enabled: !_isLoading,
                    errorText: _dateError,
                    onTap: () => _selectDate(false),
                    onClear:
                        () => setState(() {
                          _endDate = null;
                          _dateError = null;
                        }),
                  ),
                  if (_durationDays != null) ...[
                    const SizedBox(height: AppTheme.spacingS),
                    AppNotice(
                      text:
                          _durationDays == 1
                              ? 'المدة: يوم واحد'
                              : 'المدة: $_durationDays أيام',
                      color: AppTheme.secondaryColor,
                      icon: Icons.timelapse_rounded,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            AppSection(
              icon: Icons.tune_rounded,
              color: AppTheme.infoColor,
              title: 'الإعدادات',
              subtitle: 'يمكن تغييرها لاحقاً من صفحة الفسحة',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSwitch(
                    title: 'ظاهرة للمشاركين',
                    subtitle: 'عرض الفسحة على الصفحة الرئيسية',
                    icon: Icons.visibility_rounded,
                    color: AppTheme.successColor,
                    value: _isActive,
                    onChanged: (value) => setState(() => _isActive = value),
                  ),
                  const Divider(height: 1),
                  _buildSwitch(
                    title: 'التسجيل مفتوح',
                    subtitle: 'السماح للمشاركين بالتسجيل',
                    icon: Icons.how_to_reg_rounded,
                    color: AppTheme.infoColor,
                    value: _isOpen,
                    onChanged: (value) => setState(() => _isOpen = value),
                  ),
                  if (_isActive && !wasActive) ...[
                    const SizedBox(height: AppTheme.spacingS),
                    const AppNotice(
                      text: 'سيتم إخفاء الفسحة الظاهرة حالياً، إن وجدت.',
                      color: AppTheme.warningColor,
                      icon: Icons.swap_horiz_rounded,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }
}

/// Champ de date cliquable, avec bouton d'effacement
class _DateField extends StatelessWidget {
  final String label;
  final IconData icon;
  final DateTime? value;
  final bool enabled;
  final String? errorText;
  final VoidCallback onTap;
  final VoidCallback onClear;

  const _DateField({
    required this.label,
    required this.icon,
    required this.value,
    required this.enabled,
    required this.onTap,
    required this.onClear,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final date = value;

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(AppTheme.radiusM),
      child: InputDecorator(
        isEmpty: date == null,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          errorText: errorText,
          enabled: enabled,
          suffixIcon:
              date == null
                  ? const Icon(Icons.calendar_month_rounded)
                  : IconButton(
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'مسح التاريخ',
                    onPressed: enabled ? onClear : null,
                  ),
        ),
        child: Text(
          date == null ? '' : _EidSessionFormPageState._formatDate(date),
          style: AppTheme.bodyLarge.copyWith(color: AppTheme.textPrimaryColor),
        ),
      ),
    );
  }
}
