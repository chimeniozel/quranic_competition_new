import 'package:flutter/material.dart';
import '../../../core/services/competition_version_service.dart';
import '../../../models/competition_version.dart';
import '../../../core/widgets/modern_navigation.dart';
import '../../../core/widgets/ui_components.dart';
import '../../../core/widgets/loading_states.dart';
import '../../../core/theme/app_theme.dart';
import 'package:go_router/go_router.dart';

class JuryVersionPage extends StatefulWidget {
  const JuryVersionPage({super.key});

  @override
  State<JuryVersionPage> createState() => _JuryVersionPageState();
}

class _JuryVersionPageState extends State<JuryVersionPage> {
  final _service = CompetitionVersionService();

  List<CompetitionVersion> _versions = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadVersions();
  }

  Future<void> _loadVersions() async {
    setState(() => _isLoading = true);
    _versions = await _service.fetchMyVersions();
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ModernAppBar(title: 'النسخ المحكمة من طرفي'),
      body:
          _isLoading
              ? const ModernLoadingIndicator()
              : _versions.isEmpty
              ? const EmptyState(
                icon: Icons.event_available,
                title: 'لا توجد نسخ حالياً',
                subtitle: 'لم يتم تعيين أي نسخ للتحكيم بعد',
              )
              : ModernPullToRefresh(
                onRefresh: _loadVersions,
                child: ListView.builder(
                  padding: const EdgeInsets.all(AppTheme.spacingM),
                  itemCount: _versions.length,
                  itemBuilder: (context, index) {
                    final version = _versions[index];
                    return _buildVersionCard(version);
                  },
                ),
              ),
    );
  }

  Widget _buildVersionCard(CompetitionVersion version) {
    return ModernCard(
      child: InkWell(
        onTap: () {
          context.push('/jury/version_detail_page', extra: version);
        },
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête avec icône et statut
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor:
                        version.isActive
                            ? AppTheme.successColor.withOpacity(0.1)
                            : AppTheme.textSecondaryColor.withOpacity(0.1),
                    child: Icon(
                      Icons.emoji_events,
                      color:
                          version.isActive
                              ? AppTheme.successColor
                              : AppTheme.textSecondaryColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingM),
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
                        Text(
                          'السنة: ${version.year}',
                          style: AppTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  // Badge de statut
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingM,
                      vertical: AppTheme.spacingXS,
                    ),
                    decoration: BoxDecoration(
                      color:
                          version.isActive
                              ? AppTheme.successColor.withOpacity(0.1)
                              : AppTheme.errorColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusS),
                      border: Border.all(
                        color:
                            version.isActive
                                ? AppTheme.successColor
                                : AppTheme.errorColor,
                      ),
                    ),
                    child: Text(
                      version.isActive ? 'نشطة' : 'منتهية',
                      style: AppTheme.bodySmall.copyWith(
                        color:
                            version.isActive
                                ? AppTheme.successColor
                                : AppTheme.errorColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingM),
              // Informations détaillées
              Row(
                children: [
                  Expanded(
                    child: _buildInfoChip(
                      icon: Icons.people,
                      label: 'كبار',
                      value: version.maxAdults.toString(),
                      color: AppTheme.infoColor,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingS),
                  Expanded(
                    child: _buildInfoChip(
                      icon: Icons.people,
                      label: 'صغار',
                      value: version.maxChildren.toString(),
                      color: AppTheme.secondaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingS),
              // Statut d'inscription et d'évaluation
              Row(
                children: [
                  Expanded(
                    child: _buildStatusIndicator(
                      icon: Icons.app_registration,
                      label: 'التسجيل',
                      isActive: version.isRegistrationOpen,
                      activeText: 'مفتوح',
                      inactiveText: 'مغلق',
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingS),
                  Expanded(
                    child: _buildStatusIndicator(
                      icon: Icons.rate_review,
                      label: 'التقييم',
                      isActive: version.juryEvaluationEnabled,
                      activeText: 'مفعل',
                      inactiveText: 'معطل',
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

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingS),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusS),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: AppTheme.spacingXS),
          Text(label, style: AppTheme.bodySmall.copyWith(color: color)),
          const SizedBox(width: AppTheme.spacingXS),
          Text(
            value,
            style: AppTheme.labelMedium.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator({
    required IconData icon,
    required String label,
    required bool isActive,
    required String activeText,
    required String inactiveText,
  }) {
    final statusColor =
        isActive ? AppTheme.successColor : AppTheme.textSecondaryColor;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingS),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusS),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: statusColor, size: 14),
          const SizedBox(width: AppTheme.spacingXS),
          Text(
            '$label: ',
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.textSecondaryColor,
            ),
          ),
          Text(
            isActive ? activeText : inactiveText,
            style: AppTheme.bodySmall.copyWith(
              color: statusColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
