import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quranic_competition/core/services/competition_version_service.dart';
import 'package:quranic_competition/models/competition_version.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/loading_states.dart';
import '../../../../core/widgets/modern_navigation.dart';
import '../../../../core/widgets/ui_components.dart';

class ParticipantResultsVersionsPage extends StatefulWidget {
  const ParticipantResultsVersionsPage({super.key});

  @override
  State<ParticipantResultsVersionsPage> createState() =>
      _ParticipantResultsVersionsPageState();
}

class _ParticipantResultsVersionsPageState
    extends State<ParticipantResultsVersionsPage> {
  final CompetitionVersionService _versionService = CompetitionVersionService();
  bool _isLoading = true;
  List<CompetitionVersion> _versions = [];

  @override
  void initState() {
    super.initState();
    _loadVersions();
  }

  Future<void> _loadVersions() async {
    setState(() => _isLoading = true);
    try {
      _versions = await _versionService.fetchVersions();
    } catch (e) {
      print('Erreur lors du chargement des versions: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('خطأ أثناء تحميل النسخ'),
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
      appBar: const ModernAppBar(title: 'اختر النسخة'),
      body:
          _isLoading
              ? const ModernLoadingIndicator()
              : ModernPullToRefresh(
                onRefresh: _loadVersions,
                child:
                    _versions.isEmpty
                        ? const EmptyState(
                          icon: Icons.event_busy,
                          title: 'لا توجد نسخ',
                          subtitle: 'لم يتم إنشاء أي نسخة',
                        )
                        : ListView.builder(
                          padding: const EdgeInsets.all(AppTheme.spacingS),
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
    final bool isActive = version.isActive;
    final Color themeColor =
        isActive ? AppTheme.successColor : AppTheme.primaryColor;

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingS),
      child: ModernCard(
        child: InkWell(
          onTap: () {
            print('🔍 Navigation vers les résultats de: ${version.name}');
            context.push('/participant/results/${version.id}');
          },
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [themeColor.withOpacity(0.05), Colors.transparent],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
            ),
            padding: const EdgeInsets.all(AppTheme.spacingS),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // En-tête avec icône et badge
                Row(
                  children: [
                    // Icône de la version
                    Container(
                      padding: const EdgeInsets.all(AppTheme.spacingS),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [themeColor, themeColor.withOpacity(0.7)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(AppTheme.radiusM),
                        boxShadow: [
                          BoxShadow(
                            color: themeColor.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.emoji_events,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingS),

                    // Nom et statut
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            version.name,
                            style: AppTheme.headingMedium.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimaryColor,
                            ),
                          ),
                          if (isActive) ...[
                            const SizedBox(height: AppTheme.spacingXS),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppTheme.spacingS,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppTheme.successColor,
                                    AppTheme.successColor.withOpacity(0.8),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusS,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.successColor.withOpacity(
                                      0.3,
                                    ),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: AppTheme.spacingXS),
                                  Text(
                                    'نشطة الآن',
                                    style: AppTheme.bodySmall.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Flèche de navigation
                    Container(
                      padding: const EdgeInsets.all(AppTheme.spacingS),
                      decoration: BoxDecoration(
                        color: themeColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.arrow_forward_ios,
                        color: themeColor,
                        size: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingS),

                // Divider
                Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        themeColor.withOpacity(0.2),
                        themeColor.withOpacity(0.05),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spacingS),

                // Informations détaillées
                Row(
                  children: [
                    // Année
                    Expanded(
                      child: _buildInfoItem(
                        icon: Icons.calendar_today,
                        label: 'السنة',
                        value: version.year.toString(),
                        color: themeColor,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 30,
                      color: AppTheme.dividerColor,
                    ),
                    // Participants كبار
                    Expanded(
                      child: _buildInfoItem(
                        icon: Icons.groups,
                        label: 'كبار',
                        value: version.maxAdults.toString(),
                        color: AppTheme.infoColor,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 30,
                      color: AppTheme.dividerColor,
                    ),
                    // Participants صغار
                    Expanded(
                      child: _buildInfoItem(
                        icon: Icons.people,
                        label: 'صغار',
                        value: version.maxChildren.toString(),
                        color: AppTheme.warningColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(AppTheme.spacingXS),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTheme.labelMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: AppTheme.bodySmall.copyWith(
            color: AppTheme.textSecondaryColor,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
