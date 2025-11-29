import 'package:flutter/material.dart';
import 'dart:convert';
import '../../../../core/services/competition_version_service.dart';
import '../../../../core/services/push_notification_service.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../core/widgets/role_guard.dart';
import '../../../../models/competition_version.dart';
import 'package:go_router/go_router.dart';
import 'package:quranic_competition/core/widgets/modern_navigation.dart';
import 'package:quranic_competition/core/widgets/ui_components.dart';
import 'package:quranic_competition/core/widgets/loading_states.dart';
import 'package:quranic_competition/core/theme/app_theme.dart';
import 'package:quranic_competition/core/widgets/modern_dashboard.dart';

class VersionManagementPage extends StatefulWidget {
  const VersionManagementPage({super.key});

  @override
  State<VersionManagementPage> createState() => _VersionManagementPageState();
}

class _VersionManagementPageState extends State<VersionManagementPage> {
  final _service = CompetitionVersionService();
  final _permissionService = PermissionService();
  final _nameController = TextEditingController();
  final _maxAdultsController = TextEditingController();
  final _maxChildrenController = TextEditingController();
  final _successAverageAdultsController = TextEditingController();
  final _successAverageChildrenController = TextEditingController();

  bool _isRegistrationOpen = true;
  bool _isAddingLoad = false;

  List<CompetitionVersion> _versions = [];
  bool _isLoading = false;
  bool _canCreateVersions = false;
  bool _permissionsLoaded = false;

  // Vérifier si une version est active
  bool _hasActiveVersion() {
    return _versions.any((v) => v.isActive);
  }

  // Obtenir la version active
  CompetitionVersion? _getActiveVersion() {
    try {
      return _versions.firstWhere((v) => v.isActive);
    } catch (e) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _loadVersions();
  }

  Future<void> _checkPermissions() async {
    final canCreate = await _permissionService.canCreateVersions();
    if (mounted) {
      setState(() {
        _canCreateVersions = canCreate;
        _permissionsLoaded = true;
      });
    }
  }

  Future<void> _loadVersions() async {
    setState(() => _isLoading = true);
    _versions = await _service.fetchVersions();
    setState(() => _isLoading = false);
  }

