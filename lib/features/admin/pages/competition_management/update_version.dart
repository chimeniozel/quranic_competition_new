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

  bool _isLoading = false;

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
            onPressed: _isLoading ? null : _submitUpdate,
            icon: Icon(
              Icons.save,
              color:
                  _isLoading
                      ? AppTheme.textSecondaryColor
                      : AppTheme.surfaceColor,
            ),
            tooltip: 'حفظ التغييرات',
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
                                style: AppTheme.bodyMedium,
                                decoration: InputDecoration(
                                  labelText: 'اسم النسخة',
                                  hintText: 'أدخل اسم النسخة',
                                  prefixIcon: Icon(
                                    Icons.title,
                                    color: AppTheme.primaryColor,
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
                                keyboardType: TextInputType.number,
                                style: AppTheme.bodyMedium,
                                decoration: InputDecoration(
                                  labelText: 'السنة',
                                  hintText: 'أدخل السنة',
                                  prefixIcon: Icon(
                                    Icons.calendar_today,
                                    color: AppTheme.primaryColor,
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
                                      keyboardType: TextInputType.number,
                                      style: AppTheme.bodyMedium,
                                      decoration: InputDecoration(
                                        labelText: 'الحد الأقصى للكبار',
                                        hintText: 'عدد الكبار',
                                        prefixIcon: Icon(
                                          Icons.person,
                                          color: AppTheme.primaryColor,
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
                                      keyboardType: TextInputType.number,
                                      style: AppTheme.bodyMedium,
                                      decoration: InputDecoration(
                                        labelText: 'الحد الأقصى للصغار',
                                        hintText: 'عدد الصغار',
                                        prefixIcon: Icon(
                                          Icons.person,
                                          color: AppTheme.secondaryColor,
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
                                          (val) =>
                                              setState(() => _isActive = val),
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
                                          (val) => setState(
                                            () => _isRegistrationOpen = val,
                                          ),
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
                          onPressed: _isLoading ? null : _submitUpdate,
                          text:
                              _isLoading ? 'جاري التحديث...' : 'حفظ التغييرات',
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
