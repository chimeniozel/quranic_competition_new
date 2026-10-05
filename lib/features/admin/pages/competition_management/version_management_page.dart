import 'package:flutter/material.dart';
import 'package:quranic_competition/core/widgets/app_ui.dart';
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
  final _searchController = TextEditingController();

  bool _isRegistrationOpen = true;
  bool _isAddingLoad = false;

  List<CompetitionVersion> _versions = [];
  String _searchQuery = '';
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

  // Filtrer les versions selon la recherche
  List<CompetitionVersion> get _filteredVersions {
    if (_searchQuery.isEmpty) {
      return _versions;
    }
    final query = _searchQuery.toLowerCase();
    return _versions.where((version) {
      return version.name.toLowerCase().contains(query) ||
          version.year.toString().contains(query);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _loadVersions();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _maxAdultsController.dispose();
    _maxChildrenController.dispose();
    _successAverageAdultsController.dispose();
    _successAverageChildrenController.dispose();
    _searchController.dispose();
    super.dispose();
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
    // Au rafraîchissement, la liste reste affichée pendant le chargement
    setState(() => _isLoading = _versions.isEmpty);
    try {
      final versions = await _service.fetchVersions();
      if (!mounted) return;
      setState(() => _versions = versions);
    } catch (e) {
      debugPrint('Erreur lors du chargement des versions: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر تحميل النسخ. حاول مجدداً.'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openSettings(CompetitionVersion version) async {
    final result = await context.push<bool>(
      '/admin/version_update',
      extra: version,
    );
    if (result == true) await _loadVersions();
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
                            prefixIcon: const Icon(Icons.title_rounded),
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
                            prefixIcon: const Icon(Icons.people_rounded),
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
                            prefixIcon: const Icon(Icons.person_rounded),
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
                                  prefixIcon: const Icon(
                                    Icons.trending_up_rounded,
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
                            const SizedBox(width: AppTheme.spacingS),
                            Expanded(
                              child: TextField(
                                controller: _successAverageChildrenController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'متوسط النجاح للصغار (%)',
                                  hintText: '14.0',
                                  prefixIcon: const Icon(
                                    Icons.trending_up_rounded,
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
                                Icons.info_outline_rounded,
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
                                  ? Icons.lock_open_rounded
                                  : Icons.lock_rounded,
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
    final statusColor =
        isActive ? AppTheme.successColor : AppTheme.textSecondaryColor;

    return AppListCard(
      highlightColor: isActive ? AppTheme.successColor : null,
      onTap: () => context.push('/admin/version_detail', extra: version),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: statusColor.withOpacity(0.12),
        child: Icon(Icons.emoji_events_rounded, color: statusColor),
      ),
      title: version.name,
      subtitle: 'السنة ${version.year}',
      tags: [
        AppTag(
          text: isActive ? 'نشطة' : 'منتهية',
          color: statusColor,
          icon: isActive ? Icons.check_circle_rounded : Icons.history_rounded,
        ),
        AppTag(
          text: version.isRegistrationOpen ? 'التسجيل مفتوح' : 'التسجيل مغلق',
          color:
              version.isRegistrationOpen
                  ? AppTheme.infoColor
                  : AppTheme.errorColor,
          icon:
              version.isRegistrationOpen
                  ? Icons.lock_open_rounded
                  : Icons.lock_rounded,
        ),
        AppTag(
          text: 'كبار ${version.maxAdults} · صغار ${version.maxChildren}',
          color: AppTheme.secondaryColor,
          icon: Icons.groups_rounded,
        ),
      ],
      trailing: CanModifyVersionsGuard(
        child: IconButton(
          tooltip: 'الإعدادات',
          icon: const Icon(Icons.settings_rounded),
          color: AppTheme.primaryColor,
          onPressed: () => _openSettings(version),
        ),
      ),
    );
  }

  Widget _buildEmpty({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingXL),
      child: Column(
        children: [
          Icon(icon, size: 56, color: AppTheme.textDisabledColor),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            title,
            style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: AppTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
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
            icon: const Icon(Icons.refresh_rounded),
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
                  child: FloatingActionButton.extended(
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
                                await _openSettings(activeVersion);
                              },
                            ),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('نسخة جديدة'),
                  ),
                ),
              )
              : (_permissionsLoaded && _canCreateVersions)
              ? FloatingActionButton.extended(
                onPressed: () async {
                  await showAddDialog();
                  setState(() {});
                },
                icon: const Icon(Icons.add_rounded),
                label: const Text('نسخة جديدة'),
              )
              : null,
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ModernPullToRefresh(
                onRefresh: _loadVersions,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(AppTheme.spacingM),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: AppStatTile(
                            label: 'إجمالي النسخ',
                            value: '${_versions.length}',
                            icon: Icons.emoji_events_rounded,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(width: AppTheme.spacingS),
                        Expanded(
                          child: AppStatTile(
                            label: 'النسخ النشطة',
                            value:
                                '${_versions.where((v) => v.isActive).length}',
                            icon: Icons.check_circle_outline_rounded,
                            color: AppTheme.successColor,
                          ),
                        ),
                      ],
                    ),
                    if (_versions.isNotEmpty) ...[
                      const SizedBox(height: AppTheme.spacingM),
                      ModernSearchBar(
                        controller: _searchController,
                        hintText: 'البحث بالاسم أو السنة...',
                        onChanged:
                            (value) => setState(() => _searchQuery = value),
                        onClear: () => setState(() => _searchQuery = ''),
                        margin: EdgeInsets.zero,
                      ),
                    ],
                    const SizedBox(height: AppTheme.spacingM),
                    Text(
                      _searchQuery.isEmpty
                          ? '${_versions.length} نسخة'
                          : '${_filteredVersions.length} من ${_versions.length} نسخة',
                      style: AppTheme.labelMedium,
                    ),
                    const SizedBox(height: AppTheme.spacingS),
                    if (_versions.isEmpty)
                      _buildEmpty(
                        icon: Icons.emoji_events_rounded,
                        title: 'لا توجد نسخ حالياً',
                        subtitle: 'ابدأ بإضافة نسخة جديدة للمسابقة',
                      )
                    else if (_filteredVersions.isEmpty)
                      _buildEmpty(
                        icon: Icons.search_off_rounded,
                        title: 'لا توجد نتائج للبحث',
                        subtitle: 'جرب تغيير كلمات البحث',
                      )
                    else
                      ..._filteredVersions.map(_buildVersionCard),
                    // Espace pour ne pas masquer la dernière carte par le FAB
                    const SizedBox(height: 80),
                  ],
                ),
              ),
    );
  }
}