  Future<void> _submitNewVersion() async {
    if (_isAddingLoad) {
      return;
    }

    // Vérifier الصلاحيات
    if (!_canCreateVersions) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('ليس لديك صلاحية إنشاء نسخ جديدة'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    // Vérifier si une version est active
    if (_hasActiveVersion()) {
      final activeVersion = _getActiveVersion();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'لا يمكن إضافة نسخة جديدة بينما النسخة "${activeVersion?.name}" نشطة. يجب إلغاء تفعيلها أولاً.',
            ),
            backgroundColor: AppTheme.warningColor,
            duration: const Duration(seconds: 4),
            action:
                activeVersion != null
                    ? SnackBarAction(
                      label: 'الإعدادات',
                      textColor: Colors.white,
                      onPressed: () async {
                        final result = await context.push<bool>(
                          '/admin/version_update',
                          extra: activeVersion,
                        );
                        if (result == true) {
                          await _loadVersions();
                          setState(() {});
                        }
                      },
                    )
                    : null,
          ),
        );
      }
      return;
    }

    final name = _nameController.text.trim();
    final maxAdults = int.tryParse(_maxAdultsController.text.trim());
    final maxChildren = int.tryParse(_maxChildrenController.text.trim());
    final successAverageAdults = double.tryParse(
      _successAverageAdultsController.text.trim(),
    );
    final successAverageChildren = double.tryParse(
      _successAverageChildrenController.text.trim(),
    );

    if (name.isEmpty ||
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

    try {
      setState(() {
        _isAddingLoad = true;
      });
      await _service.createVersion(
        name: name,
        year: DateTime.now().year,
        maxAdults: maxAdults,
        maxChildren: maxChildren,
        isRegistrationOpen: _isRegistrationOpen,
        successAverageAdults: successAverageAdults,
        successAverageChildren: successAverageChildren,
      );
      _nameController.clear();
      _maxAdultsController.clear();
      _maxChildrenController.clear();
      _successAverageAdultsController.clear();
      _successAverageChildrenController.clear();
      context.pop();
      setState(() {
        _isRegistrationOpen = true;
        _isAddingLoad = false;
      });

      await _loadVersions();

      // Notifier tous les utilisateurs de la création d'une nouvelle version
      try {
        final pushNotificationService = PushNotificationService();
        await pushNotificationService.sendNotification(
          title: '🎉 نسخة جديدة',
          body: 'تم إنشاء نسخة جديدة من مسابقة أهل القرآن الواتسابية: $name',
          type: 'success',
          payload: jsonEncode({
            'type': 'version_created',
            'version_name': name,
          }),
          // userId = NULL pour notifier tous les utilisateurs
        );
        print('✅ Notification envoyée pour la nouvelle version: $name');
      } catch (e) {
        print('❌ Erreur lors de l\'envoi de la notification: $e');
        // Ne pas bloquer l'opération si la notification échoue
      }
    } catch (e) {
      setState(() {
        _isAddingLoad = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('فشل الإضافة: $e')));
    }
  }

  Future<void> showAddDialog() async {
    // Vérifier الصلاحيات
    if (!_canCreateVersions) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('ليس لديك صلاحية إنشاء نسخ جديدة'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    // Vérifier si une version est active
    if (_hasActiveVersion()) {
      final activeVersion = _getActiveVersion();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'لا يمكن إضافة نسخة جديدة بينما النسخة "${activeVersion?.name}" نشطة. يجب إلغاء تفعيلها أولاً.',
            ),
            backgroundColor: AppTheme.warningColor,
            duration: const Duration(seconds: 4),
            action:
                activeVersion != null
                    ? SnackBarAction(
                      label: 'الإعدادات',
                      textColor: Colors.white,
                      onPressed: () async {
                        final result = await context.push<bool>(
                          '/admin/version_update',
                          extra: activeVersion,
                        );
                        if (result == true) {
                          await _loadVersions();
                          setState(() {});
                        }
                      },
                    )
                    : null,
          ),
        );
      }
      return;
    }

    showDialog(
      context: context,
      builder:
          (_) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  title: Text(
                    'إضافة نسخة جديدة',
                    style: AppTheme.headingMedium,
                  ),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: 'اسم النسخة',
                            prefixIcon: const Icon(Icons.title),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusM,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacingS),
                        TextField(
                          controller: _maxAdultsController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'الحد الأقصى للكبار',
                            prefixIcon: const Icon(Icons.people),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusM,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacingS),
                        TextField(
                          controller: _maxChildrenController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'الحد الأقصى للصغار',
                            prefixIcon: const Icon(Icons.person),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusM,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacingS),

                        // Moyennes de succès
                        Text(
                          'متوسطات النجاح',
                          style: AppTheme.labelLarge.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacingS),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _successAverageAdultsController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'متوسط النجاح للكبار (%)',
                                  hintText: '85.0',
                                  prefixIcon: const Icon(Icons.trending_up),
                                  suffixText: '%',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.radiusM,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppTheme.spacingS),
                            Expanded(
                              child: TextField(
                                controller: _successAverageChildrenController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'متوسط النجاح للصغار (%)',
                                  hintText: '14.0',
                                  prefixIcon: const Icon(Icons.trending_up),
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

                        // Message d'information
                        Container(
                          padding: const EdgeInsets.all(AppTheme.spacingS),
                          decoration: BoxDecoration(
                            color: AppTheme.infoColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusS,
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
                                size: 16,
                              ),
                              const SizedBox(width: AppTheme.spacingS),
                              Expanded(
                                child: Text(
                                  'هذه المتوسطات تحدد الحد الأدنى للنجاح في كل جولة',
                                  style: AppTheme.bodySmall.copyWith(
                                    color: AppTheme.infoColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacingS),
                        Row(
                          children: [
                            Icon(
                              _isRegistrationOpen
                                  ? Icons.lock_open
                                  : Icons.lock,
                              color:
                                  _isRegistrationOpen
                                      ? AppTheme.successColor
                                      : AppTheme.errorColor,
                            ),
                            const SizedBox(width: AppTheme.spacingS),
                            Text('فتح التسجيل', style: AppTheme.bodyMedium),
                            const Spacer(),
                            Switch(
                              value: _isRegistrationOpen,
                              onChanged: (val) {
                                setState(() => _isRegistrationOpen = val);
                              },
                              activeColor: AppTheme.primaryColor,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    SecondaryButton(
                      text: 'إلغاء',
                      onPressed: () => context.pop(),
                    ),
                    PrimaryButton(
                      text: 'إضافة',
                      onPressed: () async {
                        await _submitNewVersion();
                      },
                      isLoading: _isAddingLoad,
                    ),
                  ],
                ),
          ),
    );
    setState(() {});
  }

  Widget _buildVersionCard(CompetitionVersion version) {
    final isActive = version.isActive;
    final statusColor = isActive ? Colors.green : Colors.red;
    final statusText = isActive ? 'نشطة' : 'منتهية';
    final statusIcon = isActive ? Icons.check_circle : Icons.cancel;

    return ModernCard(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingS,
        vertical: AppTheme.spacingS,
      ),
      child: InkWell(
        onTap: () {
          context.push('/admin/version_detail', extra: version);
        },
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingS),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête avec nom et statut
              Row(
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: statusColor.withOpacity(0.1),
                    child: Icon(
                      Icons.emoji_events,
                      color: statusColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingS),
                  // Informations principales
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          version.name,
                          style: AppTheme.labelLarge.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacingXS),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 16,
                              color: AppTheme.primaryColor,
                            ),
                            const SizedBox(width: AppTheme.spacingXS),
                            Text(
                              'السنة: ${version.year}',
                              style: AppTheme.bodyMedium.copyWith(
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Statut avec icône
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingS,
                      vertical: AppTheme.spacingXS,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusS),
                      border: Border.all(color: statusColor, width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, color: statusColor, size: 16),
                        const SizedBox(width: AppTheme.spacingXS),
                        Text(
                          statusText,
                          style: AppTheme.bodySmall.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingS),

              // Informations détaillées
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppTheme.spacingS),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(AppTheme.radiusS),
                  border: Border.all(color: AppTheme.dividerColor),
                ),
                child: Column(
                  children: [
                    // Limites de participants
                    Row(
                      children: [
                        Icon(
                          Icons.people,
                          size: 18,
                          color: AppTheme.primaryColor,
                        ),
                        const SizedBox(width: AppTheme.spacingS),
                        Text(
                          'الحد الأقصى: ',
                          style: AppTheme.bodyMedium.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          'كبار ${version.maxAdults}',
                          style: AppTheme.bodyMedium.copyWith(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(' - '),
                        Text(
                          'صغار ${version.maxChildren}',
                          style: AppTheme.bodyMedium.copyWith(
                            color: Colors.purple,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacingXS),
                    // Statut d'inscription
                    Row(
                      children: [
                        Icon(
                          version.isRegistrationOpen
                              ? Icons.lock_open
                              : Icons.lock,
                          size: 18,
                          color:
                              version.isRegistrationOpen
                                  ? Colors.green
                                  : Colors.red,
                        ),
                        const SizedBox(width: AppTheme.spacingS),
                        Text(
                          'التسجيل: ',
                          style: AppTheme.bodyMedium.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          version.isRegistrationOpen ? 'مفتوح' : 'مغلق',
                          style: AppTheme.bodyMedium.copyWith(
                            color:
                                version.isRegistrationOpen
                                    ? Colors.green
                                    : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.spacingS),

              // Bouton d'action
              CanModifyVersionsGuard(
                child: SizedBox(
                  width: double.infinity,
                  child: SecondaryButton(
                    onPressed: () async {
                      final result = await context.push<bool>(
                        '/admin/version_update',
                        extra: version,
                      );

                      if (result == true) {
                        await _loadVersions();
                        setState(() {});
                      }
                    },
                    text: 'الإعدادات',
                    icon: Icons.settings,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ModernAppBar(
        title: 'إدارة النسخ',
        actions: [
          IconButton(
            onPressed: _loadVersions,
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
          ),
        ],
      ),
      floatingActionButton:
          _hasActiveVersion()
              ? Tooltip(
                message:
                    'لا يمكن إضافة نسخة جديدة بينما توجد نسخة نشطة. يجب إلغاء تفعيل النسخة النشطة أولاً.',
                child: Opacity(
                  opacity: 0.5,
                  child: ModernFAB(
                    onPressed: () async {
                      final activeVersion = _getActiveVersion();
                      if (mounted && activeVersion != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'لا يمكن إضافة نسخة جديدة بينما النسخة "${activeVersion.name}" نشطة.',
                            ),
                            backgroundColor: AppTheme.warningColor,
                            duration: const Duration(seconds: 4),
                            action: SnackBarAction(
                              label: 'الإعدادات',
                              textColor: Colors.white,
                              onPressed: () async {
                                final result = await context.push<bool>(
                                  '/admin/version_update',
                                  extra: activeVersion,
                                );
                                if (result == true) {
                                  await _loadVersions();
                                  setState(() {});
                                }
                              },
                            ),
                          ),
                        );
                      }
                    },
                    icon: Icons.add,
                  ),
                ),
              )
              : (_permissionsLoaded && _canCreateVersions)
              ? ModernFAB(
                onPressed: () async {
                  await showAddDialog();
                  setState(() {});
                },
                icon: Icons.add,
              )
              : null,
      body:
          _isLoading
              ? const LoadingOverlay(child: SizedBox())
              : ModernPullToRefresh(
                onRefresh: _loadVersions,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppTheme.spacingS),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Section
                      DashboardSection(
                        title: 'إدارة النسخ',
                        subtitle: 'إدارة نسخ المسابقة وإعداداتها',
                        child: Row(
                          children: [
                            Expanded(
                              child: StatCard(
                                title: 'إجمالي النسخ',
                                value: '${_versions.length}',
                                icon: Icons.emoji_events,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            const SizedBox(width: AppTheme.spacingS),
                            Expanded(
                              child: StatCard(
                                title: 'النسخ النشطة',
                                value:
                                    '${_versions.where((v) => v.isActive).length}',
                                icon: Icons.check_circle,
                                color: AppTheme.successColor,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: AppTheme.spacingL),

                      // Versions List
                      DashboardSection(
                        title: 'قائمة النسخ',
                        subtitle: '${_versions.length} نسخة',
                        child:
                            _versions.isEmpty
                                ? Container(
                                  height: 300,
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.emoji_events_outlined,
                                          size: 64,
                                          color: AppTheme.textSecondaryColor,
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'لا توجد نسخ حالياً',
                                          style: AppTheme.bodyLarge.copyWith(
                                            color: AppTheme.textSecondaryColor,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'ابدأ بإضافة نسخة جديدة للمسابقة',
                                          style: AppTheme.bodyMedium.copyWith(
                                            color: AppTheme.textSecondaryColor,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                : Column(
                                  children: [
                                    ..._versions.map(
                                      (version) => _buildVersionCard(version),
                                    ),
                                    const SizedBox(height: AppTheme.spacingS),
                                  ],
                                ),
                      ),

                      const SizedBox(height: AppTheme.spacingXL),
                    ],
                  ),
                ),
              ),
    );
  }
}
