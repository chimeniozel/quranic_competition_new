import 'package:flutter/material.dart';
import '../../../../core/services/competition_version_service.dart';
import '../../../../models/competition_version.dart';
import '../../../../core/widgets/modern_navigation.dart';
import '../../../../core/widgets/ui_components.dart';
import '../../../../core/widgets/loading_states.dart';
import '../../../../core/theme/app_theme.dart';

class UpdateVersionPage extends StatefulWidget {
  final CompetitionVersion version;

  const UpdateVersionPage({super.key, required this.version});

  @override
  State<UpdateVersionPage> createState() => _UpdateVersionPageState();
}

class _UpdateVersionPageState extends State<UpdateVersionPage> {
  final _service = CompetitionVersionService();

  late TextEditingController _nameController;
  late TextEditingController _yearController;
  late TextEditingController _maxAdultsController;
  late TextEditingController _maxChildrenController;
  bool _isActive = true;
  bool _isRegistrationOpen = true;
  bool _juryEvaluationEnabled = false;

  bool _isLoading = false;
  bool _canEdit = false;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(text: widget.version.name);
    _yearController = TextEditingController(
      text: widget.version.year.toString(),
    );
    _maxAdultsController = TextEditingController(
      text: widget.version.maxAdults.toString(),
    );
    _maxChildrenController = TextEditingController(
      text: widget.version.maxChildren.toString(),
    );
    _isActive = widget.version.isActive;
    _isRegistrationOpen = widget.version.isRegistrationOpen;
    _juryEvaluationEnabled = widget.version.juryEvaluationEnabled;

