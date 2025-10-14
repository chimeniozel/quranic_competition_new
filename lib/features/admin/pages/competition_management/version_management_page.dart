import 'package:flutter/material.dart';
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
                            prefixIcon: const Icon(Icons.child_care),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusM,
                              ),
                            ),
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

              // Boutons d'action
              Row(
                children: [
                  Expanded(
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
                      text: 'تعديل',
                      icon: Icons.edit,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingS),
                  Expanded(
                    child: SecondaryButton(
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
                                content: Text(
                                  'تم حذف النسخة "${version.name}"',
                                ),
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
                      text: 'حذف',
                      icon: Icons.delete,
                      borderColor: AppTheme.errorColor,
                      textColor: AppTheme.errorColor,
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
