import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quranic_competition/core/services/competition_version_service.dart';
import 'package:quranic_competition/models/competition_version.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_ui.dart';
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
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadVersions();
  }

  Future<void> _loadVersions() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final versions = await _versionService.fetchVersions();
      // La version active d'abord, puis les plus récentes
      versions.sort((a, b) {
        if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
        return b.year.compareTo(a.year);
      });
      _versions = versions;
    } catch (e) {
      debugPrint('Erreur lors du chargement des versions: $e');
      _hasError = true;
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ModernAppBar(title: 'نتائج المسابقة'),
      body:
          _isLoading
              ? const ModernLoadingIndicator()
              : ModernPullToRefresh(
                onRefresh: _loadVersions,
                child:
                    _versions.isEmpty
                        // ListView pour que le geste « tirer pour actualiser »
                        // fonctionne aussi sur l'état vide ou d'erreur
                        ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            const SizedBox(height: AppTheme.spacingXL),
                            _hasError
                                ? EmptyState(
                                  icon: Icons.wifi_off_rounded,
                                  iconColor: AppTheme.errorColor,
                                  title: 'تعذر تحميل النسخ',
                                  subtitle: 'تحقق من الاتصال وحاول مجدداً',
                                  action: PrimaryButton(
                                    text: 'إعادة المحاولة',
                                    icon: Icons.refresh_rounded,
                                    onPressed: _loadVersions,
                                  ),
                                )
                                : const EmptyState(
                                  icon: Icons.event_busy_rounded,
                                  title: 'لا توجد نسخ',
                                  subtitle: 'لم يتم إنشاء أي نسخة',
                                ),
                          ],
                        )
                        : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
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
    return AppListCard(
      onTap: () => context.push('/participant/results/${version.id}'),
      highlightColor: version.isActive ? AppTheme.secondaryColor : null,
      leading: AppIconBadge(
        icon: Icons.leaderboard_rounded,
        color:
            version.isActive ? AppTheme.secondaryColor : AppTheme.primaryColor,
        size: 24,
      ),
      title: version.name,
      subtitle: 'السنة ${version.year}',
      tags: [
        if (version.isActive)
          const AppTag(
            text: 'نشطة الآن',
            color: AppTheme.secondaryColor,
            icon: Icons.circle,
          ),
        AppTag(
          text: 'مقاعد الكبار ${version.maxAdults}',
          color: AppTheme.primaryColor,
          icon: Icons.person_rounded,
        ),
        AppTag(
          text: 'مقاعد الصغار ${version.maxChildren}',
          color: AppTheme.infoColor,
          icon: Icons.child_care_rounded,
        ),
      ],
    );
  }
}