    // Vérifier si la compétition est active pour autoriser les modifications
    _canEdit = widget.version.isActive;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _yearController.dispose();
    _maxAdultsController.dispose();
    _maxChildrenController.dispose();
    super.dispose();
  }

  Future<void> _submitUpdate() async {
    // Vérifier si les modifications sont autorisées
    if (!_canEdit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يمكن تعديل النسخة غير النشطة'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final name = _nameController.text.trim();
    final year = int.tryParse(_yearController.text.trim());
    final maxAdults = int.tryParse(_maxAdultsController.text.trim());
    final maxChildren = int.tryParse(_maxChildrenController.text.trim());

    if (name.isEmpty ||
        year == null ||
        maxAdults == null ||
        maxChildren == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى ملء جميع الحقول بشكل صحيح')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _service.updateVersion(
        id: widget.version.id,
        name: name,
        year: year,
        maxAdults: maxAdults,
        maxChildren: maxChildren,
        isActive: _isActive,
        isRegistrationOpen: _isRegistrationOpen,
        juryEvaluationEnabled: _juryEvaluationEnabled,
      );

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم تحديث النسخة بنجاح')));

      Navigator.of(context).pop(true); // Retour avec succès
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('فشل التحديث: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ModernAppBar(
        title: 'تعديل النسخة',
        actions: [
          IconButton(
            onPressed: (_isLoading || !_canEdit) ? null : _submitUpdate,
            icon: Icon(
              Icons.save,
              color:
                  (_isLoading || !_canEdit)
                      ? AppTheme.textSecondaryColor
                      : AppTheme.surfaceColor,
            ),
            tooltip: !_canEdit ? 'التعديل غير متاح' : 'حفظ التغييرات',
          ),
        ],
      ),
      body:
          _isLoading
              ? const LoadingOverlay(child: SizedBox())
              : ModernPullToRefresh(
                onRefresh: () async {
                  // Recharger les données si nécessaire
                },
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppTheme.spacingS),
                  child: Column(
                    children: [
                      // Avertissement si la compétition n'est pas active
                      if (!_canEdit)
                        ModernCard(
                          backgroundColor: AppTheme.warningColor.withOpacity(
                            0.1,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(AppTheme.spacingM),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.warning_outlined,
                                  color: AppTheme.warningColor,
                                  size: 28,
                                ),
                                const SizedBox(width: AppTheme.spacingM),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'النسخة غير نشطة',
                                        style: AppTheme.labelLarge.copyWith(
                                          color: AppTheme.warningColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'لا يمكن تعديل النسخ غير النشطة. يجب تفعيل النسخة أولاً.',
                                        style: AppTheme.bodyMedium.copyWith(
                                          color: AppTheme.warningColor
                                              .withOpacity(0.8),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (!_canEdit) const SizedBox(height: AppTheme.spacingS),

                      // Header avec informations de la version
                      ModernCard(
                        child: Padding(
                          padding: const EdgeInsets.all(AppTheme.spacingS),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(
                                      AppTheme.spacingS,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(
                                        AppTheme.radiusM,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.edit,
                                      color: AppTheme.primaryColor,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: AppTheme.spacingM),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'تعديل النسخة',
                                          style: AppTheme.labelLarge.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'تحديث معلومات النسخة الحالية',
                                          style: AppTheme.labelMedium.copyWith(
                                            color: AppTheme.textSecondaryColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingS),

                      // Formulaire de base
                      ModernCard(
                        child: Padding(
                          padding: const EdgeInsets.all(AppTheme.spacingS),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'المعلومات الأساسية',
                                style: AppTheme.headingMedium,
                              ),
                              const SizedBox(height: AppTheme.spacingS),
                              TextField(
                                controller: _nameController,
                                enabled: _canEdit,
                                style: AppTheme.bodyMedium,
                                decoration: InputDecoration(
                                  labelText: 'اسم النسخة',
                                  hintText: 'أدخل اسم النسخة',
                                  prefixIcon: Icon(
                                    Icons.title,
                                    color:
                                        _canEdit
                                            ? AppTheme.primaryColor
                                            : AppTheme.textDisabledColor,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.radiusM,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppTheme.spacingS),
                              TextField(
                                controller: _yearController,
                                enabled: _canEdit,
                                keyboardType: TextInputType.number,
                                style: AppTheme.bodyMedium,
                                decoration: InputDecoration(
                                  labelText: 'السنة',
                                  hintText: 'أدخل السنة',
                                  prefixIcon: Icon(
                                    Icons.calendar_today,
                                    color:
                                        _canEdit
                                            ? AppTheme.primaryColor
                                            : AppTheme.textDisabledColor,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.radiusM,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingS),

                      // Limites des participants
                      ModernCard(
                        child: Padding(
                          padding: const EdgeInsets.all(AppTheme.spacingS),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'حدود المشاركين',
                                style: AppTheme.headingMedium,
                              ),
                              const SizedBox(height: AppTheme.spacingS),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _maxAdultsController,
                                      enabled: _canEdit,
                                      keyboardType: TextInputType.number,
                                      style: AppTheme.bodyMedium,
                                      decoration: InputDecoration(
                                        labelText: 'الحد الأقصى للكبار',
                                        hintText: 'عدد الكبار',
                                        prefixIcon: Icon(
                                          Icons.person,
                                          color:
                                              _canEdit
                                                  ? AppTheme.primaryColor
                                                  : AppTheme.textDisabledColor,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            AppTheme.radiusM,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: AppTheme.spacingM),
                                  Expanded(
                                    child: TextField(
                                      controller: _maxChildrenController,
                                      enabled: _canEdit,
                                      keyboardType: TextInputType.number,
                                      style: AppTheme.bodyMedium,
                                      decoration: InputDecoration(
                                        labelText: 'الحد الأقصى للصغار',
                                        hintText: 'عدد الصغار',
                                        prefixIcon: Icon(
                                          Icons.person,
                                          color:
                                              _canEdit
                                                  ? AppTheme.secondaryColor
                                                  : AppTheme.textDisabledColor,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            AppTheme.radiusM,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingS),

                      // Paramètres de statut
                      ModernCard(
                        child: Padding(
                          padding: const EdgeInsets.all(AppTheme.spacingS),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'إعدادات النسخة',
                                style: AppTheme.headingMedium,
                              ),
                              const SizedBox(height: AppTheme.spacingS),

                              // Statut actif
                              Container(
                                padding: const EdgeInsets.all(
                                  AppTheme.spacingM,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      _isActive
                                          ? AppTheme.successColor.withValues(
                                            alpha: 0.1,
                                          )
                                          : AppTheme.errorColor.withValues(
                                            alpha: 0.1,
                                          ),
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusM,
                                  ),
                                  border: Border.all(
                                    color:
                                        _isActive
                                            ? AppTheme.successColor.withValues(
                                              alpha: 0.3,
                                            )
                                            : AppTheme.errorColor.withValues(
                                              alpha: 0.3,
                                            ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      _isActive
                                          ? Icons.check_circle
                                          : Icons.cancel,
                                      color:
                                          _isActive
                                              ? AppTheme.successColor
                                              : AppTheme.errorColor,
                                      size: 24,
                                    ),
                                    const SizedBox(width: AppTheme.spacingM),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'النسخة نشطة',
                                            style: AppTheme.bodyLarge.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          Text(
                                            _isActive
                                                ? 'النسخة متاحة للاستخدام'
                                                : 'النسخة غير متاحة',
                                            style: AppTheme.bodySmall.copyWith(
                                              color:
                                                  AppTheme.textSecondaryColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Switch(
                                      value: _isActive,
                                      onChanged:
                                          _canEdit
                                              ? (val) => setState(
                                                () => _isActive = val,
                                              )
                                              : null,
                                      activeColor: AppTheme.successColor,
                                      inactiveThumbColor: AppTheme.errorColor,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: AppTheme.spacingS),

                              // Statut d'inscription
                              Container(
                                padding: const EdgeInsets.all(
                                  AppTheme.spacingM,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      _isRegistrationOpen
                                          ? AppTheme.successColor.withValues(
                                            alpha: 0.1,
                                          )
                                          : AppTheme.errorColor.withValues(
                                            alpha: 0.1,
                                          ),
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusM,
                                  ),
                                  border: Border.all(
                                    color:
                                        _isRegistrationOpen
                                            ? AppTheme.successColor.withValues(
                                              alpha: 0.3,
                                            )
                                            : AppTheme.errorColor.withValues(
                                              alpha: 0.3,
                                            ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      _isRegistrationOpen
                                          ? Icons.lock_open
                                          : Icons.lock,
                                      color:
                                          _isRegistrationOpen
                                              ? AppTheme.successColor
                                              : AppTheme.errorColor,
                                      size: 24,
                                    ),
                                    const SizedBox(width: AppTheme.spacingM),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'فتح التسجيل',
                                            style: AppTheme.bodyLarge.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          Text(
                                            _isRegistrationOpen
                                                ? 'التسجيل مفتوح للمشاركين'
                                                : 'التسجيل مغلق',
                                            style: AppTheme.bodySmall.copyWith(
                                              color:
                                                  AppTheme.textSecondaryColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Switch(
                                      value: _isRegistrationOpen,
                                      onChanged:
                                          _canEdit
                                              ? (val) => setState(
                                                () => _isRegistrationOpen = val,
                                              )
                                              : null,
                                      activeColor: AppTheme.successColor,
                                      inactiveThumbColor: AppTheme.errorColor,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: AppTheme.spacingS),

                              // Statut d'évaluation des jurys
                              Container(
                                padding: const EdgeInsets.all(
                                  AppTheme.spacingM,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      _juryEvaluationEnabled
                                          ? AppTheme.successColor.withValues(
                                            alpha: 0.1,
                                          )
                                          : AppTheme.errorColor.withValues(
                                            alpha: 0.1,
                                          ),
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusM,
                                  ),
                                  border: Border.all(
                                    color:
                                        _juryEvaluationEnabled
                                            ? AppTheme.successColor.withValues(
                                              alpha: 0.3,
                                            )
                                            : AppTheme.errorColor.withValues(
                                              alpha: 0.3,
                                            ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      _juryEvaluationEnabled
                                          ? Icons.gavel
                                          : Icons.gavel_outlined,
                                      color:
                                          _juryEvaluationEnabled
                                              ? AppTheme.successColor
                                              : AppTheme.errorColor,
                                      size: 24,
                                    ),
                                    const SizedBox(width: AppTheme.spacingM),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'تفعيل تقييم المحكمين',
                                            style: AppTheme.bodyLarge.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          Text(
                                            _juryEvaluationEnabled
                                                ? 'المحكمون يمكنهم تقييم المشاركين'
                                                : 'تقييم المحكمين معطل',
                                            style: AppTheme.bodySmall.copyWith(
                                              color:
                                                  AppTheme.textSecondaryColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Switch(
                                      value: _juryEvaluationEnabled,
                                      onChanged:
                                          _canEdit
                                              ? (val) => setState(
                                                () =>
                                                    _juryEvaluationEnabled =
                                                        val,
                                              )
                                              : null,
                                      activeColor: AppTheme.successColor,
                                      inactiveThumbColor: AppTheme.errorColor,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingL),

                      // Bouton de sauvegarde
                      SizedBox(
                        width: double.infinity,
                        child: PrimaryButton(
                          onPressed:
                              (_isLoading || !_canEdit) ? null : _submitUpdate,
                          text:
                              _isLoading
                                  ? 'جاري التحديث...'
                                  : !_canEdit
                                  ? 'التعديل غير متاح'
                                  : 'حفظ التغييرات',
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingS),
                    ],
                  ),
                ),
              ),
    );
  }
}
