import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../../core/services/competition_version_service.dart';
import '../../../../models/competition_version.dart';
import 'package:go_router/go_router.dart';
import 'package:quranic_competition/core/widgets/modern_navigation.dart';
import 'package:quranic_competition/core/widgets/ui_components.dart';
import 'package:quranic_competition/core/widgets/loading_states.dart';
import 'package:quranic_competition/core/theme/app_theme.dart';
import 'package:quranic_competition/core/widgets/modern_dashboard.dart';
import 'package:quranic_competition/core/services/confirmation_service.dart';

class VersionManagementPage extends StatefulWidget {
  const VersionManagementPage({super.key});

  @override
  State<VersionManagementPage> createState() => _VersionManagementPageState();
}

class _VersionManagementPageState extends State<VersionManagementPage> {
  final _service = CompetitionVersionService();
  final _nameController = TextEditingController();
  final _maxAdultsController = TextEditingController();
  final _maxChildrenController = TextEditingController();

  bool _isRegistrationOpen = true;
  bool _isAddingLoad = false;

  List<CompetitionVersion> _versions = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadVersions();
  }

  Future<void> _loadVersions() async {
    setState(() => _isLoading = true);
    _versions = await _service.fetchVersions();
    setState(() => _isLoading = false);
  }

  Future<void> _submitNewVersion() async {
    final name = _nameController.text.trim();
    final maxAdults = int.tryParse(_maxAdultsController.text.trim());
    final maxChildren = int.tryParse(_maxChildrenController.text.trim());

    if (name.isEmpty || maxAdults == null || maxChildren == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى ملء جميع الحقول بشكل صحيح')),
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
      );
      _nameController.clear();
      _maxAdultsController.clear();
      _maxChildrenController.clear();
      context.pop();
      setState(() {
        _isRegistrationOpen = true;
        _isAddingLoad = false;
      });

      await _loadVersions();
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
                        const SizedBox(height: AppTheme.spacingM),
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
                        const SizedBox(height: AppTheme.spacingM),
                        TextField(
                          controller: _maxChildrenController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'الحد الأقصى للصغار',
                            prefixIcon: const Icon(Icons.child_care),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusM,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacingM),
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
    return ModernCard(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingM,
        vertical: AppTheme.spacingS,
      ),
      padding: const EdgeInsets.all(AppTheme.spacingM),
      onTap: () {
        context.push('/admin/version_detail', extra: version);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Version Icon
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color:
                      version.isActive
                          ? AppTheme.successColor.withOpacity(0.1)
                          : AppTheme.errorColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                ),
                child: Icon(
                  Icons.emoji_events,
                  color:
                      version.isActive
                          ? AppTheme.successColor
                          : AppTheme.errorColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppTheme.spacingM),

              // Version Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      version.name,
                      style: AppTheme.bodyLarge.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'السنة: ${version.year}',
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'الحد الأقصى: كبار ${version.maxAdults} - صغار ${version.maxChildren}',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ),

              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color:
                      version.isActive
                          ? AppTheme.successColor.withOpacity(0.1)
                          : AppTheme.errorColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        version.isActive
                            ? AppTheme.successColor
                            : AppTheme.errorColor,
                  ),
                ),
                child: Text(
                  version.isActive ? 'نشطة' : 'منتهية',
                  style: TextStyle(
                    color:
                        version.isActive
                            ? AppTheme.successColor
                            : AppTheme.errorColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppTheme.spacingM),

          // Registration Status
          Row(
            children: [
              Icon(
                version.isRegistrationOpen ? Icons.lock_open : Icons.lock,
                color:
                    version.isRegistrationOpen
                        ? AppTheme.successColor
                        : AppTheme.errorColor,
                size: 16,
              ),
              const SizedBox(width: AppTheme.spacingS),
              Text(
                'التسجيل: ${version.isRegistrationOpen ? 'مفتوح' : 'مغلق'}',
                style: AppTheme.bodySmall.copyWith(
                  color:
                      version.isRegistrationOpen
                          ? AppTheme.successColor
                          : AppTheme.errorColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),

              // Action Buttons
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const HugeIcon(
                      icon: HugeIcons.strokeRoundedEdit03,
                      color: AppTheme.primaryColor,
                      size: 20.0,
                    ),
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
                  ),
                  IconButton(
                    icon: const HugeIcon(
                      icon: HugeIcons.strokeRoundedDelete01,
                      color: AppTheme.errorColor,
                      size: 20.0,
                    ),
                    onPressed: () async {
                      final confirmed =
                          await ConfirmationService.showDeleteConfirmation(
                            context,
                            title: 'تأكيد الحذف',
                            message: 'هل تريد حذف النسخة "${version.name}"؟',
                            confirmText: 'حذف',
                            cancelText: 'إلغاء',
                          );

                      if (confirmed) {
                        try {
                          await _service.deleteVersion(version.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('تم حذف النسخة "${version.name}"'),
                              backgroundColor: AppTheme.successColor,
                            ),
                          );
                          await _loadVersions();
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('فشل الحذف: $e'),
                              backgroundColor: AppTheme.errorColor,
                            ),
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
            ],
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
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
          ),
        ],
      ),
      floatingActionButton: ModernFAB(
        onPressed: () async {
          await showAddDialog();
          setState(() {});
        },
        icon: Icons.add,
      ),
      body:
          _isLoading
              ? const LoadingOverlay(child: SizedBox())
              : ModernPullToRefresh(
                onRefresh: _loadVersions,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppTheme.spacingM),
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
                            const SizedBox(width: AppTheme.spacingM),
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
                                    const SizedBox(height: AppTheme.spacingM),
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
