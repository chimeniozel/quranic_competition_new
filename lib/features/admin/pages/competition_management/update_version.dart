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

  TextEditingController _nameController = TextEditingController();
  TextEditingController _yearController = TextEditingController();
  TextEditingController _maxAdultsController = TextEditingController();
  TextEditingController _maxChildrenController = TextEditingController();
  TextEditingController _successAverageAdultsController =
      TextEditingController();
  TextEditingController _successAverageChildrenController =
      TextEditingController();
  bool _isActive = true;
  bool _isRegistrationOpen = true;
  bool _juryEvaluationEnabled = false;

  bool _isLoading = false;
  bool _canEdit = false;
  Map<String, int> _participantCounts = {'adults': 0, 'children': 0};

  @override
  void initState() {
    super.initState();
    // Initialiser immédiatement avec les données du widget
    _initializeWithWidgetData();
    // Puis charger les données actuelles depuis la base de données
    _loadCurrentVersionData();
  }

  Future<void> _loadCurrentVersionData() async {
    try {
      // Charger les données actuelles depuis la base de données
      final currentVersion = await _service.getVersionById(widget.version.id);
      if (currentVersion != null) {
        // Charger aussi les statistiques des participants
        final participantCounts = await _service.getParticipantCountsByAgeGroup(
          widget.version.id,
        );

        setState(() {
          _nameController.text = currentVersion.name;
          _yearController.text = currentVersion.year.toString();
          _maxAdultsController.text = currentVersion.maxAdults.toString();
          _maxChildrenController.text = currentVersion.maxChildren.toString();
          _successAverageAdultsController.text =
              currentVersion.successAverageAdults.toString();
          _successAverageChildrenController.text =
              currentVersion.successAverageChildren.toString();
          _isActive = currentVersion.isActive;
          _isRegistrationOpen = currentVersion.isRegistrationOpen;
          _juryEvaluationEnabled = currentVersion.juryEvaluationEnabled;
          _participantCounts = participantCounts;

          // Vérifier si la compétition est active pour autoriser les modifications
          _canEdit = currentVersion.isActive;
        });
      } else {
        // Fallback sur les données du widget si la version n'est pas trouvée
        _initializeWithWidgetData();
      }
    } catch (e) {
      print('Erreur lors du chargement des données de la version: $e');
      // Fallback sur les données du widget en cas d'erreur
      _initializeWithWidgetData();
    }
  }

  void _initializeWithWidgetData() {
    _nameController.text = widget.version.name;
    _yearController.text = widget.version.year.toString();
    _maxAdultsController.text = widget.version.maxAdults.toString();
    _maxChildrenController.text = widget.version.maxChildren.toString();
    _successAverageAdultsController.text =
        widget.version.successAverageAdults.toString();
    _successAverageChildrenController.text =
        widget.version.successAverageChildren.toString();
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
    _successAverageAdultsController.dispose();
    _successAverageChildrenController.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    try {
      await _loadCurrentVersionData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تحديث البيانات'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحديث البيانات: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
    final successAverageAdults = double.tryParse(
      _successAverageAdultsController.text.trim(),
    );
    final successAverageChildren = double.tryParse(
      _successAverageChildrenController.text.trim(),
    );

    if (name.isEmpty ||
        year == null ||
        maxAdults == null ||
        maxChildren == null ||
        successAverageAdults == null ||
        successAverageChildren == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى ملء جميع الحقول بشكل صحيح')),
      );
      return;
    }

    // Vérifier que les moyennes sont dans une plage valide (0-100)
    if (successAverageAdults < 0 ||
        successAverageAdults > 100 ||
        successAverageChildren < 0 ||
        successAverageChildren > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب أن تكون المتوسطات بين 0 و 100')),
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
        successAverageAdults: successAverageAdults,
        successAverageChildren: successAverageChildren,
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
            onPressed: _isLoading ? null : _refreshData,
            icon: Icon(
              Icons.refresh,
              color:
                  _isLoading
                      ? AppTheme.textSecondaryColor
                      : AppTheme.surfaceColor,
            ),
            tooltip: 'تحديث البيانات',
          ),
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
                onRefresh: _refreshData,
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

                      // Moyennes de succès
                      ModernCard(
                        child: Padding(
                          padding: const EdgeInsets.all(AppTheme.spacingS),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'متوسطات النجاح',
                                style: AppTheme.headingMedium,
                              ),
                              const SizedBox(height: AppTheme.spacingS),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller:
                                          _successAverageAdultsController,
                                      enabled: _canEdit,
                                      keyboardType: TextInputType.number,
                                      style: AppTheme.bodyMedium,
                                      decoration: InputDecoration(
                                        labelText: 'متوسط النجاح للكبار (%)',
                                        hintText: '70.0',
                                        prefixIcon: Icon(
                                          Icons.trending_up,
                                          color:
                                              _canEdit
                                                  ? AppTheme.primaryColor
                                                  : AppTheme.textDisabledColor,
                                        ),
                                        suffixText: '%',
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
                                      controller:
                                          _successAverageChildrenController,
                                      enabled: _canEdit,
                                      keyboardType: TextInputType.number,
                                      style: AppTheme.bodyMedium,
                                      decoration: InputDecoration(
                                        labelText: 'متوسط النجاح للصغار (%)',
                                        hintText: '70.0',
                                        prefixIcon: Icon(
                                          Icons.trending_up,
                                          color:
                                              _canEdit
                                                  ? AppTheme.secondaryColor
                                                  : AppTheme.textDisabledColor,
                                        ),
                                        suffixText: '%',
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
                              const SizedBox(height: AppTheme.spacingS),
                              Container(
                                padding: const EdgeInsets.all(
                                  AppTheme.spacingM,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.infoColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusM,
                                  ),
                                  border: Border.all(
                                    color: AppTheme.infoColor.withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      color: AppTheme.infoColor,
                                      size: 20,
                                    ),
                                    const SizedBox(width: AppTheme.spacingS),
                                    Expanded(
                                      child: Text(
                                        'هذه المتوسطات تحدد الحد الأدنى للنجاح في كل جولة. يجب أن تكون بين 0 و 100.',
                                        style: AppTheme.bodySmall.copyWith(
                                          color: AppTheme.infoColor,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingS),

                      // Statistiques des participants actuels
                      ModernCard(
                        child: Padding(
                          padding: const EdgeInsets.all(AppTheme.spacingS),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'إحصائيات المشاركين الحاليين',
                                style: AppTheme.headingMedium,
                              ),
                              const SizedBox(height: AppTheme.spacingS),
                              Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.all(
                                        AppTheme.spacingM,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            _participantCounts['adults']! >
                                                    int.tryParse(
                                                      _maxAdultsController.text,
                                                    )!
                                                ? AppTheme.errorColor
                                                    .withOpacity(0.1)
                                                : AppTheme.successColor
                                                    .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(
                                          AppTheme.radiusM,
                                        ),
                                        border: Border.all(
                                          color:
                                              _participantCounts['adults']! >
                                                      int.tryParse(
                                                        _maxAdultsController
                                                            .text,
                                                      )!
                                                  ? AppTheme.errorColor
                                                      .withOpacity(0.3)
                                                  : AppTheme.successColor
                                                      .withOpacity(0.3),
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          Icon(
                                            Icons.person,
                                            color:
                                                _participantCounts['adults']! >
                                                        int.tryParse(
                                                          _maxAdultsController
                                                              .text,
                                                        )!
                                                    ? AppTheme.errorColor
                                                    : AppTheme.successColor,
                                            size: 32,
                                          ),
                                          const SizedBox(
                                            height: AppTheme.spacingS,
                                          ),
                                          Text(
                                            'الكبار',
                                            style: AppTheme.labelMedium
                                                .copyWith(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${_participantCounts['adults']} / ${_maxAdultsController.text}',
                                            style: AppTheme.headingSmall.copyWith(
                                              color:
                                                  _participantCounts['adults']! >
                                                          int.tryParse(
                                                            _maxAdultsController
                                                                .text,
                                                          )!
                                                      ? AppTheme.errorColor
                                                      : AppTheme.successColor,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          if (_participantCounts['adults']! >
                                              int.tryParse(
                                                _maxAdultsController.text,
                                              )!)
                                            Text(
                                              'تجاوز الحد الأقصى!',
                                              style: AppTheme.bodySmall
                                                  .copyWith(
                                                    color: AppTheme.errorColor,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: AppTheme.spacingM),
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.all(
                                        AppTheme.spacingM,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            _participantCounts['children']! >
                                                    int.tryParse(
                                                      _maxChildrenController
                                                          .text,
                                                    )!
                                                ? AppTheme.errorColor
                                                    .withOpacity(0.1)
                                                : AppTheme.successColor
                                                    .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(
                                          AppTheme.radiusM,
                                        ),
                                        border: Border.all(
                                          color:
                                              _participantCounts['children']! >
                                                      int.tryParse(
                                                        _maxChildrenController
                                                            .text,
                                                      )!
                                                  ? AppTheme.errorColor
                                                      .withOpacity(0.3)
                                                  : AppTheme.successColor
                                                      .withOpacity(0.3),
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          Icon(
                                            Icons.child_care,
                                            color:
                                                _participantCounts['children']! >
                                                        int.tryParse(
                                                          _maxChildrenController
                                                              .text,
                                                        )!
                                                    ? AppTheme.errorColor
                                                    : AppTheme.successColor,
                                            size: 32,
                                          ),
                                          const SizedBox(
                                            height: AppTheme.spacingS,
                                          ),
                                          Text(
                                            'الصغار',
                                            style: AppTheme.labelMedium
                                                .copyWith(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${_participantCounts['children']} / ${_maxChildrenController.text}',
                                            style: AppTheme.headingSmall.copyWith(
                                              color:
                                                  _participantCounts['children']! >
                                                          int.tryParse(
                                                            _maxChildrenController
                                                                .text,
                                                          )!
                                                      ? AppTheme.errorColor
                                                      : AppTheme.successColor,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          if (_participantCounts['children']! >
                                              int.tryParse(
                                                _maxChildrenController.text,
                                              )!)
                                            Text(
                                              'تجاوز الحد الأقصى!',
                                              style: AppTheme.bodySmall
                                                  .copyWith(
                                                    color: AppTheme.errorColor,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                            ),
                                        ],
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

                              // Message d'information sur la logique des switches
                              Container(
                                padding: const EdgeInsets.all(
                                  AppTheme.spacingM,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.infoColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusM,
                                  ),
                                  border: Border.all(
                                    color: AppTheme.infoColor.withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      color: AppTheme.infoColor,
                                      size: 20,
                                    ),
                                    const SizedBox(width: AppTheme.spacingS),
                                    Expanded(
                                      child: Text(
                                        'ملاحظة: لا يمكن فتح التسجيل وتفعيل تقييم المحكمين في نفس الوقت',
                                        style: AppTheme.bodySmall.copyWith(
                                          color: AppTheme.infoColor,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: AppTheme.spacingM),

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
                                              ? (val) {
                                                setState(() {
                                                  _isRegistrationOpen = val;
                                                  // Si l'inscription est ouverte, désactiver l'évaluation des jurys
                                                  if (val) {
                                                    _juryEvaluationEnabled =
                                                        false;
                                                  }
                                                });
                                              }
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
                                              ? (val) {
                                                setState(() {
                                                  _juryEvaluationEnabled = val;
                                                  // Si l'évaluation des jurys est activée, fermer l'inscription
                                                  if (val) {
                                                    _isRegistrationOpen = false;
                                                  }
                                                });
                                              }
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
